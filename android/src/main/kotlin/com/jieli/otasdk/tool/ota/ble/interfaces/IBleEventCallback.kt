package com.jieli.otasdk.tool.ota.ble.interfaces

import android.bluetooth.BluetoothDevice
import android.bluetooth.BluetoothGattService
import com.jieli.otasdk.tool.ota.ble.model.BleScanInfo
import java.util.UUID

/**
 * BLE 底层事件监听回调接口
 *
 * 定义 BLE 适配器开关、扫描、连接、GATT 服务发现、通知使能、MTU 协商、数据收发及参数更新等全量事件回调。
 */
interface IBleEventCallback {
    /**
     * 蓝牙适配器开关状态变更回调
     *
     * @param bEnabled true 表示系统蓝牙已开启，false 表示已关闭
     */
    fun onAdapterChange(bEnabled: Boolean)

    /**
     * BLE 设备扫描启停状态变更回调
     *
     * @param bStart true 为扫描已启动，false 为扫描已停止
     */
    fun onDiscoveryBleChange(bStart: Boolean)

    /**
     * BLE 扫描命中发现设备回调
     *
     * @param device 扫描到的蓝牙设备 [BluetoothDevice]
     * @param bleScanInfo 包含广播包与 RSSI 的包装模型 [BleScanInfo]
     */
    fun onDiscoveryBle(device: BluetoothDevice?, bleScanInfo: BleScanInfo?)

    /**
     * BLE 设备物理连接状态变更回调
     *
     * @param device 目标蓝牙物理设备
     * @param status 连接状态（如已连接、断开等系统或协议状态码）
     */
    fun onBleConnection(device: BluetoothDevice?, status: Int)

    /**
     * BLE 设备 GATT 服务发现完成回调
     *
     * @param device 目标蓝牙物理设备
     * @param status 服务发现操作状态（GATT_SUCCESS 表示成功）
     * @param services 设备支持的 GATT 服务列表集合
     */
    fun onBleServiceDiscovery(device: BluetoothDevice?, status: Int, services: List<BluetoothGattService>?)

    /**
     * BLE 特征值通知 (Notification/Indication) 开启或关闭状态回调
     *
     * @param device 目标设备
     * @param serviceUuid 服务 UUID
     * @param characteristicUuid 特征值 UUID
     * @param status 操作状态码
     */
    fun onBleNotificationStatus(device: BluetoothDevice?, serviceUuid: UUID?, characteristicUuid: UUID?, status: Int)

    /**
     * BLE 数据通信 MTU 大小变更回调
     *
     * @param device 目标设备
     * @param block 协商生效的最新 MTU 大小（字节）
     * @param status 操作状态码
     */
    fun onBleDataBlockChanged(device: BluetoothDevice?, block: Int, status: Int)

    /**
     * 收到来自 BLE 设备特征值主动上报/通知的数据回调
     *
     * @param device 来源设备
     * @param serviceUuid 对应的服务 UUID
     * @param characteristicsUuid 对应的特征值 UUID
     * @param data 接收到的原始字节数组
     */
    fun onBleDataNotification(device: BluetoothDevice?, serviceUuid: UUID?, characteristicsUuid: UUID?, data: ByteArray?)

    /**
     * BLE 写入特征值数据状态结果回调
     *
     * @param device 目标设备
     * @param serviceUuid 对应的服务 UUID
     * @param characteristicsUuid 对应的特征值 UUID
     * @param data 写入的原始字节数组
     * @param status 写入操作结果状态码
     */
    fun onBleWriteStatus(device: BluetoothDevice?, serviceUuid: UUID?, characteristicsUuid: UUID?, data: ByteArray?, status: Int)

    /**
     * BLE 连接参数更新回调（连接间隔、延迟、超时）
     *
     * @param device 目标设备
     * @param interval 连接间隔 (Connection Interval)
     * @param latency 从机延迟 (Slave Latency)
     * @param timeout 监督超时 (Supervision Timeout)
     * @param status 更新操作状态码
     */
    fun onConnectionUpdated(device: BluetoothDevice?, interval: Int, latency: Int, timeout: Int, status: Int)

    /**
     * 切换当前通信活动的 BLE 目标设备回调
     *
     * @param device 当前被激活使用的目标设备
     */
    fun onSwitchBleDevice(device: BluetoothDevice?)
}
