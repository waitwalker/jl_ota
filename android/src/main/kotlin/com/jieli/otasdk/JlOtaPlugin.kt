package com.jieli.otasdk

import android.app.Activity
import androidx.lifecycle.LifecycleOwner
import com.jieli.jl_bt_ota.util.JL_Log
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.embedding.engine.plugins.FlutterPlugin
import io.flutter.embedding.engine.plugins.activity.ActivityAware
import io.flutter.embedding.engine.plugins.activity.ActivityPluginBinding
import io.flutter.plugin.common.BinaryMessenger
import io.flutter.plugin.common.MethodChannel

/**
 * Des:Main plugin class for handling OTA (Over-The-Air) update functionality
 * Provides methods for scanning OTA files and managing WiFi connections
 * Integrates with BLE (Bluetooth Low Energy) for device communication
 * author: lifang
 * date: 2025/09/20
 * Copyright: Jieli Technology
 * Modify date:
 * Modified by:
 */
class JlOtaPlugin : FlutterPlugin, ActivityAware {
  private var channel: MethodChannel? = null
  private var activity: Activity? = null
  private var blePlugin: BlePlugin? = null
  private var binaryMessenger: BinaryMessenger? = null
  private var lifecycleOwner: LifecycleOwner? = null
  private val TAG = "JlOtaPlugin"

  override fun onAttachedToEngine(flutterPluginBinding: FlutterPlugin.FlutterPluginBinding) {
    this.binaryMessenger = flutterPluginBinding.binaryMessenger
  }

  override fun onDetachedFromEngine(binding: FlutterPlugin.FlutterPluginBinding) {
    blePlugin?.dispose()
    blePlugin = null
    binaryMessenger = null
    channel?.setMethodCallHandler(null)
    channel = null
  }

  override fun onAttachedToActivity(binding: ActivityPluginBinding) {
    this.activity = binding.activity
    this.lifecycleOwner = binding.activity as? LifecycleOwner
    initializeBlePlugin()
  }

  override fun onDetachedFromActivity() {
    blePlugin?.dispose()
    blePlugin = null
    activity = null
    lifecycleOwner = null
  }

  override fun onReattachedToActivityForConfigChanges(binding: ActivityPluginBinding) {
    this.activity = binding.activity
    this.lifecycleOwner = binding.activity as? LifecycleOwner
    initializeBlePlugin()
  }

  override fun onDetachedFromActivityForConfigChanges() {
    blePlugin?.dispose()
    blePlugin = null
    activity = null
    lifecycleOwner = null
  }

  private fun initializeBlePlugin() {
    when {
      !areDependenciesPresent() -> {
        JL_Log.w(TAG, "Cannot initialize BlePlugin: missing dependencies")
      }
      activity !is MainActivity -> {
        JL_Log.w(TAG, "Activity is not MainActivity, skipping BlePlugin initialization")
      }
      else -> {
        tryInitializeBlePlugin()
      }
    }
  }

  private fun areDependenciesPresent(): Boolean {
    return activity != null && binaryMessenger != null && lifecycleOwner != null
  }

  private fun tryInitializeBlePlugin() {
    try {
      val mainActivity = activity as MainActivity
      blePlugin = BlePlugin(
        binaryMessenger = requireNotNull(binaryMessenger),
        activity = mainActivity,
        lifecycleOwner = requireNotNull(lifecycleOwner)
      )
      JL_Log.d(TAG, "BlePlugin initialized successfully")
    } catch (e: Exception) {
      JL_Log.e(TAG, "Failed to initialize BlePlugin", e.message)
    }
  }
}