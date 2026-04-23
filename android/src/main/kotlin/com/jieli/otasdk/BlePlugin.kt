package com.jieli.otasdk

import com.jieli.jl_bt_ota.util.JL_Log
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.BinaryMessenger
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.MethodChannel

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
    private val activity: MainActivity
) {
    companion object {
        private const val METHOD_CHANNEL = "com.jieli.ble_plugin/methods"
        private const val EVENT_CHANNEL = "com.jieli.ble_plugin/events"
        private const val TAG = "BlePlugin"
    }

    private val methodChannel: MethodChannel by lazy {
        MethodChannel(binaryMessenger, METHOD_CHANNEL).apply {
            setMethodCallHandler(MethodChannelHandler(activity))
        }
    }

    private val eventChannel: EventChannel by lazy {
        EventChannel(binaryMessenger, EVENT_CHANNEL).apply {
            setStreamHandler(EventChannelHandler(activity))
        }
    }

    init {
        initializeChannels()
    }

    private fun initializeChannels() {
        try {
            // Channels are initialized lazily when first accessed
            methodChannel
            eventChannel
        } catch (e: Exception) {
            JL_Log.e(TAG, "Failed to initialize BLE channels", e.toString())
            // Consider adding error reporting here
        }
    }

    /**
     * Cleans up plugin resources.
     */
    fun dispose() {
        methodChannel.setMethodCallHandler(null)
        eventChannel.setStreamHandler(null)
    }
}