package com.jieli.otasdk.tool.ota.ble

import android.bluetooth.BluetoothDevice
import android.bluetooth.BluetoothGattService
import com.jieli.jl_bt_ota.tool.callback.BaseCallbackHelper
import com.jieli.otasdk.tool.ota.ble.interfaces.BleEventCallback
import com.jieli.otasdk.tool.ota.ble.model.BleScanInfo
import java.util.UUID

/**
 * BLE 事件回调管理与广播分发器
 *
 * 继承自杰理基础回调辅助类 [BaseCallbackHelper]，负责将底层捕获的 BLE 事件统一分发给所有已注册的 [BleEventCallback] 监听器。
 */
class BleEventCallbackManager : BaseCallbackHelper<BleEventCallback>() {

    /**
     * 分发系统蓝牙适配器开关状态变更事件
     *
     * @param bEnabled true 表示蓝牙已开启
     */
    fun onAdapterChange(bEnabled: Boolean) {
        callbackEvent { callback -> callback.onAdapterChange(bEnabled) }
    }

    /**
     * 分发 BLE 设备扫描启停状态事件
     *
     * @param bStart true 表示扫描已启动
     */
    fun onDiscoveryBleChange(bStart: Boolean) {
        callbackEvent { callback -> callback.onDiscoveryBleChange(bStart) }
    }

    /**
     * 分发扫描发现新 BLE 设备事件
     *
     * @param device 扫描到的蓝牙设备
     * @param bleScanMessage 广播元数据包装模型
     */
    fun onDiscoveryBle(device: BluetoothDevice?, bleScanMessage: BleScanInfo?) {
        callbackEvent { callback -> callback.onDiscoveryBle(device, bleScanMessage) }
    }

    /**
     * 分发 BLE 设备物理连接状态变更事件
     *
     * @param device 目标设备
     * @param status 连接状态码
     */
    fun onBleConnection(device: BluetoothDevice?, status: Int) {
        callbackEvent { callback -> callback.onBleConnection(device, status) }
    }

    /**
     * 分发 GATT 服务发现完成事件
     *
     * @param device 目标设备
     * @param status 操作状态码
     * @param services 发现的服务列表集合
     */
    fun onBleServiceDiscovery(device: BluetoothDevice?, status: Int, services: List<BluetoothGattService>?) {
        callbackEvent { callback -> callback.onBleServiceDiscovery(device, status, services) }
    }

    /**
     * 分发特征值通知开启/关闭状态结果事件
     *
     * @param device 目标设备
     * @param serviceUuid 服务 UUID
     * @param characteristicUuid 特征值 UUID
     * @param status 操作状态码
     */
    fun onBleNotificationStatus(device: BluetoothDevice?, serviceUuid: UUID?, characteristicUuid: UUID?, status: Int) {
        callbackEvent { callback -> callback.onBleNotificationStatus(device, serviceUuid, characteristicUuid, status) }
    }

    /**
     * 分发 BLE 协商 MTU 大小变更生效事件
     *
     * @param device 目标设备
     * @param block 协商生效的 MTU 大小
     * @param status 操作状态码
     */
    fun onBleDataBlockChanged(device: BluetoothDevice?, block: Int, status: Int) {
        callbackEvent { callback -> callback.onBleDataBlockChanged(device, block, status) }
    }

    /**
     * 分发收到 BLE 设备特征值主动上报的数据事件
     *
     * @param device 来源设备
     * @param serviceUuid 对应的服务 UUID
     * @param characteristicsUuid 对应的特征值 UUID
     * @param data 接收到的原始字节数组
     */
    fun onBleDataNotification(device: BluetoothDevice?, serviceUuid: UUID?, characteristicsUuid: UUID?, data: ByteArray?) {
        callbackEvent { callback -> callback.onBleDataNotification(device, serviceUuid, characteristicsUuid, data) }
    }

    /**
     * 分发 BLE 特征值写入状态结果事件
     *
     * @param device 目标设备
     * @param serviceUuid 对应的服务 UUID
     * @param characteristicsUuid 对应的特征值 UUID
     * @param data 写入的原始字节数据
     * @param status 写入状态结果码
     */
    fun onBleWriteStatus(device: BluetoothDevice?, serviceUuid: UUID?, characteristicsUuid: UUID?, data: ByteArray?, status: Int) {
        callbackEvent { callback -> callback.onBleWriteStatus(device, serviceUuid, characteristicsUuid, data, status) }
    }

    /**
     * 分发 BLE 链路连接参数更新事件
     *
     * @param device 目标设备
     * @param interval 连接间隔
     * @param latency 从机延迟
     * @param timeout 监督超时
     * @param status 操作状态码
     */
    fun onConnectionUpdated(device: BluetoothDevice?, interval: Int, latency: Int, timeout: Int, status: Int) {
        callbackEvent { callback -> callback.onConnectionUpdated(device, interval, latency, timeout, status) }
    }

    /**
     * 分发切换当前活动 BLE 目标设备事件
     *
     * @param device 当前被激活使用的目标设备
     */
    fun onSwitchBleDevice(device: BluetoothDevice?) {
        callbackEvent { callback -> callback.onSwitchBleDevice(device) }
    }
}
