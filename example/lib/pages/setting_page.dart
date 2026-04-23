import 'dart:async';
import 'dart:developer';
import 'package:flutter/material.dart';
import 'package:jl_ota/constant/constants.dart';
import 'package:jl_ota_example/pages/file_list_page.dart';
import 'package:jl_ota_example/pages/about_page.dart';
import 'package:jl_ota_example/dialog/mtu_adjustment_dialog.dart';
import 'package:jl_ota_example/l10n/app_localizations.dart';
import 'package:jl_ota_example/utils/app_util.dart';
import 'package:jl_ota_example/widgets/toast_utils.dart';
import '../data/setting_manager.dart';
import '../dialog/save_settings_dialog.dart';
import '../widgets/setting_components.dart';
import '../widgets/setting_navigation_row_widget.dart';

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
  // State variables
  String _logFileDirPath = "";
  String _currentCommunicationMethod = AppConstants.communicationWayBle;
  String _sdkVersion = "unknown";
  String _appVersion = "unknown";

  bool _isDeviceAuthenticated = false;
  bool _isHidDevice = false;
  bool _customReconnectMethod = false;
  bool _connectUsingSdkBluetooth = false;
  int _mtu = 0;

  // Initial value tracking
  bool _initialDeviceAuthenticated = false;
  bool _initialHidDevice = false;
  bool _initialCustomReconnectMethod = false;
  bool _initialConnectUsingSdkBluetooth = false;
  String _initialCommunicationMethod = AppConstants.communicationWayBle;
  int _initialMtu = 0;

  // Define color constants
  static const Color primaryColor = Color(0xFF628DFF);
  static const Color disabledColor = Color(0xFF838383);
  static const Color darkTextColor = Color(0xFF242424);
  static const Color lightTextColor = Color(0xFF6F6F6F);
  static const Color dividerColor = Color(0x0A000000);

  // Define MTU minimum and maximum values
  static const int MIN_MTU = 23;
  static const int MAX_MTU = 509;

  @override
  void initState() {
    super.initState();
    _initialize();
  }

  @override
  Widget build(BuildContext context) {
    final loc = AppLocalizations.of(context)!;
    final isAndroid = AppUtil.isAndroid;

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
                  CommunicationOption(
                    title: loc.communicationWayBle,
                    isSelected: _currentCommunicationMethod == AppConstants.communicationWayBle,
                    onTap: () => _updateState(() => _currentCommunicationMethod = AppConstants.communicationWayBle),
                  ),
                  const Divider(height: 1, indent: 20, color: dividerColor),
                  CommunicationOption(
                    title: loc.communicationWaySpp,
                    isSelected: _currentCommunicationMethod == AppConstants.communicationWaySpp,
                    onTap: () => _updateState(() => _currentCommunicationMethod = AppConstants.communicationWaySpp),
                  ),
                ],
              ),

              // MTU adjustment
              SettingSection(
                children: [
                  SettingNavigationRow(
                    title: loc.adjustMtu,
                    subtitle: _mtu > 0 ? _mtu.toString() : '',
                    onTap: () => showMtuAdjustmentDialog(context),
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
            ],

            // Log file access
            SettingSection(
              children: [
                SettingNavigationRow(
                  title: loc.logFile,
                  onTap: () => Navigator.push(context, MaterialPageRoute(builder: (context) => const FileListPage())),
                ),
              ],
            ),

            // Version information
            SettingSection(
              children: [SettingNavigationRow(title: loc.sdkVersion, subtitle: _sdkVersion, onTap: () {}, showArrow: false)],
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

  // Check if settings have changed
  bool _hasSettingsChanged() {
    return _isDeviceAuthenticated != _initialDeviceAuthenticated ||
        _isHidDevice != _initialHidDevice ||
        _customReconnectMethod != _initialCustomReconnectMethod ||
        _connectUsingSdkBluetooth != _initialConnectUsingSdkBluetooth ||
        _currentCommunicationMethod != _initialCommunicationMethod ||
        _mtu != _initialMtu;
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

    log("result:$results");

    final bool isHid = results[0] as bool;
    final bool customReconnect = results[1] as bool;
    final String commMethod = results[2] as String;
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
    setState(() {
      _connectUsingSdkBluetooth = useSdkBt;
      _initialConnectUsingSdkBluetooth = useSdkBt;
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

    await showDialog(
      context: context,
      builder: (context) => SaveSettingsDialog(
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
          );

          // Update initial values to current values
          setState(() {
            _initialDeviceAuthenticated = _isDeviceAuthenticated;
            _initialHidDevice = _isHidDevice;
            _initialCustomReconnectMethod = _customReconnectMethod;
            _initialConnectUsingSdkBluetooth = _connectUsingSdkBluetooth;
            _initialCommunicationMethod = _currentCommunicationMethod;
            _initialMtu = _mtu;
          });
        },
      ),
    );
  }

  // Show MTU adjustment dialog
  void showMtuAdjustmentDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => MtuAdjustmentDialog(
        currentMtu: _mtu,
        minMtu: MIN_MTU,
        maxMtu: MAX_MTU,
        onMtuSelected: (selectedMtu) => _updateState(() => _mtu = selectedMtu),
      ),
    );
  }
}
