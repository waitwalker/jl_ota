package com.jieli.otasdk.tool.ota.spp

import android.annotation.SuppressLint
import android.bluetooth.BluetoothAdapter
import android.bluetooth.BluetoothDevice
import android.bluetooth.BluetoothProfile
import android.bluetooth.BluetoothSocket
import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.content.IntentFilter
import android.os.Bundle
import android.os.Handler
import android.os.Message
import android.os.ParcelUuid
import android.os.Parcelable
import android.os.SystemClock
import com.jieli.jl_bt_ota.util.BluetoothUtil
import com.jieli.jl_bt_ota.util.CHexConver
import com.jieli.jl_bt_ota.util.CommonUtil
import com.jieli.jl_bt_ota.util.JL_Log
import com.jieli.jl_bt_ota.util.PreferencesHelper
import com.jieli.jl_bt_ota.util.UuidUtil
import com.jieli.otasdk.OtaRuntime
import com.jieli.otasdk.tool.config.ConfigHelper
import com.jieli.otasdk.tool.ota.spp.interfaces.OnWriteSppDataCallback
import com.jieli.otasdk.tool.ota.spp.interfaces.SppEventCallback
import com.jieli.otasdk.util.AppUtil
import java.io.IOException
import java.util.UUID

/**
 * 经典蓝牙 SPP (Serial Port Profile) 串口通信核心管理类
 *
 * 负责经典蓝牙扫描、系统配对绑定、RFCOMM Socket 连接线程管理、
 * 数据接收工作线程与异步发送队列管理。实现了 [SendSppDataThread.ISppOp] 接口以支持数据写入。
 *
 * @param mContext 上下文对象
 */
@Suppress("DEPRECATION")
class SppManager private constructor(private val mContext: Context) : SendSppDataThread.ISppOp {
    /** 是否使用自定义 SPP 私有通道 */
    private val useSppPrivateChannel = ConfigHelper.getInstance().isUseMultiSppChannel()

    /** 系统底层蓝牙适配器 */
    private val mBtAdapter: BluetoothAdapter? = BluetoothAdapter.getDefaultAdapter()

    /** SPP 事件观察者回调管理器 */
    private val mSppEventCallbackManager = SppEventCallbackManager()

    /** 本次扫描生命周期中发现的经典蓝牙设备列表 */
    private val mDiscoveredEdrDevices = ArrayList<BluetoothDevice>()

    /** 当前所有已连接 SPP 通道的数据接收线程映射表（Key 格式为 "MAC_UUID"） */
    private val mConnectedSppMap = HashMap<String, ReceiveSppDataThread>()

    /** 当前处于正在尝试连接状态的 SPP 设备 */
    @Volatile
    private var connectingSppDev: BluetoothDevice? = null

    /** 当前已建立 SPP 连接的设备 */
    @Volatile
    private var connectedSppDev: BluetoothDevice? = null

    /** 当前正在进行配对绑定的设备 */
    @Volatile
    private var mBondingDevice: BluetoothDevice? = null

    /** 经典蓝牙设备发现广播接收器 */
    private var mDiscoveryReceiver: DiscoveryReceiver? = null

    /** 当前连接使用的 SPP 服务 UUID */
    private var mSppUUID: UUID? = null

    /** 系统蓝牙状态广播接收器 */
    private var mBluetoothReceiver: BluetoothReceiver? = null

    /** 当前运行的 SPP 连接工作线程 */
    private var mConnectSppThread: ConnectionSppThread? = null

    /** 专用于当前设备的 SPP 数据发送工作线程 */
    private var mSendSppDataThread: SendSppDataThread? = null

    /**
     * 自定义 SPP 通道 UUID
     */
    val customSppUUID: UUID = UUID.fromString(
        PreferencesHelper.getSharedPreferences(mContext).getString(KEY_SPP_UUID, UUID_DEFAULT_CUSTOM.toString())!!,
    )

    /**
     * 查询底层当前是否处于经典蓝牙扫描中
     */
    val isScanning: Boolean
        @SuppressLint("MissingPermission")
        get() {
            if (!AppUtil.checkHasScanPermission(mContext)) return false
            val adapter = mBtAdapter ?: return false
            return adapter.isDiscovering
        }

    /**
     * 查询当前是否有 SPP 设备处于正在连接状态
     */
    val isSppConnecting: Boolean
        get() = connectingSppDev != null

    /**
     * 获取正在连接中的 SPP 蓝牙设备
     */
    val connectingSppDevice: BluetoothDevice?
        get() = connectingSppDev

    /**
     * 获取当前处于连接状态的 SPP 蓝牙设备
     */
    val connectedSppDevice: BluetoothDevice?
        get() = connectedSppDev

    /**
     * 内部 Handler 消息处理中心，负责超时管理（扫描超时、配对超时、SPP 连接超时）
     */
    private val mHandler = Handler { msg ->
        when (msg.what) {
            MSG_DISCOVERY_EDR_TIMEOUT -> {
                val scanning = isScanning
                JL_Log.w(TAG, "call MSG_DISCOVERY_EDR_TIMEOUT >> isScanning = $scanning")
                if (scanning) {
                    stopDeviceScan()
                }
            }
            MSG_CREATE_BOND_TIMEOUT -> {
                val device = msg.obj as? BluetoothDevice
                if (device != null) {
                    val sppUUID = readSppUuid(msg.data)
                    JL_Log.w(TAG, "call MSG_CREATE_BOND_TIMEOUT >> device = " + printDeviceInfo(device) + ", sppUUID = " + sppUUID)
                    if (isPaired(device)) {
                        startConnectSppThread(device, sppUUID)
                    } else {
                        handleSppConnection(device, sppUUID, BluetoothProfile.STATE_DISCONNECTED)
                    }
                }
            }
            MSG_CONNECT_SPP_TIMEOUT -> {
                val device = msg.obj as? BluetoothDevice
                if (device != null) {
                    val sppUUID = readSppUuid(msg.data)
                    JL_Log.w(TAG, "call MSG_CONNECT_SPP_TIMEOUT >> device = " + printDeviceInfo(device) + ", sppUUID = " + sppUUID)
                    if (!isSppSocketConnected(device, sppUUID)) {
                        handleSppConnection(device, sppUUID, BluetoothProfile.STATE_DISCONNECTED)
                    }
                }
            }
        }
        true
    }

    init {
        if (CommonUtil.getMainContext() == null) {
            CommonUtil.setMainContext(mContext)
        }
        registerBluetoothReceiver()
    }

    /**
     * 注册 SPP 事件监听回调
     *
     * @param callback 实现了 [SppEventCallback] 的观察者
     */
    fun registerSppEventCallback(callback: SppEventCallback?) {
        mSppEventCallbackManager.registerSppEventCallback(callback)
    }

    /**
     * 注销 SPP 事件监听回调
     *
     * @param callback 待注销的观察者
     */
    fun unregisterSppEventCallback(callback: SppEventCallback?) {
        mSppEventCallbackManager.unregisterSppEventCallback(callback)
    }

    /**
     * 释放并清理所有 SPP 管理相关资源
     *
     * 注销广播、断开当前连接、清空线程及 Socket 映射并重置单例。
     */
    fun release() {
        unregisterDiscoveryReceiver()
        unregisterBluetoothReceiver()
        mDiscoveredEdrDevices.clear()
        stopConnectSppThread()
        val connected = connectedSppDev
        if (connected != null) {
            disconnectSpp(connected, null)
        }
        clearConnectedSppMap()
        mHandler.removeCallbacksAndMessages(null)
        mSppEventCallbackManager.release()
        instance = null
    }

    /**
     * 启动经典蓝牙设备扫描
     *
     * @param timeout 扫描超时时间（毫秒）
     * @return true 表示成功提交扫描启动指令
     */
    @SuppressLint("MissingPermission")
    fun startDeviceScan(timeout: Long): Boolean {
        if (mBtAdapter == null || !AppUtil.checkHasScanPermission(mContext)) {
            JL_Log.e(TAG, "startDeviceScan", "this device is not supported bluetooth.")
            return false
        }
        if (!BluetoothUtil.isBluetoothEnable()) {
            JL_Log.e(TAG, "startDeviceScan", "Bluetooth is not enable.")
            return false
        }
        if (isScanning) {
            JL_Log.i(TAG, "startDeviceScan", "It is scanning. timeout : $timeout")
            startScanTimeoutTask(timeout)
            return true
        }
        val ret = mBtAdapter.startDiscovery()
        JL_Log.i(TAG, "startDeviceScan", "startDiscovery : $ret, timeout : $timeout")
        if (ret) {
            mDiscoveredEdrDevices.clear()
        }
        notifyDiscoveryStatus(ret, timeout)
        return ret
    }

    /**
     * 停止正在进行的经典蓝牙设备扫描
     *
     * @return true 表示成功停止扫描
     */
    @SuppressLint("MissingPermission")
    fun stopDeviceScan(): Boolean {
        if (mBtAdapter == null || !AppUtil.checkHasScanPermission(mContext)) {
            JL_Log.e(TAG, "-stopDeviceScan- :: this device is not supported bluetooth.")
            return false
        }
        if (!BluetoothUtil.isBluetoothEnable()) {
            JL_Log.e(TAG, "-stopDeviceScan- :: Bluetooth is not enable.")
            unregisterDiscoveryReceiver()
            return true
        }
        if (!mBtAdapter.isDiscovering) {
            return true
        }
        val ret = mBtAdapter.cancelDiscovery()
        if (!ret) {
            return false
        }
        stopScanTimeoutTask()
        return true
    }

    /**
     * 校验指定设备是否已经完成系统配对绑定
     *
     * @param device 待检测的目标物理设备
     * @return true 表示处于已配对状态 [BluetoothDevice.BOND_BONDED]
     */
    @SuppressLint("MissingPermission")
    fun isPaired(device: BluetoothDevice?): Boolean {
        if (!AppUtil.checkHasConnectPermission(mContext)) return false
        return device != null && BluetoothDevice.BOND_BONDED == device.bondState
    }

    /**
     * 查询当前是否有 SPP 设备处于连接状态
     *
     * @return true 表示当前有连接
     */
    fun isSppConnected(): Boolean = connectedSppDev != null

    /**
     * 查询指定物理设备是否与当前已连接 SPP 设备一致
     *
     * @param device 待检测的目标设备
     * @return true 表示该设备已处于连接状态
     */
    fun isSppConnected(device: BluetoothDevice?): Boolean {
        return BluetoothUtil.deviceEquals(connectedSppDev, device)
    }

    /**
     * 根据蓝牙 MAC 地址连接 SPP 设备
     *
     * @param address 目标蓝牙 MAC 地址字符串
     * @return true 表示成功提交连接请求
     */
    fun connectSpp(address: String?): Boolean {
        return connectSpp(BluetoothUtil.getRemoteDevice(address))
    }

    /**
     * 使用标准 SPP 服务 UUID 连接指定蓝牙设备
     *
     * @param device 目标蓝牙物理设备
     * @return true 表示成功提交连接请求
     */
    fun connectSpp(device: BluetoothDevice?): Boolean {
        return connectSpp(device, UUID_SPP)
    }

    /**
     * 按照指定 SPP 服务 UUID 连接目标设备
     *
     * 若未配对则先触发配对流程，配对成功后启动 [ConnectionSppThread] 建立 Socket 连接
     *
     * @param device 目标蓝牙物理设备
     * @param sppUUID 目标 SPP 通道服务 UUID
     * @return true 表示成功提交连接请求
     */
    @SuppressLint("MissingPermission")
    fun connectSpp(device: BluetoothDevice?, sppUUID: UUID?): Boolean {
        if (!AppUtil.checkHasConnectPermission(mContext)) {
            JL_Log.w(TAG, "connectSpp", "miss bluetooth permission.")
            return false
        }
        if (device == null || device.type == BluetoothDevice.DEVICE_TYPE_LE) {
            JL_Log.w(TAG, "connectSpp", "device is bad object. ")
            return false
        }
        JL_Log.i(TAG, "connectSpp", "device : " + printDeviceInfo(device) + ", sppUUID = " + sppUUID)
        val connectingSpp = connectingSppDevice
        if (connectingSpp != null) {
            JL_Log.i(TAG, "connectSpp", "device is connecting. device :" + printDeviceInfo(connectingSpp))
            return false
        }
        val connectedSpp = connectedSppDevice
        if (connectedSpp != null) {
            if (BluetoothUtil.deviceEquals(connectedSpp, device)) {
                if (isSppSocketConnected(device, sppUUID)) {
                    handleSppConnection(device, sppUUID, BluetoothProfile.STATE_CONNECTED)
                    return true
                }
            } else {
                if (disconnectSpp(connectedSpp, null)) {
                    SystemClock.sleep(500)
                }
            }
        }
        setConnectingSppDevice(device)
        setSppUUID(sppUUID)
        val paired = isPaired(device)
        JL_Log.i(TAG, "connectSpp", "isPaired = $paired")
        if (!paired) {
            val ret = BluetoothUtil.createBond(device)
            JL_Log.i(TAG, "connectSpp", "createBond = $ret")
            if (!ret) {
                handleSppConnection(device, sppUUID, BluetoothProfile.STATE_DISCONNECTED)
                return false
            } else {
                startPairTimeoutTask(device, sppUUID)
            }
        } else {
            if (device.uuids == null || !BluetoothUtil.deviceHasProfile(device, sppUUID)) {
                val ret = device.fetchUuidsWithSdp()
                JL_Log.i(TAG, "connectSpp", "fetchUuidsWithSdp = $ret")
                if (!ret) {
                    handleSppConnection(device, sppUUID, BluetoothProfile.STATE_DISCONNECTED)
                    return false
                }
            } else {
                startConnectSppThread(device, sppUUID)
            }
        }
        handleSppConnection(device, sppUUID, BluetoothProfile.STATE_CONNECTING)
        startConnectTimeoutTask(device, sppUUID)
        return true
    }

    /**
     * 断开指定设备的 SPP 连接
     *
     * @param device 目标设备
     * @param sppUUID 待断开的通道 UUID，若传 null 则断开该设备的所有 SPP 通道
     * @return true 表示成功执行断开
     */
    @SuppressLint("MissingPermission")
    fun disconnectSpp(device: BluetoothDevice?, sppUUID: UUID?): Boolean {
        if (!AppUtil.checkHasConnectPermission(mContext)) {
            JL_Log.w(TAG, "disconnectSpp", "miss bluetooth permission.")
            return false
        }
        if (!BluetoothUtil.deviceEquals(device, connectedSppDev)) {
            JL_Log.e(
                TAG,
                "disconnectSpp",
                "device is not connected. device = " + printDeviceInfo(device) +
                    ",\n ConnectedSppDevice = " + printDeviceInfo(connectedSppDev),
            )
            return false
        }
        JL_Log.i(TAG, "disconnectSpp", "device = " + printDeviceInfo(device) + ", sppUUID = " + sppUUID)
        if (sppUUID == null) {
            if (!isConnectedSocketMapEmpty(device)) {
                val keySet = mConnectedSppMap.keys
                val uuidList = ArrayList<UUID>()
                val address = device!!.address
                for (key in keySet) {
                    val strings = key.split("_")
                    if (strings.size == 2 && address == strings[0]) {
                        uuidList.add(UUID.fromString(strings[1]))
                    }
                }
                for (uuid in uuidList) {
                    disconnectSpp(device, uuid)
                }
            }
        } else {
            val receiveSppDataThread = removeRecvSppDataThread(device, sppUUID)
            if (receiveSppDataThread != null) {
                val socket = receiveSppDataThread.getBluetoothSocket()
                if (socket != null) {
                    try {
                        socket.close()
                    } catch (e: IOException) {
                        e.printStackTrace()
                    }
                }
                receiveSppDataThread.stopThread()
            }
            handleSppConnection(device, sppUUID, BluetoothProfile.STATE_DISCONNECTED)
        }
        return true
    }

    /**
     * 同步向目标 SPP 设备 Socket 输出流写入数据（由发送线程调用）
     *
     * @param device 目标蓝牙物理设备
     * @param sppUUID SPP 服务 UUID
     * @param data 待发送原始字节数组
     * @return true 表示写入成功
     * @throws IOException 写入流异常
     */
    @SuppressLint("MissingPermission")
    @Synchronized
    @Throws(IOException::class)
    override fun writeDataToSppDevice(device: BluetoothDevice?, sppUUID: UUID?, data: ByteArray?): Boolean {
        if (!AppUtil.checkHasConnectPermission(mContext)) {
            JL_Log.w(TAG, "writeDataToSppDevice", "miss bluetooth permission.")
            return false
        }
        if (device == null || data == null) {
            JL_Log.e(TAG, "writeDataToSppDevice", "param is error.")
            return false
        }
        val receiveSppDataThread = getRecvSppDataThread(device, sppUUID)
        if (receiveSppDataThread == null) {
            JL_Log.e(TAG, "writeDataToSppDevice", "receiveSppDataThread is null. device = $device, sppUUID = $sppUUID")
            return false
        }
        val socket = receiveSppDataThread.getBluetoothSocket()
        if (socket == null || !socket.isConnected || socket.outputStream == null) {
            JL_Log.e(TAG, "writeDataToSppDevice", "spp socket is close.")
            return false
        }
        socket.outputStream.write(data)
        JL_Log.d(
            TAG,
            "writeDataToSppDevice",
            "device = " + device + ", sppUUID = " + sppUUID +
                "\n send ret = true, raw data = " + CHexConver.byte2HexStr(data),
        )
        return true
    }

    /**
     * 异步向目标 SPP 设备发送数据
     *
     * 将发送任务提交至 [SendSppDataThread] 队列并在后台异步完成写入
     *
     * @param device 目标设备
     * @param sppUUID SPP 服务 UUID
     * @param data 待发送数据
     * @param callback 写入结果异步监听回调
     */
    fun writeDataToSppAsync(device: BluetoothDevice?, sppUUID: UUID?, data: ByteArray?, callback: OnWriteSppDataCallback?) {
        addSendTask(device, sppUUID, data, callback)
    }

    /**
     * 查询指定设备的对应 SPP Socket 是否处于已连接有效状态
     *
     * @param device 目标设备
     * @param sppUUID SPP 服务 UUID
     * @return true 表示 Socket 已连接
     */
    @SuppressLint("MissingPermission")
    fun isSppSocketConnected(device: BluetoothDevice?, sppUUID: UUID?): Boolean {
        if (!AppUtil.checkHasConnectPermission(mContext)) {
            JL_Log.w(TAG, "isSppSocketConnected", "miss bluetooth permission.")
            return false
        }
        val thread = getRecvSppDataThread(device, sppUUID) ?: return false
        val socket = thread.getBluetoothSocket()
        return socket != null && socket.isConnected
    }

    /**
     * 记录当前正在连接的设备
     */
    private fun setConnectingSppDevice(device: BluetoothDevice?) {
        connectingSppDev = device
    }

    /**
     * 记录当前已连接的设备
     */
    private fun setConnectedSppDevice(device: BluetoothDevice?) {
        connectedSppDev = device
        if (device != null) {
            setConnectingSppDevice(null)
        }
    }

    /**
     * 记录当前配置的 SPP UUID
     */
    private fun setSppUUID(sppUUID: UUID?) {
        mSppUUID = sppUUID
    }

    /**
     * 生成设备的 Socket 唯一标识 Key（格式：MAC_UUID）
     */
    private fun getSocketUUID(device: BluetoothDevice?, sppUUID: UUID?): String? {
        if (device == null || sppUUID == null) return null
        return device.address + "_" + sppUUID
    }

    /**
     * 将接收线程存入连接映射表
     */
    private fun addRecvSppDataThread(socketUUID: String?, thread: ReceiveSppDataThread?) {
        if (socketUUID == null || thread == null) return
        mConnectedSppMap[socketUUID] = thread
    }

    /**
     * 获取指定设备及 UUID 对应的接收线程
     */
    private fun getRecvSppDataThread(device: BluetoothDevice?, sppUUID: UUID?): ReceiveSppDataThread? {
        val socketUUID = getSocketUUID(device, sppUUID) ?: return null
        return mConnectedSppMap[socketUUID]
    }

    /**
     * 移除指定设备及 UUID 对应的接收线程
     */
    private fun removeRecvSppDataThread(device: BluetoothDevice?, sppUUID: UUID?): ReceiveSppDataThread? {
        val socketUUID = getSocketUUID(device, sppUUID) ?: return null
        return mConnectedSppMap.remove(socketUUID)
    }

    /**
     * 检查当前设备在映射表中是否已无任何活跃的 Socket 连接
     */
    private fun isConnectedSocketMapEmpty(device: BluetoothDevice?): Boolean {
        if (device == null) return true
        if (mConnectedSppMap.isEmpty()) return true
        val address = device.address
        for (key in mConnectedSppMap.keys) {
            val strings = key.split("_")
            if (strings.size == 2 && address == strings[0]) {
                return false
            }
        }
        return true
    }

    /**
     * 清空全部已连接 SPP 映射表并停止所有接收线程
     */
    private fun clearConnectedSppMap() {
        if (mConnectedSppMap.isNotEmpty()) {
            for (key in mConnectedSppMap.keys) {
                mConnectedSppMap[key]?.stopThread()
            }
            mConnectedSppMap.clear()
        }
    }

    /**
     * 检索系统当前已连接的经典蓝牙设备并模拟发现上报
     */
    @SuppressLint("MissingPermission")
    private fun syncSystemConnectedDevice() {
        if (!AppUtil.checkHasConnectPermission(mContext)) return
        val list = BluetoothUtil.getSystemConnectedBtDeviceList(mContext)
        if (list.isNullOrEmpty()) return
        for (device in list) {
            if (isSppDevice(device) && !BluetoothUtil.deviceEquals(connectedSppDev, device)) {
                if (!mDiscoveredEdrDevices.contains(device)) {
                    mDiscoveredEdrDevices.add(device)
                    mSppEventCallbackManager.onDiscoveryDevice(device, 0)
                }
            }
        }
    }

    /**
     * 启动扫描超时检测任务
     */
    private fun startScanTimeoutTask(timeout: Long) {
        mHandler.removeMessages(MSG_DISCOVERY_EDR_TIMEOUT)
        mHandler.sendEmptyMessageDelayed(MSG_DISCOVERY_EDR_TIMEOUT, timeout)
    }

    /**
     * 停止扫描超时检测任务
     */
    private fun stopScanTimeoutTask() {
        mHandler.removeMessages(MSG_DISCOVERY_EDR_TIMEOUT)
    }

    /**
     * 启动配对超时检测任务
     */
    private fun startPairTimeoutTask(device: BluetoothDevice, sppUUID: UUID?) {
        JL_Log.d(TAG, "startPairTimeoutTask", "device = " + printDeviceInfo(device) + ", sppUUID = " + sppUUID)
        mHandler.removeMessages(MSG_CREATE_BOND_TIMEOUT)
        mBondingDevice = device
        val bundle = Bundle()
        bundle.putSerializable(KEY_SPP_UUID, sppUUID)
        val message = mHandler.obtainMessage(MSG_CREATE_BOND_TIMEOUT, device)
        message.data = bundle
        mHandler.sendMessageDelayed(message, BOND_DEV_TIMEOUT.toLong())
    }

    /**
     * 停止配对超时检测任务
     */
    private fun stopPairTimeoutTask(device: BluetoothDevice?) {
        JL_Log.d(TAG, "-stopPairTimeoutTask- device = " + printDeviceInfo(device))
        if (BluetoothUtil.deviceEquals(device, mBondingDevice)) {
            mHandler.removeMessages(MSG_CREATE_BOND_TIMEOUT)
            mBondingDevice = null
        }
    }

    /**
     * 启动 SPP 链路连接建立超时检测任务
     */
    private fun startConnectTimeoutTask(device: BluetoothDevice, sppUUID: UUID?) {
        JL_Log.i(TAG, "-startConnectTimeoutTask- device = " + printDeviceInfo(device) + ", sppUUID = " + sppUUID)
        mHandler.removeMessages(MSG_CONNECT_SPP_TIMEOUT)
        val bundle = Bundle()
        bundle.putSerializable(KEY_SPP_UUID, sppUUID)
        val message = mHandler.obtainMessage(MSG_CONNECT_SPP_TIMEOUT, device)
        message.data = bundle
        mHandler.sendMessageDelayed(message, CONNECT_DEV_TIMEOUT.toLong())
    }

    /**
     * 停止连接超时检测任务
     */
    private fun stopConnectTimeoutTask() {
        JL_Log.w(TAG, "-stopConnectTimeoutTask-")
        mHandler.removeMessages(MSG_CONNECT_SPP_TIMEOUT)
    }

    /**
     * 注册经典蓝牙设备发现广播监听
     */
    private fun registerDiscoverReceiver() {
        if (mDiscoveryReceiver == null) {
            mDiscoveryReceiver = DiscoveryReceiver()
            val intentFilter = IntentFilter()
            intentFilter.addAction(BluetoothAdapter.ACTION_DISCOVERY_STARTED)
            intentFilter.addAction(BluetoothAdapter.ACTION_DISCOVERY_FINISHED)
            intentFilter.addAction(BluetoothDevice.ACTION_FOUND)
            mContext.registerReceiver(mDiscoveryReceiver, intentFilter)
        }
    }

    /**
     * 注销经典蓝牙设备发现广播监听
     */
    private fun unregisterDiscoveryReceiver() {
        if (mDiscoveryReceiver != null) {
            mContext.unregisterReceiver(mDiscoveryReceiver)
            mDiscoveryReceiver = null
        }
    }

    /**
     * 注册系统蓝牙状态及 UUID 变化广播
     */
    private fun registerBluetoothReceiver() {
        if (mBluetoothReceiver == null) {
            mBluetoothReceiver = BluetoothReceiver()
            val intentFilter = IntentFilter(BluetoothAdapter.ACTION_STATE_CHANGED)
            intentFilter.addAction(BluetoothDevice.ACTION_BOND_STATE_CHANGED)
            intentFilter.addAction(BluetoothDevice.ACTION_UUID)
            mContext.registerReceiver(mBluetoothReceiver, intentFilter)
        }
    }

    /**
     * 注销系统蓝牙广播
     */
    private fun unregisterBluetoothReceiver() {
        if (mBluetoothReceiver != null) {
            mContext.unregisterReceiver(mBluetoothReceiver)
            mBluetoothReceiver = null
        }
    }

    /**
     * 格式化打印设备调试信息
     */
    private fun printDeviceInfo(device: BluetoothDevice?): String {
        return BluetoothUtil.printBtDeviceInfo(mContext, device)
    }

    /**
     * 启动连接工作线程
     */
    private fun startConnectSppThread(device: BluetoothDevice?, sppUUID: UUID?) {
        JL_Log.d(TAG, "startConnectSppThread", "device = " + printDeviceInfo(device) + ", sppUUID = " + sppUUID)
        if (mConnectSppThread == null) {
            mConnectSppThread = ConnectionSppThread(
                mContext,
                device,
                sppUUID,
                object : ConnectionSppThread.OnConnectSppListener {
                    override fun onThreadStart(threadID: Long) {
                    }

                    override fun onThreadStop(
                        threadID: Long,
                        result: Boolean,
                        device: BluetoothDevice?,
                        sppUUID: UUID?,
                        socket: BluetoothSocket?,
                    ) {
                        val thread = mConnectSppThread
                        if (thread != null && thread.id == threadID) {
                            mConnectSppThread = null
                        }
                        if (result) {
                            setConnectedSppDevice(device)
                            startReceiveSppDataThread(device, sppUUID, socket)
                            startSendSppDataThread()
                            handleSppConnection(device, sppUUID, BluetoothProfile.STATE_CONNECTED)
                        } else {
                            handleSppConnection(device, sppUUID, BluetoothProfile.STATE_DISCONNECTED)
                        }
                    }
                },
            )
            mConnectSppThread!!.start()
        }
    }

    /**
     * 停止连接工作线程
     */
    private fun stopConnectSppThread() {
        val thread = mConnectSppThread
        if (thread != null) {
            if (thread.isAlive) {
                thread.interrupt()
            }
            mConnectSppThread = null
        }
    }

    /**
     * 为已建立的 Socket 启动数据接收工作线程
     */
    private fun startReceiveSppDataThread(device: BluetoothDevice?, sppUUID: UUID?, socket: BluetoothSocket?) {
        var receiveSppDataThread = getRecvSppDataThread(device, sppUUID)
        if (receiveSppDataThread == null) {
            receiveSppDataThread = ReceiveSppDataThread(
                mContext,
                device,
                sppUUID,
                socket,
                object : ReceiveSppDataThread.OnRecvSppDataListener {
                    override fun onThreadStart(threadID: Long) {
                    }

                    override fun onRecvSppData(threadID: Long, device: BluetoothDevice?, sppUUID: UUID?, data: ByteArray?) {
                        JL_Log.d(
                            TAG,
                            "onRecvSppData",
                            "device : " + device + ", sppUUID = " + sppUUID +
                                ", \n raw data = " + CHexConver.byte2HexStr(data),
                        )
                        mSppEventCallbackManager.onReceiveSppData(device, sppUUID, data)
                    }

                    override fun onThreadStop(threadID: Long, reason: Int, device: BluetoothDevice?, sppUUID: UUID?) {
                        if (reason == ReceiveSppDataThread.EXIT_REASON_IO_EXCEPTION) {
                            disconnectSpp(device, sppUUID)
                        }
                    }
                },
            )
            addRecvSppDataThread(getSocketUUID(device, sppUUID), receiveSppDataThread)
            receiveSppDataThread.start()
        }
    }

    /**
     * 停止指定设备的数据接收线程
     */
    private fun stopReceiveSppDataThread(device: BluetoothDevice?, sppUUID: UUID?) {
        val receiveSppDataThread = removeRecvSppDataThread(device, sppUUID)
        receiveSppDataThread?.stopThread()
    }

    /**
     * 启动 SPP 数据异步发送线程
     */
    private fun startSendSppDataThread() {
        if (mSendSppDataThread == null) {
            mSendSppDataThread = SendSppDataThread(
                mContext,
                this,
                object : SendSppDataThread.OnSendDataListener {
                    override fun onThreadStart(threadID: Long) {
                    }

                    override fun onThreadStop(threadID: Long) {
                        val thread = mSendSppDataThread
                        if (thread != null && thread.id == threadID) {
                            mSendSppDataThread = null
                        }
                    }
                },
            )
            mSendSppDataThread!!.start()
        }
    }

    /**
     * 停止数据发送工作线程
     */
    private fun stopSendSppDataThread() {
        mSendSppDataThread?.stopThread()
    }

    /**
     * 向发送队列添加发送任务
     */
    private fun addSendTask(device: BluetoothDevice?, sppUUID: UUID?, data: ByteArray?, callback: OnWriteSppDataCallback?) {
        mSendSppDataThread?.addSendTask(SendSppDataThread.SppSendTask(device, sppUUID, data, callback))
    }

    /**
     * 校验设备是否为当前管理的目标操作对象
     */
    private fun isValidDevice(device: BluetoothDevice?): Boolean {
        return BluetoothUtil.deviceEquals(connectingSppDev, device) ||
            BluetoothUtil.deviceEquals(device, mBondingDevice) ||
            BluetoothUtil.deviceEquals(device, connectedSppDev)
    }

    /**
     * 处理 SPP 连接状态迁移并通知所有观察者
     *
     * @param device 目标设备
     * @param sppUUID SPP 服务 UUID
     * @param status 连接状态码
     */
    private fun handleSppConnection(device: BluetoothDevice?, sppUUID: UUID?, status: Int) {
        val validDevice = isValidDevice(device)
        JL_Log.i(
            TAG,
            "handleSppConnection",
            "device : " + printDeviceInfo(device) + ", isValidDevice = " + validDevice + ", sppUUID = " + sppUUID + ", status = " + status,
        )
        if (validDevice) {
            if (status == BluetoothProfile.STATE_DISCONNECTED || status == BluetoothProfile.STATE_CONNECTED) {
                if (BluetoothUtil.deviceEquals(device, connectingSppDev)) {
                    setConnectingSppDevice(null)
                }
                stopConnectTimeoutTask()
                if (status == BluetoothProfile.STATE_DISCONNECTED) {
                    if (BluetoothUtil.deviceEquals(device, connectedSppDev)) {
                        stopReceiveSppDataThread(device, sppUUID)
                        if (isConnectedSocketMapEmpty(device)) {
                            stopSendSppDataThread()
                            setConnectedSppDevice(null)
                        }
                    }
                } else {
                    if (connectedSppDev == null) {
                        setConnectedSppDevice(device)
                    }
                }
            }
            mSppEventCallbackManager.onSppConnection(device, sppUUID, status)
            if (useSppPrivateChannel) {
                if (status == BluetoothProfile.STATE_CONNECTED) {
                    if (customSppUUID != sppUUID) {
                        connectSpp(device, customSppUUID)
                    }
                } else if (status == BluetoothProfile.STATE_DISCONNECTED && BluetoothUtil.deviceEquals(connectedSppDev, device)) {
                    disconnectSpp(connectedSppDev, null)
                }
            }
        }
    }

    /**
     * 校验设备是否为经典蓝牙设备
     */
    @SuppressLint("MissingPermission")
    private fun isSppDevice(device: BluetoothDevice?): Boolean {
        if (!AppUtil.checkHasConnectPermission(mContext)) return false
        return device != null && device.type != BluetoothDevice.DEVICE_TYPE_LE
    }

    /**
     * 通知经典蓝牙扫描状态变更
     */
    private fun notifyDiscoveryStatus(scanning: Boolean, timeout: Long) {
        if (scanning) {
            registerDiscoverReceiver()
            startScanTimeoutTask(timeout)
        } else {
            stopScanTimeoutTask()
            unregisterDiscoveryReceiver()
        }
        mSppEventCallbackManager.onDiscoveryDeviceChange(scanning)
        if (scanning) {
            syncSystemConnectedDevice()
        }
    }

    /**
     * 从 Bundle 中提取 SPP UUID 对象
     */
    @Suppress("DEPRECATION")
    private fun readSppUuid(bundle: Bundle?): UUID? {
        var sppUUID: UUID? = UUID_SPP
        if (bundle != null) {
            sppUUID = bundle.getSerializable(KEY_SPP_UUID) as? UUID
        }
        return sppUUID
    }

    /**
     * 经典蓝牙设备发现广播接收器
     */
    private inner class DiscoveryReceiver : BroadcastReceiver() {
        @SuppressLint("MissingPermission")
        override fun onReceive(context: Context?, intent: Intent?) {
            if (intent == null) return
            val action = intent.action ?: return
            when (action) {
                BluetoothAdapter.ACTION_DISCOVERY_STARTED -> JL_Log.d(TAG, "ACTION_DISCOVERY_STARTED", "")
                BluetoothAdapter.ACTION_DISCOVERY_FINISHED -> {
                    JL_Log.d(TAG, "ACTION_DISCOVERY_FINISHED", "")
                    notifyDiscoveryStatus(false, 0)
                }
                BluetoothDevice.ACTION_FOUND -> {
                    val device: BluetoothDevice = intent.getParcelableExtra(BluetoothDevice.EXTRA_DEVICE) ?: return
                    val rssi = intent.getShortExtra(BluetoothDevice.EXTRA_RSSI, (-1).toShort())
                    if (isSppDevice(device) && BluetoothUtil.isBluetoothEnable()) {
                        if (!mDiscoveredEdrDevices.contains(device)) {
                            mDiscoveredEdrDevices.add(device)
                            mSppEventCallbackManager.onDiscoveryDevice(device, rssi.toInt())
                        }
                    }
                }
            }
        }
    }

    /**
     * 系统蓝牙开关、配对状态及 UUID 解析广播接收器
     */
    private inner class BluetoothReceiver : BroadcastReceiver() {
        @SuppressLint("MissingPermission")
        override fun onReceive(context: Context?, intent: Intent?) {
            if (intent == null) return
            val action = intent.action ?: return
            when (action) {
                BluetoothAdapter.ACTION_STATE_CHANGED -> {
                    var state = intent.getIntExtra(BluetoothAdapter.EXTRA_CONNECTION_STATE, -1)
                    val adapter = mBtAdapter
                    if (adapter != null && state == -1) {
                        state = adapter.state
                    }
                    if (state == BluetoothAdapter.STATE_OFF) {
                        mDiscoveredEdrDevices.clear()
                        notifyDiscoveryStatus(false, 0)
                        disconnectSpp(connectedSppDevice, null)
                        mSppEventCallbackManager.onAdapterChange(false)
                    } else if (state == BluetoothAdapter.STATE_ON) {
                        mSppEventCallbackManager.onAdapterChange(true)
                    }
                }
                BluetoothDevice.ACTION_BOND_STATE_CHANGED -> {
                    val device: BluetoothDevice = intent.getParcelableExtra(BluetoothDevice.EXTRA_DEVICE) ?: return
                    if (!AppUtil.checkHasConnectPermission(context)) return
                    val bond = device.bondState
                    val validDevice = isValidDevice(device)
                    JL_Log.i(
                        TAG,
                        "ACTION_BOND_STATE_CHANGED",
                        "device : " + printDeviceInfo(device) + ", bond = " + bond + ", isValidDevice = " + validDevice,
                    )
                    if (bond == BluetoothDevice.BOND_NONE || bond == BluetoothDevice.BOND_BONDED) {
                        if (validDevice) {
                            stopPairTimeoutTask(device)
                            if (bond == BluetoothDevice.BOND_BONDED) {
                                startConnectSppThread(device, mSppUUID)
                            } else {
                                handleSppConnection(device, mSppUUID, BluetoothProfile.STATE_DISCONNECTED)
                            }
                        }
                    }
                }
                BluetoothDevice.ACTION_UUID -> {
                    val device: BluetoothDevice = intent.getParcelableExtra(BluetoothDevice.EXTRA_DEVICE) ?: return
                    val parcelUuids = intent.getParcelableArrayExtra(BluetoothDevice.EXTRA_UUID)
                    if (parcelUuids == null) {
                        JL_Log.e(TAG, "ACTION_UUID", "device : $device, no uuids")
                    } else {
                        val uuids = arrayOfNulls<ParcelUuid>(parcelUuids.size)
                        for (i in parcelUuids.indices) {
                            uuids[i] = ParcelUuid.fromString(parcelUuids[i].toString())
                            JL_Log.d(TAG, "ACTION_UUID", "index = $i uuid = " + UuidUtil.read16BitUUID(uuids[i]!!.uuid))
                        }
                    }
                    val connectingSpp = connectingSppDevice
                    JL_Log.d(TAG, "ACTION_UUID", "connectingSpp : " + printDeviceInfo(connectingSpp) + ", device = " + printDeviceInfo(device))
                    if (BluetoothUtil.deviceEquals(connectingSpp, device)) {
                        startConnectSppThread(device, mSppUUID)
                    }
                }
            }
        }
    }

    companion object {
        /** 日志标识 TAG */
        private const val TAG = "SppManager"

        /** 经典蓝牙标准 SPP 通道服务 UUID (0x1101) */
        @JvmField
        val UUID_SPP: UUID = UUID.fromString("00001101-0000-1000-8000-00805f9b34fb")

        /** 默认自定义 SPP 通道服务 UUID */
        @JvmField
        val UUID_DEFAULT_CUSTOM: UUID = UUID.fromString("fe010000-1234-5678-abcd-00805f9b34fb")

        /** SPP UUID 持久化键名 */
        private const val KEY_SPP_UUID = "spp_uuid"

        /** 设备配对超时时间 (30 秒) */
        private const val BOND_DEV_TIMEOUT = 30 * 1000

        /** SPP 连接超时时间 (40 秒) */
        private const val CONNECT_DEV_TIMEOUT = 40 * 1000

        /** 消息：扫描超时 */
        private const val MSG_DISCOVERY_EDR_TIMEOUT = 1022

        /** 消息：配对超时 */
        private const val MSG_CREATE_BOND_TIMEOUT = 1023

        /** 消息：连接超时 */
        private const val MSG_CONNECT_SPP_TIMEOUT = 1024

        /** 单例静态句柄 */
        @SuppressLint("StaticFieldLeak")
        @Volatile
        private var instance: SppManager? = null

        /**
         * 获取 [SppManager] 全局单例
         *
         * @return [SppManager] 实例
         */
        @JvmStatic
        fun getInstance(): SppManager {
            if (instance == null) {
                synchronized(SppManager::class.java) {
                    if (instance == null) {
                        instance = SppManager(OtaRuntime.getContext())
                    }
                }
            }
            return instance!!
        }
    }
}
