package com.jieli.otasdk.util

import android.bluetooth.BluetoothAdapter
import android.bluetooth.BluetoothDevice
import android.bluetooth.BluetoothProfile
import android.content.Context
import android.os.Handler
import android.os.Looper
import android.os.Message

import com.jieli.jl_bt_ota.constant.JL_Constant
import com.jieli.jl_bt_ota.model.BleScanMessage
import com.jieli.jl_bt_ota.tool.DeviceReConnectManager
import com.jieli.jl_bt_ota.util.BluetoothUtil
import com.jieli.jl_bt_ota.util.JL_Log
import com.jieli.jl_bt_ota.util.ParseDataUtil
import com.jieli.otasdk.tool.ota.ble.BleManager
import com.jieli.otasdk.tool.ota.ble.interfaces.BleEventCallback
import com.jieli.otasdk.tool.ota.ble.model.BleScanInfo
import java.util.*

/**
 * 杰理设备 OTA 重连辅助管理类
 *
 * 负责管理 OTA 升级重启后的设备自动回连流程，支持识别 OTA 重启后蓝牙 MAC 地址可能产生的偏移/变更、
 * 优先检测系统已配对连接设备、自动开启低功耗蓝牙扫描重试以及管理重连生命周期与超时机制。
 *
 * @author zqjasonZhong
 * @email zhongzhuocheng@zh-jieli.com
 * @desc 回连辅助类
 * @since 2022/12/9
 * @property mContext 应用程序上下文对象
 * @property mBtManager 低功耗蓝牙底层管理器
 */
class ReConnectHelper(private val mContext: Context, private val mBtManager: BleManager) {
    /** 待执行的重连任务参数缓存列表 */
    private val mParams: MutableList<ReconnectParam> = ArrayList()

    /** 扫描发现的设备 OTA 广播包缓存映射表（Key: 设备 MAC 地址，Value: 解析出的 OTA 广播报文） */
    private val mBleAdvCache: MutableMap<String, BleScanMessage> = HashMap()

    /**
     * 主线程 Handler，用于处理超时事件、重连任务轮询调度以及任务队列的动态清理
     */
    private val mUIHandler = Handler(Looper.getMainLooper()) { msg: Message ->
        when (msg.what) {
            MSG_RECONNECT_TIMEOUT -> {
                stopBtScan()
                mParams.clear()
            }
            MSG_PROCESS_TASK -> processReconnectTask()
            else -> if (msg.obj is String) {
                val address = msg.obj as String
                removeParam(address)
            }
        }
        true
    }

    /**
     * 释放重连辅助类持有的全部资源
     *
     * 清空待重连参数队列、广播包缓存，移除 Handler 中的所有未处理消息，并注销 BLE 事件回调。
     */
    fun release() {
        mParams.clear()
        mBleAdvCache.clear()
        mUIHandler.removeCallbacksAndMessages(null)
        mBtManager.unregisterBleEventCallback(bleEventCallback)
    }

    /**
     * 获取当前是否正在处于重连处理流程中
     *
     * @return true 表示正在执行重连任务，false 表示空闲
     */
    val isReconnecting: Boolean
        get() = mUIHandler.hasMessages(MSG_RECONNECT_TIMEOUT)

    /**
     * 判断指定的检测地址是否与源设备的重连配置相匹配
     *
     * 会考虑设备原本的 MAC 地址以及 OTA 后的连接地址。
     *
     * @param srcAddress 设备源 MAC 地址
     * @param checkAddress 待检测对比的 MAC 地址
     * @return true 表示匹配命中，false 表示不匹配或参数无效
     */
    fun isMatchAddress(srcAddress: String, checkAddress: String): Boolean {
        val param = getCacheParam(srcAddress)
        return if (null == param || !BluetoothAdapter.checkBluetoothAddress(checkAddress)) false else checkAddress == param.deviceAddress || checkAddress == param.connectAddress
    }

    /**
     * 向重连队列中添加一个设备的重连参数
     *
     * 若成功加入，将设置单个任务的超时时间，并驱动执行重连流程。
     *
     * @param param 目标设备的重连参数模型 [ReconnectParam]
     * @return true 表示添加成功或任务已存在，false 表示添加失败
     */
    fun putParam(param: ReconnectParam?): Boolean {
        if (null == param) return false
        if (!mParams.contains(param)) {
            if (mParams.add(param)) {
                // 添加任务超时
                mUIHandler.sendEmptyMessageDelayed(mParams.hashCode(), RECONNECT_TIMEOUT)
                if (!isReconnecting) {
                    mUIHandler.sendMessageDelayed(
                        mUIHandler.obtainMessage(
                            MSG_RECONNECT_TIMEOUT,
                            param.deviceAddress
                        ), RECONNECT_TIMEOUT + 10 * 1000
                    )
                    mUIHandler.sendEmptyMessage(MSG_PROCESS_TASK)
                }
                return true
            }
        } else {
            return true
        }
        return false
    }

    /**
     * 停止低功耗蓝牙扫描
     */
    private fun stopBtScan() {
        mBtManager.stopLeScan()
    }

    /**
     * 根据设备 MAC 地址在任务队列中查找匹配的重连参数
     *
     * 支持直接匹配原始地址，或利用广播缓存比对旧蓝牙地址（针对 OTA 地址偏移场景）。
     *
     * @param address 设备 MAC 地址
     * @return 匹配成功的 [ReconnectParam]，若未找到则返回 null
     */
    private fun getCacheParam(address: String): ReconnectParam? {
        if (!BluetoothAdapter.checkBluetoothAddress(address)) return null
        val advMsg = mBleAdvCache[address]
        for (param in ArrayList(mParams)) {
            if (address == param.deviceAddress || advMsg != null && param.deviceAddress == advMsg.oldBleAddress) {
                return param
            }
        }
        return null
    }

    /**
     * 移除指定设备地址的重连参数
     *
     * 移除后若任务队列为空，则清理重连总超时定时器；若仍有剩余任务，则继续调度后续重连。
     *
     * @param address 设备 MAC 地址
     */
    private fun removeParam(address: String) {
        val param = getCacheParam(address) ?: return
        if (mParams.remove(param)) {
            mUIHandler.removeMessages(param.hashCode())
            if (mParams.isEmpty()) {
                mUIHandler.removeMessages(MSG_RECONNECT_TIMEOUT)
                return
            }
        }
        mUIHandler.sendEmptyMessage(MSG_PROCESS_TASK)
    }

    /**
     * 调度并执行重连任务的核心逻辑
     *
     * 流程：
     * 1. 检查当前是否正在扫描，若处于扫描中则延时重试；
     * 2. 检查系统当前已连接的蓝牙设备，若存在目标设备则直接发起 BLE 连接；
     * 3. 否则启动低功耗蓝牙广播扫描寻找设备。
     */
    private fun processReconnectTask() {
        if (mBtManager.isBleScanning) {
            mUIHandler.sendEmptyMessageDelayed(MSG_PROCESS_TASK, FAILED_DELAY)
            return
        }
        val connectedDevice = systemConnectedDevice
        if (null != connectedDevice) {
            val param = getCacheParam(connectedDevice.address)
            if (null != param) param.connectAddress = connectedDevice.address
            mBtManager.connectBleDevice(connectedDevice)
            return
        }
        if (!mBtManager.startLeScan(SCAN_TIMEOUT)) {
            JL_Log.i(TAG, "processReconnectTask : start Le scan failed.")
            mUIHandler.sendEmptyMessageDelayed(MSG_PROCESS_TASK, FAILED_DELAY)
        }
    }

    /**
     * 获取系统已连接且属于目标重连设备的蓝牙设备对象
     *
     * @return 匹配的 [BluetoothDevice]，若无匹配设备则返回 null
     */
    private val systemConnectedDevice: BluetoothDevice?
        get() {
            val list = BluetoothUtil.getSystemConnectedBtDeviceList(mContext)
            if (null == list || list.isEmpty()) return null
            for (device in list) {
                if (isReconnectDevice(device, null)) {
                    return device
                }
            }
            return null
        }

    /**
     * 判断给定的蓝牙设备或广播报文是否属于待重连的目标设备
     *
     * 支持结合 OTA 新广播包格式（`isUseNewADV`）判断旧 MAC 地址是否匹配。
     *
     * @param device 扫描到的蓝牙设备实例
     * @param message 解析后的 OTA 广播报文
     * @return true 表示属于目标重连设备，false 表示非目标设备
     */
    private fun isReconnectDevice(device: BluetoothDevice?, message: BleScanMessage?): Boolean {
        if (null == device || mParams.isEmpty()) return false
        var ret = false
        for (param in ArrayList(mParams)) {
            ret = if (param.isUseNewADV && message != null && message.isOTA) {
                param.deviceAddress == message.oldBleAddress
            } else {
                param.deviceAddress == device.address
            }
            if (ret) break
        }
        return ret
    }

    /**
     * BLE 事件回调监听器实现
     *
     * 监听系统蓝牙开关变化、扫描启停、扫描发现设备以及连接状态变化，在重连过程中驱动状态机流转。
     */
    private val bleEventCallback: BleEventCallback = object : BleEventCallback() {
        /**
         * 蓝牙适配器开关状态变更回调
         *
         * @param bEnabled true 表示蓝牙已开启，false 表示蓝牙已关闭
         */
        override fun onAdapterChange(bEnabled: Boolean) {
            if (!isReconnecting) return
            if (bEnabled) {
                JL_Log.i(TAG, "onAdapterChange : bluetooth is on, try to start le scan.")
                mUIHandler.sendEmptyMessage(MSG_PROCESS_TASK)
            }
        }

        /**
         * BLE 扫描发现状态变更回调
         *
         * @param bStart true 表示开始扫描，false 表示停止扫描
         */
        override fun onDiscoveryBleChange(bStart: Boolean) {
            if (!isReconnecting) return
            val isConnecting = mBtManager.isConnecting
            JL_Log.i(TAG, "onDiscoveryBleChange : $bStart, isConnecting = $isConnecting")
            if (!bStart) {
                if (!isConnecting) {
                    mUIHandler.sendEmptyMessage(MSG_PROCESS_TASK)
                }
            }
        }

        /**
         * 扫描发现低功耗蓝牙设备回调
         *
         * 解析 OTA 标识广播包并更新缓存；若发现目标重连设备，则立即停止扫描并发起连接。
         *
         * @param device 扫描到的蓝牙设备
         * @param bleScanMessage 扫描到的元数据包 [BleScanInfo]
         */
        override fun onDiscoveryBle(device: BluetoothDevice?, bleScanMessage: BleScanInfo?) {
            if (!isReconnecting || null == device || bleScanMessage == null) return
            val advMsg = ParseDataUtil.parseOTAFlagFilterWithBroad(
                bleScanMessage.rawData,
                JL_Constant.OTA_IDENTIFY
            )
            if (advMsg != null) {
                mBleAdvCache[device.address] = advMsg
                JL_Log.d(TAG, "onDiscoveryBle : put data in map.")
            }
            val isReconnectDevice = isReconnectDevice(device, advMsg)
            JL_Log.d(
                TAG,
                "onDiscoveryBle : $device, isReconnectDevice = $isReconnectDevice, $advMsg"
            )
            if (isReconnectDevice) {
                stopBtScan()
                val param = getCacheParam(device.address)
                if (null != param) param.connectAddress = device.address
                JL_Log.d(TAG, "onDiscoveryBle : $device, param = $param")
                mBtManager.connectBleDevice(device)
            }
        }

        /**
         * BLE 连接状态变更回调
         *
         * 命中目标重连设备连接成功后，清理该设备的重连参数；若断开连接则重新调度重连流程。
         *
         * @param device 触发状态变更的蓝牙设备
         * @param status 连接状态码（如 [BluetoothProfile.STATE_CONNECTED]、[BluetoothProfile.STATE_DISCONNECTED]）
         */
        override fun onBleConnection(device: BluetoothDevice?, status: Int) {
            if (!isReconnecting || null == device) return
            val advMsg = mBleAdvCache[device.address]
            val isReconnectDevice = isReconnectDevice(device, advMsg)
            if (!isReconnectDevice) return
            JL_Log.i(TAG, "onBleConnection : $device, status = $status, $advMsg")
            if (status == BluetoothProfile.STATE_CONNECTED) {
                JL_Log.w(TAG, "onBleConnection : removeParam >>> " + device.address)
                removeParam(device.address)
            } else if (status == BluetoothProfile.STATE_DISCONNECTED) {
                JL_Log.i(TAG, "-onConnection- resume reconnect task.")
                mUIHandler.sendEmptyMessage(MSG_PROCESS_TASK)
            }
        }
    }

    /**
     * 重连任务参数模型类
     *
     * 封装待回连设备的原 MAC 地址、新广播格式标识以及实际建立连接的 MAC 地址。
     *
     * @property deviceAddress 目标设备的原始蓝牙 MAC 地址
     * @property isUseNewADV 是否采用新版 OTA 广播格式解析
     */
    class ReconnectParam(val deviceAddress: String, val isUseNewADV: Boolean) {
        /** 实际用于建立连接的目标 MAC 地址（OTA 升级后可能发生地址变更） */
        var connectAddress: String? = null

        override fun equals(o: Any?): Boolean {
            if (this === o) return true
            if (o == null || javaClass != o.javaClass) return false
            val that = o as ReconnectParam
            return isUseNewADV == that.isUseNewADV && deviceAddress == that.deviceAddress
        }

        override fun hashCode(): Int {
            return Objects.hash(deviceAddress, isUseNewADV)
        }

        override fun toString(): String {
            return "ReconnectParam{" +
                    "deviceAddress='" + deviceAddress + '\'' +
                    ", isUseNewADV=" + isUseNewADV +
                    ", connectAddress='" + connectAddress + '\'' +
                    '}'
        }
    }

    companion object {
        /** 日志标签 */
        private val TAG = ReConnectHelper::class.java.simpleName

        /** 单个设备重连超时时间（取自 SDK，默认 65 秒） */
        private val RECONNECT_TIMEOUT = DeviceReConnectManager.RECONNECT_TIMEOUT // 65秒

        /** 单次 BLE 扫描超时时间（20 秒） */
        private const val SCAN_TIMEOUT = 20 * 1000L // 20秒

        /** 任务重试与失败延时（3 秒） */
        private const val FAILED_DELAY = 3 * 1000L

        /** 消息类型：重连整体超时 */
        private const val MSG_RECONNECT_TIMEOUT = 0x01

        /** 消息类型：处理重连任务调度 */
        private const val MSG_PROCESS_TASK = 0x02
    }

    init {
        // 构造初始化时向 BleManager 注册自身的回调监听
        mBtManager.registerBleEventCallback(bleEventCallback)
    }
}
