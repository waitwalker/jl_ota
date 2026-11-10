package com.jieli.otasdk.data.constant

/**
 * MethodChannel 方法通道常量定义类
 *
 * 集中管理 Flutter 与 Android 原生之间通过 MethodChannel 通信的方法名 (Method) 和参数键名 (Argument)。
 */
object MethodChannelConstants {
    // <<<--- 方法名称定义 METHOD --->>>
    /** 检查当前是否正在执行蓝牙扫描的方法名 */
    const val METHOD_IS_SCANNING = "isScanning"

    /** 检查设备蓝牙与定位环境是否就绪的方法名 */
    const val METHOD_CHECK_BLUETOOTH_ENVIRONMENT = "checkBluetoothEnvironment"

    /** 启动蓝牙设备扫描的方法名 */
    const val METHOD_START_SCAN = "startScan"

    /** 停止蓝牙设备扫描的方法名 */
    const val METHOD_STOP_SCAN = "stopScan"

    /** 获取当前扫描过滤关键字的方法名 */
    const val METHOD_GET_SCAN_FILTER = "getScanFilter"

    /** 设置蓝牙扫描过滤关键字的方法名 */
    const val METHOD_SET_SCAN_FILTER = "setScanFilter"

    /** 发起连接目标蓝牙设备的方法名 */
    const val METHOD_CONNECT_DEVICE = "connectDevice"

    /** 断开目标蓝牙设备连接的方法名 */
    const val METHOD_DISCONNECT_BT_DEVICE = "disconnectBtDevice"

    /** 获取当前蓝牙通信连接方式（BLE/SPP）的方法名 */
    const val METHOD_GET_CONNECT_WAY = "getConnectWay"

    /** 设置蓝牙通信连接方式（BLE/SPP）的方法名 */
    const val METHOD_SET_CONNECT_WAY = "setConnectWay"

    /** 检查是否开启设备认证握手流程的方法名 */
    const val METHOD_IS_USE_DEVICE_AUTH = "isUseDeviceAuth"

    /** 设置是否开启设备认证握手流程的方法名 */
    const val METHOD_SET_USE_DEVICE_AUTH = "setUseDeviceAuth"

    /** 检查目标设备是否配置为 HID 模式的方法名 */
    const val METHOD_IS_HID_DEVICE = "isHidDevice"

    /** 设置目标设备是否配置为 HID 模式的方法名 */
    const val METHOD_SET_HID_DEVICE = "setHidDevice"

    /** 检查是否启用自定义回连策略的方法名 */
    const val METHOD_IS_USE_CUSTOM_RECONNECT_WAY = "isUseCustomReConnectWay"

    /** 设置是否启用自定义回连策略的方法名 */
    const val METHOD_SET_USE_CUSTOM_RECONNECT_WAY = "setUseCustomReConnectWay"

    /** 获取 BLE 请求协商 MTU 尺寸的方法名 */
    const val METHOD_GET_BLE_REQUEST_MTU = "getBleRequestMtu"

    /** 设置 BLE 请求协商 MTU 尺寸的方法名 */
    const val METHOD_SET_BLE_REQUEST_MTU = "setBleRequestMtu"

    /** 获取杰理底层 SDK 库版本号的方法名 */
    const val METHOD_GET_SDK_VERSION = "getSdkVersion"

    /** 查询当前是否处于 OTA 升级过程中的方法名 */
    const val METHOD_TYPE_IS_OTA = "isOta"

    /** 启动固件 OTA 升级流程的方法名 */
    const val METHOD_START_OTA = "startOTA"

    /** 开启或关闭底层 SDK 日志输出的方法名 */
    const val METHOD_SET_LOG_ENABLED = "setLogEnabled"

    // <<<--- 参数键名定义 ARG --->>>
    /** 蓝牙扫描过滤条件字符串参数名 */
    const val ARG_FILTER = "filter"

    /** 蓝牙通信连接方式整型参数名（如 0 为 BLE，1 为 SPP） */
    const val ARG_CONNECT_WAY = "connectWay"

    /** 是否启用设备认证流程布尔参数名 */
    const val ARG_IS_AUTH = "isAuth"

    /** 是否为 HID 设备布尔参数名 */
    const val ARG_IS_HID = "isHid"

    /** 是否采用自定义回连方式布尔参数名 */
    const val ARG_IS_CUSTOM = "isCustom"

    /** BLE 协商 MTU 大小整型参数名 */
    const val ARG_MTU = "mtu"

    /** 待升级固件文件绝对路径参数名 */
    const val ARG_PATH = "path"

    /** 设备在扫描结果列表中的下标索引参数名 */
    const val ARG_INDEX = "index"

    /** 是否开启日志输出布尔参数名 */
    const val ARG_ENABLED = "enabled"
}
