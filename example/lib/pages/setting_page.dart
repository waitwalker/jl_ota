import 'dart:async';
import 'package:flutter/material.dart';
import 'package:jl_ota/ble_method.dart';
import 'package:jl_ota/constant/constants.dart';
import 'package:jl_ota_example/pages/file_list_page.dart';
import 'package:jl_ota_example/pages/about_page.dart';
import 'package:jl_ota_example/dialog/mtu_adjustment_dialog.dart';
import 'package:jl_ota_example/l10n/app_localizations.dart';
import 'package:jl_ota_example/pages/service_uuid_input_page.dart';
import 'package:jl_ota_example/utils/app_util.dart';
import 'package:jl_ota_example/widgets/toast_utils.dart';
import 'package:provider/provider.dart';
import '../data/setting_manager.dart';
import '../dialog/generic_confirm_dialog.dart';
import '../utils/connection_state_manager.dart';
import '../widgets/setting_components.dart';
import '../widgets/setting_navigation_row_widget.dart';
import 'custom_cmd_page.dart';

/// Settings Page
///
/// Provides various application configuration options, including:
/// - Toggle settings for device authentication, HID devices, custom reconnection, etc.
/// - BLE/SPP communication mode selection
/// - MTU size adjustment
/// - Log file access
/// - Version information viewing
/// - About application information
class SettingPage extends StatefulWidget {
  const SettingPage({super.key});

  @override
  State<SettingPage> createState() => _SettingPageState();
}

class _SettingPageState extends State<SettingPage> {
  // Scroll controller for auto-scrolling
  final ScrollController _scrollController = ScrollController();

  // State variables
  String _logFileDirPath = "";
  int _currentCommunicationMethod = AppConstants.communicationWayBle;
  String _sdkVersion = "unknown";
  String _appVersion = "unknown";

  bool _isDeviceAuthenticated = false;
  bool _isHidDevice = false;
  bool _customReconnectMethod = false;
  bool _connectUsingSdkBluetooth = false;
  bool _isGattOverEdr = false;
  List<String> _gattServiceUuids = [];
  int _mtu = 0;

  // Initial value tracking
  bool _initialDeviceAuthenticated = false;
  bool _initialHidDevice = false;
  bool _initialCustomReconnectMethod = false;
  bool _initialConnectUsingSdkBluetooth = false;
  bool _initialGattOverEdr = false;
  int _initialCommunicationMethod = AppConstants.communicationWayBle;
  int _initialMtu = 0;

  bool get isBleEnabled => _currentCommunicationMethod == AppConstants.communicationWayBle;

  bool get isUsingSdkBluetooth => _connectUsingSdkBluetooth;

  String get mtuDisplay => _mtu > 0 ? _mtu.toString() : '';

  // Define color constants
  static const Color primaryColor = Color(0xFF628DFF);
  static const Color disabledColor = Color(0xFF838383);
  static const Color darkTextColor = Color(0xFF242424);
  static const Color lightTextColor = Color(0xFF6F6F6F);
  static const Color dividerColor = Color(0x0A000000);

  // Define MTU minimum and maximum values
  static const int minMtu = 23;
  static const int maxMtu = 509;

  static const String defaultServiceUuid = 'AE00';

  int _connectState = AppConstants.connectionFailed;

  @override
  void initState() {
    super.initState();
    _initialize();
  }

  @override
  Widget build(BuildContext context) {
    final loc = AppLocalizations.of(context)!;
    final isAndroid = AppUtil.isAndroid;

    _connectState = context.watch<ConnectionStateManager>().connectState;

    // Check if any settings have been modified
    final bool hasChanges = _hasSettingsChanged();

    return Scaffold(
      appBar: AppBar(
        title: Text(
          loc.settings,
          style: const TextStyle(color: darkTextColor, fontSize: 18, fontWeight: FontWeight.bold),
        ),
        backgroundColor: Colors.white,
        centerTitle: true,
        elevation: 0,
        // Remove default shadow below AppBar
        scrolledUnderElevation: 0,
        // Prevent shadow from appearing when scrolling content
        surfaceTintColor: Colors.white,
        // Ensure the surface tint color remains white
        actions: [
          TextButton(
            onPressed: hasChanges ? () => _onSavePressed(isAndroid) : null,
            child: Text(
              loc.save,
              style: TextStyle(color: hasChanges ? primaryColor : disabledColor, fontSize: 15, fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
      body: SingleChildScrollView(
        controller: _scrollController,
        child: Column(
          children: [
            // Log path hint
            Padding(
              padding: const EdgeInsets.only(left: 20, right: 20, top: 12),
              child: isAndroid
                  ? Center(
                      child: Text(
                        _logFileDirPath,
                        style: TextStyle(color: lightTextColor, fontSize: 13, fontFamily: 'PingFangSC'),
                      ),
                    )
                  : SizedBox(
                      width: double.infinity,
                      child: Text(
                        _logFileDirPath,
                        textAlign: TextAlign.left,
                        style: TextStyle(color: lightTextColor, fontSize: 13, fontFamily: 'PingFangSC'),
                      ),
                    ),
            ),

            // Device authentication settings
            SettingSection(
              children: [
                SettingSwitchRow(
                  title: loc.deviceAuthentication,
                  value: _isDeviceAuthenticated,
                  onChanged: (value) => _updateState(() => _isDeviceAuthenticated = value),
                ),
              ],
            ),

            // Android-specific settings
            if (isAndroid) ...[
              SettingSection(
                children: [
                  SettingSwitchRow(title: loc.hidDevice, value: _isHidDevice, onChanged: (value) => _updateState(() => _isHidDevice = value)),
                ],
              ),

              SettingSection(
                children: [
                  SettingSwitchRow(
                    title: loc.customReconnectMethod,
                    value: _customReconnectMethod,
                    onChanged: (value) => _updateState(() => _customReconnectMethod = value),
                  ),
                ],
              ),

              // Communication method selection
              SettingSection(
                title: loc.currentCommunicationMethod,
                children: [
                  _buildCommunicationOptionBle(loc),
                  const Divider(height: 1, indent: 20, color: dividerColor),
                  _buildCommunicationOptionSpp(loc),
                  const Divider(height: 1, indent: 20, color: dividerColor),
                  _buildCommunicationOptionGatt(loc),
                ],
              ),

              // MTU adjustment
              SettingSection(
                children: [
                  Opacity(
                    opacity: isBleEnabled ? 1.0 : 0.5,
                    // 启用时完全不透明(1.0)，禁用时半透明(0.5)
                    child: SettingNavigationRow(
                      title: loc.adjustMtu,
                      subtitle: mtuDisplay,
                      onTap: isBleEnabled
                          ? () {
                              if (_connectState == AppConstants.connectionDisconnect && mounted) {
                                ToastUtils.show(context, loc.bluetoothDisconnected);
                              } else {
                                showMtuAdjustmentDialog(context);
                              }
                            }
                          : null,
                    ),
                  ),
                ],
              ),
            ],

            // iOS-specific settings
            if (!isAndroid) ...[
              SettingSection(
                children: [
                  SettingSwitchRow(
                    title: loc.connectUsingSdkBluetooth,
                    value: _connectUsingSdkBluetooth,
                    onChanged: (value) => _updateState(() => _connectUsingSdkBluetooth = value),
                  ),
                ],
              ),
              SettingSection(
                children: [
                  SettingSwitchRow(
                    title: loc.communicationWayGatt,
                    value: _isGattOverEdr,
                    onChanged: (gattOverEdrState) {
                      if (gattOverEdrState) openUuidSettings(context);
                      _updateState(() => _isGattOverEdr = gattOverEdrState);
                    },
                  ),
                ],
              ),
            ],

            // Log file access
            SettingSection(
              children: [
                SettingNavigationRow(
                  title: loc.logFile,
                  onTap: () {
                    if (_connectState == AppConstants.connectionDisconnect && mounted) {
                      ToastUtils.show(context, loc.bluetoothDisconnected);
                    } else {
                      Navigator.push(context, MaterialPageRoute(builder: (context) => const FileListPage()));
                    }
                  },
                ),
              ],
            ),

            // Version information
            SettingSection(
              children: [SettingNavigationRow(title: loc.sdkVersion, subtitle: _sdkVersion, onTap: () {}, showArrow: false)],
            ),

            // Custom command
            SettingSection(
              children: [
                Opacity(
                  opacity: isAndroid ? 1.0 : (isUsingSdkBluetooth ? 1.0 : 0.5),
                  // 启用时完全不透明(1.0)，禁用时半透明(0.5)
                  child: SettingNavigationRow(title: loc.customCommand, onTap: _onCustomCmdTap(isAndroid, loc)),
                ),
              ],
            ),

            // About application
            SettingSection(
              children: [
                SettingNavigationRow(
                  title: loc.aboutApp,
                  subtitle: _appVersion,
                  onTap: () => Navigator.push(context, MaterialPageRoute(builder: (context) => const AboutPage())),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  /// Builds BLE communication option
  Widget _buildCommunicationOptionBle(AppLocalizations loc) {
    return CommunicationOption(
      title: loc.communicationWayBle,
      isSelected: _currentCommunicationMethod == AppConstants.communicationWayBle,
      onTap: () => _updateState(() => _currentCommunicationMethod = AppConstants.communicationWayBle),
    );
  }

  /// Builds SPP communication option
  Widget _buildCommunicationOptionSpp(AppLocalizations loc) {
    return CommunicationOption(
      title: loc.communicationWaySpp,
      isSelected: _currentCommunicationMethod == AppConstants.communicationWaySpp,
      onTap: () => _updateState(() => _currentCommunicationMethod = AppConstants.communicationWaySpp),
    );
  }

  /// Builds GATT communication option
  Widget _buildCommunicationOptionGatt(AppLocalizations loc) {
    return CommunicationOption(
      title: loc.communicationWayGatt,
      isSelected: _currentCommunicationMethod == AppConstants.communicationWayGattOverBrEdr,
      onTap: () => _updateState(() => _currentCommunicationMethod = AppConstants.communicationWayGattOverBrEdr),
    );
  }

  VoidCallback? _onCustomCmdTap(bool isAndroid, AppLocalizations loc) {
    return (isAndroid || isUsingSdkBluetooth) ? () => _navigateToCustomCmd(loc) : null;
  }

  void _navigateToCustomCmd(AppLocalizations loc) {
    if (_connectState == AppConstants.connectionDisconnect) {
      ToastUtils.show(context, loc.bluetoothDisconnected);
      return;
    }
    Navigator.push(context, MaterialPageRoute(builder: (context) => const CustomCmdPage()));
  }

  // Auto-scroll to bottom after the first frame
  void _autoScrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.jumpTo(_scrollController.position.maxScrollExtent);
      }
    });
  }

  // Check if settings have changed
  bool _hasSettingsChanged() {
    final current = (
      _isDeviceAuthenticated,
      _isHidDevice,
      _customReconnectMethod,
      _connectUsingSdkBluetooth,
      _isGattOverEdr,
      _currentCommunicationMethod,
      _mtu,
    );

    final initial = (
      _initialDeviceAuthenticated,
      _initialHidDevice,
      _initialCustomReconnectMethod,
      _initialConnectUsingSdkBluetooth,
      _initialGattOverEdr,
      _initialCommunicationMethod,
      _initialMtu,
    );

    return current != initial;
  }

  // Initialize data
  Future<void> _initialize() async {
    // Load data in parallel to improve performance
    await Future.wait([
      _loadLogPath(),
      _loadAuthStatus(),
      _loadVersions(),
      if (AppUtil.isAndroid) _loadAndroidSettings(),
      if (AppUtil.isIOS) _loadIOSSettings(),
    ]);

    // Auto-scroll to bottom after data is loaded
    _autoScrollToBottom();
  }

  // Load log path
  Future<void> _loadLogPath() async {
    final path = await SettingManager.getLogDirPath();
    setState(() {
      _logFileDirPath = "${AppLocalizations.of(context)!.logLocation}$path";
    });
  }

  // Load authentication status
  Future<void> _loadAuthStatus() async {
    final isAuth = await SettingManager.loadDeviceAuth();
    setState(() {
      _isDeviceAuthenticated = isAuth;
      _initialDeviceAuthenticated = isAuth;
    });
  }

  // Load version information
  Future<void> _loadVersions() async {
    final versions = await SettingManager.getVersions();
    setState(() {
      _sdkVersion = versions[AppConstants.sdkName]!;
      _appVersion = versions[AppConstants.appName]!;
    });
  }

  // Load Android-specific settings
  Future<void> _loadAndroidSettings() async {
    final List<Object?> results = await Future.wait([
      SettingManager.loadHidDevice(),
      SettingManager.loadCustomReconnect(),
      SettingManager.loadCommunicationMethod(),
      SettingManager.loadMtu(),
    ]);

    final bool isHid = results[0] as bool;
    final bool customReconnect = results[1] as bool;
    final int commMethod = results[2] as int;
    final int mtu = results[3] as int;

    setState(() {
      _isHidDevice = isHid;
      _customReconnectMethod = customReconnect;
      _currentCommunicationMethod = commMethod;
      _mtu = mtu;

      // Save initial values
      _initialHidDevice = isHid;
      _initialCustomReconnectMethod = customReconnect;
      _initialCommunicationMethod = commMethod;
      _initialMtu = mtu;
    });
  }

  // Load iOS-specific settings
  Future<void> _loadIOSSettings() async {
    final useSdkBt = await SettingManager.loadSdkBluetooth();
    final useGattOverEdr = await SettingManager.isUseGattOverEdr();

    setState(() {
      _connectUsingSdkBluetooth = useSdkBt;
      _initialConnectUsingSdkBluetooth = useSdkBt;
      _isGattOverEdr = useGattOverEdr;
      _initialGattOverEdr = useGattOverEdr;
    });
  }

  // Unified state update method
  void _updateState(VoidCallback update) {
    setState(() {
      update();
    });
  }

  // Save settings
  Future<void> _onSavePressed(bool isAndroid) async {
    if (!_hasSettingsChanged()) return;

    await context.showConfirmDialog(
      message: AppLocalizations.of(context)!.saveAndRestartMessage,
      cancelText: AppLocalizations.of(context)!.cancel,
      confirmText: AppLocalizations.of(context)!.restart,
      onCancel: () {
        ToastUtils.show(context, AppLocalizations.of(context)!.failedToSaveSettings);
      },
      onConfirm: () async {
        await SettingManager.saveSettings(
          isAndroid: isAndroid,
          deviceAuth: _isDeviceAuthenticated,
          hidDevice: _isHidDevice,
          customReconnect: _customReconnectMethod,
          communicationMethod: _currentCommunicationMethod,
          mtu: _mtu,
          useSdkBluetooth: _connectUsingSdkBluetooth,
          gattOverEdr: _isGattOverEdr,
          gattServiceUuids: _gattServiceUuids,
        );

        // Update initial values to current values
        setState(() {
          _initialDeviceAuthenticated = _isDeviceAuthenticated;
          _initialHidDevice = _isHidDevice;
          _initialCustomReconnectMethod = _customReconnectMethod;
          _initialConnectUsingSdkBluetooth = _connectUsingSdkBluetooth;
          _initialGattOverEdr = _isGattOverEdr;
          _initialCommunicationMethod = _currentCommunicationMethod;
          _initialMtu = _mtu;
        });
      },
    );
  }

  // Show MTU adjustment dialog
  void showMtuAdjustmentDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => MtuAdjustmentDialog(
        currentMtu: _mtu,
        minMtu: minMtu,
        maxMtu: maxMtu,
        onMtuSelected: (selectedMtu) => _updateState(() => _mtu = selectedMtu),
      ),
    );
  }

  Future<void> openUuidSettings(BuildContext context) async {
    final savedUUIDs = await BleMethod.getGattServiceUuids();

    if (!context.mounted) return;

    final initialUUIDs = savedUUIDs.isEmpty ? [defaultServiceUuid] : savedUUIDs;

    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (ctx) => ServiceUUIDInputPage(
          initialUUIDs: initialUUIDs,
          onSave: (gattServiceUuids) {
            _gattServiceUuids = gattServiceUuids;
          },
        ),
      ),
    );
  }
}
