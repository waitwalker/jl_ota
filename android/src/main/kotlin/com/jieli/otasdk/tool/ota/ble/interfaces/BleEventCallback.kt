package com.jieli.otasdk.tool.ota.ble.interfaces

import android.bluetooth.BluetoothDevice
import android.bluetooth.BluetoothGattService
import com.jieli.otasdk.tool.ota.ble.model.BleScanInfo
import java.util.UUID

/**
 * BLE 事件监听回调空实现抽象基类
 *
 * 实现了 [IBleEventCallback] 接口并提供全空方法体，便于业务按需覆盖特定关心的事件。
 */
abstract class BleEventCallback : IBleEventCallback {
    /**
     * 蓝牙适配器开关状态变更回调
     *
     * @param bEnabled true 为蓝牙已开启
     */
    override fun onAdapterChange(bEnabled: Boolean) {}

    /**
     * BLE 设备扫描启停状态变更回调
     *
     * @param bStart true 为扫描开启
     */
    override fun onDiscoveryBleChange(bStart: Boolean) {}

    /**
     * BLE 扫描发现设备回调
     *
     * @param device 扫描到的蓝牙设备
     * @param bleScanInfo 设备广播与 RSSI 信息
     */
    override fun onDiscoveryBle(device: BluetoothDevice?, bleScanInfo: BleScanInfo?) {}

    /**
     * BLE 设备连接状态变更回调
     *
     * @param device 目标设备
     * @param status 连接状态码
     */
    override fun onBleConnection(device: BluetoothDevice?, status: Int) {}

    /**
     * BLE 服务发现完成回调
     *
     * @param device 目标设备
     * @param status 操作状态码
     * @param services 发现的服务列表
     */
    override fun onBleServiceDiscovery(device: BluetoothDevice?, status: Int, services: List<BluetoothGattService>?) {}

    /**
     * BLE 特征值通知开启/关闭状态回调
     *
     * @param device 目标设备
     * @param serviceUuid 服务 UUID
     * @param characteristicUuid 特征值 UUID
     * @param status 操作状态码
     */
    override fun onBleNotificationStatus(device: BluetoothDevice?, serviceUuid: UUID?, characteristicUuid: UUID?, status: Int) {}

    /**
     * BLE MTU 尺寸协商生效回调
     *
     * @param device 目标设备
     * @param block 协商生效的 MTU 大小
     * @param status 操作状态码
     */
    override fun onBleDataBlockChanged(device: BluetoothDevice?, block: Int, status: Int) {}

    /**
     * 收到来自 BLE 设备特征值主动上报的数据回调
     *
     * @param device 来源设备
     * @param serviceUuid 对应的服务 UUID
     * @param characteristicsUuid 对应的特征值 UUID
     * @param data 接收到的原始字节数组
     */
    override fun onBleDataNotification(device: BluetoothDevice?, serviceUuid: UUID?, characteristicsUuid: UUID?, data: ByteArray?) {}

    /**
     * 写入特征值数据完成状态回调
     *
     * @param device 目标设备
     * @param serviceUuid 对应的服务 UUID
     * @param characteristicsUuid 对应的特征值 UUID
     * @param data 写入的字节数组
     * @param status 写入状态码
     */
    override fun onBleWriteStatus(device: BluetoothDevice?, serviceUuid: UUID?, characteristicsUuid: UUID?, data: ByteArray?, status: Int) {}

    /**
     * BLE 连接参数更新回调
     *
     * @param device 目标设备
     * @param interval 连接间隔
     * @param latency 从机延迟
     * @param timeout 监督超时
     * @param status 操作状态码
     */
    override fun onConnectionUpdated(device: BluetoothDevice?, interval: Int, latency: Int, timeout: Int, status: Int) {}

    /**
     * 切换当前通信活动的 BLE 目标设备回调
     *
     * @param device 当前被激活使用的目标设备
     */
    override fun onSwitchBleDevice(device: BluetoothDevice?) {}
}
