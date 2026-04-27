import 'dart:async';
import 'dart:developer';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:jl_ota/ble_event_stream.dart';
import 'package:jl_ota/ble_method.dart';
import 'package:jl_ota_example/l10n/app_localizations.dart';
import 'package:jl_ota/model/device_connection.dart';
import 'package:jl_ota/model/scan_device.dart';
import 'package:jl_ota_example/utils/app_util.dart';
import 'package:provider/provider.dart';
import 'package:jl_ota/constant/ble_event_constants.dart';
import 'package:jl_ota/constant/constants.dart';
import '../data/dialog_manager.dart';
import '../dialog/loading_dialog.dart';
import '../utils/share_preference.dart';
import '../widgets/device_filter_widget.dart';
import '../widgets/connect_list.dart';
import '../utils/data_notifier.dart';

/// Device Management Page
///
/// Responsible for operations such as scanning, connecting, and disconnecting Bluetooth devices. Main functionalities include:
/// - Displaying a list of available Bluetooth devices
/// - Supporting device name filtering and search
/// - Handling device connection status changes
/// - Managing scan lifecycle
/// - Displaying connection loading status
class DevicesPage extends StatefulWidget {
  const DevicesPage({super.key});

  @override
  State<DevicesPage> createState() => _DevicesPageState();
}

class _DevicesPageState extends State<DevicesPage> with WidgetsBindingObserver {
  String _filterContent = "";
  List<ScanDevice> _devices = [];
  bool _isLoading = true;
  static const int delayMilliseconds = 500; // 定义延迟时间为500毫秒
  StreamSubscription<List<ScanDevice>>? _scanSubscription;
  StreamSubscription<DeviceConnection>? _deviceConnectionSubscription;
  StreamSubscription<Map<String, dynamic>>? _otaConnectionSubscription;
  StreamSubscription<String>? _scanStateSubscription;
  StreamSubscription? _otaStateSubscription;

  late DialogManager _dialogManager;

  static const MethodChannel _methodChannel = MethodChannel('com.jieli.ble_plugin/methods');

  /// Add a class-level variable to track the dialog state
  bool _isOtaDialogShown = false;

  /// Tracks whether the loading dialog is already shown
  bool _isDialogLoading = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _initializeApp();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          AppLocalizations.of(context)!.connect,
          style: const TextStyle(color: Color(0xFF242424), fontSize: 18, fontWeight: FontWeight.bold),
        ),
        backgroundColor: Colors.white,
        centerTitle: true,
      ),
      body: RefreshIndicator(
        onRefresh: _restartScan,
        child: Column(
          children: [
            const SizedBox(height: 10),
            DeviceFilterWidget(filterContent: _filterContent, onFilterChanged: _handleFilterChanged),
            const SizedBox(height: 10),
            Expanded(
              child: ConnectListView(devices: _filteredDevices, isShowLoading: _isLoading, onTap: _handleDeviceTapped),
            ),
          ],
        ),
      ),
    );
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // Restart scan when app resumes
    if (state == AppLifecycleState.resumed) {
      _restartScan();
    }
  }

  @override
  void dispose() {
    _cleanupResources();
    super.dispose();
  }

  /// Initialize the application by loading preferences and setting up listeners
  void _initializeApp() async {
    await _loadFilterContent();
    _setupEventListeners();
    _startScan();
    _initData();
  }

  /// Load filter content from shared preferences
  Future<void> _loadFilterContent() async {
    try {
      final content = await FilePreferenceManager.loadFilterContent();
      if (mounted) {
        setState(() {
          _filterContent = content;
        });
      }
    } catch (e) {
      log("Failed to load filter content: $e");
    }
  }

  /// Set up all event listeners for Bluetooth events
  void _setupEventListeners() {
    _subscribeToScanListStream();
    _subscribeToScanStateStream();
    _subscribeToDeviceConnectionStream();
    _subscribeToOtaConnectionStream();
    _subscribeToOtaStateStream();
  }

  /// Clean up resources when the widget is disposed
  void _cleanupResources() {
    _scanSubscription?.cancel();
    _deviceConnectionSubscription?.cancel();
    _otaConnectionSubscription?.cancel();
    _scanStateSubscription?.cancel();
    _otaStateSubscription?.cancel();

    BleMethod.stopScan();

    WidgetsBinding.instance.removeObserver(this);
  }

  List<ScanDevice> convertToScanDeviceList(List<dynamic> list) {
    return list.map((item) {
      if (item is ScanDevice) {
        return item;
      } else if (item is Map) {
        return ScanDevice.fromMap(item);
      } else {
        throw Exception('无法转换的类型: ${item.runtimeType}');
      }
    }).toList();
  }

  /// Subscribe to scan list changes
  void _subscribeToScanListStream() {
    _scanSubscription =
        BleEventStream.scanDeviceListStream.listen((devices) {
              setState(() => _devices = convertToScanDeviceList(devices));
            })
            as StreamSubscription<List<ScanDevice>>?;
  }

  /// Subscribe to scan state changes
  void _subscribeToScanStateStream() {
    _scanStateSubscription = BleEventStream.scanStateStream.listen(
      (state) {
        if (!mounted) return;

        setState(() {
          if (state == BleEventConstants.SCAN_STATE_SCANNING) {
            _isLoading = true;
          } else if (state == BleEventConstants.SCAN_STATE_IDLE) {
            _isLoading = false;
          }
        });
      },
      onError: (error) {
        log("Scan state stream error: $error");
      },
    );
  }

  /// Restart the device scanning process
  Future<void> _restartScan() async {
    _stopScan();
    _startScan();

    Future.delayed(Duration(milliseconds: delayMilliseconds), () {
      if (mounted) {
        setState(() {
          _isLoading = true; // Set loading to true
        });
      }
    });
  }

  /// Stop the current scan
  Future<void> _stopScan() async {
    try {
      await BleMethod.stopScan();
    } catch (e) {
      log("Failed to stop scan: $e");
    }
  }

  /// Start scanning for Bluetooth devices
  void _startScan() async {
    if (!mounted) return;
    await BleMethod.startScan();
  }

  /// Init data
  void _initData() {
    _dialogManager = DialogManager(context: context, methodChannel: _methodChannel);
  }

  /// Subscribe to device connection state changes
  void _subscribeToDeviceConnectionStream() {
    _deviceConnectionSubscription =
        BleEventStream.deviceConnectionStream.listen(
              (connection) async {
                switch (connection.state) {
                  case AppConstants.connectionDisconnect:
                    log("[device page] device connection state: ${connection.state}, disconnect");
                    break;
                  case AppConstants.connectionOK:
                    log("[device page] device connection state: ${connection.state}, connected");
                    break;
                  case AppConstants.connectionFailed:
                    log("[device page] device connection state: ${connection.state}, connect failed");
                    break;
                  case AppConstants.connectionConnecting:
                    log("[device page] device connection state: ${connection.state}, connecting");
                    break;
                  default:
                }

                if (connection.state == AppConstants.connectionConnecting) {
                  // Show loading dialog when the device is connecting
                  if (mounted && !_isDialogLoading) {
                    await LoadingDialog.showLoadingDialog(context, timeoutSeconds: 15); // timeoutSeconds: 15 seconds timeout
                    _isDialogLoading = true; // Mark that the loading dialog is shown
                  }
                } else {
                  // Dismiss the loading dialog if it is visible
                  if (mounted && Navigator.canPop(context)) {
                    await LoadingDialog.hideLoadingDialog();
                  }
                  _isDialogLoading = false; // Reset the connection status
                }
              },
              onError: (error) {
                log("Device connection stream error: $error");
              },
            )
            as StreamSubscription<DeviceConnection>?;
  }

  /// Get filtered list of devices based on search content, ensuring no duplicates
  List<ScanDevice> get _filteredDevices {
    // Use a Map to remove duplicates by MAC address
    final Map<String, ScanDevice> uniqueDevices = {};

    for (final device in _devices) {
      // Try to extract MAC address from device description
      final address = _extractAddressFromDescription(device.description);

      // Use MAC address as key if available, otherwise fall back to device name
      final key = address ?? device.name;

      // Only add the device if we haven't seen it before, or if this instance is more recent
      if (!uniqueDevices.containsKey(key)) {
        uniqueDevices[key] = device;
      }
    }

    // Convert back to list
    final distinctDevices = uniqueDevices.values.toList();

    // Apply filter if needed
    if (_filterContent.isEmpty) return distinctDevices;

    return distinctDevices.where((device) {
      return device.name.toLowerCase().contains(_filterContent.toLowerCase());
    }).toList();
  }

  /// Handle filter content changes
  void _handleFilterChanged(String value) {
    setState(() {
      _filterContent = value;
    });
  }

  /// Extracts the MAC address from a device description string.
  String? _extractAddressFromDescription(String description) {
    const addressGroupName = 'address';
    const macAddressPattern = r'[0-9A-Fa-f:]+';
    final addressPattern = RegExp('$addressGroupName: ($macAddressPattern)');
    final match = addressPattern.firstMatch(description);
    return match?.group(RegexCaptureGroups.address);
  }

  /// Handle device tap events (connect/disconnect)
  void _handleDeviceTapped(ScanDevice device) {
    // Try to extract address first
    final deviceAddress = _extractAddressFromDescription(device.description);

    log('deviceAddress: $deviceAddress, device description: ${device.description}');

    int index;

    if (deviceAddress != null) {
      // Use address for matching if available
      index = _devices.indexWhere((d) {
        final dAddress = _extractAddressFromDescription(d.description);
        return dAddress == deviceAddress;
      });
    } else {
      // Use device description directly as a unique identifier for matching
      index = _devices.indexWhere((d) => d.description == device.description);
    }

    if (index == -1) return;

    if (device.isOnline) {
      _disconnectBtDevice(index);
    } else {
      _connectToDevice(index);
    }
  }

  /// Connect to a device at the specified index
  void _connectToDevice(int index) async {
    try {
      await BleMethod.connectDevice(index);
    } catch (e) {
      log("Failed to connect to device: $e");
      // Optionally show an error message to the user
    }
  }

  /// Disconnect from a device at the specified index
  void _disconnectBtDevice(int index) async {
    try {
      await BleMethod.disconnectBtDevice(index);
    } catch (e) {
      log("Failed to disconnect from device: $e");
      // Optionally show an error message to the user
    }
  }

  /// Subscribe to OTA connection events
  void _subscribeToOtaConnectionStream() {
    _otaConnectionSubscription = BleEventStream.otaConnectionStream.listen(
      (otaData) {
        if (mounted) {
          // 更新状态数据回调=》通知到弹窗进度里面
          log("[device page] OTA connection ota data: $otaData, notify dialog");
          Provider.of<DataNotifier>(context, listen: false).setOtaData(otaData);
        }
      },
      onError: (error) {
        log("[device page] OTA connection stream error: $error");
      },
    );
  }

  /// Subscribe to OTA state
  void _subscribeToOtaStateStream() {
    if (AppUtil.isIOS) {
      _otaStateSubscription = BleEventStream.otaStateStream.listen((otaData) {
        switch (otaData[BleEventConstants.KEY_STATE]) {
          /// 初始状态
          case BleEventConstants.KEY_STATE_IDLE:
            log("[device page] ota state: ${otaData[BleEventConstants.KEY_STATE]}, idle");
            break;

          /// 正在检查文件的类型
          case BleEventConstants.KEY_CHECK_FILE:
            log("[device page] ota state: ${otaData[BleEventConstants.KEY_STATE]}, checking file");
            break;

          /// 表示OTA的开始状态
          case BleEventConstants.KEY_STATE_START:
            log("[device page] ota state: ${otaData[BleEventConstants.KEY_STATE]}, start");
            break;

          /// 表示OTA的重新连接状态
          case BleEventConstants.KEY_STATE_RECONNECT:
            log("[device page] ota state: ${otaData[BleEventConstants.KEY_STATE]}, reconnect");
            break;

          /// 表示OTA的工作状态
          case BleEventConstants.KEY_STATE_WORKING:
            log("[device page] ota state: ${otaData[BleEventConstants.KEY_STATE]}, working");
            break;

          /// 用于在事件数据中标识进度信息的键。
          case BleEventConstants.KEY_PROGRESS:
            log("[device page] ota state: ${otaData[BleEventConstants.KEY_STATE]}, progress ${otaData[BleEventConstants.KEY_PROGRESS]}");
            break;

          /// 正在升级的类型
          case BleEventConstants.KEY_UPGRADING:
            log("[device page] ota state: ${otaData[BleEventConstants.KEY_STATE]}, upgrading");
            break;

          /// 未知错误
          case BleEventConstants.KEY_STATE_UNKNOWN:
            log("[device page] ota state: ${otaData[BleEventConstants.KEY_STATE]}, unknown");
            break;
          default:
        }
        if (mounted) {
          setState(() {
            updateOtaState(otaData);
          });
        }
      });
    }
  }

  /// Update OTA state
  void updateOtaState(Map<String, dynamic> otaData) {
    if (!mounted) return;

    final newOtaState = otaData[BleEventConstants.KEY_STATE] as String? ?? BleEventConstants.KEY_STATE_UNKNOWN;

    // Handle data for different states
    switch (newOtaState) {
      case BleEventConstants.KEY_STATE_WORKING:
        // Only show dialog if it hasn't been shown yet
        if (!_isOtaDialogShown) {
          setState(() {
            _isOtaDialogShown = true;
          });

          // Asynchronous operations are placed outside of setState
          _dialogManager.showOtaDialog().then((_) {
            if (mounted) {
              setState(() {
                _isOtaDialogShown = false;
              });
            }
          });
        }
        break;
    }
  }
}

class RegexCaptureGroups {
  static const int address = 1; // Define index constant
}
