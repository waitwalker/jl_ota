package com.jieli.otasdk.tool.bluetooth

import android.bluetooth.BluetoothDevice
import com.jieli.otasdk.tool.ota.ble.model.BleScanInfo
import java.util.*

/**
 * 蓝牙事件基础监听回调抽象类
 *
 * 定义底层蓝牙状态变化、设备扫描、连接状态、数据收发及 MTU 协商等核心事件的回调方法，
 * 子类可按需选择性覆盖重写。
 */
open class OnBTEventCallback {

    /**
     * 蓝牙适配器开关状态变更回调
     *
     * @param bEnabled true 表示系统蓝牙已打开，false 表示已关闭
     */
    open fun onAdapterChange(bEnabled: Boolean) {

    }

    /**
     * 蓝牙设备扫描启停状态变更回调
     *
     * @param bStart true 表示扫描已启动，false 表示扫描已停止
     * @param scanType 扫描协议类型（如 [com.jieli.otasdk.data.constant.OtaConstant.PROTOCOL_BLE] 或 [com.jieli.otasdk.data.constant.OtaConstant.PROTOCOL_SPP]）
     */
    open fun onDiscoveryChange(bStart: Boolean, scanType: Int) {

    }

    /**
     * 扫描发现新蓝牙设备回调
     *
     * @param device 扫描到的蓝牙设备对象 [BluetoothDevice]
     * @param bleScanMessage 包含设备广播包原始数据及信号强度 RSSI 的包装对象 [BleScanInfo]
     */
    open fun onDiscovery(device: BluetoothDevice?, bleScanMessage: BleScanInfo?) {

    }

    /**
     * 蓝牙设备连接状态变更回调
     *
     * @param device 连接发生变更的蓝牙设备 [BluetoothDevice]
     * @param way 连接方式协议（如 BLE 方式或 SPP 方式）
     * @param status 连接状态码（参考系统连接状态或 SDK 状态常量）
     */
    open fun onDeviceConnection(device: BluetoothDevice?, way: Int, status: Int) {

    }

    /**
     * 接收到设备端发来的数据回调
     *
     * @param device 发送数据的蓝牙设备 [BluetoothDevice]
     * @param way 通信协议方式（BLE 或 SPP）
     * @param uuid 数据对应的特征值 UUID 或 SPP 服务 UUID
     * @param data 接收到的原始字节数组
     */
    open fun onReceiveData(device: BluetoothDevice?, way: Int, uuid: UUID?, data: ByteArray?) {

    }

    /**
     * BLE 连接数据通信 MTU 大小变更回调
     *
     * @param device 目标蓝牙设备 [BluetoothDevice]
     * @param mtu 协商成功后的最新 MTU 大小（字节）
     * @param status GATT 操作状态码
     */
    open fun onBleMtuChange(device: BluetoothDevice?, mtu: Int, status: Int) {

    }
}
