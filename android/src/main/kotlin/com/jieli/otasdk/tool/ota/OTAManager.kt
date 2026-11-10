package com.jieli.otasdk.tool.ota

import android.bluetooth.BluetoothDevice
import android.bluetooth.BluetoothGatt
import android.bluetooth.le.ScanSettings
import android.content.Context
import com.jieli.jl_bt_ota.constant.BluetoothConstant
import com.jieli.jl_bt_ota.constant.StateCode
import com.jieli.jl_bt_ota.impl.BluetoothOTAManager
import com.jieli.jl_bt_ota.model.BluetoothOTAConfigure
import com.jieli.jl_bt_ota.model.ble.BleConnectParam
import com.jieli.jl_bt_ota.util.BluetoothUtil
import com.jieli.jl_bt_ota.util.CHexConver
import com.jieli.jl_bt_ota.util.JL_Log
import com.jieli.otasdk.data.constant.OtaConstant
import com.jieli.otasdk.tool.bluetooth.BluetoothHelper
import com.jieli.otasdk.tool.bluetooth.OnBTEventCallback
import com.jieli.otasdk.tool.config.ConfigHelper
import com.jieli.otasdk.tool.ota.spp.SppManager
import com.jieli.otasdk.util.AppUtil
import java.util.UUID

/**
 * 杰理 OTA 核心升级实现类
 *
 * 继承自杰理官方 SDK 抽象类 [BluetoothOTAManager]，作为第三方或 Flutter 插件接入杰理 OTA 流程的实现纽带。
 * 负责桥接 SDK 的数据收发、连接事件分发与底层蓝牙物理操作。
 *
 * @param context 上下文对象
 */
class OTAManager(context: Context) : BluetoothOTAManager(context) {

    /** 全局配置助手单例引用 */
    private val configHelper = ConfigHelper.getInstance()

    /** 统一蓝牙操作门面辅助类单例 */
    private val bluetoothHelper = BluetoothHelper.getInstance()

    /**
     * 蓝牙底层事件监听回调，负责将底层连接状态、收到的设备数据及 MTU 变化上报给 [BluetoothOTAManager]
     */
    private val btEventCallback = object : OnBTEventCallback() {

        override fun onDeviceConnection(device: BluetoothDevice?, way: Int, status: Int) {
            super.onDeviceConnection(device, way, status)
            val connectionState = AppUtil.changeConnectStatus(status)
            JL_Log.i(
                TAG, "onDeviceConnection", "device : ${printDeviceInfo(device)}, way = $way, " +
                        "status ：$status, change status : $connectionState"
            )
            onBtDeviceConnection(device, connectionState)
        }

        override fun onReceiveData(
            device: BluetoothDevice?, way: Int, uuid: UUID?, data: ByteArray?
        ) {
            super.onReceiveData(device, way, uuid, data)
            JL_Log.d(
                TAG, "onReceiveData",
                "device : ${printDeviceInfo(device)}, way = $way," +
                        "\nuuid = $uuid, data ：${CHexConver.byte2HexStr(data)}"
            )
            if (way == OtaConstant.PROTOCOL_SPP && SppManager.UUID_SPP != uuid) {
                JL_Log.d(TAG, "onReceiveData", "skip spec")
                return
            }
            onReceiveDeviceData(device, data)
        }

        override fun onBleMtuChange(device: BluetoothDevice?, mtu: Int, status: Int) {
            super.onBleMtuChange(device, mtu, status)
            onMtuChanged(bluetoothHelper.getConnectedGatt(device), mtu, status)
        }
    }

    init {
        val bluetoothOption = BluetoothOTAConfigure()
        // 选择通讯方式（优先 SPP 或 BLE）
        bluetoothOption.priority = if (configHelper.isSppWay()) {
            BluetoothOTAConfigure.PREFER_SPP
        } else {
            BluetoothOTAConfigure.PREFER_BLE
        }
        // 是否需要自定义回连方式 (默认不需要，如需要自定义回连方式，需要客户自行实现)
        bluetoothOption.isUseReconnect =
            (configHelper.isUseCustomReConnectWay() && configHelper.isHidDevice())
        // 是否启用设备认证流程 (与固件工程师确认)
        bluetoothOption.isUseAuthDevice = configHelper.isUseDeviceAuth()
        // 设置 BLE 初始 MTU
        bluetoothOption.mtu = BluetoothConstant.BLE_MTU_MIN
        // 是否需要改变 BLE 的 MTU
        bluetoothOption.isNeedChangeMtu = false
        // 是否启用杰理服务器 (暂时不支持)
        bluetoothOption.isUseJLServer = false
        // 设置回连搜索设备模式 -- 设置为高性能模式，只能在应用前台使用
        bluetoothOption.bleScanMode = ScanSettings.SCAN_MODE_LOW_LATENCY
        // 设置开启库内自动回连设备参数
        bluetoothOption.bleConnectParam = BleConnectParam()

        // 配置 OTA 参数到基类
        configure(bluetoothOption)
        bluetoothHelper.registerCallback(btEventCallback)
        if (bluetoothHelper.isConnected()) {
            bluetoothHelper.getConnectedDevice()?.let { connectedDevice ->
                onBtDeviceConnection(connectedDevice, StateCode.CONNECTION_OK)
                if (configHelper.isBleWay()) {
                    onMtuChanged(
                        bluetoothHelper.getConnectedGatt(connectedDevice),
                        bluetoothHelper.getBleMtu() + 3,
                        BluetoothGatt.GATT_SUCCESS
                    )
                }
            }
        }
    }

    /**
     * 获取当前处于连接状态的目标蓝牙设备
     *
     * @return 已连接的 [BluetoothDevice] 实例
     */
    override fun getConnectedDevice(): BluetoothDevice? = bluetoothHelper.getConnectedDevice()

    /**
     * 获取当前连接设备的 BluetoothGatt 对象（仅 BLE 连接有效）
     *
     * @return [BluetoothGatt] 实例
     */
    override fun getConnectedBluetoothGatt(): BluetoothGatt? = bluetoothHelper.getConnectedGatt(getConnectedDevice())

    /**
     * 连接蓝牙设备接口实现（由外部统一由 BluetoothHelper 处理）
     *
     * @param bluetoothDevice 目标蓝牙设备
     */
    override fun connectBluetoothDevice(bluetoothDevice: BluetoothDevice?) {
    }

    /**
     * 断开指定蓝牙设备的连接
     *
     * @param bluetoothDevice 待断开的蓝牙设备
     */
    override fun disconnectBluetoothDevice(bluetoothDevice: BluetoothDevice?) {
        bluetoothHelper.disconnectDevice(bluetoothDevice)
    }

    /**
     * 向蓝牙设备发送升级数据包
     *
     * @param bluetoothDevice 目标蓝牙设备
     * @param bytes 待发送的固件数据包
     * @return true 表示成功加入发送队列
     */
    override fun sendDataToDevice(bluetoothDevice: BluetoothDevice?, bytes: ByteArray?): Boolean {
        JL_Log.d(
            TAG, "sendDataToDevice", "device : ${printDeviceInfo(bluetoothDevice)}\n"
                    + "data = [${CHexConver.byte2HexStr(bytes)}]"
        )
        return bluetoothHelper.writeDataToDevice(bluetoothDevice, bytes)
    }

    /**
     * 释放与清理 OTA 相关资源并注销蓝牙事件回调
     */
    override fun release() {
        super.release()
        bluetoothHelper.unregisterCallback(btEventCallback)
    }

    /**
     * 设置设备回连目标 MAC 地址
     *
     * @param addr 目标 MAC 地址
     */
    fun setReconnectAddr(addr: String?) {
//        setReconnectAddress(addr)
    }

    /**
     * 格式化打印设备调试信息
     *
     * @param device 目标设备
     * @return 描述字符串
     */
    private fun printDeviceInfo(device: BluetoothDevice?): String? {
        return BluetoothUtil.printBtDeviceInfo(context, device)
    }
}
