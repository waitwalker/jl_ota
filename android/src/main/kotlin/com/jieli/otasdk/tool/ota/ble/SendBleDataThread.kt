package com.jieli.otasdk.tool.ota.ble

import android.bluetooth.BluetoothGatt
import com.jieli.jl_bt_ota.util.JL_Log
import com.jieli.otasdk.tool.ota.ble.interfaces.IBleOp
import com.jieli.otasdk.tool.ota.ble.interfaces.OnThreadStateListener
import com.jieli.otasdk.tool.ota.ble.interfaces.OnWriteDataCallback
import com.jieli.otasdk.tool.ota.ble.model.BleSendTask
import java.util.UUID
import java.util.concurrent.LinkedBlockingQueue

/**
 * BLE 数据发送独立工作线程
 *
 * 维护数据发送阻塞队列 [LinkedBlockingQueue]，负责大包根据 MTU 自动分包切片、
 * 单包写入底层、等待系统写入回调 (ACK)、超时重试机制（最多重试 3 次）及多线程同步唤醒。
 *
 * @param mBleManager 写入底层操作接口 [IBleOp]
 * @param mListener 线程生命周期监听器 [OnThreadStateListener]
 */
class SendBleDataThread(
    private val mBleManager: IBleOp?,
    private val mListener: OnThreadStateListener?,
) : Thread(TAG) {
    /** 待发送任务阻塞队列 */
    private val mQueue = LinkedBlockingQueue<BleSendTask>()

    /** 线程是否处于运行工作状态标志位 */
    @Volatile
    private var isDataSend = false

    /** 线程当前是否处于队列为空的等待状态 */
    @Volatile
    private var isThreadWaiting = false

    /** 线程当前是否正在阻塞等待系统底层 onCharacteristicWrite 回调 */
    @Volatile
    private var isWaitingForCallback = false

    /** 当前数据分包连续发送失败已重试的次数 */
    @Volatile
    private var retryNum = 0

    /** 当前正在发送或等待 ACK 回调的任务 */
    private var mCurrentTask: BleSendTask? = null

    /**
     * 查询发送线程当前是否处于运行状态
     *
     * @return true 表示正在运行
     */
    fun isRunning(): Boolean = isDataSend

    /**
     * 向发送队列添加待发送的数据
     *
     * 内部依据底层 MTU 大小自动计算分包数量并做数组切片，保证每个切片均不超过 MTU 限制。
     *
     * @param gatt 目标 GATT 句柄
     * @param serviceUUID 目标服务 UUID
     * @param characteristicUUID 目标特征值 UUID
     * @param data 完整数据字节数组
     * @param callback 异步写入结果监听回调
     * @return true 表示数据全部切片并成功加入发送队列
     */
    fun addSendTask(
        gatt: BluetoothGatt?,
        serviceUUID: UUID?,
        characteristicUUID: UUID?,
        data: ByteArray?,
        callback: OnWriteDataCallback?,
    ): Boolean {
        if (mBleManager == null || gatt == null || serviceUUID == null || characteristicUUID == null || data == null || data.isEmpty()) {
            return false
        }
        val mtu = mBleManager.getBleMtu()
        JL_Log.d(TAG, "addSendTask : $mtu")
        val dataLen = data.size
        val blockCount = dataLen / mtu
        var ret = false
        for (i in 0 until blockCount) {
            val mBlockData = ByteArray(mtu)
            System.arraycopy(data, i * mtu, mBlockData, 0, mBlockData.size)
            ret = addSendData(gatt, serviceUUID, characteristicUUID, mBlockData, callback)
        }
        if (dataLen % mtu != 0) {
            val noBlockData = ByteArray(dataLen % mtu)
            System.arraycopy(data, dataLen - dataLen % mtu, noBlockData, 0, noBlockData.size)
            ret = addSendData(gatt, serviceUUID, characteristicUUID, noBlockData, callback)
        }
        return ret
    }

    /**
     * 唤醒发送线程
     *
     * 当外部收到底层 onCharacteristicWrite 回调（匹配当前任务 GATT + UUID）或因外部强制停止时唤醒等待中的线程。
     * 唤醒后用最新状态更新当前任务。
     *
     * @param sendTask 触发唤醒的最新任务实体，传 null 表示强制唤醒退出
     */
    fun wakeupSendThread(sendTask: BleSendTask?) {
        if (sendTask == null || (mCurrentTask != null && mCurrentTask == sendTask)) {
            if (sendTask != null) {
                sendTask.callback = mCurrentTask!!.callback
                mCurrentTask = sendTask
            }
            synchronized(mQueue) {
                if (isThreadWaiting) {
                    if (isWaitingForCallback) {
                        (mQueue as java.lang.Object).notifyAll()
                    } else {
                        (mQueue as java.lang.Object).notify()
                    }
                } else if (isWaitingForCallback) {
                    (mQueue as java.lang.Object).notify()
                }
            }
        }
    }

    /**
     * 将单个已完成分片的数据块封装为 [BleSendTask] 并放入任务队列
     *
     * @param gatt 目标 GATT 句柄
     * @param serviceUUID 目标服务 UUID
     * @param characteristicUUID 目标特征值 UUID
     * @param data 分片字节数组
     * @param callback 异步回调
     * @return true 表示成功入队
     */
    private fun addSendData(
        gatt: BluetoothGatt,
        serviceUUID: UUID,
        characteristicUUID: UUID,
        data: ByteArray,
        callback: OnWriteDataCallback?,
    ): Boolean {
        if (!isDataSend) {
            return false
        }
        val sendTask = BleSendTask(gatt, serviceUUID, characteristicUUID, data, callback)
        var ret = false
        try {
            mQueue.put(sendTask)
            ret = true
        } catch (e: InterruptedException) {
            Thread.currentThread().interrupt()
            e.printStackTrace()
        }
        if (ret && isThreadWaiting && !isWaitingForCallback) {
            isThreadWaiting = false
            synchronized(mQueue) {
                (mQueue as java.lang.Object).notify()
            }
        }
        return ret
    }

    /**
     * 标记运行状态并启动工作线程
     */
    @Synchronized
    override fun start() {
        isDataSend = true
        super.start()
    }

    /**
     * 停止数据发送线程并唤醒阻塞等待
     */
    @Synchronized
    fun stopThread() {
        isDataSend = false
        wakeupSendThread(null)
    }

    /**
     * 触发分发发送结果回调
     *
     * @param task 发送任务
     * @param result 发送是否成功
     */
    private fun callbackResult(task: BleSendTask?, result: Boolean) {
        val callback = task?.callback
        if (task != null && callback != null) {
            val gatt = task.bleGatt ?: return
            callback.onBleResult(gatt.device, task.serviceUUID, task.characteristicUUID, result, task.data)
        } else {
            JL_Log.i(TAG, "getCallback is null.")
        }
    }

    /**
     * 线程主循环逻辑
     *
     * 循环从阻塞队列中获取任务，调用底层接口写入，阻塞等待底层回调 ACK，
     * 若失败则在容错范围内自动重试，全部重试失败则通知外部错误并清理队列。
     */
    override fun run() {
        JL_Log.d(TAG, "send ble data thread is started.")
        if (mListener != null) {
            mListener.onStart(id, name)
        }
        val bleOp = mBleManager ?: return
        synchronized(mQueue) {
            while (isDataSend) {
                mCurrentTask = null
                isThreadWaiting = false
                isWaitingForCallback = false
                if (mQueue.isEmpty()) {
                    isThreadWaiting = true
                    JL_Log.d(TAG, "queue is empty, so waiting for data")
                    try {
                        (mQueue as java.lang.Object).wait()
                    } catch (e: InterruptedException) {
                        e.printStackTrace()
                    }
                } else {
                    mCurrentTask = mQueue.peek()
                    if (mCurrentTask != null) {
                        isWaitingForCallback = bleOp.writeDataByBle(
                            mCurrentTask!!.bleGatt,
                            mCurrentTask!!.serviceUUID,
                            mCurrentTask!!.characteristicUUID,
                            mCurrentTask!!.data,
                        )
                        if (isWaitingForCallback) {
                            try {
                                (mQueue as java.lang.Object).wait(BleManager.SEND_DATA_MAX_TIMEOUT.toLong())
                            } catch (e: InterruptedException) {
                                e.printStackTrace()
                            }
                        } else {
                            mCurrentTask!!.status = -1
                        }
                        // wait 返回后 mCurrentTask 可能已被 wakeup 换成带回调和状态的新任务，必须重新读取。
                        JL_Log.d(TAG, "data send ret :" + mCurrentTask!!.status)
                        if (mCurrentTask!!.status != BluetoothGatt.GATT_SUCCESS) {
                            retryNum++
                            if (retryNum >= 3) {
                                callbackResult(mCurrentTask, false)
                                mQueue.clear()
                            } else {
                                if (mCurrentTask!!.status != -1) {
                                    mCurrentTask!!.status = -1
                                    try {
                                        Thread.sleep(10)
                                    } catch (e: InterruptedException) {
                                        e.printStackTrace()
                                    }
                                }
                                continue
                            }
                        } else {
                            callbackResult(mCurrentTask, true)
                        }
                    }
                    retryNum = 0
                    if (mQueue.isNotEmpty()) {
                        mQueue.poll()
                    }
                }
            }
        }
        isWaitingForCallback = false
        isThreadWaiting = false
        mQueue.clear()
        if (mListener != null) {
            mListener.onEnd(id, name)
        }
        JL_Log.d(TAG, "send ble data thread exit.")
    }

    companion object {
        /** 日志标识 TAG */
        private const val TAG = "SendBleDataThread"
    }
}
