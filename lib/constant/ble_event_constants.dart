/// 定义了与BLE（蓝牙低功耗）事件流相关的常量。
class BleEventConstants {
  /// 扫描状态常量
  static const String SCAN_STATE_SCANNING = "scanning"; // 正在扫描状态
  static const String SCAN_STATE_FOUND_DEV = "foundDevice"; // 发现设备状态
  static const String SCAN_STATE_IDLE = "idle"; // 空闲状态

  /// 表示蓝牙状态事件的类型。
  static const String TYPE_BLUETOOTH_STATE = 'bluetoothState';

  /// 表示扫描设备列表事件的类型。
  static const String TYPE_SCAN_DEVICE_LIST = 'scanDeviceList';

  /// 表示设备连接状态事件的类型。
  static const String TYPE_DEVICE_CONNECTION = 'deviceConnection';

  /// 表示OTA连接状态事件的类型。
  static const String TYPE_OTA_CONNECTION = 'otaConnection';

  /// 表示强制升级状态事件的类型。
  static const String TYPE_MANDATORY_UPGRADE = 'mandatoryUpgrade';

  /// 表示OTA状态事件的类型。
  static const String TYPE_OTA_STATE = 'otaState';

  /// 用于在事件数据中标识事件类型的键。
  static const String KEY_TYPE = 'type';

  /// 用于在事件数据中标识事件承载的值的键。
  static const String KEY_VALUE = 'value';

  /// 用于在事件数据中标识状态的键，如进度状态。
  static const String KEY_STATUS = 'status';

  /// 用于在事件数据中标识设备状态的键。
  static const String KEY_STATE = 'state';

  /// 表示OTA的空闲状态
  static const String KEY_STATE_IDLE = "idle";

  /// 表示OTA的开始状态
  static const String KEY_STATE_START = "start";

  /// 表示OTA的重新连接状态
  static const String KEY_STATE_RECONNECT = "reconnect";

  /// 表示OTA的工作状态
  static const String KEY_STATE_WORKING = 'working';

  /// 表示OTA的未知状态
  static const String KEY_STATE_UNKNOWN = "unknown";

  /// 用于在事件数据中标识进度信息的键。
  static const String KEY_PROGRESS = 'progress';

  /// 正在检查文件的类型
  static const String KEY_CHECK_FILE = 'Checking file';

  /// 正在升级的类型
  static const String KEY_UPGRADING = 'Upgrading';

  /// 用于在事件数据中标识列表数据的键。
  static const String KEY_LIST = 'list';

  /// 用于在事件数据中标识事件数据的键。
  static const String KEY_EVENT = 'event';

  /// 用于在事件数据中标识是否需要强制升级的键。
  static const String KEY_IS_REQUIRED = 'isRequired';

  /// 用于在事件数据中标识文件或设备的名称的键。
  static const String KEY_NAME = 'name';

  /// 用于在事件数据中标识文件路径的键。
  static const String KEY_PATH = 'path';

  /// 用于在事件数据中标识设备类型的键。
  static const String KEY_DEVICE_TYPE = 'deviceType';

  /// 用于在事件数据中标识操作成功状态的键。
  static const String KEY_SUCCESS = 'success';

  /// 用于在事件数据中标识错误代码的键。
  static const String KEY_CODE = 'code';

  /// 用于在事件数据中标识错误信息或状态消息的键。
  static const String KEY_MESSAGE = 'message';

  /// 表示错误异常的类型
  static const String ERROR = 'error';
}
