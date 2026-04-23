//
//  MethodChannelConstants.swift
//  Runner
//
//  Created by 李放 on 2025/9/1.
//

/// Defines constants related to the MethodChannel, which are used for method invocations between Flutter and the native platform.
struct MethodChannelConstants {
    // 方法名称
    static let METHOD_IS_SCANNING = "isScanning" // 检查是否正在扫描设备的方法名
    static let METHOD_CHECK_BLUETOOTH_ENVIRONMENT = "checkBluetoothEnvironment" // 检查蓝牙环境的方法名
    static let METHOD_START_SCAN = "startScan" // 开始扫描设备的方法名
    static let METHOD_STOP_SCAN = "stopScan" // 停止扫描设备的方法名
    static let METHOD_GET_SCAN_FILTER = "getScanFilter" // 获取扫描过滤条件的方法名
    static let METHOD_SET_SCAN_FILTER = "setScanFilter" // 设置扫描过滤条件的方法名
    static let METHOD_CONNECT_DEVICE = "connectDevice" // 连接设备的方法名
    static let METHOD_DISCONNECT_BT_DEVICE = "disconnectBtDevice" // 断开蓝牙设备连接的方法名
    static let METHOD_IS_BLE_WAY = "isBleWay" // 检查是否使用BLE方式的方法名
    static let METHOD_SET_BLE_WAY = "setBleWay" // 设置是否使用BLE方式的方法名
    static let METHOD_IS_USE_DEVICE_AUTH = "isUseDeviceAuth" // 检查是否使用设备认证的方法名
    static let METHOD_SET_USE_DEVICE_AUTH = "setUseDeviceAuth" // 设置是否使用设备认证的方法名
    static let METHOD_IS_USING_SDK_BLUETOOTH = "isUseSDKBluetooth" // 检查是否使用SDK蓝牙连接的方法名
    static let METHOD_SET_USING_SDK_BLUETOOTH = "setUseSDKBluetooth" // 设置是否使用SDK蓝牙连接的方法名
    static let METHOD_IS_HID_DEVICE = "isHidDevice" // 检查是否为HID设备的方法名
    static let METHOD_SET_HID_DEVICE = "setHidDevice" // 设置是否为HID设备的方法名
    static let METHOD_IS_USE_CUSTOM_RECONNECT_WAY = "isUseCustomReConnectWay" // 检查是否使用自定义重连方式的方法名
    static let METHOD_SET_USE_CUSTOM_RECONNECT_WAY = "setUseCustomReConnectWay" // 设置是否使用自定义重连方式的方法名
    static let METHOD_GET_BLE_REQUEST_MTU = "getBleRequestMtu" // 获取BLE请求MTU的方法名
    static let METHOD_SET_BLE_REQUEST_MTU = "setBleRequestMtu" // 设置BLE请求MTU的方法名
    static let METHOD_GET_SDK_VERSION = "getSdkVersion" // 获取SDK版本的方法名
    static let METHOD_GET_APP_VERSION = "getAppVersion" // 获取应用版本的方法名
    static let METHOD_GET_LOG_FILES = "getLogFiles" // 获取日志文件列表的方法名
    static let METHOD_LOG_FILE_INDEX = "logFileIndex" // 处理日志文件索引的方法名
    static let METHOD_SHARE_LOG_FILE = "shareLogFile" // 分享日志文件的方法名
    static let METHOD_DOWNLOAD_FILE = "downloadFile" // 下载文件的方法名
    static let METHOD_TYPE_IS_OTA = "isOta" // 当时是否正在OTA升级
    static let METHOD_READ_FILE_LIST = "readFileList" // 读取文件列表的方法名
    static let METHOD_SET_SELECTED_INDEX = "setSelectedIndex" // 设置选中索引的方法名
    static let METHOD_DELETE_OTA_FILE_INDEX = "deleteOtaFileIndex" // 删除OTA文件索引的方法名
    static let METHOD_TRY_TO_CHECK_STORAGE_ENVIRONMENT = "tryToCheckStorageEnvironment" // 检查存储环境的方法名
    static let METHOD_PICK_FILE = "pickFile" // 选择文件的方法名
    static let METHOD_START_OTA = "startOTA" // 开始OTA更新的方法名
    static let METHOD_DELETE_ALL_LOG_FILE = "deleteAllLogFile" // 删除所有日志文件的方法名
    static let METHOD_GET_WIFI_IP_ADDRESS = "getWifiIpAddress" // 获取WiFi IP地址的方法名
    static let METHOD_GET_LOG_FILE_DIR_PATH = "getLogFileDirPath" // 获取打印日志位置
    static let METHOD_POP_ALL_ACTIVITY = "popAllActivity" // 退出所有的Activity
    static let METHOD_ON_FILE_PICKED = "onFilePicked" // 当前从文本系统中选择的升级文件
    static let METHOD_HANDLE_FILE_PICKED = "handleFilePicked" // 处理修改的升级文件名称

    // 参数键
    static let ARG_FILTER = "filter" // 扫描过滤条件参数名
    static let ARG_IS_BLE = "isBle" // 是否使用BLE方式参数名
    static let ARG_IS_AUTH = "isAuth" // 是否使用设备认证参数名
    static let ARG_IS_USING_SDK_BLUETOOTH = "isUsingSDKBluetooth" // 是否使用SDK蓝牙连接
    static let ARG_IS_HID = "isHid" // 是否为HID设备参数名
    static let ARG_IS_CUSTOM = "isCustom" // 是否使用自定义重连方式参数名
    static let ARG_MTU = "mtu" // MTU参数名
    static let ARG_LOG_FILE_INDEX = "logFileIndex" // 日志文件索引参数名
    static let ARG_HTTP_URL = "httpUrl" // HTTP URL参数名
    static let ARG_POS = "pos" // 位置参数名
    static let ARG_PATH = "path" // 升级的path
    static let ARG_INDEX = "index" // 索引参数名
    static let ARG_FILE_NAME = "fileName" // 升级文件名称
}
