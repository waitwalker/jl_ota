package com.jieli.otasdk.tool.bluetooth

import android.bluetooth.BluetoothDevice
import android.os.Handler
import android.os.Looper
import com.jieli.otasdk.tool.ota.ble.model.BleScanInfo
import java.util.*

/**
 * 蓝牙事件回调分发辅助管理类
 *
 * 维护已注册的 [OnBTEventCallback] 回调列表，并将底层收到的蓝牙事件切换至主线程安全地广播分发给所有观察者。
 */
class BTEventCbHelper : OnBTEventCallback() {
    /** 已注册的回调监听器集合 */
    private val callbacks = mutableListOf<OnBTEventCallback>()

    /** 主线程 Handler，用于将非主线程回调派发至主线程 */
    private val uiHandler = Handler(Looper.getMainLooper())

    /**
     * 注册蓝牙事件回调监听器
     *
     * @param callback 实现了 [OnBTEventCallback] 的观察者
     */
    fun registerCallback(callback: OnBTEventCallback) {
        if (callbacks.contains(callback)) return
        callbacks.add(callback)
    }

    /**
     * 注销已注册的蓝牙事件回调监听器
     *
     * @param callback 待移除的观察者实例
     */
    fun unregisterCallback(callback: OnBTEventCallback) {
        if (callbacks.isEmpty()) return
        callbacks.remove(callback)
    }

    /**
     * 释放所有回调资源并清空 Handler 消息队列
     */
    fun release() {
        callbacks.clear()
        uiHandler.removeCallbacksAndMessages(null)
    }

    /**
     * 分发蓝牙适配器开关状态变更事件
     *
     * @param bEnabled true 表示系统蓝牙已打开
     */
    override fun onAdapterChange(bEnabled: Boolean) {
        callbackEvent(object : CallbackImpl<OnBTEventCallback> {
            override fun onCallback(callback: OnBTEventCallback) {
                callback.onAdapterChange(bEnabled)
            }
        })
    }

    /**
     * 分发蓝牙扫描状态变更事件
     *
     * @param bStart true 为扫描开启，false 为扫描停止
     * @param scanType 扫描协议类型
     */
    override fun onDiscoveryChange(bStart: Boolean, scanType: Int) {
        callbackEvent(object : CallbackImpl<OnBTEventCallback> {
            override fun onCallback(callback: OnBTEventCallback) {
                callback.onDiscoveryChange(bStart, scanType)
            }
        })
    }

    /**
     * 分发扫描发现设备事件
     *
     * @param device 扫描到的蓝牙设备
     * @param bleScanMessage 广播信息包装实体
     */
    override fun onDiscovery(device: BluetoothDevice?, bleScanMessage: BleScanInfo?) {
        callbackEvent(object : CallbackImpl<OnBTEventCallback> {
            override fun onCallback(callback: OnBTEventCallback) {
                callback.onDiscovery(device, bleScanMessage)
            }
        })
    }

    /**
     * 分发设备连接状态变更事件
     *
     * @param device 连接状态变更的蓝牙设备
     * @param way 连接协议方式（BLE/SPP）
     * @param status 连接状态码
     */
    override fun onDeviceConnection(device: BluetoothDevice?, way: Int, status: Int) {
        callbackEvent(object : CallbackImpl<OnBTEventCallback> {
            override fun onCallback(callback: OnBTEventCallback) {
                callback.onDeviceConnection(device, way, status)
            }
        })
    }

    /**
     * 分发接收到设备原始数据事件
     *
     * @param device 来源设备
     * @param way 通信协议方式
     * @param uuid 特征值或服务 UUID
     * @param data 接收到的原始字节数据
     */
    override fun onReceiveData(device: BluetoothDevice?, way: Int, uuid: UUID?, data: ByteArray?) {
        callbackEvent(object : CallbackImpl<OnBTEventCallback> {
            override fun onCallback(callback: OnBTEventCallback) {
                callback.onReceiveData(device, way, uuid, data)
            }
        })
    }

    /**
     * 分发 BLE 数据传输 MTU 大小变更事件
     *
     * @param device 目标设备
     * @param mtu 协商后的 MTU 大小
     * @param status GATT 操作状态码
     */
    override fun onBleMtuChange(device: BluetoothDevice?, mtu: Int, status: Int) {
        callbackEvent(object : CallbackImpl<OnBTEventCallback> {
            override fun onCallback(callback: OnBTEventCallback) {
                callback.onBleMtuChange(device, mtu, status)
            }
        })
    }

    /**
     * 将具体的事件回调任务切换至主线程执行分发
     *
     * @param impl 具体的事件分发执行体
     */
    private fun callbackEvent(impl: CallbackImpl<OnBTEventCallback>?) {
        if (null == impl) return
        val runnable = CallbackRunnable(callbacks, impl)
        if (Thread.currentThread().id == Looper.getMainLooper().thread.id) {
            runnable.run()
        } else {
            uiHandler.post(runnable)
        }
    }

    /**
     * 通用回调单步执行接口
     */
    interface CallbackImpl<T> {
        /**
         * 执行具体的单个回调通知
         *
         * @param callback 目标监听器实例
         */
        fun onCallback(callback: T)
    }

    /**
     * 回调广播执行任务 Runnable
     *
     * 内部做列表快照防御性拷贝，避免遍历时并发修改异常
     */
    class CallbackRunnable<T>(
        private val callbacks: MutableList<T>,
        private val impl: CallbackImpl<T>?
    ) : Runnable {

        override fun run() {
            if (callbacks.isEmpty() || impl == null) return
            val temp = mutableListOf<T>()
            temp.addAll(callbacks)
            temp.forEach {
                impl.onCallback(it)
            }
        }
    }
}
