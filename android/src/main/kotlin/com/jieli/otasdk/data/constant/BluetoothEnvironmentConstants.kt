package com.jieli.otasdk.data.constant

/**
 * Des: 定义与蓝牙环境检查相关的常量。
 * 此类包含用于日志记录、错误消息以及特定于蓝牙环境检查操作的标识符。
 * author: lifang
 * date: 2025/07/30
 * Copyright: Jieli Technology
 * Modify date:
 * Modified by:
 */
object BluetoothEnvironmentConstants {
    /**
     * 用于日志记录的标签，标识与蓝牙环境检查相关的日志条目。
     */
    const val TAG = "BluetoothEnvironmentChecker"

    /**
     * 当检查蓝牙环境时遇到错误，用于记录或显示的错误消息。
     */
    const val LOG_ERROR_CHECKING_ENVIRONMENT = "Error checking bluetooth environment"

    /**
     * 用于标识与蓝牙环境检查相关的Fragment的标签。
     * 此标签可用于在FragmentManager中查找或引用特定的Fragment。
     */
    const val FRAGMENT_TAG = "bt_env_check"
}