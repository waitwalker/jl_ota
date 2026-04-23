/// 定义了与BLE（蓝牙低功耗）方法调用相关的常量。
class BleMethodConstants {
  /// 检查是否正在扫描设备的方法名。
  static const String METHOD_IS_SCANNING = 'isScanning';

  /// 检查蓝牙环境的方法名。
  static const String METHOD_CHECK_BLUETOOTH_ENVIRONMENT = 'checkBluetoothEnvironment';

  /// 开始扫描设备的方法名。
  static const String METHOD_START_SCAN = 'startScan';

  /// 停止扫描设备的方法名。
  static const String METHOD_STOP_SCAN = 'stopScan';

  /// 获取扫描过滤条件的方法名。
  static const String METHOD_GET_SCAN_FILTER = 'getScanFilter';

  /// 设置扫描过滤条件的方法名。
  static const String METHOD_SET_SCAN_FILTER = 'setScanFilter';

  /// 连接设备的方法名。
  static const String METHOD_CONNECT_DEVICE = 'connectDevice';

  /// 断开蓝牙设备连接的方法名。
  static const String METHOD_DISCONNECT_BT_DEVICE = 'disconnectBtDevice';

  /// 检查是否使用BLE方式的方法名。
  static const String METHOD_IS_BLE_WAY = 'isBleWay';

  /// 设置是否使用BLE方式的方法名。
  static const String METHOD_SET_BLE_WAY = 'setBleWay';

  /// 检查是否使用SDK蓝牙连接的方法名。
  static const String METHOD_IS_USING_SDK_BLUETOOTH = 'isUseSDKBluetooth';

  /// 设置是否使用SDK蓝牙连接的方法名。
  static const String METHOD_SET_USING_SDK_BLUETOOTH = 'setUseSDKBluetooth';

  /// 检查是否使用设备认证的方法名。
  static const String METHOD_IS_USE_DEVICE_AUTH = 'isUseDeviceAuth';

  /// 设置是否使用设备认证的方法名。
  static const String METHOD_SET_USE_DEVICE_AUTH = 'setUseDeviceAuth';

  /// 检查是否为HID设备的方法名。
  static const String METHOD_IS_HID_DEVICE = 'isHidDevice';

  /// 设置是否为HID设备的方法名。
  static const String METHOD_SET_HID_DEVICE = 'setHidDevice';

  /// 检查是否使用自定义重连方式的方法名。
  static const String METHOD_IS_USE_CUSTOM_RECONNECT_WAY = 'isUseCustomReConnectWay';

  /// 设置是否使用自定义重连方式的方法名。
  static const String METHOD_SET_USE_CUSTOM_RECONNECT_WAY = 'setUseCustomReConnectWay';

  /// 获取BLE请求MTU的方法名。
  static const String METHOD_GET_BLE_REQUEST_MTU = 'getBleRequestMtu';

  /// 设置BLE请求MTU的方法名。
  static const String METHOD_SET_BLE_REQUEST_MTU = 'setBleRequestMtu';

  /// 获取SDK版本的方法名。
  static const String METHOD_GET_SDK_VERSION = 'getSdkVersion';

  /// 获取应用版本的方法名。
  static const String METHOD_GET_APP_VERSION = 'getAppVersion';

  /// 获取打印日志位置。
  static const String METHOD_GET_LOG_FILE_DIR_PATH = 'getLogFileDirPath';

  /// 获取日志文件列表的方法名。
  static const String METHOD_GET_LOG_FILES = 'getLogFiles';

  /// 处理日志文件索引的方法名。
  static const String METHOD_LOG_FILE_INDEX = 'logFileIndex';

  /// 分享日志文件的方法名。
  static const String METHOD_SHARE_LOG_FILE = 'shareLogFile';

  /// 下载文件的方法名。
  static const String METHOD_DOWNLOAD_FILE = 'downloadFile';

  /// 读取文件列表的方法名。
  static const String METHOD_READ_FILE_LIST = 'readFileList';

  /// 设置选中索引的方法名。
  static const String METHOD_SET_SELECTED_INDEX = 'setSelectedIndex';

  /// 删除OTA文件索引的方法名。
  static const String METHOD_DELETE_OTA_FILE_INDEX = 'deleteOtaFileIndex';

  /// 检查存储环境的方法名。
  static const String METHOD_TRY_TO_CHECK_STORAGE_ENVIRONMENT = 'tryToCheckStorageEnvironment';

  /// 选择文件的方法名。
  static const String METHOD_PICK_FILE = 'pickFile';

  /// 表示当时是否正在OTA升级。
  static const String METHOD_TYPE_IS_OTA = 'isOta';

  /// 开始OTA更新的方法名。
  static const String METHOD_START_OTA = 'startOTA';

  /// 删除所有日志文件的方法名。
  static const String METHOD_DELETE_ALL_LOG_FILE = 'deleteAllLogFile';

  /// 获取WiFi IP地址的方法名。
  static const String METHOD_GET_WIFI_IP_ADDRESS = 'getWifiIpAddress';

  /// 退出所有的Activity
  static const String METHOD_POP_ALL_ACTIVITY = 'popAllActivity';

  /// 索引参数名。
  static const String ARG_INDEX = 'index';

  /// 过滤条件参数名。
  static const String ARG_FILTER = 'filter';

  /// 是否使用BLE方式参数名。
  static const String ARG_IS_BLE = 'isBle';

  /// 是否使用SDK蓝牙连接。
  static const String ARG_IS_USING_SDK_BLUETOOTH = 'isUsingSDKBluetooth';

  /// 是否使用设备认证参数名。
  static const String ARG_IS_AUTH = 'isAuth';

  /// 是否为HID设备参数名。
  static const String ARG_IS_HID = 'isHid';

  /// 是否使用自定义重连方式参数名。
  static const String ARG_IS_CUSTOM = 'isCustom';

  /// MTU参数名。
  static const String ARG_MTU = 'mtu';

  /// 日志文件索引参数名。
  static const String ARG_LOG_FILE_INDEX = 'logFileIndex';

  /// HTTP URL参数名。
  static const String ARG_HTTP_URL = 'httpUrl';

  /// 位置参数名。
  static const String ARG_POS = 'pos';

  /// 升级的path
  static const String ARG_PATH = 'path';
}
