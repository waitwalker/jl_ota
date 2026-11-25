package com.jieli.otasdk.model.connect.base

import android.bluetooth.BluetoothDevice
import android.content.Context
import androidx.lifecycle.MutableLiveData
import androidx.lifecycle.ViewModel
import com.jieli.jl_bt_ota.constant.StateCode
import com.jieli.jl_bt_ota.util.BluetoothUtil
import com.jieli.jl_bt_ota.util.JL_Log
import com.jieli.otasdk.OtaRuntime
import com.jieli.otasdk.data.model.device.DeviceConnection
import com.jieli.otasdk.tool.bluetooth.BluetoothHelper
import com.jieli.otasdk.tool.bluetooth.OnBTEventCallback
import com.jieli.otasdk.tool.config.ConfigHelper
import com.jieli.otasdk.util.AppUtil

/**
 * 蓝牙基础业务模型基类
 *
 * 封装蓝牙连接通用逻辑与状态维护，提供全局连接状态通知、
 * 当前连接设备获取、设备连接状态转换以及资源释放生命周期管理。
 */
open class BluetoothViewModel : ViewModel() {
    /** 日志标识 TAG（默认为子类类名） */
    protected val tag: String = javaClass.simpleName

    /** 全局配置助手单例引用 */
    protected val configHelper: ConfigHelper by lazy { ConfigHelper.getInstance() }

    /** 蓝牙底层操作助手单例引用 */
    protected val bluetoothHelper: BluetoothHelper by lazy { BluetoothHelper.getInstance() }

    /** 内部持有的设备连接状态数据流 */
    private val _deviceConnectionMLD = MutableLiveData<DeviceConnection>()

    /** 公开暴露的设备连接状态数据流（供外部或 UI 监听） */
    val deviceConnectionMLD: MutableLiveData<DeviceConnection> = _deviceConnectionMLD

    /**
     * 蓝牙底层连接状态事件回调监听器
     */
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
     * 查询当前是否有蓝牙设备处于已连接状态
     *
     * @return true 表示已有连接设备
     */
    fun isConnected(): Boolean = bluetoothHelper.isConnected()

    /**
     * 判断指定的蓝牙设备是否处于已连接状态
     *
     * @param device 待检测的目标蓝牙设备
     * @return true 表示该设备已连接
     */
    open fun isDeviceConnected(device: BluetoothDevice?): Boolean =
        bluetoothHelper.isDeviceConnected(device)

    /**
     * 获取当前处于已连接状态的蓝牙设备
     *
     * @return 已连接的 [BluetoothDevice] 实例；若无连接则返回 null
     */
    fun getConnectedDevice(): BluetoothDevice? = bluetoothHelper.getConnectedDevice()

    /**
     * 获取全局 Application 上下文
     *
     * @return 应用程序上下文 [Context]
     */
    fun getContext(): Context = OtaRuntime.getContext()

    /**
     * 获取指定蓝牙设备的当前连接状态代码
     *
     * @param device 待查询状态的目标蓝牙设备
     * @return 状态码：
     *         [StateCode.CONNECTION_OK] (已连接),
     *         [StateCode.CONNECTION_CONNECTING] (正在连接中),
     *         [StateCode.CONNECTION_DISCONNECT] (未连接或断开)
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
     * ViewModel 销毁回调，自动执行资源清理
     */
    override fun onCleared() {
        super.onCleared()
        destroy()
    }

    /**
     * 销毁 ViewModel 并注销底层蓝牙事件回调
     */
    open fun destroy() {
        bluetoothHelper.unregisterCallback(btEventCallback)
    }
}