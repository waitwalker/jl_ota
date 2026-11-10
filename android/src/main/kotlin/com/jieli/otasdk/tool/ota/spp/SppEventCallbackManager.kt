package com.jieli.otasdk.tool.ota.spp

import android.bluetooth.BluetoothDevice
import android.os.Handler
import android.os.Looper
import com.jieli.otasdk.tool.ota.spp.interfaces.ISppEventCallback
import com.jieli.otasdk.tool.ota.spp.interfaces.SppEventCallback
import java.util.UUID

/**
 * 经典蓝牙 SPP 事件回调管理与广播分发类
 *
 * 维护已注册的 [SppEventCallback] 列表，将底层收到的 SPP 事件在主线程安全分发给所有观察者。
 */
class SppEventCallbackManager : ISppEventCallback {
    /** 观察者监听器列表集合 */
    private val mCallbacks = ArrayList<SppEventCallback>()

    /** 主线程 Handler */
    private val mHandler = Handler(Looper.getMainLooper())

    /**
     * 注册 SPP 事件监听回调
     *
     * @param callback 实现了 [SppEventCallback] 的观察者
     */
    fun registerSppEventCallback(callback: SppEventCallback?) {
        if (callback != null && !mCallbacks.contains(callback)) {
            mCallbacks.add(callback)
        }
    }

    /**
     * 注销 SPP 事件监听回调
     *
     * @param callback 待注销的观察者
     */
    fun unregisterSppEventCallback(callback: SppEventCallback?) {
        if (callback != null && mCallbacks.isNotEmpty()) {
            mCallbacks.remove(callback)
        }
    }

    /**
     * 释放所有回调资源并清理 Handler 消息
     */
    fun release() {
        mCallbacks.clear()
        mHandler.removeCallbacksAndMessages(null)
    }

    /**
     * 分发蓝牙开关变更事件
     *
     * @param enabled true 为蓝牙已开启
     */
    override fun onAdapterChange(enabled: Boolean) {
        callbackSppEvent { callback -> callback.onAdapterChange(enabled) }
    }

    /**
     * 分发经典蓝牙扫描启停状态事件
     *
     * @param started true 为扫描启动
     */
    override fun onDiscoveryDeviceChange(started: Boolean) {
        callbackSppEvent { callback -> callback.onDiscoveryDeviceChange(started) }
    }

    /**
     * 分发扫描发现设备事件
     *
     * @param device 扫描到的蓝牙设备
     * @param rssi 信号强度
     */
    override fun onDiscoveryDevice(device: BluetoothDevice?, rssi: Int) {
        callbackSppEvent { callback -> callback.onDiscoveryDevice(device, rssi) }
    }

    /**
     * 分发 SPP 连接状态变更事件
     *
     * @param device 目标设备
     * @param uuid SPP 通道服务 UUID
     * @param status 连接状态码
     */
    override fun onSppConnection(device: BluetoothDevice?, uuid: UUID?, status: Int) {
        callbackSppEvent { callback -> callback.onSppConnection(device, uuid, status) }
    }

    /**
     * 分发接收到 SPP 链路数据事件
     *
     * @param device 来源设备
     * @param uuid 关联的 SPP 服务 UUID
     * @param data 接收到的原始字节数组
     */
    override fun onReceiveSppData(device: BluetoothDevice?, uuid: UUID?, data: ByteArray?) {
        callbackSppEvent { callback -> callback.onReceiveSppData(device, uuid, data) }
    }

    /**
     * 将具体的事件回调派发至主线程执行
     *
     * @param impl 具体的事件执行体
     */
    private fun callbackSppEvent(impl: SppEventCallbackImpl?) {
        if (impl == null) return
        val runnable = OnSppEventRunnable(impl)
        if (Thread.currentThread().id == Looper.getMainLooper().thread.id) {
            runnable.run()
        } else {
            mHandler.post(runnable)
        }
    }

    /**
     * 单个 SPP 回调执行函数式接口
     */
    private fun interface SppEventCallbackImpl {
        fun onCallback(callback: SppEventCallback)
    }

    /**
     * 回调遍历广播任务 Runnable
     *
     * 做列表浅拷贝防御遍历，防止并发修改异常
     */
    private inner class OnSppEventRunnable(private val mImpl: SppEventCallbackImpl?) : Runnable {
        override fun run() {
            if (mCallbacks.isNotEmpty() && mImpl != null) {
                for (callback in ArrayList(mCallbacks)) {
                    mImpl.onCallback(callback)
                }
            }
        }
    }
}
