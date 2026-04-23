import 'dart:async';
import 'dart:developer';
import 'package:jl_ota/constant/constants.dart';
import 'package:jl_ota/ble_method.dart';

/// Settings Manager
///
/// Responsible for handling application settings-related operations, including:
/// - Loading and saving device authentication, HID devices, custom reconnection settings
/// - Managing BLE communication parameters (MTU, communication methods, etc.)
/// - Handling platform-specific settings (Android/iOS differences)
/// - Retrieving version information and log paths
///
/// This class provides a unified interface to manage various configuration options
/// for the application and handles exceptions when interacting with native code.
class SettingManager {
  // 加载设备认证状态
  static Future<bool> loadDeviceAuth() async {
    try {
      return await BleMethod.isUseDeviceAuth();
    } catch (e) {
      log("Failed to load device auth: $e");
      return false;
    }
  }

  // 加载HID设备状态（仅Android）
  static Future<bool> loadHidDevice() async {
    try {
      return await BleMethod.isHidDevice();
    } catch (e) {
      log("Failed to load HID device: $e");
      return false;
    }
  }

  // 加载自定义重连方式（仅Android）
  static Future<bool> loadCustomReconnect() async {
    try {
      return await BleMethod.isUseCustomReConnectWay();
    } catch (e) {
      log("Failed to load custom reconnect: $e");
      return false;
    }
  }

  // 加载通信方式（仅Android）
  static Future<String> loadCommunicationMethod() async {
    try {
      final isBle = await BleMethod.isBleWay();
      return isBle ? AppConstants.communicationWayBle : AppConstants.communicationWaySpp;
    } catch (e) {
      log("Failed to load communication method: $e");
      return AppConstants.communicationWayBle;
    }
  }

  // 加载MTU值（仅Android）
  static Future<int> loadMtu() async {
    try {
      return await BleMethod.getBleRequestMtu();
    } catch (e) {
      log("Failed to load MTU: $e");
      return 23; // 默认值
    }
  }

  // 加载SDK蓝牙连接状态（仅iOS）
  static Future<bool> loadSdkBluetooth() async {
    try {
      return await BleMethod.isUseSdkBluetooth();
    } catch (e) {
      log("Failed to load SDK bluetooth: $e");
      return false;
    }
  }

  // 获取日志路径
  static Future<String> getLogDirPath() async {
    try {
      return await BleMethod.getLogFileDirPath();
    } catch (e) {
      log("Failed to get log dir: $e");
      return "";
    }
  }

  // 获取版本信息
  static Future<Map<String, String>> getVersions() async {
    try {
      final sdkVersion = await BleMethod.getSdkVersion();
      final appVersion = await BleMethod.getAppVersion();
      return {AppConstants.sdkName: sdkVersion, AppConstants.appName: appVersion};
    } catch (e) {
      log("Failed to get versions: $e");
      return {AppConstants.sdkName: "unknown", AppConstants.appName: "unknown"};
    }
  }

  // 保存设置（核心方法）
  static Future<void> saveSettings({
    required bool isAndroid,
    required bool deviceAuth,
    required bool hidDevice,
    required bool customReconnect,
    required String communicationMethod,
    required int mtu,
    required bool useSdkBluetooth,
  }) async {
    try {
      // 通用设置：设备认证
      await BleMethod.setUseDeviceAuth(deviceAuth);

      if (isAndroid) {
        // Android特有设置
        await BleMethod.setHidDevice(hidDevice);
        await BleMethod.setUseCustomReConnectWay(customReconnect);
        await BleMethod.setBleWay(communicationMethod == AppConstants.communicationWayBle);
        await BleMethod.setBleRequestMtu(mtu);
        await BleMethod.popAllActivity(); // 重启应用
      } else {
        // iOS特有设置
        await BleMethod.setConnectUsingSdkBluetooth(useSdkBluetooth);
      }
    } catch (e) {
      log("Failed to save settings: $e");
      rethrow;
    }
  }
}
