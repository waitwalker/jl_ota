package com.jieli.otasdk.data.constant

import java.util.Locale
import java.util.UUID

/**
 * 杰理 OTA 核心参数与辅助工具常量类
 *
 * 集中管理通用服务 UUID、通信协议标识、默认配置选项、测试参数以及格式化输出方法。
 */
class OtaConstant {

    companion object {
        /** 经典蓝牙 A2DP 音频传输协议 UUID */
        val UUID_A2DP: UUID = UUID.fromString("0000110b-0000-1000-8000-00805f9b34fb")

        /** 经典蓝牙 SPP 串口通信协议标准 UUID */
        val UUID_SPP: UUID = UUID.fromString("00001101-0000-1000-8000-00805f9b34fb")

        /** 低功耗蓝牙 BLE 通信协议标识 */
        const val PROTOCOL_BLE = 0

        /** 经典蓝牙 SPP 通信协议标识 */
        const val PROTOCOL_SPP = 1

        /** 插件默认使用的通信协议（默认为 BLE 协议） */
        const val CURRENT_PROTOCOL = PROTOCOL_BLE

        /** 默认是否需要开启设备认证握手流程 */
        const val IS_NEED_DEVICE_AUTH = true

        /** 默认是否通过 HID 设备通道连接 */
        const val HID_DEVICE_WAY = false

        /** 默认是否启用自定义设备回连策略 */
        const val NEED_CUSTOM_RECONNECT_WAY = false

        /** 默认是否使用 SPP 多通道并发传输 */
        const val USE_SPP_MULTIPLE_CHANNEL = false

        /** 是否默认开启 OTA 自动化压测模式 */
        const val AUTO_TEST_OTA = false

        /** 自动化压测的默认执行轮数 */
        const val AUTO_TEST_COUNT = 30

        /** 自动化压测时是否默认允许失败容错重试 */
        const val AUTO_FAULT_TOLERANT = false

        /** 自动化压测期间允许的默认容错重试次数 */
        const val AUTO_FAULT_TOLERANT_COUNT = 1

        /** 本地固件下载与存放目录名称 */
        const val DIR_UPGRADE = "upgrade"

        /** 单次蓝牙设备扫描的默认超时时间（毫秒，默认 30 秒） */
        const val SCAN_TIMEOUT = 30 * 1000L

        /**
         * 采用系统默认 Locale 格式化字符串
         *
         * @param format 格式化字符串模板
         * @param args 格式化可变参数列表
         * @return 格式化后的完整字符串
         */
        fun formatString(format: String, vararg args: Any?): String {
            return String.format(Locale.getDefault(), format, *args)
        }
    }
}
