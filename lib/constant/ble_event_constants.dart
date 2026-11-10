/// BLE 与 OTA 原生事件流（EventChannel）常量定义类
///
/// 集中定义原生 Android 侧通过 EventChannel 向上层派发的所有事件类型（type）、
/// 载荷字段键名（Key）以及状态枚举字符串。
class BleEventConstants {
  /// 扫描状态：正在执行低功耗蓝牙设备扫描
  static const String SCAN_STATE_SCANNING = "scanning";

  /// 扫描状态：在扫描周期内发现新设备或设备列表刷新
  static const String SCAN_STATE_FOUND_DEV = "foundDevice";

  /// 扫描状态：扫描处于空闲/已停止状态
  static const String SCAN_STATE_IDLE = "idle";

  /// 原生事件类型：系统蓝牙适配器开关状态变更事件
  static const String TYPE_BLUETOOTH_STATE = 'bluetoothState';

  /// 原生事件类型：扫描发现的蓝牙设备列表数据更新事件
  static const String TYPE_SCAN_DEVICE_LIST = 'scanDeviceList';

  /// 原生事件类型：蓝牙设备物理链路连接状态（连接中/已连接/断开）变更事件
  static const String TYPE_DEVICE_CONNECTION = 'deviceConnection';

  /// 原生事件类型：OTA 升级通道连接状态变更事件
  static const String TYPE_OTA_CONNECTION = 'otaConnection';

  /// 原生事件类型：是否属于强制升级模式判定事件
  static const String TYPE_MANDATORY_UPGRADE = 'mandatoryUpgrade';

  /// 原生事件类型：OTA 固件升级执行状态（准备/传输中/重启/完成/失败）变更事件
  static const String TYPE_OTA_STATE = 'otaState';

  /// 事件数据字典键名：标识原生派发的事件类型（对应 TYPE_* 常量）
  static const String KEY_TYPE = 'type';

  /// 事件数据字典键名：标识事件携带的具体数据载荷对象（Map 或基本类型）
  static const String KEY_VALUE = 'value';

  /// 事件数据字典键名：标识业务执行的状态码或状态描述
  static const String KEY_STATUS = 'status';

  /// 事件数据字典键名：标识当前设备或流程的具体运行状态
  static const String KEY_STATE = 'state';

  /// OTA 流程状态：空闲状态，未开始升级
  static const String KEY_STATE_IDLE = "idle";

  /// OTA 流程状态：升级任务开始启动
  static const String KEY_STATE_START = "start";

  /// OTA 流程状态：设备重启进入 BootLoader，正在等待自动回连
  static const String KEY_STATE_RECONNECT = "reconnect";

  /// OTA 流程状态：固件文件传输中或固件校验中
  static const String KEY_STATE_WORKING = 'working';

  /// OTA 流程状态：未知状态
  static const String KEY_STATE_UNKNOWN = "unknown";

  /// 事件数据字典键名：当前固件写入进度百分比（0.0 ~ 1.0 或 0 ~ 100）
  static const String KEY_PROGRESS = 'progress';

  /// OTA 阶段描述：正在校验升级文件有效性
  static const String KEY_CHECK_FILE = 'Checking file';

  /// OTA 阶段描述：正在向设备传输升级数据包
  static const String KEY_UPGRADING = 'Upgrading';

  /// 事件数据字典键名：包含设备列表或数据集合的 List 载荷
  static const String KEY_LIST = 'list';

  /// 事件数据字典键名：事件内部嵌套数据对象
  static const String KEY_EVENT = 'event';

  /// 事件数据字典键名：布尔值，标识当前设备固件是否必须强制升级（不允许取消）
  static const String KEY_IS_REQUIRED = 'isRequired';

  /// 事件数据字典键名：文件名称或蓝牙设备广播名称
  static const String KEY_NAME = 'name';

  /// 事件数据字典键名：本地文件绝对路径
  static const String KEY_PATH = 'path';

  /// 事件数据字典键名：蓝牙设备类型（如经典蓝牙/BLE/双模/音箱/耳机等）
  static const String KEY_DEVICE_TYPE = 'deviceType';

  /// 事件数据字典键名：布尔值，标识操作是否成功执行
  static const String KEY_SUCCESS = 'success';

  /// 事件数据字典键名：错误码或返回结果状态码
  static const String KEY_CODE = 'code';

  /// 事件数据字典键名：错误原因描述或状态提示信息
  static const String KEY_MESSAGE = 'message';

  /// 事件数据字典键名：异常或错误标识
  static const String ERROR = 'error';
}
