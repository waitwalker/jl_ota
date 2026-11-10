package com.jieli.otasdk.data.constant

/**
 * EventChannel 事件通道常量定义类
 *
 * 集中管理原生层通过 EventChannel 向 Flutter 端派发的各类事件类型、状态字符串、数据 Payload 键名以及通用状态文本。
 */
object EventChannelConstants {
    // <<<--- 事件大类标识 TYPE --->>>
    /** 蓝牙适配器开关状态事件类型 */
    const val TYPE_BLUETOOTH_STATE = "bluetoothState"

    /** 蓝牙设备连接状态事件类型 */
    const val TYPE_DEVICE_CONNECTION = "deviceConnection"

    /** 扫描设备列表变更事件类型 */
    const val TYPE_SCAN_DEVICE_LIST = "scanDeviceList"

    /** OTA 期间专用连接状态事件类型 */
    const val TYPE_OTA_CONNECTION = "otaConnection"

    /** 设备强制升级通知事件类型 */
    const val TYPE_MANDATORY_UPGRADE = "mandatoryUpgrade"

    /** OTA 升级全生命周期状态事件类型 */
    const val TYPE_OTA_STATE = "otaState"

    // <<<--- 状态值定义 STATE --->>>
    /** 空闲或就绪状态 */
    const val STATE_IDLE = "idle"

    /** 开始状态 */
    const val STATE_START = "start"

    /** 重连状态（如 OTA 芯片重启后的回连） */
    const val STATE_RECONNECT = "reconnect"

    /** 工作/传输中状态 */
    const val STATE_WORKING = "working"

    /** 未知状态 */
    const val STATE_UNKNOWN = "unknown"

    // <<<--- 扫描状态定义 SCAN_STATE --->>>
    /** 正在扫描设备中 */
    const val SCAN_STATE_SCANNING = "scanning"

    /** 扫描发现新设备 */
    const val SCAN_STATE_FOUND_DEV = "foundDevice"

    /** 扫描处于空闲或已停止状态 */
    const val SCAN_STATE_IDLE = "idle"

    // <<<--- 数据负载字段键 KEY --->>>
    /** 事件大类键名 */
    const val KEY_TYPE = "type"

    /** 事件具体数据键名 */
    const val KEY_VALUE = "value"

    /** 状态标识键名 */
    const val KEY_STATE = "state"

    /** 设备列表集合键名 */
    const val KEY_LIST = "list"

    /** 状态布尔值或整型键名 */
    const val KEY_STATUS = "status"

    /** 升级进度百分比键名 (0 - 100) */
    const val KEY_PROGRESS = "progress"

    /** 提示或错误文本消息键名 */
    const val KEY_MESSAGE = "message"

    /** 蓝牙设备类型描述键名（如经典蓝牙、BLE、双模） */
    const val KEY_DEVICE_TYPE = "deviceType"

    /** 设备显示名称键名 */
    const val KEY_NAME = "name"

    /** 设备附加描述信息键名（如 RSSI 与 MAC 地址） */
    const val KEY_DESC = "desc"

    /** 文件存储路径键名 */
    const val KEY_PATH = "path"

    /** 是否需要强制执行布尔标识键名 */
    const val KEY_IS_REQUIRED = "isRequired"

    /** 操作是否成功布尔标识键名 */
    const val KEY_SUCCESS = "success"

    /** 状态码或错误码整型键名 */
    const val KEY_CODE = "code"

    // <<<--- 消息文本提示 MSG --->>>
    /** 正在校验固件文件提示 */
    const val MSG_CHECKING_FILE = "Checking file"

    /** 固件传输升级中提示 */
    const val MSG_UPGRADING = "Upgrading"

    /** 操作或升级成功提示 */
    const val MSG_SUCCESS = "Success"

    /** 未知异常错误提示 */
    const val MSG_UNKNOWN_ERROR = "Unknown Error"

    /** 当前已有 OTA 升级在执行中提示 */
    const val MSG_OTA_IN_PROGRESS = "OTA in progress"

    /** 未找到有效的 OTA 固件文件提示 */
    const val MSG_NO_OTA_FILE = "No found ota file"
}
