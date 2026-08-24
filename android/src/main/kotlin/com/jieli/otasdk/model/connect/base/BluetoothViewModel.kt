package com.jieli.otasdk.model.connect.base

import android.bluetooth.BluetoothDevice
import android.content.Context
import androidx.lifecycle.MutableLiveData
import androidx.lifecycle.ViewModel
import com.jieli.jl_bt_ota.constant.StateCode
import com.jieli.jl_bt_ota.util.BluetoothUtil
import com.jieli.jl_bt_ota.util.JL_Log
import com.jieli.otasdk.MyApplication
import com.jieli.otasdk.data.model.device.DeviceConnection
import com.jieli.otasdk.tool.bluetooth.BluetoothHelper
import com.jieli.otasdk.tool.bluetooth.OnBTEventCallback
import com.jieli.otasdk.tool.config.ConfigHelper
import com.jieli.otasdk.util.AppUtil

/**
 * @author zqjasonZhong
 * @since 2022/9/8
 * @email zhongzhuocheng@zh-jieli.com
 * @desc  蓝牙逻辑处理
 */
open class BluetoothViewModel : ViewModel() {
    protected val tag: String = javaClass.simpleName
    protected val configHelper: ConfigHelper by lazy { ConfigHelper.getInstance() }
    protected val bluetoothHelper: BluetoothHelper by lazy { BluetoothHelper.getInstance() }

    private val _deviceConnectionMLD = MutableLiveData<DeviceConnection>()
    val deviceConnectionMLD: MutableLiveData<DeviceConnection> = _deviceConnectionMLD

    private val btEventCallback = object : OnBTEventCallback() {
        override fun onDeviceConnection(device: BluetoothDevice?, way: Int, status: Int) {
            val connection = DeviceConnection(device, AppUtil.changeConnectStatus(status))
            _deviceConnectionMLD.postValue(connection)
        }
    }

    init {
        bluetoothHelper.registerCallback(btEventCallback)
    }

    /**
     * Check if any device is connected
     */
    fun isConnected(): Boolean = bluetoothHelper.isConnected()

    /**
     * Check if the specified device is connected
     *
     * @param device The Bluetooth device to check
     * @return true if the device is connected, false otherwise
     */
    open fun isDeviceConnected(device: BluetoothDevice?): Boolean =
        bluetoothHelper.isDeviceConnected(device)

    /**
     * Get the currently connected device
     *
     * @return The connected Bluetooth device, or null if no device is connected
     */
    fun getConnectedDevice(): BluetoothDevice? = bluetoothHelper.getConnectedDevice()

    /**
     * Get the application context
     *
     * @return The application context
     */
    fun getContext(): Context = MyApplication.getInstance()

    /**
     * Get the device connection state
     *
     * @param device The Bluetooth device to check
     * @return StateCode.CONNECTION_OK if connected,
     *         StateCode.CONNECTION_CONNECTING if connecting,
     *         StateCode.CONNECTION_DISCONNECT if disconnected
     */
    fun getDeviceConnection(device: BluetoothDevice?): Int {
        return when {
            device == null -> StateCode.CONNECTION_DISCONNECT
            isDeviceConnected(device) -> StateCode.CONNECTION_OK
            BluetoothUtil.deviceEquals(device, bluetoothHelper.getConnectingDevice()) ->
                StateCode.CONNECTION_CONNECTING
            else -> StateCode.CONNECTION_DISCONNECT
        }
    }

    /**
     * Clean up resources
     */
    override fun onCleared() {
        super.onCleared()
        destroy()
    }

    /**
     * Destroy the ViewModel and unregister callbacks
     */
    open fun destroy() {
        bluetoothHelper.unregisterCallback(btEventCallback)
    }
}