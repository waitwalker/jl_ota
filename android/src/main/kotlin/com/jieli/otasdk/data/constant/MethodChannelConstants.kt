package com.jieli.otasdk.data.constant

/**
 * Des：定义了与方法通道（MethodChannel）相关的常量，这些常量用于Flutter与原生平台之间的方法调用。
 * author: lifang
 * date: 2025/07/30
 * Copyright: Jieli Technology
 * Modify date:
 * Modified by:
 */
object MethodChannelConstants {
    // 方法名称
    const val METHOD_IS_SCANNING = "isScanning" // 检查是否正在扫描设备的方法名
    const val METHOD_CHECK_BLUETOOTH_ENVIRONMENT = "checkBluetoothEnvironment" // 检查蓝牙环境的方法名
    const val METHOD_START_SCAN = "startScan" // 开始扫描设备的方法名
    const val METHOD_STOP_SCAN = "stopScan" // 停止扫描设备的方法名
    const val METHOD_GET_SCAN_FILTER = "getScanFilter" // 获取扫描过滤条件的方法名
    const val METHOD_SET_SCAN_FILTER = "setScanFilter" // 设置扫描过滤条件的方法名
    const val METHOD_CONNECT_DEVICE = "connectDevice" // 连接设备的方法名
    const val METHOD_DISCONNECT_BT_DEVICE = "disconnectBtDevice" // 断开蓝牙设备连接的方法名
    const val METHOD_GET_CONNECT_WAY = "getConnectWay" // 获取当前连接方式的方法名
    const val METHOD_SET_CONNECT_WAY = "setConnectWay" // 设置当前连接方式的方法名
    const val METHOD_IS_USE_DEVICE_AUTH = "isUseDeviceAuth" // 检查是否使用设备认证的方法名
    const val METHOD_SET_USE_DEVICE_AUTH = "setUseDeviceAuth" // 设置是否使用设备认证的方法名
    const val METHOD_IS_HID_DEVICE = "isHidDevice" // 检查是否为HID设备的方法名
    const val METHOD_SET_HID_DEVICE = "setHidDevice" // 设置是否为HID设备的方法名
    const val METHOD_IS_USE_CUSTOM_RECONNECT_WAY = "isUseCustomReConnectWay" // 检查是否使用自定义重连方式的方法名
    const val METHOD_SET_USE_CUSTOM_RECONNECT_WAY = "setUseCustomReConnectWay" // 设置是否使用自定义重连方式的方法名
    const val METHOD_GET_BLE_REQUEST_MTU = "getBleRequestMtu" // 获取BLE请求MTU的方法名
    const val METHOD_SET_BLE_REQUEST_MTU = "setBleRequestMtu" // 设置BLE请求MTU的方法名
    const val METHOD_GET_SDK_VERSION = "getSdkVersion" // 获取SDK版本的方法名
    const val METHOD_TYPE_IS_OTA = "isOta" // 当时是否正在OTA升级
    const val METHOD_START_OTA = "startOTA" // 开始OTA更新的方法名
    const val METHOD_SET_LOG_ENABLED = "setLogEnabled" // 打开或关闭 SDK 日志，默认关闭

    // 参数键
    const val ARG_FILTER = "filter" // 扫描过滤条件参数名
    const val ARG_CONNECT_WAY = "connectWay" // 使用连接方式的参数名
    const val ARG_IS_AUTH = "isAuth" // 是否使用设备认证参数名
    const val ARG_IS_HID = "isHid" // 是否为HID设备参数名
    const val ARG_IS_CUSTOM = "isCustom" // 是否使用自定义重连方式参数名
    const val ARG_MTU = "mtu" // MTU参数名
    const val ARG_PATH = "path" // 升级的path
    const val ARG_INDEX = "index" // 索引参数名
    const val ARG_ENABLED = "enabled" // 是否打开 SDK 日志
}