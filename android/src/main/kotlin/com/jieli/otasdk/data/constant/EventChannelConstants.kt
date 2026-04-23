package com.jieli.otasdk.data.constant

/**
 * Des：定义了事件通道中使用的常量，包括事件类型、状态值、扫描状态、负载键和消息文本。
 * author: lifang
 * date: 2025/07/30
 * Copyright: Jieli Technology
 * Modify date:
 * Modified by:
 */
object EventChannelConstants {
    // 事件类型
    const val TYPE_BLUETOOTH_STATE = "bluetoothState" // 蓝牙状态事件类型
    const val TYPE_DEVICE_CONNECTION = "deviceConnection" // 设备连接事件类型
    const val TYPE_SCAN_DEVICE_LIST = "scanDeviceList" // 扫描设备列表事件类型
    const val TYPE_OTA_CONNECTION = "otaConnection" // OTA连接事件类型
    const val TYPE_DOWNLOAD_STATUS = "downloadStatus" // 下载状态事件类型
    const val TYPE_OTA_FILE_LIST = "otaFileList" // OTA文件列表事件类型
    const val TYPE_SELECTED_FILE_PATHS = "selectedFilePaths" // 选中文件路径列表事件类型
    const val TYPE_MANDATORY_UPGRADE = "mandatoryUpgrade" // 强制升级事件类型
    const val TYPE_OTA_STATE = "otaState" // OTA状态事件类型

    // 状态值
    const val STATUS_ON_PROGRESS = "onProgress" // 正在进行中状态
    const val STATUS_ON_STOP = "onStop" // 已停止状态
    const val STATUS_ON_ERROR = "onError" // 错误状态
    const val STATUS_ON_START = "onStart" // 已开始状态
    const val STATUS_UNKNOWN = "unknown" // 未知状态
    const val STATE_IDLE = "idle" // 空闲状态
    const val STATE_START = "start" // 开始状态
    const val STATE_RECONNECT = "reconnect" // 重新连接状态
    const val STATE_WORKING = "working" // 工作状态
    const val STATE_UNKNOWN = "unknown" // 未知状态

    // 扫描状态
    const val SCAN_STATE_SCANNING = "scanning" // 正在扫描状态
    const val SCAN_STATE_FOUND_DEV = "foundDevice" // 发现设备状态
    const val SCAN_STATE_IDLE = "idle" // 空闲状态

    // 负载键
    const val KEY_TYPE = "type" // 类型键
    const val KEY_VALUE = "value" // 值键
    const val KEY_STATE = "state" // 状态键
    const val KEY_LIST = "list" // 列表键
    const val KEY_STATUS = "status" // 状态键
    const val KEY_PROGRESS = "progress" // 进度键
    const val KEY_MESSAGE = "message" // 消息键
    const val KEY_DEVICE_TYPE = "deviceType" // 设备类型键
    const val KEY_NAME = "name" // 名称键
    const val KEY_DESC = "desc" // 描述键
    const val KEY_PATH = "path" // 路径键
    const val KEY_IS_REQUIRED = "isRequired" // 是否必需键
    const val KEY_SUCCESS = "success" // 成功键
    const val KEY_CODE = "code" // 代码键

    // 消息文本
    const val MSG_CHECKING_FILE = "Checking file" // 正在检查文件消息
    const val MSG_UPGRADING = "Upgrading" // 正在升级消息
    const val MSG_SUCCESS = "Success" // 成功消息
    const val MSG_UNKNOWN_ERROR = "Unknown Error" // 未知错误消息
    const val MSG_OTA_IN_PROGRESS = "OTA in progress" // OTA正在进行中消息
    const val MSG_NO_OTA_FILE = "No found ota file" // 未找到OTA文件消息
}