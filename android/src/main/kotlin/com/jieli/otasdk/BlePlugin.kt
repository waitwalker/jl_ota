package com.jieli.otasdk

import android.app.Activity
import androidx.lifecycle.LifecycleOwner
import com.jieli.jl_bt_ota.util.JL_Log
import io.flutter.plugin.common.BinaryMessenger
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.MethodChannel
import java.lang.ref.WeakReference

/**
 * BLE 插件核心实现类
 *
 * 负责管理与 Flutter 通信的 MethodChannel 和 EventChannel，
 * 封装通道的初始化、事件流注册、以及插件资源的销毁与释放。
 *
 * @param binaryMessenger Flutter 消息信使，用于建立通道连接
 * @param activity 当前宿主 Activity 实例
 * @param plugin JlOtaPlugin 宿主插件引用
 * @param lifecycleOwner 生命周期拥有者，用于监听宿主生命周期变化
 */
class BlePlugin(
    binaryMessenger: BinaryMessenger,
    activity: Activity,
    private val plugin: JlOtaPlugin,
    private val lifecycleOwner: LifecycleOwner?
) {
    companion object {
        /** MethodChannel 通道标识名称，用于 Flutter 与原生方法交互 */
        private const val METHOD_CHANNEL = "com.jieli.ble_plugin/methods"

        /** EventChannel 通道标识名称，用于原生向 Flutter 持续派发事件流 */
        private const val EVENT_CHANNEL = "com.jieli.ble_plugin/events"

        /** 日志标签 TAG */
        private const val TAG = "BlePlugin"
    }

    /** 宿主 Activity 的弱引用，避免引起内存泄漏 */
    private val activityRef = WeakReference(activity)

    /** Flutter BinaryMessenger 的弱引用，避免内存泄漏 */
    private val binaryMessengerRef = WeakReference(binaryMessenger)

    /** MethodChannel 请求分发处理器 */
    private var methodChannelHandler: MethodChannelHandler? = null

    /** EventChannel 事件流分发处理器 */
    private var eventChannelHandler: EventChannelHandler? = null

    /** MethodChannel 实例句柄 */
    private var methodChannel: MethodChannel? = null

    /** EventChannel 实例句柄 */
    private var eventChannel: EventChannel? = null

    /** 插件是否已被销毁释放的标志位 */
    @Volatile
    private var isDisposed = false

    /** 保证多线程初始化与销毁安全的互斥同步锁 */
    private val lock = Any()

    init {
        initializeChannels()
    }

    /**
     * 初始化 MethodChannel 与 EventChannel 通道
     *
     * 校验 Activity 和 BinaryMessenger 有效性，若宿主正处于销毁流程则跳过初始化。
     */
    private fun initializeChannels() {
        synchronized(lock) {
            if (isDisposed) {
                JL_Log.w(TAG, "Plugin is disposed, skipping initialization")
                return
            }

            try {
                val messenger = binaryMessengerRef.get()
                if (messenger == null) {
                    JL_Log.e(TAG, "BinaryMessenger is null, cannot initialize channels")
                    return
                }

                val activity = activityRef.get()
                if (activity == null) {
                    JL_Log.e(TAG, "Activity is null, cannot initialize channels")
                    return
                }

                if (activity.isFinishing || activity.isDestroyed) {
                    JL_Log.w(TAG, "Activity is finishing or destroyed, skipping initialization")
                    return
                }

                initializeMethodChannel(messenger, activity)
                initializeEventChannel(messenger, activity)

                JL_Log.d(TAG, "BLE channels initialized successfully")
            } catch (e: Exception) {
                JL_Log.e(TAG, "Failed to initialize BLE channels", e.message)
            }
        }
    }

    /**
     * 初始化 Flutter MethodChannel
     *
     * 创建通道实例并设置 [MethodChannelHandler] 为方法调用接收器。
     *
     * @param messenger 用于创建通道的消息信使
     * @param activity 宿主 Activity
     */
    private fun initializeMethodChannel(messenger: BinaryMessenger, activity: Activity) {
        try {
            val channel = MethodChannel(messenger, METHOD_CHANNEL)
            val handler = MethodChannelHandler(activity, plugin, lifecycleOwner)

            channel.setMethodCallHandler(handler)

            methodChannel = channel
            methodChannelHandler = handler

            JL_Log.d(TAG, "MethodChannel initialized: $METHOD_CHANNEL")
        } catch (e: Exception) {
            JL_Log.e(TAG, "Failed to initialize MethodChannel", e.message)
            throw e
        }
    }

    /**
     * 初始化 Flutter EventChannel
     *
     * 创建通道实例并设置 [EventChannelHandler] 为事件流数据源。
     *
     * @param messenger 用于创建通道的消息信使
     * @param activity 宿主 Activity
     */
    private fun initializeEventChannel(messenger: BinaryMessenger, activity: Activity) {
        try {
            val channel = EventChannel(messenger, EVENT_CHANNEL)
            val handler = EventChannelHandler(activity)

            channel.setStreamHandler(handler)

            eventChannel = channel
            eventChannelHandler = handler

            JL_Log.d(TAG, "EventChannel initialized: $EVENT_CHANNEL")
        } catch (e: Exception) {
            JL_Log.e(TAG, "Failed to initialize EventChannel", e.message)
            throw e
        }
    }

    /**
     * 释放与清理插件全部通道及相关资源
     *
     * 注销 MethodChannel 与 EventChannel 回调、重置处理器并清空弱引用。
     * 应当在宿主引擎解绑或 Activity 销毁时调用。
     */
    fun dispose() {
        synchronized(lock) {
            if (isDisposed) {
                JL_Log.w(TAG, "Plugin already disposed, skipping")
                return
            }

            JL_Log.d(TAG, "Starting dispose")

            // 1. 释放并注销 MethodChannelHandler
            try {
                methodChannel?.setMethodCallHandler(null)
                methodChannelHandler?.cleanup()
                methodChannelHandler = null
                methodChannel = null
                JL_Log.d(TAG, "MethodChannel disposed")
            } catch (e: Exception) {
                JL_Log.e(TAG, "Error disposing MethodChannel", e.message)
            }

            // 2. 释放并注销 EventChannelHandler
            try {
                eventChannel?.setStreamHandler(null)
                eventChannelHandler = null
                eventChannel = null
                JL_Log.d(TAG, "EventChannel disposed")
            } catch (e: Exception) {
                JL_Log.e(TAG, "Error disposing EventChannel", e.message)
            }

            // 3. 清除弱引用缓存
            activityRef.clear()
            binaryMessengerRef.clear()

            isDisposed = true

            JL_Log.d(TAG, "Dispose completed")
        }
    }

    /**
     * 查询插件当前是否已被销毁释放
     *
     * @return true 表示已被释放，false 表示正常可用
     */
    fun isDisposed(): Boolean {
        return isDisposed
    }
}
