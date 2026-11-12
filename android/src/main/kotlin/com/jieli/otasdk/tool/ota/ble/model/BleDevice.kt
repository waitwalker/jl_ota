package com.jieli.otasdk.tool.ota.ble.model

import android.annotation.SuppressLint
import android.bluetooth.BluetoothDevice
import android.bluetooth.BluetoothGatt
import android.bluetooth.BluetoothGattCharacteristic
import android.bluetooth.BluetoothGattService
import android.bluetooth.BluetoothProfile
import android.bluetooth.BluetoothStatusCodes
import android.os.Build
import com.jieli.jl_bt_ota.constant.BluetoothConstant
import com.jieli.jl_bt_ota.util.BluetoothUtil
import com.jieli.jl_bt_ota.util.CHexConver
import com.jieli.jl_bt_ota.util.JL_Log
import com.jieli.otasdk.OtaRuntime
import com.jieli.otasdk.tool.ota.ble.SendBleDataThread
import com.jieli.otasdk.util.AppUtil
import com.jieli.otasdk.tool.ota.ble.interfaces.IBleOp
import com.jieli.otasdk.tool.ota.ble.interfaces.OnThreadStateListener
import com.jieli.otasdk.tool.ota.ble.interfaces.OnWriteDataCallback
import java.util.UUID

/**
 * BLE 已连接设备模型封装类
 *
 * 包装目标蓝牙物理设备 [BluetoothDevice]、连接参数 [BleConnectParam]、底层 [BluetoothGatt] 句柄以及独立的数据发送线程 [SendBleDataThread]。
 * 在连接建立与断开时自动启停数据发送线程，并管理 MTU、重连次数与配对状态。
 *
 * @param device 目标蓝牙物理设备
 * @param param 连接参数配置
 * @param reconnectLimit 允许的最大自动重连重试次数，默认为 [MAX_RETRY_CONNECT_COUNT]
 */
class BleDevice @JvmOverloads constructor(
    private val device: BluetoothDevice,
    private val param: BleConnectParam,
    private val reconnectLimit: Int = MAX_RETRY_CONNECT_COUNT,
) {
    /** 当前物理连接状态，默认为已断开 [BluetoothProfile.STATE_DISCONNECTED] */
    private var connection = BluetoothProfile.STATE_DISCONNECTED

    /** 当前生效的 BLE MTU 大小，默认为 [BluetoothConstant.BLE_MTU_MIN] */
    private var mtu = BluetoothConstant.BLE_MTU_MIN

    /** 最近一次提交给 GATT 的写入数据。API 33 起 characteristic.value 不再回填这次写入的内容。 */
    @Volatile
    private var lastWritePayload: ByteArray? = null

    /** 系统底层已建立的 BluetoothGatt 连接句柄 */
    private var gatt: BluetoothGatt? = null

    /** 专用于向该设备排队发送数据包的工作线程 */
    private var sendDataThread: SendBleDataThread? = null

    /** 记录连接成功的时间戳（毫秒） */
    private var connectedTime: Long = 0

    /** 标志位：是否需要触发自动重连 */
    private var isNeedReconnect = false

    /** 记录已发生的连续重连次数 */
    private var reconnectCount = 0

    /** 标志位：当前设备是否被上层业务选中并处于激活通信状态 */
    private var isUsing = false

    /** 标志位：是否正在等待系统蓝牙配对绑定结果 */
    private var isWaitBoundResult = false

    /**
     * 获取包装的底层物理设备实例
     *
     * @return [BluetoothDevice] 实例
     */
    fun getDevice(): BluetoothDevice = device

    /**
     * 获取当前连接使用的配置参数
     *
     * @return [BleConnectParam] 实例
     */
    fun getParam(): BleConnectParam = param

    /**
     * 获取当前物理连接状态码
     *
     * @return [BluetoothProfile.STATE_CONNECTED] 等状态码
     */
    fun getConnection(): Int = connection

    /**
     * 更新当前设备的连接状态
     *
     * 当状态变更为已连接时自动启动发送线程；当断开时重置状态并停止发送线程。
     *
     * @param connection 最新的连接状态码
     * @return 当前对象实例，支持链式调用
     */
    fun setConnection(connection: Int): BleDevice {
        if (this.connection != connection) {
            this.connection = connection
            if (connection == BluetoothProfile.STATE_CONNECTED) {
                setConnectedTime(System.currentTimeMillis())
                startSendDataThread()
            } else if (connection == BluetoothProfile.STATE_DISCONNECTED) {
                setConnectedTime(0L)
                setUsing(false)
                stopSendDataThread()
            } else if (connection == BluetoothProfile.STATE_CONNECTING) {
                setConnectedTime(System.currentTimeMillis())
                setUsing(false)
            }
        }
        return this
    }

    /**
     * 查询设备当前是否正处于连接中
     *
     * @return true 表示处于正在连接状态
     */
    fun isConnecting(): Boolean = connection == BluetoothProfile.STATE_CONNECTING

    /**
     * 查询设备当前是否已成功建立连接
     *
     * @return true 表示处于已连接状态
     */
    fun isConnected(): Boolean = connection == BluetoothProfile.STATE_CONNECTED

    /**
     * 获取持有的底层 BluetoothGatt 句柄
     *
     * @return [BluetoothGatt] 句柄
     */
    fun getGatt(): BluetoothGatt? = gatt

    /**
     * 设置底层已建立的 BluetoothGatt 句柄
     *
     * @param gatt GATT 句柄
     * @return 当前对象实例，支持链式调用
     */
    fun setGatt(gatt: BluetoothGatt?): BleDevice {
        this.gatt = gatt
        return this
    }

    /**
     * 获取实际可用数据分包的最大 MTU 长度（大包自动减去安全开销）
     *
     * @return 实际可用 MTU 大小（字节）
     */
    fun getMtu(): Int {
        var realMtu = mtu
        if (realMtu > 128) {
            realMtu -= 6
        }
        return realMtu
    }

    /**
     * 设置协商后的 MTU 尺寸
     *
     * @param mtu 协商生效的 MTU 大小
     * @return 当前对象实例，支持链式调用
     */
    fun setMtu(mtu: Int): BleDevice {
        this.mtu = mtu
        return this
    }

    /**
     * 获取连接成功的时间戳
     *
     * @return 连接时间戳（毫秒）
     */
    fun getConnectedTime(): Long = connectedTime

    /**
     * 记录连接成功的时间戳
     *
     * @param connectedTime 毫秒级时间戳
     * @return 当前对象实例，支持链式调用
     */
    fun setConnectedTime(connectedTime: Long): BleDevice {
        this.connectedTime = connectedTime
        return this
    }

    /**
     * 自增重试计数并校验是否超出最大重连上限
     *
     * @return true 表示已超出重连上限次数
     */
    fun isOverReconnectLimit(): Boolean {
        reconnectCount++
        return reconnectCount > reconnectLimit
    }

    /**
     * 查询是否需要重连
     *
     * @return true 表示需要重连
     */
    fun isNeedReconnect(): Boolean = isNeedReconnect

    /**
     * 设置是否需要重连
     *
     * @param needReconnect 是否开启重连
     * @return 当前对象实例，支持链式调用
     */
    fun setNeedReconnect(needReconnect: Boolean): BleDevice {
        isNeedReconnect = needReconnect
        return this
    }

    /**
     * 查询当前设备是否处于激活使用状态
     *
     * @return true 表示处于使用中
     */
    fun isUsing(): Boolean = isUsing

    /**
     * 标记当前设备是否为当前活动设备
     *
     * @param using 是否处于使用状态
     * @return 当前对象实例，支持链式调用
     */
    fun setUsing(using: Boolean): BleDevice {
        isUsing = using
        return this
    }

    /**
     * 查询是否正在等待系统配对绑定结果
     *
     * @return true 表示正在等待配对广播
     */
    fun isWaitBoundResult(): Boolean = isWaitBoundResult

    /**
     * 设置是否处于等待配对绑定结果状态
     *
     * @param waitBoundResult 是否等待配对
     * @return 当前对象实例，支持链式调用
     */
    fun setWaitBoundResult(waitBoundResult: Boolean): BleDevice {
        isWaitBoundResult = waitBoundResult
        return this
    }

    /**
     * 查询是否为通过 BR/EDR 建立的 GATT 连接
     *
     * @return true 表示为 GATT over BR/EDR
     */
    fun isConnectGattOverBrEdr(): Boolean = param.getTransport() == BluetoothConstant.TRANSPORT_BREDR

    /**
     * 唤醒当前设备的数据发送线程（当收到数据写入 ACK 或超时时调用）
     *
     * @param task 匹配的发送任务
     */
    fun wakeupSendThread(task: BleSendTask?) {
        val thread = sendDataThread
        if (thread != null && task != null && gatt!!.equals(task.bleGatt)) {
            thread.wakeupSendThread(task)
        }
    }

    /**
     * 向发送队列添加待发送的数据包任务
     *
     * @param serviceUUID 目标服务 UUID
     * @param characteristicUUID 目标写入特征值 UUID
     * @param data 待发送的原始字节数组
     * @param callback 发送完成结果异步回调
     * @return true 表示成功加入发送线程的缓冲队列
     */
    fun addSendTask(serviceUUID: UUID?, characteristicUUID: UUID?, data: ByteArray?, callback: OnWriteDataCallback?): Boolean {
        var ret = false
        val thread = sendDataThread
        if (thread != null && thread.isRunning()) {
            ret = thread.addSendTask(gatt, serviceUUID, characteristicUUID, data, callback)
        }
        return ret
    }

    /**
     * 启动当前设备的专用数据发送工作线程
     */
    private fun startSendDataThread() {
        val runningThread = sendDataThread
        if (runningThread == null || !runningThread.isRunning()) {
            sendDataThread = SendBleDataThread(object : IBleOp {
                override fun getBleMtu(): Int = this@BleDevice.getMtu()

                override fun writeDataByBle(
                    gatt: BluetoothGatt?,
                    serviceUUID: UUID?,
                    characteristicUUID: UUID?,
                    data: ByteArray?,
                ): Boolean = writeDataToDeviceByBle(gatt, serviceUUID, characteristicUUID, data)
            }, object : OnThreadStateListener {
                override fun onStart(id: Long, name: String?) {
                }

                override fun onEnd(id: Long, name: String?) {
                    val thread = sendDataThread
                    if (thread != null && AppUtil.threadId(thread) == id) {
                        sendDataThread = null
                    }
                }
            })
            sendDataThread!!.start()
        }
    }

    /**
     * 停止数据发送工作线程
     */
    private fun stopSendDataThread() {
        sendDataThread?.stopThread()
    }

    /**
     * 读取最近一次提交写入的数据副本
     */
    fun peekLastWritePayload(): ByteArray? = lastWritePayload?.clone()

    /**
     * 调用系统底层 BluetoothGatt 实际执行特征值写入
     *
     * @param gatt 目标 GATT 句柄
     * @param serviceUUID 目标服务 UUID
     * @param characteristicUUID 目标特征值 UUID
     * @param data 待写入的数据
     * @return true 表示成功调用底层的 writeCharacteristic
     */
    @SuppressLint("MissingPermission")
    private fun writeDataToDeviceByBle(
        gatt: BluetoothGatt?,
        serviceUUID: UUID?,
        characteristicUUID: UUID?,
        data: ByteArray?,
    ): Boolean {
        if (gatt == null || serviceUUID == null || characteristicUUID == null || data == null || data.isEmpty()
            || !AppUtil.checkHasConnectPermission(OtaRuntime.getContext())
        ) {
            JL_Log.d(TAG, "writeDataByBle", "param is invalid.")
            return false
        }
        val gattService: BluetoothGattService? = gatt.getService(serviceUUID)
        if (gattService == null) {
            JL_Log.d(TAG, "writeDataByBle", "service is null.")
            return false
        }
        val gattCharacteristic: BluetoothGattCharacteristic? = gattService.getCharacteristic(characteristicUUID)
        if (gattCharacteristic == null) {
            JL_Log.d(TAG, "writeDataByBle", "characteristic is null")
            return false
        }
        var ret = false
        lastWritePayload = data.clone()
        try {
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
                val status = gatt.writeCharacteristic(gattCharacteristic, data, gattCharacteristic.writeType)
                ret = status == BluetoothStatusCodes.SUCCESS
            } else {
                @Suppress("DEPRECATION")
                gattCharacteristic.setValue(data)
                @Suppress("DEPRECATION")
                ret = gatt.writeCharacteristic(gattCharacteristic)
            }
        } catch (e: Exception) {
            e.printStackTrace()
        }
        JL_Log.d(TAG, "writeDataByBle", "device : " + gatt.device + ", put send queue : " + ret + ", data = " + CHexConver.byte2HexStr(data))
        return ret
    }

    override fun toString(): String {
        return "BleDevice{" +
            "device=" + device +
            ", reconnectLimit=" + reconnectLimit +
            ", connection=" + BluetoothUtil.printBtConnectionState(connection) +
            ", mtu=" + mtu +
            ", connectedTime=" + connectedTime +
            ", gatt=" + gatt +
            ", sendDataThread=" + sendDataThread +
            ", reconnectCount=" + reconnectCount +
            ", isNeedReconnect=" + isNeedReconnect +
            ", isUsing=" + isUsing +
            ", isWaitBoundResult=" + isWaitBoundResult +
            '}'
    }

    companion object {
        /** 日志标识 TAG */
        private const val TAG = "BleManager"

        /** 默认的最大断开重试连接次数 */
        private const val MAX_RETRY_CONNECT_COUNT = 1
    }
}
