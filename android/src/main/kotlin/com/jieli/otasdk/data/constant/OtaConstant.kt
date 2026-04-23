package com.jieli.otasdk.data.constant

import java.util.Locale
import java.util.UUID

/**
 * Des：定义了与OTA更新相关的常量和辅助方法。
 * author: lifang
 * date: 2025/07/30
 * Copyright: Jieli Technology
 * Modify date:
 * Modified by:
 */
class OtaConstant {

    companion object {

        // A2DP协议的UUID
        val UUID_A2DP: UUID = UUID.fromString("0000110b-0000-1000-8000-00805f9b34fb")
        // SPP协议的UUID
        val UUID_SPP: UUID = UUID.fromString("00001101-0000-1000-8000-00805f9b34fb")

        // BLE协议标识
        const val PROTOCOL_BLE = 0

        // SPP协议标识
        const val PROTOCOL_SPP = 1

        // 当前使用的协议，默认为BLE
        const val CURRENT_PROTOCOL = PROTOCOL_BLE

        // 是否需要设备认证
        const val IS_NEED_DEVICE_AUTH = true

        // 是否通过HID设备连接
        const val HID_DEVICE_WAY = false

        // 是否需要自定义重连方式
        const val NEED_CUSTOM_RECONNECT_WAY = false

        // 是否使用SPP多通道连接
        const val USE_SPP_MULTIPLE_CHANNEL = false

        // 是否启用自动化测试
        const val AUTO_TEST_OTA = false

        // 自动化测试的次数
        const val AUTO_TEST_COUNT = 30

        // 自动化测试时是否允许容错
        const val AUTO_FAULT_TOLERANT = false

        // 容错次数
        const val AUTO_FAULT_TOLERANT_COUNT = 1

        // 根目录名称
        const val DIR_ROOT = "JieLiOTA"

        // 升级文件目录名称
        const val DIR_UPGRADE = "upgrade"

        // 日志目录名称
        const val DIR_LOGCAT = "logcat"

        // 扫描超时时间（毫秒）
        const val SCAN_TIMEOUT = 30 * 1000L

        /**
         * 使用本地化格式格式化字符串。
         *
         * @param format 格式化字符串模板
         * @param args 格式化参数
         * @return 格式化后的字符串
         */
        fun formatString(format: String, vararg args: Any?): String {
            return String.format(Locale.getDefault(), format, *args)
        }
    }
}