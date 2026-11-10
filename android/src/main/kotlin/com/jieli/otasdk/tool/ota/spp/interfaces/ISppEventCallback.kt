package com.jieli.otasdk.tool.ota.spp.interfaces

import android.bluetooth.BluetoothDevice
import java.util.UUID

/**
 * 经典蓝牙 SPP 串口通信事件监听回调接口
 *
 * 定义蓝牙开关、设备扫描、SPP 链路连接及数据接收等事件回调。
 */
interface ISppEventCallback {
    /**
     * 蓝牙适配器开关状态变更回调
     *
     * @param enabled true 为蓝牙已开启，false 为已关闭
     */
    fun onAdapterChange(enabled: Boolean)

    /**
     * 经典蓝牙设备发现扫描启停状态变更回调
     *
     * @param started true 为扫描已启动，false 为扫描已停止
     */
    fun onDiscoveryDeviceChange(started: Boolean)

    /**
     * 扫描命中发现蓝牙设备回调
     *
     * @param device 扫描到的蓝牙设备 [BluetoothDevice]
     * @param rssi 信号强度 (dBm)
     */
    fun onDiscoveryDevice(device: BluetoothDevice?, rssi: Int)

    /**
     * SPP 链路连接状态变更回调
     *
     * @param device 目标设备
     * @param uuid 关联的 SPP 通道服务 UUID
     * @param status 连接状态码（如 [android.bluetooth.BluetoothProfile.STATE_CONNECTED]）
     */
    fun onSppConnection(device: BluetoothDevice?, uuid: UUID?, status: Int)

    /**
     * 收到来自 SPP 链路的数据回调
     *
     * @param device 来源设备
     * @param uuid 对应的 SPP 通道服务 UUID
     * @param data 接收到的原始字节数据
     */
    fun onReceiveSppData(device: BluetoothDevice?, uuid: UUID?, data: ByteArray?)
}
