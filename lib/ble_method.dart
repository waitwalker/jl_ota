import 'package:flutter/services.dart';
import 'constant/ble_method_constants.dart';

/// Bluetooth Feature Plugin Wrapper
///
/// Communicates with the native Android side via MethodChannel.
/// All external interfaces are static methods/properties and can be directly accessed through BleMethod.xxx.
class BleMethod {
  static const MethodChannel _methodChannel = MethodChannel('com.jieli.ble_plugin/methods');

  // 检查是否正在扫描
  static Future<bool> isScanning() async {
    try {
      return await _methodChannel.invokeMethod(BleMethodConstants.METHOD_IS_SCANNING) ?? false;
    } on PlatformException catch (e) {
      print("Failed to check if scanning: ${e.message}");
      rethrow;
    }
  }

  // 检查蓝牙环境是否可用
  static Future<bool> checkBluetoothEnvironment() async {
    try {
      final bool isAvailable = await _methodChannel.invokeMethod(BleMethodConstants.METHOD_CHECK_BLUETOOTH_ENVIRONMENT);
      return isAvailable;
    } on PlatformException catch (e) {
      print("Failed to check Bluetooth environment: ${e.message}");
      rethrow;
    }
  }

  // 开始扫描
  static Future<void> startScan() async {
    try {
      await _methodChannel.invokeMethod(BleMethodConstants.METHOD_START_SCAN);
    } on PlatformException catch (e) {
      print("Failed to start scan: ${e.message}");
      rethrow;
    }
  }

  // 停止扫描
  static Future<void> stopScan() async {
    try {
      await _methodChannel.invokeMethod(BleMethodConstants.METHOD_STOP_SCAN);
    } on PlatformException catch (e) {
      print("Failed to stop scan: ${e.message}");
      rethrow;
    }
  }

  // 读取当前过滤字符串
  static Future<String?> getScanFilter() async {
    try {
      return await _methodChannel.invokeMethod<String>(BleMethodConstants.METHOD_GET_SCAN_FILTER);
    } on PlatformException catch (e) {
      print("Failed to get scan filter: ${e.message}");
      rethrow;
    }
  }

  // 设置新的过滤字符串
  static Future<void> setScanFilter(String? filter) async {
    try {
      await _methodChannel.invokeMethod(BleMethodConstants.METHOD_SET_SCAN_FILTER, {BleMethodConstants.ARG_FILTER: filter});
    } on PlatformException catch (e) {
      print("Failed to set scan filter: ${e.message}");
      rethrow;
    }
  }

  // 连接设备
  static Future<void> connectDevice(int index) async {
    try {
      await _methodChannel.invokeMethod(BleMethodConstants.METHOD_CONNECT_DEVICE, {BleMethodConstants.ARG_INDEX: index});
    } on PlatformException catch (e) {
      print("Failed to connect device at index $index: ${e.message}");
      rethrow;
    }
  }

  // 断开设备连接
  static Future<void> disconnectBtDevice(int index) async {
    try {
      await _methodChannel.invokeMethod(BleMethodConstants.METHOD_DISCONNECT_BT_DEVICE, {BleMethodConstants.ARG_INDEX: index});
    } on PlatformException catch (e) {
      print("Failed to disconnect device at index $index: ${e.message}");
      rethrow;
    }
  }

  // 读取当前使用的通讯方式
  static Future<int> getConnectWay() async {
    try {
      return await _methodChannel.invokeMethod(BleMethodConstants.METHOD_GET_CONNECT_WAY) ?? true;
    } on PlatformException catch (e) {
      print("Failed to check if BLE way is used: ${e.message}");
      rethrow;
    }
  }

  // 设置当前使用的通讯方式
  static Future<void> setConnectWay(int connectWay) async {
    try {
      await _methodChannel.invokeMethod(BleMethodConstants.METHOD_SET_CONNECT_WAY, {BleMethodConstants.ARG_CONNECT_WAY: connectWay});
    } on PlatformException catch (e) {
      print("Failed to set BLE way: ${e.message}");
      rethrow;
    }
  }

  // 读取是否使用SDK蓝牙连接
  static Future<bool> isUseSdkBluetooth() async {
    try {
      return await _methodChannel.invokeMethod(BleMethodConstants.METHOD_IS_USING_SDK_BLUETOOTH) ?? true;
    } on PlatformException catch (e) {
      print("Failed to check if sdk bluetooth is used: ${e.message}");
      rethrow;
    }
  }

  // 设置是否使用SDK蓝牙连接
  static Future<void> setConnectUsingSdkBluetooth(bool isUsingSDKBluetooth) async {
    try {
      await _methodChannel.invokeMethod(BleMethodConstants.METHOD_SET_USING_SDK_BLUETOOTH, {
        BleMethodConstants.ARG_IS_USING_SDK_BLUETOOTH: isUsingSDKBluetooth,
      });
    } on PlatformException catch (e) {
      print("Failed to use sdk bluetooth: ${e.message}");
      rethrow;
    }
  }

  // 读取是否使用GattOverEdr
  static Future<bool> isUseGattOverEdr() async {
    try {
      return await _methodChannel.invokeMethod(BleMethodConstants.METHOD_IS_USING_GATT_OVER_EDR) ?? true;
    } on PlatformException catch (e) {
      print("Failed to check if sdk bluetooth is used: ${e.message}");
      rethrow;
    }
  }

  // 设置是否使用Gatt Over edr
  static Future<void> setGattOverEdrState(bool gattOverEdrState) async {
    try {
      await _methodChannel.invokeMethod(BleMethodConstants.METHOD_SET_GATT_OVER_EDR, {
        BleMethodConstants.ARG_IS_USING_GATT_OVER_EDR: gattOverEdrState,
      });
    } on PlatformException catch (e) {
      print("Failed to set gatt over edr: ${e.message}");
      rethrow;
    }
  }

  // 读取Gatt Service Uuids
  static Future<List<String>> getGattServiceUuids() async {
    try {
      final result = await _methodChannel.invokeMethod(BleMethodConstants.METHOD_GET_GATT_SERVICE_UUIDS);
      return List<String>.from(result ?? []);
    } on PlatformException catch (e) {
      print("Failed to get gatt service uuids: ${e.message}");
      return [];
    }
  }

  // 设置Gatt Service uuids
  static Future<void> setGattServiceUuids(List<String> uuids) async {
    try {
      await _methodChannel.invokeMethod(BleMethodConstants.METHOD_SET_GATT_SERVICE_UUIDS, {BleMethodConstants.ARG_GATT_SERVICE_UUIDS: uuids});
    } on PlatformException catch (e) {
      print("Failed to set gatt servie uuids: ${e.message}");
      rethrow;
    }
  }

  // 读取是否需要设备认证
  static Future<bool> isUseDeviceAuth() async {
    try {
      return await _methodChannel.invokeMethod(BleMethodConstants.METHOD_IS_USE_DEVICE_AUTH) ?? true;
    } on PlatformException catch (e) {
      print("Failed to check if device authentication is used: ${e.message}");
      rethrow;
    }
  }

  // 设置是否需要设备认证
  static Future<void> setUseDeviceAuth(bool isAuth) async {
    try {
      await _methodChannel.invokeMethod(BleMethodConstants.METHOD_SET_USE_DEVICE_AUTH, {BleMethodConstants.ARG_IS_AUTH: isAuth});
    } on PlatformException catch (e) {
      print("Failed to set device authentication: ${e.message}");
      rethrow;
    }
  }

  // 读取当前是否为HID设备
  static Future<bool> isHidDevice() async {
    try {
      return await _methodChannel.invokeMethod(BleMethodConstants.METHOD_IS_HID_DEVICE) ?? false;
    } on PlatformException catch (e) {
      print("Failed to check if HID device: ${e.message}");
      rethrow;
    }
  }

  // 设置是否为HID设备
  static Future<void> setHidDevice(bool isHid) async {
    try {
      await _methodChannel.invokeMethod(BleMethodConstants.METHOD_SET_HID_DEVICE, {BleMethodConstants.ARG_IS_HID: isHid});
    } on PlatformException catch (e) {
      print("Failed to set HID device: ${e.message}");
      rethrow;
    }
  }

  // 读取是否使用自定义回连方式
  static Future<bool> isUseCustomReConnectWay() async {
    try {
      return await _methodChannel.invokeMethod(BleMethodConstants.METHOD_IS_USE_CUSTOM_RECONNECT_WAY) ?? false;
    } on PlatformException catch (e) {
      print("Failed to check if custom reconnect way is used: ${e.message}");
      rethrow;
    }
  }

  // 设置是否使用自定义回连方式
  static Future<void> setUseCustomReConnectWay(bool isCustom) async {
    try {
      await _methodChannel.invokeMethod(BleMethodConstants.METHOD_SET_USE_CUSTOM_RECONNECT_WAY, {BleMethodConstants.ARG_IS_CUSTOM: isCustom});
    } on PlatformException catch (e) {
      print("Failed to set custom reconnect way: ${e.message}");
      rethrow;
    }
  }

  // 获取当前BLE MTU请求值
  static Future<int> getBleRequestMtu() async {
    try {
      return await _methodChannel.invokeMethod(BleMethodConstants.METHOD_GET_BLE_REQUEST_MTU) ?? 0;
    } on PlatformException catch (e) {
      print("Failed to get BLE MTU: ${e.message}");
      rethrow;
    }
  }

  // 设置BLE MTU请求值(范围:23~509）
  static Future<void> setBleRequestMtu(int mtu) async {
    try {
      await _methodChannel.invokeMethod(BleMethodConstants.METHOD_SET_BLE_REQUEST_MTU, {BleMethodConstants.ARG_MTU: mtu});
    } on PlatformException catch (e) {
      print("Failed to set BLE MTU: ${e.message}");
      rethrow;
    }
  }

  // 获取SDK版本号
  static Future<String> getSdkVersion() async {
    try {
      return await _methodChannel.invokeMethod(BleMethodConstants.METHOD_GET_SDK_VERSION) ?? 'V?.?.?(?)';
    } on PlatformException catch (e) {
      print("Failed to get SDK version: ${e.message}");
      rethrow;
    }
  }

  // 获取APP版本号
  static Future<String> getAppVersion() async {
    try {
      return await _methodChannel.invokeMethod(BleMethodConstants.METHOD_GET_APP_VERSION) ?? 'V?.?.?(?)';
    } on PlatformException catch (e) {
      print("Failed to get APP version: ${e.message}");
      rethrow;
    }
  }

  // 读取日志文件目录路径
  static Future<String> getLogFileDirPath() async {
    try {
      return await _methodChannel.invokeMethod(BleMethodConstants.METHOD_GET_LOG_FILE_DIR_PATH) ?? '';
    } on PlatformException catch (e) {
      print("Failed to get log file directory path: ${e.message}");
      rethrow;
    }
  }

  // 获取日志文件列表
  static Future<void> getLogFiles() async {
    try {
      await _methodChannel.invokeMethod(BleMethodConstants.METHOD_GET_LOG_FILES);
    } on PlatformException catch (e) {
      print("Failed to get log files: ${e.message}");
      rethrow;
    }
  }

  // 点击日志文件列表的索引
  static Future<void> clickLogFileIndex(int logFileIndex) async {
    try {
      await _methodChannel.invokeMethod(BleMethodConstants.METHOD_LOG_FILE_INDEX, {BleMethodConstants.ARG_LOG_FILE_INDEX: logFileIndex});
    } on PlatformException catch (e) {
      print("Failed to click log file index $logFileIndex: ${e.message}");
      rethrow;
    }
  }

  // 删除全部的日志文件
  static Future<bool> deleteAllLogFiles() async {
    try {
      return await _methodChannel.invokeMethod(BleMethodConstants.METHOD_DELETE_ALL_LOG_FILE) ?? false;
    } on PlatformException catch (e) {
      print("Failed to delete all log files: ${e.message}");
      rethrow;
    }
  }

  // 分享日志文件
  static Future<void> shareLogFile(int logFileIndex) async {
    try {
      await _methodChannel.invokeMethod(BleMethodConstants.METHOD_SHARE_LOG_FILE, {BleMethodConstants.ARG_LOG_FILE_INDEX: logFileIndex});
    } on PlatformException catch (e) {
      print("Failed to share log file at index $logFileIndex: ${e.message}");
      rethrow;
    }
  }

  // 下载文件
  static Future<void> downloadFile(String httpUrl) async {
    try {
      await _methodChannel.invokeMethod(BleMethodConstants.METHOD_DOWNLOAD_FILE, {BleMethodConstants.ARG_HTTP_URL: httpUrl});
    } on PlatformException catch (e) {
      print("Failed to download file from $httpUrl: ${e.message}");
      rethrow;
    }
  }

  // 是否在OTA升级
  static Future<bool> isOTA() async {
    try {
      return await _methodChannel.invokeMethod(BleMethodConstants.METHOD_TYPE_IS_OTA) ?? true;
    } on PlatformException catch (e) {
      print("Failed to get Ota state: ${e.message}");
      rethrow;
    }
  }

  // 读取OTA文件列表
  static Future<void> readFileList() async {
    try {
      await _methodChannel.invokeMethod(BleMethodConstants.METHOD_READ_FILE_LIST);
    } on PlatformException catch (e) {
      print("Failed to read OTA file list: ${e.message}");
      rethrow;
    }
  }

  // 设置OTA文件列表选中的文件索引
  static Future<void> setSelectedIndex(int pos) async {
    try {
      await _methodChannel.invokeMethod(BleMethodConstants.METHOD_SET_SELECTED_INDEX, {BleMethodConstants.ARG_POS: pos});
    } on PlatformException catch (e) {
      print("Failed to set selected index $pos: ${e.message}");
      rethrow;
    }
  }

  // 删除OTA文件列表选中的文件索引
  static Future<void> deleteOtaIndex(int pos) async {
    try {
      await _methodChannel.invokeMethod(BleMethodConstants.METHOD_DELETE_OTA_FILE_INDEX, {BleMethodConstants.ARG_POS: pos});
    } on PlatformException catch (e) {
      print("Failed to delete OTA file index $pos: ${e.message}");
      rethrow;
    }
  }

  // 检测外部存储权限环境
  static Future<bool> tryToCheckStorageEnvironment() async {
    try {
      return await _methodChannel.invokeMethod(BleMethodConstants.METHOD_TRY_TO_CHECK_STORAGE_ENVIRONMENT) ?? false;
    } on PlatformException catch (e) {
      print("Failed to check storage environment: ${e.message}");
      rethrow;
    }
  }

  // 选择文件
  static Future<void> pickFile() async {
    try {
      await _methodChannel.invokeMethod(BleMethodConstants.METHOD_PICK_FILE);
    } on PlatformException catch (e) {
      print("Failed to pick file: ${e.message}");
      rethrow;
    }
  }

  // 开始OTA更新
  static Future<void> startOTA(String path) async {
    try {
      await _methodChannel.invokeMethod(BleMethodConstants.METHOD_START_OTA, {BleMethodConstants.ARG_PATH: path});
    } on PlatformException catch (e) {
      print("Failed to start OTA: ${e.message}");
      rethrow;
    }
  }

  /// 获取WiFi的IP地址
  /// 返回格式: "http://[ip]:[port]"
  static Future<String> getWifiIpAddress() async {
    try {
      final String? ipAddress = await _methodChannel.invokeMethod<String>(BleMethodConstants.METHOD_GET_WIFI_IP_ADDRESS);
      return ipAddress ?? 'Failed to get WiFi IP address';
    } on PlatformException catch (e) {
      print("Failed to get WiFi IP address: ${e.message}");
      rethrow;
    }
  }

  /// 退出所有的Activity
  static Future<void> popAllActivity() async {
    try {
      await _methodChannel.invokeMethod(BleMethodConstants.METHOD_POP_ALL_ACTIVITY);
    } on PlatformException catch (e) {
      print("Failed to pop all activities: ${e.message}");
      rethrow;
    }
  }

  // 发送自定义命令
  static Future<void> sendCustomCommand(Uint8List data) async {
    try {
      await _methodChannel.invokeMethod(BleMethodConstants.METHOD_SEND_CUSTOM_COMMAND, {BleMethodConstants.ARG_CUSTOM_DATA: data});
    } on PlatformException catch (e) {
      print("Failed to send custom command: ${e.message}");
      rethrow;
    }
  }
}
