//
//  EventChannelConstants.swift
//  Runner
//
//  Created by 李放 on 2025/9/1.
//

/// Defines constants used in the event channel, including event types, state values, scan states, payload keys, and message texts.
struct EventChannelConstants {
    // 事件类型
    static let TYPE_BLUETOOTH_STATE = "bluetoothState" // 蓝牙状态事件类型
    static let TYPE_DEVICE_CONNECTION = "deviceConnection" // 设备连接事件类型
    static let TYPE_SCAN_DEVICE_LIST = "scanDeviceList" // 扫描设备列表事件类型
    static let TYPE_OTA_CONNECTION = "otaConnection" // OTA连接事件类型
    static let TYPE_DOWNLOAD_STATUS = "downloadStatus" // 下载状态事件类型
    static let TYPE_OTA_FILE_LIST = "otaFileList" // OTA文件列表事件类型
    static let TYPE_SELECTED_FILE_PATHS = "selectedFilePaths" // 选中文件路径列表事件类型
    static let TYPE_MANDATORY_UPGRADE = "mandatoryUpgrade" // 强制升级事件类型
    static let TYPE_OTA_STATE = "otaState" // OTA状态事件类型

    // 状态值
    static let STATUS_ON_PROGRESS = "onProgress" // 正在进行中状态
    static let STATUS_ON_STOP = "onStop" // 已停止状态
    static let STATUS_ON_ERROR = "onError" // 错误状态
    static let STATUS_ON_START = "onStart" // 已开始状态
    static let STATUS_UNKNOWN = "unknown" // 未知状态
    static let STATE_IDLE = "idle" // 空闲状态
    static let STATE_START = "start" // 开始状态
    static let STATE_RECONNECT = "reconnect" // 重新连接状态
    static let STATE_WORKING = "working" // 工作状态
    static let STATE_UNKNOWN = "unknown" // 未知状态

    // 扫描状态
    static let SCAN_STATE_SCANNING = "scanning" // 正在扫描状态
    static let SCAN_STATE_FOUND_DEV = "foundDevice" // 发现设备状态
    static let SCAN_STATE_IDLE = "idle" // 空闲状态

    // 负载键
    static let KEY_TYPE = "type" // 类型键
    static let KEY_VALUE = "value" // 值键
    static let KEY_STATE = "state" // 状态键
    static let KEY_LIST = "list" // 列表键
    static let KEY_STATUS = "status" // 状态键
    static let KEY_PROGRESS = "progress" // 进度键
    static let KEY_MESSAGE = "message" // 消息键
    static let KEY_DEVICE_TYPE = "deviceType" // 设备类型键
    static let KEY_NAME = "name" // 名称键
    static let KEY_DESC = "desc" // 描述键
    static let KEY_PATH = "path" // 路径键
    static let KEY_IS_REQUIRED = "isRequired" // 是否必需键
    static let KEY_SUCCESS = "success" // 成功键
    static let KEY_CODE = "code" // 代码键

    // 消息文本
    static let MSG_CHECKING_FILE = "Checking file" // 正在检查文件消息
    static let MSG_UPGRADING = "Upgrading" // 正在升级消息
    static let MSG_SUCCESS = "Success" // 成功消息
    static let MSG_UNKNOWN_ERROR = "Unknown Error" // 未知错误消息
    static let MSG_OTA_IN_PROGRESS = "OTA in progress" // OTA正在进行中消息
    static let MSG_NO_OTA_FILE = "No found ota file" // 未找到OTA文件消息
}
