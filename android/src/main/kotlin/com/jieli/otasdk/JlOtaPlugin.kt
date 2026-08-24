package com.jieli.otasdk

import android.Manifest
import android.app.Activity
import android.content.Intent
import android.content.pm.PackageManager
import android.net.Uri
import android.os.Handler
import android.os.Looper
import com.jieli.jl_bt_ota.util.JL_Log
import com.jieli.otasdk.util.StoragePermissionHelper
import io.flutter.embedding.engine.plugins.FlutterPlugin
import io.flutter.embedding.engine.plugins.activity.ActivityAware
import io.flutter.embedding.engine.plugins.activity.ActivityPluginBinding
import io.flutter.plugin.common.BinaryMessenger
import io.flutter.plugin.common.MethodChannel
import io.flutter.plugin.common.PluginRegistry

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
class JlOtaPlugin : FlutterPlugin, ActivityAware, PluginRegistry.ActivityResultListener,
    PluginRegistry.RequestPermissionsResultListener {

    companion object {
        private const val TAG = "JlOtaPlugin"
        private const val PICK_FILE_REQUEST_CODE = 1001
        private const val PERMISSION_REQUEST_CODE = 1002
        private const val INTENT_ACTION_GET_CONTENT = "android.intent.action.GET_CONTENT"
        private const val MIME_TYPE_OCTET_STREAM = "application/*"

        // 供 MethodChannelHandler 访问
        var selectedUri: Uri? = null
            internal set
    }

    private var channel: MethodChannel? = null
    private var activity: Activity? = null
    private var blePlugin: BlePlugin? = null
    private var binaryMessenger: BinaryMessenger? = null
    private var activityBinding: ActivityPluginBinding? = null

    // 权限相关
    val storagePermissionHelper: StoragePermissionHelper by lazy {
        StoragePermissionHelper(activity ?: throw IllegalStateException("Activity not attached"))
    }
    private var permissionCallback: ((Boolean) -> Unit)? = null

    override fun onAttachedToEngine(flutterPluginBinding: FlutterPlugin.FlutterPluginBinding) {
        this.binaryMessenger = flutterPluginBinding.binaryMessenger
        // 用 applicationContext 初始化 MyApplication 单例（如果宿主没有继承 MyApplication）
        try {
            MyApplication.initWith(flutterPluginBinding.applicationContext)
        } catch (e: Exception) {
            JL_Log.e(TAG, "Failed to initialize MyApplication", e.toString())
        }
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
        this.activityBinding = binding
        binding.addActivityResultListener(this)
        binding.addRequestPermissionsResultListener(this)
        initializeBlePlugin()
    }

    override fun onDetachedFromActivity() {
        activityBinding?.removeActivityResultListener(this)
        activityBinding?.removeRequestPermissionsResultListener(this)
        blePlugin?.dispose()
        blePlugin = null
        activity = null
        activityBinding = null
    }

    override fun onReattachedToActivityForConfigChanges(binding: ActivityPluginBinding) {
        this.activity = binding.activity
        this.activityBinding = binding
        binding.addActivityResultListener(this)
        binding.addRequestPermissionsResultListener(this)
        initializeBlePlugin()
    }

    override fun onDetachedFromActivityForConfigChanges() {
        activityBinding?.removeActivityResultListener(this)
        activityBinding?.removeRequestPermissionsResultListener(this)
        blePlugin?.dispose()
        blePlugin = null
        activity = null
        activityBinding = null
    }

    private fun initializeBlePlugin() {
        val act = activity
        val messenger = binaryMessenger
        if (act != null && messenger != null) {
            try {
                blePlugin = BlePlugin(messenger, act, this)
            } catch (e: Exception) {
                JL_Log.e(TAG, "Failed to initialize BLE plugin", e.toString())
            }
        }
    }

    // region 文件选择
    fun pickFile() {
        activity?.let { act ->
            Intent(INTENT_ACTION_GET_CONTENT).apply {
                type = MIME_TYPE_OCTET_STREAM
                addCategory(Intent.CATEGORY_OPENABLE)
            }.also { intent ->
                act.startActivityForResult(intent, PICK_FILE_REQUEST_CODE)
            }
        }
    }

    override fun onActivityResult(requestCode: Int, resultCode: Int, data: Intent?): Boolean {
        if (requestCode == PICK_FILE_REQUEST_CODE) {
            if (resultCode == Activity.RESULT_OK && data?.data != null) {
                data.data?.let { uri ->
                    selectedUri = uri
                    val fileName = com.jieli.jlFileTransfer.FileUtils.getFileName(activity, uri)
                    notifyFilePicked(fileName)
                }
            }
            return true
        }
        return false
    }

    private fun notifyFilePicked(fileName: String) {
        binaryMessenger?.let { messenger ->
            val methodChannel = MethodChannel(messenger, "com.jieli.ble_plugin/methods")
            methodChannel.invokeMethod(
                com.jieli.otasdk.data.constant.MethodChannelConstants.METHOD_ON_FILE_PICKED,
                mapOf(com.jieli.otasdk.data.constant.MethodChannelConstants.ARG_FILE_NAME to fileName)
            )
        }
    }
    // endregion

    // region 权限请求
    fun requestMissingPermissions(permissions: Array<String>, callback: (Boolean) -> Unit) {
        val act = activity ?: return
        // 检查是否已经拥有所有权限
        val allGranted = permissions.all { permission ->
            androidx.core.content.ContextCompat.checkSelfPermission(
                act, permission
            ) == android.content.pm.PackageManager.PERMISSION_GRANTED
        }
        if (allGranted) {
            callback(true)
            return
        }
        permissionCallback = callback
        act.requestPermissions(permissions, PERMISSION_REQUEST_CODE)
    }

    override fun onRequestPermissionsResult(
        requestCode: Int,
        permissions: Array<out String>,
        grantResults: IntArray
    ): Boolean {
        if (requestCode == PERMISSION_REQUEST_CODE) {
            permissionCallback?.invoke(isPermissionRequestSatisfied(permissions, grantResults))
            permissionCallback = null
            return true
        }
        return false
    }

    private fun isPermissionRequestSatisfied(
        permissions: Array<out String>,
        grantResults: IntArray
    ): Boolean {
        if (permissions.isEmpty() || permissions.size != grantResults.size) return false

        val grantMap = permissions.indices.associate { index -> permissions[index] to grantResults[index] }
        val locationRequested =
            grantMap.containsKey(Manifest.permission.ACCESS_FINE_LOCATION) ||
                grantMap.containsKey(Manifest.permission.ACCESS_COARSE_LOCATION)
        val locationGranted =
            !locationRequested ||
                grantMap[Manifest.permission.ACCESS_FINE_LOCATION] == PackageManager.PERMISSION_GRANTED ||
                grantMap[Manifest.permission.ACCESS_COARSE_LOCATION] == PackageManager.PERMISSION_GRANTED

        return locationGranted && grantMap.entries
            .filterNot {
                it.key == Manifest.permission.ACCESS_FINE_LOCATION ||
                        it.key == Manifest.permission.ACCESS_COARSE_LOCATION
            }
            .all { it.value == PackageManager.PERMISSION_GRANTED }
    }
    // endregion
}
