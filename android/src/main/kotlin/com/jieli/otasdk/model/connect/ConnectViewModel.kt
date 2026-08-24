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
 * @author zqjasonZhong
 * @since 2022/9/8
 * @email zhongzhuocheng@zh-jieli.com
 * @desc 连接设备逻辑实现
 */
class ConnectViewModel private constructor() : BluetoothViewModel() {

    companion object {
        @Volatile
        private var instance: ConnectViewModel? = null

        fun getInstance(): ConnectViewModel {
            return instance ?: synchronized(this) {
                instance ?: ConnectViewModel().also {
                    instance = it
                }
            }
        }

        /**
         * Destroy the singleton instance and release resources
         */
        fun destroyInstance() {
            instance?.cleanUp()
            instance = null
        }
    }

    /**
     * LiveData for Bluetooth state changes (true = enabled, false = disabled)
     */
    val bluetoothStateMLD = MutableLiveData<Boolean>()

    /**
     * LiveData for scan results
     */
    val scanResultMLD = MutableLiveData<ScanResult>()

    /**
     * Cached list of scanned devices
     */
    var scanDeviceList = mutableListOf<ScanDevice>()
        internal set  // Restrict external modification

    private var isNeedScan = false

    @Volatile
    private var isCleaned = false

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

    override fun onCleared() {
        super.onCleared()
        cleanUp()
    }

    fun isSwitchOtaMode(): Boolean = configHelper.isEnableBroadcastBox()

    fun getScanFilter(): String? = configHelper.getScanFilter()

    fun setScanFilter(filter: String?) {
        configHelper.setScanFilter(filter)
    }

    fun isScanning(): Boolean = bluetoothHelper.isScanning()

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

    fun stopScan() {
        if (isCleaned) return
        bluetoothHelper.stopScan()
    }

    fun connectBtDevice(device: BluetoothDevice?) {
        if (isCleaned || device == null) return
        bluetoothHelper.connectDevice(device)
    }

    fun disconnectBtDevice(device: BluetoothDevice?) {
        if (isCleaned || device == null) return
        bluetoothHelper.disconnectDevice(device)
    }

    fun clearScanDeviceList() {
        if (isCleaned) return
        scanDeviceList = mutableListOf()
    }

    fun cleanUp() {
        if (isCleaned) return

        isCleaned = true

        // Stop scanning
        stopScan()

        // Unregister callback
        bluetoothHelper.unregisterCallback(btEventCallback)

        // Clear LiveData
        clearLiveData()

        // Reset properties
        scanDeviceList = mutableListOf()
        isNeedScan = false
    }

    private fun updateScanStatus(isScanning: Boolean) {
        val status = if (isScanning) {
            ScanResult.SCAN_STATUS_SCANNING
        } else {
            ScanResult.SCAN_STATUS_IDLE
        }
        scanResultMLD.value = ScanResult(status)
    }

    private fun postConnectedDeviceIfExists() {
        getConnectedDevice()?.let { device ->
            // Small delay to ensure scan is properly initialized
            SystemClock.sleep(50)

            if (!isCleaned) {
                val scanDevice = ScanDevice(device, 0, ByteArray(0)).apply {
                    state = StateCode.CONNECTION_OK
                }
                scanResultMLD.value = ScanResult(ScanResult.SCAN_STATUS_FOUND_DEV, scanDevice)
            }
        }
    }

    private fun handleRestartScan() {
        isNeedScan = false
        startScan()
    }

    private fun scheduleRestartScan() {
        isNeedScan = true
    }

    private fun createScanResult(device: BluetoothDevice, bleScanMessage: BleScanInfo?): ScanResult {
        val rssi = bleScanMessage?.rssi ?: 0
        val rawData = bleScanMessage?.rawData ?: ByteArray(0)

        val scanDevice = ScanDevice(device, rssi, rawData).apply {
            state = getDeviceConnection(device)
        }

        return ScanResult(ScanResult.SCAN_STATUS_FOUND_DEV, scanDevice)
    }

    private fun clearLiveData() {
        bluetoothStateMLD.value = null
        scanResultMLD.value = null
    }
}