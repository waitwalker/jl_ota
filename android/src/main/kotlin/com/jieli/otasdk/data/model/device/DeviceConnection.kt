package com.jieli.otasdk.data.model.device

import android.bluetooth.BluetoothDevice

/**
 * 蓝牙设备连接状态数据包装类
 *
 * @property device 目标蓝牙物理设备实例 [BluetoothDevice]，可为空
 * @property state 当前连接状态码（参考 [com.jieli.jl_bt_ota.constant.StateCode]）
 */
data class DeviceConnection(
    val device: BluetoothDevice?,
    val state: Int
) {
    /**
     * 判断当前连接实体与另一个连接实体是否针对同一个蓝牙物理设备
     *
     * @param other 比较目标
     * @return true 表示针对同一物理设备
     */
    override fun equals(other: Any?): Boolean {
        if (this === other) return true
        if (javaClass != other?.javaClass) return false

        other as DeviceConnection
        if (device == null) return other.device == null
        return device == other.device
    }

    /**
     * 基于底层 BluetoothDevice 计算哈希码
     *
     * @return 哈希码数值
     */
    override fun hashCode(): Int {
        return device?.hashCode() ?: 0
    }

    /**
     * 返回设备 MAC 地址与连接状态的可读字符串表示
     */
    override fun toString(): String {
        return "DeviceConnection(device=${device?.address}, state=$state)"
    }
}
