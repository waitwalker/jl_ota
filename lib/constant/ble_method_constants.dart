/// BLE 与 OTA 原生方法通道（MethodChannel）常量定义类
///
/// 集中定义 Flutter 侧向原生 Android 侧发起调用时所使用的全部方法名称（Method）及入参参数键（Argument Key）。
class BleMethodConstants {
  /// 方法名：查询当前底层是否正在执行蓝牙扫描
  static const String METHOD_IS_SCANNING = 'isScanning';

  /// 方法名：检查系统蓝牙环境（包含蓝牙开关状态与定位/蓝牙系统动态权限）
  static const String METHOD_CHECK_BLUETOOTH_ENVIRONMENT = 'checkBluetoothEnvironment';

  /// 方法名：启动低功耗蓝牙扫描流程
  static const String METHOD_START_SCAN = 'startScan';

  /// 方法名：停止当前低功耗蓝牙扫描
  static const String METHOD_STOP_SCAN = 'stopScan';

  /// 方法名：获取当前配置的设备扫描过滤规则字符串
  static const String METHOD_GET_SCAN_FILTER = 'getScanFilter';

  /// 方法名：设置新的设备扫描过滤规则字符串
  static const String METHOD_SET_SCAN_FILTER = 'setScanFilter';

  /// 方法名：发起连接指定扫描列表序号（index）的蓝牙设备
  static const String METHOD_CONNECT_DEVICE = 'connectDevice';

  /// 方法名：断开指定已连接的蓝牙设备
  static const String METHOD_DISCONNECT_BT_DEVICE = 'disconnectBtDevice';

  /// 方法名：获取当前配置的蓝牙通信方式（BLE / SPP）
  static const String METHOD_GET_CONNECT_WAY = 'getConnectWay';

  /// 方法名：设置当前首选的蓝牙通信方式（BLE / SPP）
  static const String METHOD_SET_CONNECT_WAY = 'setConnectWay';

  /// 方法名：查询是否强制使用杰理官方 SDK 内部的蓝牙连接管理
  static const String METHOD_IS_USING_SDK_BLUETOOTH = 'isUseSDKBluetooth';

  /// 方法名：设置是否使用杰理官方 SDK 内部的蓝牙连接管理
  static const String METHOD_SET_USING_SDK_BLUETOOTH = 'setUseSDKBluetooth';

  /// 方法名：查询是否启用基于经典蓝牙物理链路的 GATT 通信（Gatt Over Edr）
  static const String METHOD_IS_USING_GATT_OVER_EDR = 'isUseGattOverEdr';

  /// 方法名：设置是否启用基于经典蓝牙物理链路的 GATT 通信（Gatt Over Edr）
  static const String METHOD_SET_GATT_OVER_EDR = 'setGattOverEdr';

  /// 方法名：获取已配置的自定义 GATT Service UUID 列表
  static const String METHOD_GET_GATT_SERVICE_UUIDS = 'getGattServiceUuids';

  /// 方法名：配置自定义 GATT Service UUID 列表
  static const String METHOD_SET_GATT_SERVICE_UUIDS = 'setGattServiceUuids';

  /// 方法名：查询是否开启了设备连接安全认证
  static const String METHOD_IS_USE_DEVICE_AUTH = 'isUseDeviceAuth';

  /// 方法名：设置是否启用设备连接安全认证
  static const String METHOD_SET_USE_DEVICE_AUTH = 'setUseDeviceAuth';

  /// 方法名：查询当前设备是否被标记为 HID 输入设备
  static const String METHOD_IS_HID_DEVICE = 'isHidDevice';

  /// 方法名：标记当前设备是否为 HID 输入设备
  static const String METHOD_SET_HID_DEVICE = 'setHidDevice';

  /// 方法名：查询是否启用了自定义回连机制
  static const String METHOD_IS_USE_CUSTOM_RECONNECT_WAY = 'isUseCustomReConnectWay';

  /// 方法名：设置是否启用自定义回连机制
  static const String METHOD_SET_USE_CUSTOM_RECONNECT_WAY = 'setUseCustomReConnectWay';

  /// 方法名：获取当前向底层协商的 BLE MTU 请求数值
  static const String METHOD_GET_BLE_REQUEST_MTU = 'getBleRequestMtu';

  /// 方法名：设置向底层协商的 BLE MTU 请求数值（建议范围：23 ~ 509）
  static const String METHOD_SET_BLE_REQUEST_MTU = 'setBleRequestMtu';

  /// 方法名：获取原生底层杰理 OTA SDK 的版本号字符串
  static const String METHOD_GET_SDK_VERSION = 'getSdkVersion';

  /// 方法名：查询当前是否正在处于 OTA 固件升级执行阶段
  static const String METHOD_TYPE_IS_OTA = 'isOta';

  /// 方法名：根据传入的固件文件本地路径启动 OTA 升级流程
  static const String METHOD_START_OTA = 'startOTA';

  /// 方法名：开启或关闭原生底层杰理 SDK 的调试日志打印
  static const String METHOD_SET_LOG_ENABLED = 'setLogEnabled';

  /// 入参键名：目标设备在扫描列表中的下标索引（int）
  static const String ARG_INDEX = 'index';

  /// 入参键名：设备扫描过滤名称或标识规则（String）
  static const String ARG_FILTER = 'filter';

  /// 入参键名：蓝牙物理连接方式常量（int，0: BLE, 1: SPP）
  static const String ARG_CONNECT_WAY = 'connectWay';

  /// 入参键名：是否启用杰理 SDK 内部蓝牙连接（bool）
  static const String ARG_IS_USING_SDK_BLUETOOTH = 'isUsingSDKBluetooth';

  /// 入参键名：是否启用 Gatt Over Edr 模式（bool）
  static const String ARG_IS_USING_GATT_OVER_EDR = 'isUsingGattOVerEdr';

  /// 入参键名：GATT 服务 UUID 集合（`List<String>`）
  static const String ARG_GATT_SERVICE_UUIDS = 'gattServiceUuids';

  /// 入参键名：是否开启设备安全认证（bool）
  static const String ARG_IS_AUTH = 'isAuth';

  /// 入参键名：是否为 HID 外设模式（bool）
  static const String ARG_IS_HID = 'isHid';

  /// 入参键名：是否使用自定义设备回连策略（bool）
  static const String ARG_IS_CUSTOM = 'isCustom';

  /// 入参键名：BLE MTU 目标字节大小（int）
  static const String ARG_MTU = 'mtu';

  /// 入参键名：待升级的 OTA 固件包本地文件绝对路径（String）
  static const String ARG_PATH = 'path';

  /// 入参键名：是否开启底层 SDK 日志输出（bool）
  static const String ARG_ENABLED = 'enabled';
}
