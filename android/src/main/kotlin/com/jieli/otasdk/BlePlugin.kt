package com.jieli.otasdk

import androidx.lifecycle.LifecycleOwner
import com.jieli.jl_bt_ota.util.JL_Log
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.BinaryMessenger
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.MethodChannel
import java.lang.ref.WeakReference

/**
 * Des:
 * author: lifang
 * date: 2025/07/18
 * Copyright: Jieli Technology
 * Modify date: 2025/07/22
 * Modified by: lifang
 */
class BlePlugin(
    binaryMessenger: BinaryMessenger,
    activity: MainActivity,
    private val lifecycleOwner: LifecycleOwner
) {
    companion object {
        private const val METHOD_CHANNEL = "com.jieli.ble_plugin/methods"
        private const val EVENT_CHANNEL = "com.jieli.ble_plugin/events"
        private const val TAG = "BlePlugin"
    }

    // Use WeakReference to avoid memory leaks
    private val activityRef = WeakReference(activity)
    private val binaryMessengerRef = WeakReference(binaryMessenger)

    private var methodChannelHandler: MethodChannelHandler? = null
    private var eventChannelHandler: EventChannelHandler? = null

    private var methodChannel: MethodChannel? = null
    private var eventChannel: EventChannel? = null

    // Flag to track if plugin has been disposed
    @Volatile
    private var isDisposed = false

    // Synchronization lock for thread safety
    private val lock = Any()

    init {
        initializeChannels()
    }

    /**
     * Initialize method and event channels
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
     * Initialize MethodChannel
     */
    private fun initializeMethodChannel(messenger: BinaryMessenger, activity: MainActivity) {
        try {
            val channel = MethodChannel(messenger, METHOD_CHANNEL)
            val handler = MethodChannelHandler(activity, lifecycleOwner)

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
     * Initialize EventChannel
     */
    private fun initializeEventChannel(messenger: BinaryMessenger, activity: MainActivity) {
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
     * Cleans up plugin resources
     * Should be called when the plugin is detached or no longer needed
     */
    fun dispose() {
        synchronized(lock) {
            if (isDisposed) {
                JL_Log.w(TAG, "Plugin already disposed, skipping")
                return
            }

            JL_Log.d(TAG, "Starting dispose")

            // 1. Dispose MethodChannelHandler
            try {
                methodChannel?.setMethodCallHandler(null)
                methodChannelHandler?.cleanup()
                methodChannelHandler = null
                methodChannel = null
                JL_Log.d(TAG, "MethodChannel disposed")
            } catch (e: Exception) {
                JL_Log.e(TAG, "Error disposing MethodChannel", e.message)
            }

            // 2. Dispose EventChannelHandler
            try {
                eventChannel?.setStreamHandler(null)
                eventChannelHandler = null
                eventChannel = null
                JL_Log.d(TAG, "EventChannel disposed")
            } catch (e: Exception) {
                JL_Log.e(TAG, "Error disposing EventChannel", e.message)
            }

            // 3. Clear references
            activityRef.clear()
            binaryMessengerRef.clear()

            isDisposed = true

            JL_Log.d(TAG, "Dispose completed")
        }
    }

    /**
     * Check if plugin has been disposed
     */
    fun isDisposed(): Boolean {
        return isDisposed
    }
}