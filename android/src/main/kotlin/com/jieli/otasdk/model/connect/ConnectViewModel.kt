package com.jieli.otasdk.model.connect

import android.bluetooth.BluetoothDevice
import android.os.SystemClock
import androidx.lifecycle.MutableLiveData
import com.jieli.jl_bt_ota.constant.StateCode
import com.jieli.jl_bt_ota.util.BluetoothUtil
import com.jieli.otasdk.data.constant.OtaConstant
import com.jieli.otasdk.data.model.ScanResult
import com.jieli.otasdk.data.model.device.ScanDevice
import com.jieli.otasdk.model.connect.base.BluetoothViewModel
import com.jieli.otasdk.tool.bluetooth.OnBTEventCallback
import com.jieli.otasdk.tool.ota.ble.model.BleScanInfo
import com.jieli.otasdk.util.AppUtil
import kotlinx.coroutines.*

/**
 * 蓝牙设备连接与扫描业务模型类
 *
 * 继承自 [BluetoothViewModel]，负责管理蓝牙适配器开关监听、设备扫描生命周期、
 * 扫描结果列表维护以及设备的连接与断开逻辑。
 */
class ConnectViewModel private constructor() : BluetoothViewModel() {

    companion object {
        @Volatile
        private var instance: ConnectViewModel? = null

        /**
         * 获取 [ConnectViewModel] 线程安全单例
         *
         * @return [ConnectViewModel] 实例
         */
        fun getInstance(): ConnectViewModel {
            return instance ?: synchronized(this) {
                instance ?: ConnectViewModel().also {
                    instance = it
                }
            }
        }

        /**
         * 销毁单例并释放相关资源
         */
        fun destroyInstance() {
            instance?.cleanUp()
            instance = null
        }
    }

    /** 蓝牙适配器开关状态数据流（true 表示开启，false 表示已关闭） */
    val bluetoothStateMLD = MutableLiveData<Boolean>()

    /** 蓝牙扫描状态与发现设备数据流 */
    val scanResultMLD = MutableLiveData<ScanResult>()

    /** 当前已扫描发现的设备缓存列表（限制外部直接修改） */
    var scanDeviceList = mutableListOf<ScanDevice>()
        internal set

    /** 标志位：当前扫描停止后是否需要立即重启扫描 */
    private var isNeedScan = false

    /** 标志位：指示当前 ViewModel 是否已执行清理释放操作 */
    @Volatile
    private var isCleaned = false

    /**
     * 底层蓝牙事件监听回调实现
     *
     * 监控蓝牙适配器状态变化、扫描启停状态变化以及新设备发现事件
     */
    private val btEventCallback = object : OnBTEventCallback() {

        override fun onAdapterChange(bEnabled: Boolean) {
            if (isCleaned) return
            bluetoothStateMLD.postValue(bEnabled)
        }

        override fun onDiscoveryChange(bStart: Boolean, scanType: Int) {
            if (isCleaned) return

            updateScanStatus(bStart)

            if (bStart) {
                postConnectedDeviceIfExists()
            } else if (isNeedScan) {
                handleRestartScan()
            }
        }

        override fun onDiscovery(device: BluetoothDevice?, bleScanMessage: BleScanInfo?) {
            if (isCleaned) return
            val bluetoothDevice = device ?: return

            val scanResult = createScanResult(bluetoothDevice, bleScanMessage)
            scanResultMLD.value = scanResult
        }
    }

    init {
        bluetoothHelper.registerCallback(btEventCallback)
    }

    /**
     * ViewModel 销毁回调，自动执行资源清理
     */
    override fun onCleared() {
        super.onCleared()
        cleanUp()
    }

    /**
     * 查询是否开启广播音箱功能模式
     *
     * @return true 表示启用
     */
    fun isSwitchOtaMode(): Boolean = configHelper.isEnableBroadcastBox()

    /**
     * 获取当前配置的蓝牙扫描过滤字符串
     *
     * @return 过滤关键字
     */
    fun getScanFilter(): String? = configHelper.getScanFilter()

    /**
     * 设置蓝牙扫描过滤关键字
     *
     * @param filter 过滤关键字
     */
    fun setScanFilter(filter: String?) {
        configHelper.setScanFilter(filter)
    }

    /**
     * 查询底层当前是否正在执行蓝牙扫描
     *
     * @return true 表示正在扫描
     */
    fun isScanning(): Boolean = bluetoothHelper.isScanning()

    /**
     * 启动蓝牙设备扫描
     *
     * 1. 若蓝牙未开启，则调用工具类引导开启蓝牙；
     * 2. 若当前已在扫描中，则标记需要重启并先停止当前扫描；
     * 3. 正常情况下启动指定超时时间的扫描流程。
     */
    fun startScan() {
        if (isCleaned) return

        if (!BluetoothUtil.isBluetoothEnable()) {
            AppUtil.enableBluetooth(getContext())
            return
        }

        if (isScanning()) {
            scheduleRestartScan()
            bluetoothHelper.stopScan()
            return
        }

        bluetoothHelper.startScan(OtaConstant.SCAN_TIMEOUT)
    }

    /**
     * 停止当前的蓝牙设备扫描
     */
    fun stopScan() {
        if (isCleaned) return
        bluetoothHelper.stopScan()
    }

    /**
     * 连接指定的蓝牙设备
     *
     * @param device 待连接的目标蓝牙设备
     */
    fun connectBtDevice(device: BluetoothDevice?) {
        if (isCleaned || device == null) return
        bluetoothHelper.connectDevice(device)
    }

    /**
     * 断开指定的蓝牙设备连接
     *
     * @param device 待断开的目标蓝牙设备
     */
    fun disconnectBtDevice(device: BluetoothDevice?) {
        if (isCleaned || device == null) return
        bluetoothHelper.disconnectDevice(device)
    }

    /**
     * 清空已扫描到的设备列表缓存
     */
    fun clearScanDeviceList() {
        if (isCleaned) return
        scanDeviceList = mutableListOf()
    }

    /**
     * 释放与清理所有持有的资源
     *
     * 停止扫描、注销蓝牙回调、重置所有 LiveData 数据并清空设备列表
     */
    fun cleanUp() {
        if (isCleaned) return

        isCleaned = true

        // 停止扫描
        stopScan()

        // 注销本类与基类的蓝牙回调
        bluetoothHelper.unregisterCallback(btEventCallback)
        super.destroy()

        // 清空 LiveData
        clearLiveData()

        // 重置内部状态与单例引用，避免重绑后拿到已失效实例
        scanDeviceList = mutableListOf()
        isNeedScan = false
        if (instance === this) {
            instance = null
        }
    }

    /**
     * 更新并通知当前扫描状态
     *
     * @param isScanning true 为扫描中，false 为空闲
     */
    private fun updateScanStatus(isScanning: Boolean) {
        val status = if (isScanning) {
            ScanResult.SCAN_STATUS_SCANNING
        } else {
            ScanResult.SCAN_STATUS_IDLE
        }
        scanResultMLD.value = ScanResult(status)
    }

    /**
     * 扫描开启时，如果当前已有已连接的设备，将其以已连接状态分发至扫描结果流中
     */
    private fun postConnectedDeviceIfExists() {
        getConnectedDevice()?.let { device ->
            // 短暂延时确保扫描状态初始化就绪
            SystemClock.sleep(50)

            if (!isCleaned) {
                val scanDevice = ScanDevice(device, 0, ByteArray(0)).apply {
                    state = StateCode.CONNECTION_OK
                }
                scanResultMLD.value = ScanResult(ScanResult.SCAN_STATUS_FOUND_DEV, scanDevice)
            }
        }
    }

    /**
     * 内部处理重启扫描操作
     */
    private fun handleRestartScan() {
        isNeedScan = false
        startScan()
    }

    /**
     * 标记后续需要触发重启扫描
     */
    private fun scheduleRestartScan() {
        isNeedScan = true
    }

    /**
     * 构造并封装扫描到的设备数据模型
     *
     * @param device 发现的蓝牙设备
     * @param bleScanMessage 设备的广播包与信号强度信息
     * @return 封装后的 [ScanResult]
     */
    private fun createScanResult(device: BluetoothDevice, bleScanMessage: BleScanInfo?): ScanResult {
        val rssi = bleScanMessage?.rssi ?: 0
        val rawData = bleScanMessage?.rawData ?: ByteArray(0)

        val scanDevice = ScanDevice(device, rssi, rawData).apply {
            state = getDeviceConnection(device)
        }

        return ScanResult(ScanResult.SCAN_STATUS_FOUND_DEV, scanDevice)
    }

    /**
     * 清空所有 LiveData 的缓存值
     */
    private fun clearLiveData() {
        bluetoothStateMLD.value = null
        scanResultMLD.value = null
    }
}