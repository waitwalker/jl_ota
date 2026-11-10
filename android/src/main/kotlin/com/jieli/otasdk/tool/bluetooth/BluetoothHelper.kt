package com.jieli.otasdk.tool.bluetooth

import android.bluetooth.BluetoothDevice
import android.bluetooth.BluetoothGatt
import android.bluetooth.BluetoothProfile
import com.jieli.jl_bt_ota.constant.BluetoothConstant
import com.jieli.jl_bt_ota.util.BluetoothUtil
import com.jieli.jl_bt_ota.util.CHexConver
import com.jieli.jl_bt_ota.util.JL_Log
import com.jieli.otasdk.tool.config.ConfigHelper
import com.jieli.otasdk.tool.ota.ble.BleManager
import com.jieli.otasdk.tool.ota.ble.interfaces.BleEventCallback
import com.jieli.otasdk.tool.ota.ble.model.BleScanInfo
import com.jieli.otasdk.tool.ota.spp.SppManager
import com.jieli.otasdk.tool.ota.spp.interfaces.SppEventCallback
import com.jieli.otasdk.util.AppUtil
import com.jieli.otasdk.data.constant.OtaConstant
import com.jieli.otasdk.tool.ota.ble.model.BleConnectParam
import java.util.*

/**
 * 蓝牙底层统一操作门面辅助类
 *
 * 聚合并抽象了 BLE ([BleManager]) 与 SPP ([SppManager]) 的核心操作，
 * 根据用户配置的协议类型自动路由设备扫描、建立连接、断开连接、数据收发与状态监听。
 */
class BluetoothHelper {

    /** 全局配置助手单例引用 */
    private val configHelper = ConfigHelper.getInstance()

    /** BLE 底层连接管理器单例 */
    private val bleManager = BleManager.getInstance()!!

    /** SPP 经典蓝牙串口管理器单例 */
    private val sppManager = SppManager.getInstance()!!

    /** 统一蓝牙事件分发助手 */
    private val btEventCbHelper = BTEventCbHelper()

    companion object {
        /** 日志标识 TAG */
        const val TAG: String = "BluetoothHelper"

        /** 单例引用 */
        @Volatile
        private var instance: BluetoothHelper? = null

        /**
         * 获取 [BluetoothHelper] 线程安全单例
         *
         * @return [BluetoothHelper] 实例
         */
        fun getInstance(): BluetoothHelper = instance ?: synchronized(this) {
            instance ?: BluetoothHelper().also { instance = it }
        }
    }

    /**
     * BLE 事件监听回调内部实现，负责将 BLE 底层事件适配并转发至统一分发助手
     */
    private val bleEventCallback = object : BleEventCallback() {

        override fun onAdapterChange(bEnabled: Boolean) {
            btEventCbHelper.onAdapterChange(bEnabled)
        }

        override fun onDiscoveryBleChange(bStart: Boolean) {
            btEventCbHelper.onDiscoveryChange(bStart, OtaConstant.PROTOCOL_BLE)
        }

        override fun onDiscoveryBle(device: BluetoothDevice?, bleScanMessage: BleScanInfo?) {
            btEventCbHelper.onDiscovery(device, bleScanMessage)
        }

        override fun onBleConnection(device: BluetoothDevice?, status: Int) {
            btEventCbHelper.onDeviceConnection(device, OtaConstant.PROTOCOL_BLE, status)
        }

        override fun onBleDataNotification(
            device: BluetoothDevice?,
            serviceUuid: UUID?,
            characteristicsUuid: UUID?,
            data: ByteArray?
        ) {
            btEventCbHelper.onReceiveData(
                device,
                OtaConstant.PROTOCOL_BLE,
                characteristicsUuid,
                data
            )
        }

        override fun onBleDataBlockChanged(device: BluetoothDevice?, block: Int, status: Int) {
            btEventCbHelper.onBleMtuChange(device, block, status)
        }
    }

    /**
     * SPP 事件监听回调内部实现，负责将 SPP 底层事件适配并转发至统一分发助手
     */
    private val sppEventCallback = object : SppEventCallback() {

        override fun onAdapterChange(bEnabled: Boolean) {
            btEventCbHelper.onAdapterChange(bEnabled)
        }

        override fun onDiscoveryDeviceChange(bStart: Boolean) {
            btEventCbHelper.onDiscoveryChange(bStart, OtaConstant.PROTOCOL_SPP)
        }

        override fun onDiscoveryDevice(device: BluetoothDevice?, rssi: Int) {
            btEventCbHelper.onDiscovery(device, BleScanInfo().setRssi(rssi))
        }

        override fun onSppConnection(device: BluetoothDevice?, uuid: UUID?, status: Int) {
            if (status == BluetoothProfile.STATE_CONNECTED && configHelper.isUseMultiSppChannel()
                && UUID.fromString(configHelper.getCustomSppChannel()) != uuid
            ) {
                JL_Log.i(TAG, "onSppConnection", "skip custom uuid = $uuid")
                return
            }
            JL_Log.d(
                TAG, "onSppConnection",
                "device : ${printDeviceInfo(device)}, uuid = $uuid, status = $status"
            )
            btEventCbHelper.onDeviceConnection(device, OtaConstant.PROTOCOL_SPP, status)
        }

        override fun onReceiveSppData(device: BluetoothDevice?, uuid: UUID?, data: ByteArray?) {
            btEventCbHelper.onReceiveData(device, OtaConstant.PROTOCOL_SPP, uuid, data)
        }
    }

    init {
        bleManager.registerBleEventCallback(bleEventCallback)
        sppManager.registerSppEventCallback(sppEventCallback)
    }

    /**
     * 释放与清理所有持有的资源
     *
     * 注销底层 BLE 与 SPP 的回调，释放底层管理器，并重置单例。
     */
    fun destroy() {
        bleManager.unregisterBleEventCallback(bleEventCallback)
        bleManager.destroy()
        sppManager.unregisterSppEventCallback(sppEventCallback)
        sppManager.release()
        btEventCbHelper.release()
        instance = null
    }

    /**
     * 注册蓝牙事件统一监听回调
     *
     * @param callback 实现了 [OnBTEventCallback] 的观察者
     */
    fun registerCallback(callback: OnBTEventCallback) {
        btEventCbHelper.registerCallback(callback)
    }

    /**
     * 注销已注册的蓝牙事件监听回调
     *
     * @param callback 待注销的观察者
     */
    fun unregisterCallback(callback: OnBTEventCallback) {
        btEventCbHelper.unregisterCallback(callback)
    }

    /**
     * 查询当前是否有蓝牙设备处于已连接状态
     *
     * @return true 表示已有连接设备
     */
    fun isConnected(): Boolean {
        return getConnectedDevice() != null
    }

    /**
     * 判断指定的蓝牙物理设备是否处于连接状态
     *
     * @param device 待检测的目标蓝牙设备
     * @return true 表示指定设备已连接
     */
    fun isDeviceConnected(device: BluetoothDevice?): Boolean {
        return BluetoothUtil.deviceEquals(getConnectedDevice(), device)
    }

    /**
     * 查询底层当前是否正在执行蓝牙扫描
     *
     * @return true 表示正在扫描
     */
    fun isScanning(): Boolean = if (configHelper.isBleWay()) {
        bleManager.isBleScanning
    } else {
        sppManager.isScanning
    }

    /**
     * 查询底层当前是否处于正在连接设备的过程中
     *
     * @return true 表示正在连接
     */
    fun isConnecting(): Boolean = if (configHelper.isSppWay()) {
        sppManager.isSppConnecting
    } else {
        bleManager.isBleScanning
    }

    /**
     * 获取当前处于已连接状态的蓝牙物理设备
     *
     * @return 已连接的 [BluetoothDevice]；若未连接则返回 null
     */
    fun getConnectedDevice(): BluetoothDevice? {
        return if (configHelper.isSppWay()) {
            sppManager.connectedSppDevice
        } else {
            bleManager.connectedBtDevice
        }
    }

    /**
     * 获取当前正在尝试连接的蓝牙物理设备
     *
     * @return 正在连接的 [BluetoothDevice]；若无则返回 null
     */
    fun getConnectingDevice(): BluetoothDevice? {
        return if (configHelper.isSppWay()) {
            sppManager.connectingSppDevice
        } else {
            bleManager.connectingDevice
        }
    }

    /**
     * 获取指定设备已建立的 BluetoothGatt 句柄（仅限 BLE 方式）
     *
     * @param device 目标设备，默认为当前连接设备
     * @return [BluetoothGatt] 句柄；若为 SPP 协议或未连接则返回 null
     */
    fun getConnectedGatt(device: BluetoothDevice? = getConnectedDevice()): BluetoothGatt? {
        return if (configHelper.isSppWay()) {
            null
        } else {
            bleManager.getConnectedBtGatt(device)
        }
    }

    /**
     * 获取 BLE 连接当前的协商 MTU 大小
     *
     * @param device 目标设备，默认为当前连接设备
     * @return 协商后的有效 MTU 大小（字节）
     */
    fun getBleMtu(device: BluetoothDevice? = getConnectedDevice()): Int {
        return if (configHelper.isSppWay()) {
            BluetoothConstant.BLE_MTU_MAX
        } else {
            bleManager.getBleMtu(device)
        }
    }

    /**
     * 启动蓝牙设备扫描
     *
     * 根据配置的协议类型选择启动 BLE 扫描或经典蓝牙扫描
     *
     * @param timeout 扫描超时时间（毫秒）
     * @return true 表示扫描成功启动
     */
    fun startScan(timeout: Long): Boolean {
        return if (configHelper.isBleWay()) {
            bleManager.startLeScan(timeout)
        } else {
            sppManager.startDeviceScan(timeout)
        }
    }

    /**
     * 停止正在进行的蓝牙设备扫描
     */
    fun stopScan() {
        if (configHelper.isBleWay()) {
            bleManager.stopLeScan()
        } else {
            sppManager.stopDeviceScan()
        }
    }

    /**
     * 发起连接指定的蓝牙设备
     *
     * 依据全局配置的连接方式选择 SPP 连接、GATT over BR/EDR 连接或标准 BLE 连接
     *
     * @param device 目标蓝牙物理设备
     * @return true 表示成功提交连接请求
     */
    fun connectDevice(device: BluetoothDevice?): Boolean {
        if (device == null) return false

        val connectWay = configHelper.getConnectWay()

        when (connectWay) {
            BluetoothConstant.PROTOCOL_TYPE_SPP -> {
                return sppManager.connectSpp(device)
            }
            BluetoothConstant.PROTOCOL_TYPE_GATT_OVER_BR_EDR -> {
                return bleManager.connectBleDevice(
                    device,
                    BleConnectParam()
                        .setRequestMtu(BluetoothConstant.BLE_MTU_MAX)
                        .setTransport(BleConnectParam.TRANSPORT_BREDR)
                )
            }
            else -> {
                return bleManager.connectBleDevice(device)
            }
        }
    }

    /**
     * 断开指定的蓝牙设备连接
     *
     * @param device 目标蓝牙设备
     */
    fun disconnectDevice(device: BluetoothDevice?) {
        if (configHelper.isSppWay()) {
            sppManager.disconnectSpp(device, null)
        } else {
            bleManager.disconnectBleDevice(device)
        }
    }

    /**
     * 直接通过 BLE 协议连接指定设备
     *
     * @param device 目标蓝牙设备
     * @return true 表示成功发起连接
     */
    fun connectBleDevice(device: BluetoothDevice?): Boolean =
        bleManager.connectBleDevice(device)

    /**
     * 执行设备重新连接操作
     *
     * @param address 目标蓝牙 MAC 地址
     * @param isUseNewAdv 是否采用新版广播过滤策略进行回连
     */
    fun reconnectDevice(address: String?, isUseNewAdv: Boolean) {
        if (configHelper.isSppWay()) {
            // TODO: 需要增加 SPP 自定义回连方式
        } else {
            bleManager.reconnectDevice(address, isUseNewAdv)
        }
    }

    /**
     * 向蓝牙设备异步写入数据
     *
     * 内部自动判断当前连接的底层通道（BLE 或 SPP），并将数据发送给目标设备
     *
     * @param bluetoothDevice 目标蓝牙设备
     * @param byteArray 待发送的原始字节数组
     * @return true 表示成功加入发送队列
     */
    fun writeDataToDevice(bluetoothDevice: BluetoothDevice?, byteArray: ByteArray?): Boolean {
        if (null == bluetoothDevice || null == byteArray || byteArray.isEmpty()) return false
        if (bleManager.isConnectedDevice(bluetoothDevice)) { // 目前连接的设备是 BLE
            bleManager.writeDataByBleAsync(
                bluetoothDevice,
                BleManager.BLE_UUID_SERVICE,
                BleManager.BLE_UUID_WRITE,
                byteArray
            ) { device, _, _, result, data ->
                JL_Log.d(
                    TAG, "writeDataByBleAsync",
                    "device : ${printDeviceInfo(device)}, result : $result,\n" +
                            "data : [${CHexConver.byte2HexStr(data)}]"
                )
            }
            return true
        }
        if (sppManager.isSppConnected(bluetoothDevice)) { // 目前连接的设备是 SPP
            sppManager.writeDataToSppAsync(
                bluetoothDevice,
                SppManager.UUID_SPP,
                byteArray
            ) { device, sppUUID, result, data ->
                JL_Log.d(
                    TAG,
                    "writeDataToSppAsync",
                    "device : ${printDeviceInfo(device)}, uuid : $sppUUID, result : $result," +
                            "\ndata : ${CHexConver.byte2HexStr(data)}"
                )
            }
            return true
        }
        return false
    }

    /**
     * 格式化打印设备调试信息
     *
     * @param device 目标蓝牙物理设备
     * @return 设备名称与 MAC 地址格式化描述
     */
    private fun printDeviceInfo(device: BluetoothDevice?): String? {
        return AppUtil.printBtDeviceInfo(device)
    }
}
