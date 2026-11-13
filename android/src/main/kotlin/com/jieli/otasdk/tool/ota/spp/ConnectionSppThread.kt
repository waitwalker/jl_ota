package com.jieli.otasdk.tool.ota.spp

import android.bluetooth.BluetoothDevice
import android.bluetooth.BluetoothSocket
import android.content.Context
import android.os.Build
import android.os.Handler
import android.os.Looper
import com.jieli.jl_bt_ota.util.BluetoothUtil
import com.jieli.jl_bt_ota.util.JL_Log
import com.jieli.otasdk.util.AppUtil
import java.util.UUID

/**
 * 经典蓝牙 SPP 连接专用工作线程
 *
 * 负责在独立后台线程执行 RFCOMM Socket 阻塞连接 ([BluetoothDevice.createRfcommSocketToServiceRecord] 及 [BluetoothSocket.connect])，
 * 连接建立成功或失败后将结果派发回主线程通知监听者。
 *
 * @param mContext 上下文对象
 * @param mDevice 目标蓝牙物理设备
 * @param mSppUUID 目标 SPP 通道服务 UUID
 * @param mListener 连接状态与结果监听器 [OnConnectSppListener]
 */
class ConnectionSppThread(
    private val mContext: Context?,
    private val mDevice: BluetoothDevice?,
    private val mSppUUID: UUID?,
    private val mListener: OnConnectSppListener?,
) : Thread("ConnectionSppThread") {
    /** 主线程 Handler，用于向主线程派发回调 */
    private val mHandler = Handler(Looper.getMainLooper())

    @Synchronized
    override fun run() {
        val threadId = AppUtil.threadId(this)
        onThreadStart(threadId)
        if (mDevice == null || !AppUtil.checkHasConnectPermission(mContext)) {
            onThreadStop(threadId, false, null, null, null)
            return
        }
        var ret = false
        var socket: BluetoothSocket? = null
        JL_Log.e(TAG, "-ConnectionSppThread- connect device : " + BluetoothUtil.printBtDeviceInfo(mContext, mDevice) + ", uuid = " + mSppUUID)
        try {
            socket = mDevice.createRfcommSocketToServiceRecord(mSppUUID)
            socket.connect()
            ret = true
        } catch (e: Exception) {
            e.printStackTrace()
            JL_Log.e(TAG, "-ConnectionSppThread- exception : " + e.message + ", uuid = " + mSppUUID)
        }
        if (ret && Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
            JL_Log.i(
                TAG,
                "-ConnectionSppThread- connect spp ok, recv max = " + socket!!.maxReceivePacketSize +
                    ", send max = " + socket.maxTransmitPacketSize,
            )
        }
        onThreadStop(threadId, ret, mDevice, mSppUUID, socket)
    }

    /**
     * 通知线程启动（派发回主线程）
     *
     * @param id 线程 ID
     */
    fun onThreadStart(id: Long) {
        if (mListener != null) {
            mHandler.post { mListener.onThreadStart(id) }
        }
    }

    /**
     * 通知线程停止并上报连接执行结果（派发回主线程）
     *
     * @param threadID 线程 ID
     * @param result 连接是否成功
     * @param device 目标设备
     * @param sppUUID SPP 服务 UUID
     * @param socket 建立成功的 BluetoothSocket 实例（失败则为 null）
     */
    fun onThreadStop(threadID: Long, result: Boolean, device: BluetoothDevice?, sppUUID: UUID?, socket: BluetoothSocket?) {
        if (mListener != null) {
            mHandler.post { mListener.onThreadStop(threadID, result, device, sppUUID, socket) }
        }
    }

    /**
     * SPP 连接工作线程生命周期与结果监听接口
     */
    interface OnConnectSppListener {
        /**
         * 连接线程启动运行回调
         *
         * @param threadID 线程 ID
         */
        fun onThreadStart(threadID: Long)

        /**
         * 连接线程结束退出回调
         *
         * @param threadID 线程 ID
         * @param result 是否连接成功
         * @param device 目标蓝牙物理设备
         * @param sppUUID SPP 服务 UUID
         * @param socket 建立的 Socket 连接句柄
         */
        fun onThreadStop(threadID: Long, result: Boolean, device: BluetoothDevice?, sppUUID: UUID?, socket: BluetoothSocket?)
    }

    companion object {
        /** 日志标识 TAG */
        private const val TAG = "ConnectionSppThread"
    }
}
