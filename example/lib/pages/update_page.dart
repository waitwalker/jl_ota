import 'dart:async';
import 'dart:developer';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:jl_ota/ble_event_stream.dart';
import 'package:jl_ota/ble_method.dart';
import 'package:jl_ota/constant/ble_event_constants.dart';
import 'package:jl_ota/constant/constants.dart';
import 'package:jl_ota_example/extensions/hex_color.dart';
import 'package:jl_ota_example/pages/file_share_page.dart';
import 'package:jl_ota_example/pages/qr_code_page.dart';
import 'package:jl_ota_example/utils/app_util.dart';
import 'package:jl_ota_example/widgets/toast_utils.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:provider/provider.dart';

import '../data/ota_connection_manager.dart';
import '../data/dialog_manager.dart';
import '../data/ota_file_manager.dart';
import '../data/popup_menu_manager.dart';
import '../l10n/app_localizations.dart';
import '../utils/share_preference.dart';
import '../widgets/ota_file_list.dart';
import '../utils/data_notifier.dart';

/// Firmware Update Page
///
/// This page is one of the core functional modules of the application, primarily responsible for device firmware update functionality.
/// Main features include:
/// 1. Displaying the current device connection status and type
/// 2. Providing file selection options (local add, computer transfer, scan-to-download)
/// 3. Managing OTA file list (view, select, delete)
/// 4. Executing firmware update operations
/// 5. Interacting with the native platform for file operations
class UpdatePage extends StatefulWidget {
  const UpdatePage({super.key});

  @override
  State<UpdatePage> createState() => _UpdatePageState();
}

class _UpdatePageState extends State<UpdatePage> {
  late int _state = AppConstants.connectionDisconnect;
  late String _deviceType = '';
  List<Map<String, String>> _otaFileList = []; // 用于存储文件列表
  String? _selectedFilePath; // 用于存储当前选中的文件路径
  final GlobalKey _addFileButtonKey = GlobalKey();
  Map<String, dynamic>? _otaData;

  bool _isStorageEnvironmentChecked = false;
  bool _isOtaStarted = false;
  bool _isInitialDataLoaded = false;

  static const MethodChannel _methodChannel = MethodChannel('com.jieli.ble_plugin/methods');
  StreamSubscription<List<Map<String, String>>>? _otaFileListSubscription;

  late OtaFileManager _otaFileManager;
  late DialogManager _dialogManager;
  late PopupMenuManager _popupMenuManager;
  late OtaConnectionManager _otaConnectionManager;

  bool _hasCameraPermission = false;
  bool _hasGalleryPermission = false;

  @override
  void initState() {
    super.initState();
    _initializeManagers();
    _initialize();
    _methodChannel.setMethodCallHandler(_handleMethodCall);
    FilePreferenceManager.loadOtaPath().then((path) {
      setState(() {
        _selectedFilePath = path;
      });
    });
  }

  void _initializeManagers() {
    _otaFileManager = OtaFileManager(
      otaFileList: _otaFileList,
      onFileListUpdated: (newList) {
        setState(() {
          _otaFileList = newList;
        });
      },
      onSelectedFileChanged: (filePath) {
        setState(() {
          if (_selectedFilePath == filePath) {
            _selectedFilePath = null;
          }
        });
      },
    );

    _dialogManager = DialogManager(context: context, methodChannel: _methodChannel);

    _popupMenuManager = PopupMenuManager();

    _otaConnectionManager = OtaConnectionManager(onOtaDataCleaned: _cleanOtaData);
  }

  @override
  Widget build(BuildContext context) {
    final loc = AppLocalizations.of(context)!;
    _otaData = Provider.of<DataNotifier>(context).otaData;
    final isAndroid = AppUtil.isAndroid;

    if (!_isOtaStarted && _otaData != null && _otaData!.isNotEmpty) {
      _state = _otaData?[BleEventConstants.KEY_STATE] ?? 0;
      _deviceType = _otaData?[BleEventConstants.KEY_DEVICE_TYPE] ?? '';
      if (_state == AppConstants.connectionDisconnect) {
        _deviceType = '';
      }
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(
          loc.update,
          style: TextStyle(color: Color(0xFF242424), fontSize: 18, fontWeight: FontWeight.bold),
        ),
        backgroundColor: Colors.white,
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.only(left: 24, top: 20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text.rich(
                    TextSpan(
                      children: [
                        TextSpan(
                          text: '${loc.deviceStatus}：',
                          style: TextStyle(fontSize: 15, color: HexColor.hexColor("#242424"), fontWeight: FontWeight.bold),
                        ),
                        TextSpan(
                          text: _state == AppConstants.connectionOK ? loc.connected : loc.disconnected,
                          style: TextStyle(fontSize: 15, color: HexColor.hexColor("#628DFF"), fontWeight: FontWeight.bold),
                        ),
                      ],
                    ),
                  ),
                  SizedBox(height: 10),
                  Text(
                    '${loc.deviceType}：$_deviceType',
                    style: TextStyle(fontSize: 15, color: HexColor.hexColor("#242424"), fontWeight: FontWeight.bold),
                  ),
                ],
              ),
            ),
            SizedBox(height: 17),
            Container(
              width: MediaQuery.of(context).size.width - 32,
              decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(8)),
              margin: const EdgeInsets.symmetric(horizontal: 16),
              child: Column(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    margin: EdgeInsets.only(top: 16),
                    color: HexColor.hexColor("#FFFFFF"),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          loc.fileSelection,
                          style: TextStyle(fontSize: 15, color: HexColor.hexColor("#242424"), fontWeight: FontWeight.bold),
                        ),
                        InkWell(
                          key: _addFileButtonKey,
                          onTap: () {
                            if (!_isStorageEnvironmentChecked && isAndroid) {
                              _checkStorageEnvironment();
                              return;
                            }
                            _popupMenuManager.removeAddFilePopupMenu();

                            _popupMenuManager.showAddFilePopupMenu(
                              context: context,
                              buttonKey: _addFileButtonKey,
                              onLocalAdd: _handleLocalAdd,
                              onComputerTransfer: _handleComputerTransfer,
                              onScanDownload: _handleScanDownload,
                            );
                          },
                          child: Image.asset('assets/images/ic_add_file.png', width: 24, height: 24),
                        ),
                      ],
                    ),
                  ),
                  if (_isInitialDataLoaded && _otaFileList.isEmpty)
                    Container(
                      height: 170,
                      margin: EdgeInsets.only(top: 40, bottom: 63),
                      child: Image.asset('assets/images/img_empty_folder.png', width: 154, height: 106),
                    )
                  else
                    OtaFileListView(
                      otaFileList: _otaFileList,
                      selectedFilePath: _selectedFilePath,
                      onFileSelected: (filePath) {
                        FilePreferenceManager.saveOtaPath(filePath);
                        setState(() {
                          _selectedFilePath = filePath;
                        });
                      },
                      onFileLongPressed: _showLongClickPopupMenu,
                      popupMenuManager: _popupMenuManager,
                      onDeleteFile: _deleteFile,
                    ),
                ],
              ),
            ),
            Visibility(
              //visible: !_otaState,
              child: Container(
                margin: EdgeInsets.only(top: 45, left: 16, right: 16),
                child: ElevatedButton(
                  onPressed: _state == AppConstants.connectionOK
                      ? () {
                          if (_otaFileList.isEmpty) {
                            ToastUtils.show(context, loc.selectUpgradeFile);
                            return;
                          }
                          _handleStartOta();
                        }
                      : null,
                  style: ElevatedButton.styleFrom(
                    minimumSize: Size(MediaQuery.of(context).size.width - 32, 48),
                    backgroundColor: _state == AppConstants.connectionOK ? HexColor.hexColor("#628DFF") : HexColor.hexColor("#D7DADD"),
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
                  ),
                  child: Text(
                    loc.update,
                    style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Colors.white),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  void dispose() {
    _popupMenuManager.removeAddFilePopupMenu();
    _popupMenuManager.removeLongClickPopupMenu();
    _otaFileListSubscription?.cancel();
    _otaConnectionManager.dispose();
    super.dispose();
  }

  Future<dynamic> _handleMethodCall(MethodCall call) async {
    if (call.method == BleEventConstants.TYPE_ON_FILE_PICKED) {
      final fileName = call.arguments[BleEventConstants.KEY_FILE_NAME];

      WidgetsBinding.instance.addPostFrameCallback((_) async {
        await _dialogManager.showSaveFileDialog(fileName);
      });
    }
  }

  Future<void> _startOTA() async {
    setState(() {
      _isOtaStarted = true;
    });
    await BleMethod.startOTA(_selectedFilePath!);
  }

  void _handleStartOta() {
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      await _dialogManager.showOtaDialog();
    });
    _startOTA();
  }

  void _handleLocalAdd() {
    if (AppUtil.isAndroid) {
      AppUtil.pickFile();
    } else {
      Navigator.push(context, MaterialPageRoute(builder: (context) => FileSharePage()));
    }
  }

  void _handleComputerTransfer() {
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      await _dialogManager.showComputerTransferDialog();
    });
  }

  void _handleScanDownload() {
    if (AppUtil.isIOS) {
      _openQrScanner();
    } else {
      _initializePermissions().then((_) {
        if (_hasCameraPermission && _hasGalleryPermission) {
          if (mounted) {
            _enterQrcodePage();
          }
        } else {
          log("Permissions not granted");
          if (mounted) {
            ToastUtils.show(context, AppLocalizations.of(context)!.systemSetCamera);
          }
        }
      });
    }
  }

  void _openQrScanner() async {
    try {
      final result = await Navigator.push(context, CupertinoPageRoute(fullscreenDialog: true, builder: (context) => QrCodePage()));

      if (result != null && result is String && mounted) {
        _dialogManager.showDownloadFileDialog(result);
      }
    } catch (e) {
      log("Error in QR scanner: $e");
    }
  }

  _enterQrcodePage() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => QrCodePage(
          onScanResult: (result) {
            WidgetsBinding.instance.addPostFrameCallback((_) async {
              _dialogManager.showDownloadFileDialog(result);
            });
          },
        ),
      ),
    );
  }

  Future<void> _initializePermissions() async {
    try {
      final cameraStatus = await Permission.camera.request();

      // 根据 Android 版本请求不同的存储权限
      PermissionStatus storageStatus;
      if (await AppUtil.isAndroid13OrHigher()) {
        // Android 13+ 使用新的媒体权限
        storageStatus = await Permission.photos.request();
      } else {
        // Android 12及以下使用存储权限
        storageStatus = await Permission.storage.request();
      }

      setState(() {
        _hasCameraPermission = cameraStatus.isGranted;
        _hasGalleryPermission = storageStatus.isGranted;
      });
    } catch (e) {
      log("Permission error: $e");
    }
  }

  Future<void> _checkStorageEnvironment() async {
    try {
      bool result = await BleMethod.tryToCheckStorageEnvironment();
      setState(() {
        _isStorageEnvironmentChecked = result;
      });
      if (result && mounted) {
        _popupMenuManager.removeAddFilePopupMenu();
        _popupMenuManager.showAddFilePopupMenu(
          context: context,
          buttonKey: _addFileButtonKey,
          onLocalAdd: _handleLocalAdd,
          onComputerTransfer: _handleComputerTransfer,
          onScanDownload: _handleScanDownload,
        );
      }
    } catch (e) {
      log("Failed to check storage environment: $e");
    }
  }

  void _showLongClickPopupMenu(BuildContext context, Map<String, String> file, GlobalKey itemKey, int index) {
    _popupMenuManager.showLongClickPopupMenu(context: context, file: file, itemKey: itemKey, index: index, onDelete: _deleteFile);
  }

  Future<void> _deleteFile(Map<String, String> file, int index) async {
    await _otaFileManager.deleteFile(index);
  }

  void _initialize() async {
    AppUtil.readFileList();
    _startListeningToOtaFileList();
    _subscribeToOtaConnectionStream();
    _subscribeToDeviceConnectionStream();
  }

  void _startListeningToOtaFileList() {
    _otaFileListSubscription?.cancel();
    _otaFileListSubscription = BleEventStream.otaFileListStream.listen((fileList) {
      if (mounted) {
        setState(() {
          _otaFileList = fileList;
          _isInitialDataLoaded = true;
        });
      }
    });
  }

  void _cleanOtaData() {
    setState(() {
      _state = AppConstants.connectionDisconnect;
      _deviceType = '';
      if (_otaData != null) {
        _otaData!.clear();
        _otaData = null;
      }
    });
  }

  void _subscribeToOtaConnectionStream() {
    if (_isOtaStarted) {
      _otaConnectionManager.subscribeToOtaConnectionStream();
    }
  }

  void _subscribeToDeviceConnectionStream() {
    _otaConnectionManager.subscribeToDeviceConnectionStream();
  }
}
