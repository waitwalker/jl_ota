package com.jieli.otasdk.tool.ota.spp

import android.bluetooth.BluetoothDevice
import android.bluetooth.BluetoothSocket
import android.content.Context
import com.jieli.jl_bt_ota.util.JL_Log
import com.jieli.otasdk.util.AppUtil
import java.io.IOException
import java.io.InputStream
import java.util.UUID

/**
 * 经典蓝牙 SPP 数据接收工作线程
 *
 * 持有已连接 [BluetoothSocket] 的输入流 [InputStream]，循环读取从远端设备发来的字节流，
 * 捕获流结束或 IO 异常，并将收到的数据切片回调给 [OnRecvSppDataListener]。
 *
 * @param context 上下文对象
 * @param mConnectedSppDev 目标已连接蓝牙物理设备
 * @param mSppUUID 对应的 SPP 通道服务 UUID
 * @param mBluetoothSocket 已建立连接的 Socket 实例
 * @param blockSize 单次读取缓冲区尺寸
 * @param mOnRecvSppDataListener 数据接收与线程状态监听器
 */
class ReceiveSppDataThread(
    context: Context,
    private val mConnectedSppDev: BluetoothDevice?,
    private val mSppUUID: UUID?,
    private val mBluetoothSocket: BluetoothSocket?,
    blockSize: Int,
    private val mOnRecvSppDataListener: OnRecvSppDataListener?,
) : Thread("ReceiveSppDataThread : $mConnectedSppDev") {
    /**
     * 使用默认缓冲区大小 [DEFAULT_BLOCK_SIZE] 的便捷构造函数
     */
    constructor(
        context: Context,
        device: BluetoothDevice?,
        sppUUID: UUID?,
        socket: BluetoothSocket?,
        listener: OnRecvSppDataListener?,
    ) : this(context, device, sppUUID, socket, DEFAULT_BLOCK_SIZE, listener)

    /** 应用程序 Application 上下文引用 */
    private val mContext: Context = context.applicationContext

    /** 接收缓冲区大小（字节） */
    private val mBlockSize: Int = if (blockSize > 0) blockSize else DEFAULT_BLOCK_SIZE

    /** 线程运行状态标志位 */
    @Volatile
    private var running = false

    /** Socket 绑定的输入流 */
    private var mInputStream: InputStream? = null

    /**
     * 获取绑定的 BluetoothSocket 实例
     *
     * @return [BluetoothSocket] 句柄
     */
    fun getBluetoothSocket(): BluetoothSocket? = mBluetoothSocket

    /**
     * 获取绑定的 SPP 通道服务 UUID
     *
     * @return [UUID] 实例
     */
    fun getSppUUID(): UUID? = mSppUUID

    /**
     * 停止接收线程并关闭输入流
     */
    fun stopThread() {
        JL_Log.i(TAG, "stopThread called.")
        running = false
        interrupt()
        closeInputStream()
    }

    /**
     * 查询接收线程当前是否处于运行状态
     *
     * @return true 表示正在接收数据
     */
    fun isRunning(): Boolean = running

    /**
     * 线程主循环逻辑
     */
    override fun run() {
        JL_Log.i(TAG, "ReceiveDataThread start.")
        running = true
        var exitReason = EXIT_REASON_SUCCESS
        val threadId = AppUtil.threadId(this)
        if (mOnRecvSppDataListener != null) {
            mOnRecvSppDataListener.onThreadStart(threadId)
        }
        if (!isValidParams()) {
            exitReason = EXIT_REASON_PARAM_ERROR
            notifyThreadStop(threadId, exitReason)
            return
        }
        exitReason = receiveDataLoop(threadId)
        cleanup()
        notifyThreadStop(threadId, exitReason)
        JL_Log.i(TAG, "ReceiveDataThread exit with reason: $exitReason")
    }

    /**
     * 校验前置连接参数与权限有效性
     *
     * @return true 表示参数完全有效
     */
    private fun isValidParams(): Boolean {
        if (mConnectedSppDev == null) {
            JL_Log.e(TAG, "Connected device is null")
            return false
        }
        if (!AppUtil.checkHasConnectPermission(mContext)) {
            JL_Log.e(TAG, "Missing Bluetooth connect permission")
            return false
        }
        if (mBluetoothSocket == null) {
            JL_Log.e(TAG, "Bluetooth socket is null")
            return false
        }
        return true
    }

    /**
     * 数据接收循环体，持续从 InputStream 中读取字节
     *
     * @param threadId 当前线程 ID
     * @return 线程退出的原因状态码
     */
    private fun receiveDataLoop(threadId: Long): Int {
        var exitReason = EXIT_REASON_SUCCESS
        try {
            mInputStream = mBluetoothSocket!!.inputStream
            if (mInputStream == null) {
                JL_Log.e(TAG, "Failed to get input stream")
                return EXIT_REASON_IO_EXCEPTION
            }
            JL_Log.i(TAG, "Start receiving data, isRunning: $running")
            val buffer = ByteArray(mBlockSize)
            while (running && !isInterrupted) {
                try {
                    val bytesRead = mInputStream!!.read(buffer)
                    if (bytesRead > 0) {
                        val data = ByteArray(bytesRead)
                        System.arraycopy(buffer, 0, data, 0, bytesRead)
                        mOnRecvSppDataListener?.onRecvSppData(threadId, mConnectedSppDev, mSppUUID, data)
                    } else if (bytesRead == -1) {
                        JL_Log.i(TAG, "InputStream reached end of stream")
                        break
                    } else {
                        try {
                            Thread.sleep(READ_TIMEOUT_MS.toLong())
                        } catch (e: InterruptedException) {
                            JL_Log.i(TAG, "Sleep interrupted")
                            Thread.currentThread().interrupt()
                            break
                        }
                    }
                } catch (e: IOException) {
                    JL_Log.e(TAG, "IO exception while reading data", e.message)
                    exitReason = EXIT_REASON_IO_EXCEPTION
                    break
                }
            }
            if (isInterrupted) {
                JL_Log.i(TAG, "Thread was interrupted")
                if (exitReason == EXIT_REASON_SUCCESS) {
                    exitReason = EXIT_REASON_THREAD_INTERRUPTED
                }
            }
        } catch (e: IOException) {
            JL_Log.e(TAG, "Failed to open input stream", e.message)
            exitReason = EXIT_REASON_IO_EXCEPTION
        } catch (e: SecurityException) {
            JL_Log.e(TAG, "Security exception while accessing input stream", e.message)
            exitReason = EXIT_REASON_IO_EXCEPTION
        }
        return exitReason
    }

    /**
     * 清理资源并关闭流
     */
    private fun cleanup() {
        running = false
        closeInputStream()
    }

    /**
     * 安全关闭 Socket 输入流
     */
    private fun closeInputStream() {
        val inputStream = mInputStream ?: return
        try {
            inputStream.close()
            JL_Log.d(TAG, "Input stream closed")
        } catch (e: IOException) {
            JL_Log.e(TAG, "Error closing input stream", e.message)
        } finally {
            mInputStream = null
        }
    }

    /**
     * 通知外部监听器线程已停止运行
     *
     * @param threadId 线程 ID
     * @param exitReason 退出原因状态码
     */
    private fun notifyThreadStop(threadId: Long, exitReason: Int) {
        if (mOnRecvSppDataListener != null) {
            try {
                mOnRecvSppDataListener.onThreadStop(threadId, exitReason, mConnectedSppDev, mSppUUID)
            } catch (e: Exception) {
                JL_Log.e(TAG, "Error in onThreadStop callback", e.message)
            }
        }
    }

    /**
     * SPP 数据接收工作线程监听接口
     */
    interface OnRecvSppDataListener {
        /**
         * 接收线程启动运行回调
         *
         * @param threadID 线程 ID
         */
        fun onThreadStart(threadID: Long)

        /**
         * 接收到远端设备发送的数据回调
         *
         * @param threadID 线程 ID
         * @param device 来源蓝牙物理设备
         * @param sppUUID SPP 服务 UUID
         * @param data 接收到的原始字节数组
         */
        fun onRecvSppData(threadID: Long, device: BluetoothDevice?, sppUUID: UUID?, data: ByteArray?)

        /**
         * 接收线程停止退出回调
         *
         * @param threadID 线程 ID
         * @param reason 退出原因状态码
         * @param device 目标设备
         * @param sppUUID SPP 服务 UUID
         */
        fun onThreadStop(threadID: Long, reason: Int, device: BluetoothDevice?, sppUUID: UUID?)
    }

    companion object {
        /** 日志标识 TAG */
        private val TAG = ReceiveSppDataThread::class.java.simpleName

        /** 默认读取缓冲区大小 (4KB) */
        private const val DEFAULT_BLOCK_SIZE = 4096

        /** 轮询读取等待延时 (毫秒) */
        private const val READ_TIMEOUT_MS = 30

        /** 退出原因：正常完成或主动停止 */
        const val EXIT_REASON_SUCCESS = 0

        /** 退出原因：参数或权限错误 */
        const val EXIT_REASON_PARAM_ERROR = 1

        /** 退出原因：底层 IO 读写异常（通常为设备断开） */
        const val EXIT_REASON_IO_EXCEPTION = 2

        /** 退出原因：线程被外部中断 */
        const val EXIT_REASON_THREAD_INTERRUPTED = 3
    }
}
