package com.jieli.otasdk.data.model.device

import android.bluetooth.BluetoothDevice

/**
 * @author zqjasonZhong
 * @since 2022/9/9
 * @email zhongzhuocheng@zh-jieli.com
 * @desc 设备连接状态
 */
data class DeviceConnection(
    val device: BluetoothDevice?,
    val state: Int
) {
    /**
     * Checks if this connection refers to the same device as another connection.
     * Null devices are only equal to other null devices.
     */
    override fun equals(other: Any?): Boolean {
        if (this === other) return true
        if (javaClass != other?.javaClass) return false

        other as DeviceConnection
        if (device == null) return other.device == null
        return device == other.device
    }

    /**
     * Generates hash code based on the Bluetooth device.
     * Returns 0 for null devices.
     */
    override fun hashCode(): Int {
        return device?.hashCode() ?: 0
    }

    override fun toString(): String {
        return "DeviceConnection(device=${device?.address}, state=$state)"
    }
}