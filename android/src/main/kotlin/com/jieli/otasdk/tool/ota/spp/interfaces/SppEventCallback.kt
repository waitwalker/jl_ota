package com.jieli.otasdk.tool.ota.spp.interfaces

import android.bluetooth.BluetoothDevice
import java.util.UUID

/**
 * SPP 事件监听回调空实现抽象基类
 *
 * 实现了 [ISppEventCallback] 接口并提供全空方法体，便于业务按需覆盖特定关心的事件。
 */
abstract class SppEventCallback : ISppEventCallback {
    /**
     * 蓝牙适配器开关状态变更回调
     *
     * @param enabled true 为蓝牙已开启
     */
    override fun onAdapterChange(enabled: Boolean) {}

    /**
     * 经典蓝牙设备扫描启停状态回调
     *
     * @param started true 为扫描启动
     */
    override fun onDiscoveryDeviceChange(started: Boolean) {}

    /**
     * 扫描命中发现蓝牙设备回调
     *
     * @param device 扫描到的蓝牙设备
     * @param rssi 信号强度
     */
    override fun onDiscoveryDevice(device: BluetoothDevice?, rssi: Int) {}

    /**
     * SPP 链路连接状态变更回调
     *
     * @param device 目标设备
     * @param uuid SPP 通道服务 UUID
     * @param status 连接状态码
     */
    override fun onSppConnection(device: BluetoothDevice?, uuid: UUID?, status: Int) {}

    /**
     * 收到 SPP 链路数据回调
     *
     * @param device 来源设备
     * @param uuid 对应的 SPP 通道服务 UUID
     * @param data 接收到的原始字节数组
     */
    override fun onReceiveSppData(device: BluetoothDevice?, uuid: UUID?, data: ByteArray?) {}
}
