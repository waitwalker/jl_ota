import 'package:flutter/services.dart';
import 'constant/ble_method_constants.dart';

/// 蓝牙功能与 OTA 方法通道封装类
///
/// 通过 [MethodChannel] 与原生 Android 端（[JlOtaPlugin] / [BlePlugin]）进行异步通信。
/// 外部直接调用静态方法即可触发原生蓝牙扫描、设备连接、MTU 设置、参数配置及固件 OTA 升级等操作。
class BleMethod {
  /// 与原生通信的方法通道实例
  static const MethodChannel _methodChannel = MethodChannel('com.jieli.ble_plugin/methods');

  /// 查询底层当前是否正在执行蓝牙扫描
  ///
  /// 返回 `true` 表示正在扫描中，`false` 表示扫描空闲或已停止。
  static Future<bool> isScanning() async {
    try {
      return await _methodChannel.invokeMethod(BleMethodConstants.METHOD_IS_SCANNING) ?? false;
    } on PlatformException catch (e) {
      print("Failed to check if scanning: ${e.message}");
      rethrow;
    }
  }

  /// 检查系统蓝牙运行环境是否可用
  ///
  /// 校验系统蓝牙硬件是否就绪、系统蓝牙开关是否开启，以及是否已授予必要的系统动态权限（Android 12 以下为定位权限，Android 12+ 为蓝牙扫描/连接权限）。
  /// 返回 `true` 表示环境检测通过可正常操作蓝牙，`false` 表示环境未就绪。
  static Future<bool> checkBluetoothEnvironment() async {
    try {
      final bool isAvailable = await _methodChannel.invokeMethod(BleMethodConstants.METHOD_CHECK_BLUETOOTH_ENVIRONMENT);
      return isAvailable;
    } on PlatformException catch (e) {
      print("Failed to check Bluetooth environment: ${e.message}");
      rethrow;
    }
  }

  /// 启动低功耗蓝牙扫描
  ///
  /// 调用原生层开启 BLE 广播扫描，扫描到的设备将通过 [BleEventStream.scanDeviceListStream] 实时派发。
  static Future<void> startScan() async {
    try {
      await _methodChannel.invokeMethod(BleMethodConstants.METHOD_START_SCAN);
    } on PlatformException catch (e) {
      print("Failed to start scan: ${e.message}");
      rethrow;
    }
  }

  /// 停止当前的低功耗蓝牙扫描
  static Future<void> stopScan() async {
    try {
      await _methodChannel.invokeMethod(BleMethodConstants.METHOD_STOP_SCAN);
    } on PlatformException catch (e) {
      print("Failed to stop scan: ${e.message}");
      rethrow;
    }
  }

  /// 获取当前配置的蓝牙扫描过滤字符串
  ///
  /// 返回当前生效的设备过滤规则，若未设置则可能返回 `null`。
  static Future<String?> getScanFilter() async {
    try {
      return await _methodChannel.invokeMethod<String>(BleMethodConstants.METHOD_GET_SCAN_FILTER);
    } on PlatformException catch (e) {
      print("Failed to get scan filter: ${e.message}");
      rethrow;
    }
  }

  /// 设置新的设备扫描过滤规则
  ///
  /// [filter] 过滤规则文本（如设备广播名或前缀），传 `null` 或空串表示不过滤
  static Future<void> setScanFilter(String? filter) async {
    try {
      await _methodChannel.invokeMethod(BleMethodConstants.METHOD_SET_SCAN_FILTER, {BleMethodConstants.ARG_FILTER: filter});
    } on PlatformException catch (e) {
      print("Failed to set scan filter: ${e.message}");
      rethrow;
    }
  }

  /// 发起连接指定扫描列表序号（index）的蓝牙设备
  ///
  /// [index] 目标设备在扫描发现设备列表中的下标索引
  static Future<void> connectDevice(int index) async {
    try {
      await _methodChannel.invokeMethod(BleMethodConstants.METHOD_CONNECT_DEVICE, {BleMethodConstants.ARG_INDEX: index});
    } on PlatformException catch (e) {
      print("Failed to connect device at index $index: ${e.message}");
      rethrow;
    }
  }

  /// 断开指定序号蓝牙设备的连接
  ///
  /// [index] 目标设备在设备列表中的下标索引
  static Future<void> disconnectBtDevice(int index) async {
    try {
      await _methodChannel.invokeMethod(BleMethodConstants.METHOD_DISCONNECT_BT_DEVICE, {BleMethodConstants.ARG_INDEX: index});
    } on PlatformException catch (e) {
      print("Failed to disconnect device at index $index: ${e.message}");
      rethrow;
    }
  }

  /// 读取当前配置的蓝牙通信方式
  ///
  /// 返回通信方式枚举常量：
  /// - `0`: [AppConstants.communicationWayBle] BLE 低功耗蓝牙
  /// - `1`: [AppConstants.communicationWaySpp] SPP 经典蓝牙串口
  static Future<int> getConnectWay() async {
    try {
      return await _methodChannel.invokeMethod(BleMethodConstants.METHOD_GET_CONNECT_WAY) ?? true;
    } on PlatformException catch (e) {
      print("Failed to check if BLE way is used: ${e.message}");
      rethrow;
    }
  }

  /// 设置当前首选的蓝牙通信方式
  ///
  /// [connectWay] 通信方式常量（0: BLE, 1: SPP）
  static Future<void> setConnectWay(int connectWay) async {
    try {
      await _methodChannel.invokeMethod(BleMethodConstants.METHOD_SET_CONNECT_WAY, {BleMethodConstants.ARG_CONNECT_WAY: connectWay});
    } on PlatformException catch (e) {
      print("Failed to set BLE way: ${e.message}");
      rethrow;
    }
  }

  /// 查询是否使用杰理 SDK 内部的蓝牙连接管理
  ///
  /// 返回 `true` 表示由 SDK 内部驱动蓝牙连接生命周期，`false` 表示由外部托管。
  static Future<bool> isUseSdkBluetooth() async {
    try {
      return await _methodChannel.invokeMethod(BleMethodConstants.METHOD_IS_USING_SDK_BLUETOOTH) ?? true;
    } on PlatformException catch (e) {
      print("Failed to check if sdk bluetooth is used: ${e.message}");
      rethrow;
    }
  }

  /// 设置是否使用杰理 SDK 内部的蓝牙连接管理
  ///
  /// [isUsingSDKBluetooth] `true` 表示启用 SDK 内部连接管理，`false` 表示关闭
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

  /// 查询是否启用了基于经典蓝牙物理链路的 GATT 通信（Gatt Over Edr）
  ///
  /// 返回 `true` 表示启用，`false` 表示未启用。
  static Future<bool> isUseGattOverEdr() async {
    try {
      return await _methodChannel.invokeMethod(BleMethodConstants.METHOD_IS_USING_GATT_OVER_EDR) ?? true;
    } on PlatformException catch (e) {
      print("Failed to check if sdk bluetooth is used: ${e.message}");
      rethrow;
    }
  }

  /// 设置是否启用基于经典蓝牙物理链路的 GATT 通信（Gatt Over Edr）
  ///
  /// [gattOverEdrState] `true` 表示开启，`false` 表示关闭
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

  /// 读取已配置的自定义 GATT Service UUID 列表
  ///
  /// 返回 UUID 字符串列表。若读取失败或未配置则返回空列表。
  static Future<List<String>> getGattServiceUuids() async {
    try {
      final result = await _methodChannel.invokeMethod(BleMethodConstants.METHOD_GET_GATT_SERVICE_UUIDS);
      return List<String>.from(result ?? []);
    } on PlatformException catch (e) {
      print("Failed to get gatt service uuids: ${e.message}");
      return [];
    }
  }

  /// 设置自定义 GATT Service UUID 列表
  ///
  /// [uuids] 目标服务 UUID 字符串集合
  static Future<void> setGattServiceUuids(List<String> uuids) async {
    try {
      await _methodChannel.invokeMethod(BleMethodConstants.METHOD_SET_GATT_SERVICE_UUIDS, {BleMethodConstants.ARG_GATT_SERVICE_UUIDS: uuids});
    } on PlatformException catch (e) {
      print("Failed to set gatt servie uuids: ${e.message}");
      rethrow;
    }
  }

  /// 查询是否开启了设备连接安全认证
  ///
  /// 返回 `true` 表示需要进行认证校验，`false` 表示跳过认证。
  static Future<bool> isUseDeviceAuth() async {
    try {
      return await _methodChannel.invokeMethod(BleMethodConstants.METHOD_IS_USE_DEVICE_AUTH) ?? true;
    } on PlatformException catch (e) {
      print("Failed to check if device authentication is used: ${e.message}");
      rethrow;
    }
  }

  /// 设置是否开启设备连接安全认证
  ///
  /// [isAuth] `true` 表示启用设备认证，`false` 表示关闭
  static Future<void> setUseDeviceAuth(bool isAuth) async {
    try {
      await _methodChannel.invokeMethod(BleMethodConstants.METHOD_SET_USE_DEVICE_AUTH, {BleMethodConstants.ARG_IS_AUTH: isAuth});
    } on PlatformException catch (e) {
      print("Failed to set device authentication: ${e.message}");
      rethrow;
    }
  }

  /// 读取当前目标设备是否被标记为 HID 输入设备
  ///
  /// 返回 `true` 表示是 HID 设备，`false` 表示普通设备。
  static Future<bool> isHidDevice() async {
    try {
      return await _methodChannel.invokeMethod(BleMethodConstants.METHOD_IS_HID_DEVICE) ?? false;
    } on PlatformException catch (e) {
      print("Failed to check if HID device: ${e.message}");
      rethrow;
    }
  }

  /// 设置目标设备是否为 HID 输入设备
  ///
  /// [isHid] `true` 表示标记为 HID 设备，`false` 表示普通设备
  static Future<void> setHidDevice(bool isHid) async {
    try {
      await _methodChannel.invokeMethod(BleMethodConstants.METHOD_SET_HID_DEVICE, {BleMethodConstants.ARG_IS_HID: isHid});
    } on PlatformException catch (e) {
      print("Failed to set HID device: ${e.message}");
      rethrow;
    }
  }

  /// 查询是否启用了自定义回连方式
  ///
  /// 返回 `true` 表示使用自定义回连策略，`false` 表示使用系统/SDK 默认回连。
  static Future<bool> isUseCustomReConnectWay() async {
    try {
      return await _methodChannel.invokeMethod(BleMethodConstants.METHOD_IS_USE_CUSTOM_RECONNECT_WAY) ?? false;
    } on PlatformException catch (e) {
      print("Failed to check if custom reconnect way is used: ${e.message}");
      rethrow;
    }
  }

  /// 设置是否启用自定义回连方式
  ///
  /// [isCustom] `true` 表示启用自定义回连，`false` 表示关闭
  static Future<void> setUseCustomReConnectWay(bool isCustom) async {
    try {
      await _methodChannel.invokeMethod(BleMethodConstants.METHOD_SET_USE_CUSTOM_RECONNECT_WAY, {BleMethodConstants.ARG_IS_CUSTOM: isCustom});
    } on PlatformException catch (e) {
      print("Failed to set custom reconnect way: ${e.message}");
      rethrow;
    }
  }

  /// 获取当前向原生底层配置的 BLE MTU 请求数值
  ///
  /// 返回配置的 MTU 字节大小。
  static Future<int> getBleRequestMtu() async {
    try {
      return await _methodChannel.invokeMethod(BleMethodConstants.METHOD_GET_BLE_REQUEST_MTU) ?? 0;
    } on PlatformException catch (e) {
      print("Failed to get BLE MTU: ${e.message}");
      rethrow;
    }
  }

  /// 设置向底层协商的 BLE MTU 请求数值
  ///
  /// [mtu] 期望的 MTU 大小（建议有效范围：23 ~ 509）
  static Future<void> setBleRequestMtu(int mtu) async {
    try {
      await _methodChannel.invokeMethod(BleMethodConstants.METHOD_SET_BLE_REQUEST_MTU, {BleMethodConstants.ARG_MTU: mtu});
    } on PlatformException catch (e) {
      print("Failed to set BLE MTU: ${e.message}");
      rethrow;
    }
  }

  /// 获取原生底层杰理 OTA SDK 的版本号字符串
  ///
  /// 返回形如 "V1.8.0(20230501)" 的版本标识字符串。
  static Future<String> getSdkVersion() async {
    try {
      return await _methodChannel.invokeMethod(BleMethodConstants.METHOD_GET_SDK_VERSION) ?? 'V?.?.?(?)';
    } on PlatformException catch (e) {
      print("Failed to get SDK version: ${e.message}");
      rethrow;
    }
  }

  /// 查询当前是否正在处于 OTA 固件升级流程中
  ///
  /// 返回 `true` 表示正在升级中，`false` 表示未在升级。
  static Future<bool> isOTA() async {
    try {
      return await _methodChannel.invokeMethod(BleMethodConstants.METHOD_TYPE_IS_OTA) ?? true;
    } on PlatformException catch (e) {
      print("Failed to get Ota state: ${e.message}");
      rethrow;
    }
  }

  /// 开启或关闭原生底层杰理 SDK 的调试日志打印
  ///
  /// [enabled] `true` 表示打开 SDK 调试日志输出，`false` 表示关闭日志
  static Future<void> setLogEnabled(bool enabled) async {
    try {
      await _methodChannel.invokeMethod(BleMethodConstants.METHOD_SET_LOG_ENABLED, {BleMethodConstants.ARG_ENABLED: enabled});
    } on PlatformException catch (e) {
      print("Failed to set log enabled: ${e.message}");
      rethrow;
    }
  }

  /// 根据传入的固件文件本地绝对路径启动 OTA 升级流程
  ///
  /// 启动后升级进度及状态流转可通过 [BleEventStream.otaStateStream] 持续监听。
  /// [path] 待升级的 ufw 固件包本地绝对文件路径
  static Future<void> startOTA(String path) async {
    try {
      await _methodChannel.invokeMethod(BleMethodConstants.METHOD_START_OTA, {BleMethodConstants.ARG_PATH: path});
    } on PlatformException catch (e) {
      print("Failed to start OTA: ${e.message}");
      rethrow;
    }
  }
}
