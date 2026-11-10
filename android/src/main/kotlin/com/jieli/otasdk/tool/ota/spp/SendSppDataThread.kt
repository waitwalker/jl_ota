package com.jieli.otasdk.tool.ota.spp

import android.bluetooth.BluetoothDevice
import android.content.Context
import android.os.Handler
import android.os.Looper
import com.jieli.jl_bt_ota.util.CHexConver
import com.jieli.jl_bt_ota.util.JL_Log
import com.jieli.otasdk.tool.ota.spp.interfaces.OnWriteSppDataCallback
import com.jieli.otasdk.util.AppUtil
import java.io.IOException
import java.util.UUID
import java.util.concurrent.LinkedBlockingQueue

/**
 * 经典蓝牙 SPP 数据发送工作线程
 *
 * 维护待发送任务阻塞队列 [LinkedBlockingQueue]，单线程有序地将数据写入底层 Socket 输出流，
 * 并将写入结果切回主线程通知 [OnWriteSppDataCallback]。
 *
 * @param mContext 上下文对象
 * @param mSppOp 底层 SPP 写入操作接口 [ISppOp]
 * @param mListener 发送线程生命周期监听器 [OnSendDataListener]
 */
class SendSppDataThread(
    private val mContext: Context?,
    private val mSppOp: ISppOp?,
    private val mListener: OnSendDataListener?,
) : Thread() {
    /** 任务阻塞等待队列 */
    private val mQueue = LinkedBlockingQueue<SppSendTask>()

    /** 标志位：线程是否处于运行状态 */
    @Volatile
    private var isDataSend = false

    /** 标志位：队列是否为空且处于阻塞等待状态 */
    @Volatile
    private var isQueueEmpty = false

    /** 主线程 Handler，用于派发写入结果回调 */
    private val mHandler = Handler(Looper.getMainLooper())

    /**
     * 标记运行状态并启动发送线程
     */
    @Synchronized
    override fun start() {
        isDataSend = true
        super.start()
    }

    /**
     * 停止发送线程并唤醒阻塞等待
     */
    @Synchronized
    fun stopThread() {
        isDataSend = false
        wakeupThread()
    }

    /**
     * 向发送队列添加待发送的任务
     *
     * @param task 封装的待发送任务实体 [SppSendTask]
     */
    fun addSendTask(task: SppSendTask) {
        if (!isDataSend) return
        var ret = false
        try {
            mQueue.put(task)
            ret = true
        } catch (e: InterruptedException) {
            e.printStackTrace()
        }
        if (ret && isQueueEmpty) {
            isQueueEmpty = false
            synchronized(mQueue) {
                (mQueue as java.lang.Object).notifyAll()
            }
        }
    }

    /**
     * 唤醒因队列空闲而阻塞的线程
     */
    private fun wakeupThread() {
        synchronized(mQueue) {
            if (isQueueEmpty) {
                (mQueue as java.lang.Object).notifyAll()
            }
        }
    }

    /**
     * 线程执行主循环
     */
    override fun run() {
        val threadId = id
        if (mListener != null) {
            mHandler.post { mListener.onThreadStart(threadId) }
        }
        if (mSppOp == null || !AppUtil.checkHasConnectPermission(mContext)) {
            if (mListener != null) {
                mHandler.post { mListener.onThreadStop(threadId) }
            }
            return
        }
        val sppOp = mSppOp
        synchronized(mQueue) {
            while (isDataSend) {
                isQueueEmpty = mQueue.isEmpty()
                if (isQueueEmpty) {
                    JL_Log.d(TAG, "queue is empty, so waiting for data")
                    try {
                        (mQueue as java.lang.Object).wait()
                    } catch (e: InterruptedException) {
                        e.printStackTrace()
                    }
                } else {
                    val currentTask = mQueue.poll()
                    if (currentTask != null) {
                        val ret: Boolean
                        try {
                            ret = sppOp.writeDataToSppDevice(currentTask.device, currentTask.sppUUID, currentTask.data)
                        } catch (e: IOException) {
                            e.printStackTrace()
                            isDataSend = false
                            break
                        }
                        mHandler.post {
                            currentTask.callback?.onSppResult(currentTask.device, currentTask.sppUUID, ret, currentTask.data)
                        }
                    }
                }
            }
        }
        mQueue.clear()
        if (mListener != null) {
            mHandler.post { mListener.onThreadStop(threadId) }
        }
    }

    /**
     * 底层 SPP 数据写入操作接口
     */
    fun interface ISppOp {
        /**
         * 实际向 SPP 设备 Socket 输出流写入数据
         *
         * @param device 目标蓝牙物理设备
         * @param sppUUID SPP 服务 UUID
         * @param data 待写入字节数组
         * @return true 表示成功写入流
         * @throws IOException 写入流发生异常
         */
        @Throws(IOException::class)
        fun writeDataToSppDevice(device: BluetoothDevice?, sppUUID: UUID?, data: ByteArray?): Boolean
    }

    /**
     * SPP 数据发送工作线程生命周期监听接口
     */
    interface OnSendDataListener {
        /**
         * 发送线程启动运行回调
         *
         * @param threadID 线程 ID
         */
        fun onThreadStart(threadID: Long)

        /**
         * 发送线程停止退出回调
         *
         * @param threadID 线程 ID
         */
        fun onThreadStop(threadID: Long)
    }

    /**
     * 单个 SPP 数据发送任务包装实体
     *
     * @property device 目标蓝牙物理设备
     * @property sppUUID 目标 SPP 服务 UUID
     * @property data 待发送的原始字节数组
     * @property callback 发送完成结果异步回调
     */
    class SppSendTask(
        var device: BluetoothDevice?,
        var sppUUID: UUID?,
        var data: ByteArray?,
        var callback: OnWriteSppDataCallback?,
    ) {
        override fun toString(): String {
            return "SppSendTask{" +
                "device=" + device +
                ", sppUUID=" + sppUUID +
                ", data=" + CHexConver.byte2HexStr(data) +
                ", callback=" + callback +
                '}'
        }
    }

    companion object {
        /** 日志标识 TAG */
        private const val TAG = "SendSppDataThread"
    }
}
