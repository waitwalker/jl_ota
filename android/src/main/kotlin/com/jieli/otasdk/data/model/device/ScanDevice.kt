package com.jieli.otasdk.data.model.device

import android.bluetooth.BluetoothDevice
import com.jieli.jl_bt_ota.constant.StateCode
import com.jieli.jl_bt_ota.util.BluetoothUtil
import com.jieli.jl_bt_ota.util.CHexConver

/**
 * 扫描发现的蓝牙设备包装模型类
 *
 * 封装扫描捕获的物理设备、信号强度、原始广播包数据以及当前维护的连接状态。
 *
 * @param device 扫描发现的底层蓝牙设备实例 [BluetoothDevice]
 * @param rssi 设备的信号强度指示 (RSSI, dBm)
 * @param data 原始 BLE 广播包或扫描响应包的字节数据
 */
open class ScanDevice @JvmOverloads constructor(
    val device: BluetoothDevice,
    var rssi: Int,
    var data: ByteArray? = null
) {
    /** 当前维护的设备连接状态码，默认为未连接 [StateCode.CONNECTION_DISCONNECT] */
    var state: Int = StateCode.CONNECTION_DISCONNECT

    /**
     * 判断当前设备是否处于已连接状态
     *
     * @return true 表示已连接 [StateCode.CONNECTION_OK]
     */
    open fun isDevConnected(): Boolean = state == StateCode.CONNECTION_OK

    /**
     * 基于 BluetoothDevice 计算哈希值
     */
    override fun hashCode(): Int {
        return device.hashCode()
    }

    /**
     * 判断设备是否相同（基于 BluetoothDevice 物理相等）
     */
    override fun equals(other: Any?): Boolean {
        if (other !is ScanDevice) return false
        return device == other.device
    }

    /**
     * 输出设备信息、RSSI、连接状态与广播包 Hex 字符串
     */
    override fun toString(): String {
        return "ScanDevice(device=$device, rssi=$rssi, state=${StateCode.printConnectionState(state)}, data=${
            CHexConver.byte2HexStr(
                data
            )
        })"
    }
}
