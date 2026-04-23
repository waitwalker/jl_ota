package com.jieli.otasdk

import android.app.Activity
import com.jieli.jl_bt_ota.util.JL_Log
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.embedding.engine.plugins.FlutterPlugin
import io.flutter.embedding.engine.plugins.activity.ActivityAware
import io.flutter.embedding.engine.plugins.activity.ActivityPluginBinding
import io.flutter.plugin.common.BinaryMessenger
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import io.flutter.plugin.common.MethodChannel.MethodCallHandler
import io.flutter.plugin.common.MethodChannel.Result

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
class JlOtaPlugin : FlutterPlugin, ActivityAware{
  private var channel: MethodChannel? = null
  private var activity: Activity? = null
  private var blePlugin: BlePlugin? = null
  private var binaryMessenger: BinaryMessenger? = null

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
    initializeBlePlugin()
  }

  override fun onDetachedFromActivity() {
    blePlugin?.dispose()
    blePlugin = null
    activity = null
  }

  override fun onReattachedToActivityForConfigChanges(binding: ActivityPluginBinding) {
    this.activity = binding.activity
    initializeBlePlugin()
  }

  override fun onDetachedFromActivityForConfigChanges() {
    blePlugin?.dispose()
    blePlugin = null
    activity = null
  }


  private fun initializeBlePlugin() {
    if (activity != null && binaryMessenger != null) {
      try {
        if (activity is MainActivity) {
          blePlugin = BlePlugin(binaryMessenger!!, activity as MainActivity)
        }
      } catch (e: Exception) {
      }
    }
  }
}
