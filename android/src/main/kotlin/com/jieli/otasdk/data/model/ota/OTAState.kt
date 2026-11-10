package com.jieli.otasdk.data.model.ota

import android.bluetooth.BluetoothDevice
import com.jieli.otasdk.data.constant.OtaConstant

/**
 * OTA 升级基础状态基类
 *
 * 封装 OTA 升级过程中的基础状态码及关联的蓝牙设备，派生出开始、传输、回连、结束等具体状态子类。
 *
 * @property state 当前 OTA 状态码，默认为空闲 [OTA_STATE_IDLE]
 * @property device 处于升级状态的目标蓝牙设备 [BluetoothDevice]
 */
open class OTAState(val state: Int = OTA_STATE_IDLE, var device: BluetoothDevice?) {

    companion object {
        /** OTA 处于空闲状态（升级未开始或已结束） */
        const val OTA_STATE_IDLE = 0

        /** OTA 正式开始启动状态 */
        const val OTA_STATE_START = 1

        /** OTA 固件数据传输进行中状态 */
        const val OTA_STATE_WORKING = 2

        /** OTA 升级中芯片重启并需要设备重连状态 */
        const val OTA_STATE_RECONNECT = 3

        /**
         * 将状态码转换为易读的描述字符串
         *
         * @param state 状态码数值
         * @return 可读状态字符串
         */
        fun printOTAState(state: Int): String = when (state) {
            OTA_STATE_IDLE -> "OTA_STATE_IDLE(0)"
            OTA_STATE_START -> "OTA_STATE_START(1)"
            OTA_STATE_WORKING -> "OTA_STATE_WORKING(2)"
            OTA_STATE_RECONNECT -> "OTA_STATE_RECONNECT(3)"
            else -> OtaConstant.formatString("OTA_STATE_UNKNOWN(%d)", state)
        }
    }

    override fun toString(): String {
        return "OTAState(state=${printOTAState(state)}, device=$device)"
    }
}
