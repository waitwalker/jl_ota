package com.jieli.otasdk

import android.Manifest
import android.app.Activity
import android.content.pm.PackageManager
import androidx.core.content.ContextCompat
import androidx.lifecycle.LifecycleOwner
import com.jieli.jl_bt_ota.util.JL_Log
import io.flutter.embedding.engine.plugins.FlutterPlugin
import io.flutter.embedding.engine.plugins.activity.ActivityAware
import io.flutter.embedding.engine.plugins.activity.ActivityPluginBinding
import io.flutter.plugin.common.BinaryMessenger
import io.flutter.plugin.common.PluginRegistry

/**
 * 杰理 OTA 插件 Android 原生主入口类
 *
 * 实现了 [FlutterPlugin]、[ActivityAware] 与 [PluginRegistry.RequestPermissionsResultListener]，
 * 负责接入 Flutter Engine 生命周期和 Activity 绑定流程，
 * 集中管理 BLE 插件实例创建、全局运行时环境初始化以及动态权限申请与回调。
 */
class JlOtaPlugin : FlutterPlugin, ActivityAware, PluginRegistry.RequestPermissionsResultListener {

    companion object {
        /** 日志标识 TAG */
        private const val TAG = "JlOtaPlugin"

        /** 动态权限请求识别码 */
        private const val PERMISSION_REQUEST_CODE = 1002
    }

    /** 当前绑定的宿主 Activity 实例 */
    private var activity: Activity? = null

    /** BLE 业务通道插件管理类实例 */
    private var blePlugin: BlePlugin? = null

    /** Flutter 二进制通信信使 */
    private var binaryMessenger: BinaryMessenger? = null

    /** Activity 插件绑定上下文，用于注册和注销权限回调监听 */
    private var activityBinding: ActivityPluginBinding? = null

    /** 动态权限申请结果的回调闭包 */
    private var permissionCallback: ((Boolean) -> Unit)? = null

    /**
     * Flutter Engine 引擎绑定回调
     *
     * 获取 BinaryMessenger 并初始化全局 [OtaRuntime]
     *
     * @param flutterPluginBinding 插件绑定上下文
     */
    override fun onAttachedToEngine(flutterPluginBinding: FlutterPlugin.FlutterPluginBinding) {
        this.binaryMessenger = flutterPluginBinding.binaryMessenger
        try {
            OtaRuntime.init(flutterPluginBinding.applicationContext)
        } catch (e: Exception) {
            JL_Log.e(TAG, "Failed to initialize OtaRuntime", e.toString())
        }
    }

    /**
     * Flutter Engine 引擎解绑回调
     *
     * 释放 BLE 插件资源并置空引用
     *
     * @param binding 插件绑定上下文
     */
    override fun onDetachedFromEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        blePlugin?.dispose()
        blePlugin = null
        binaryMessenger = null
    }

    /**
     * Activity 附加绑定回调
     *
     * 保存 Activity 引用、注册权限结果监听器并初始化 [BlePlugin]
     *
     * @param binding Activity 绑定上下文
     */
    override fun onAttachedToActivity(binding: ActivityPluginBinding) {
        this.activity = binding.activity
        this.activityBinding = binding
        binding.addRequestPermissionsResultListener(this)
        initializeBlePlugin()
    }

    /**
     * Activity 分离解绑回调
     *
     * 注销权限监听、释放 [BlePlugin] 并清空引用
     */
    override fun onDetachedFromActivity() {
        activityBinding?.removeRequestPermissionsResultListener(this)
        blePlugin?.dispose()
        blePlugin = null
        activity = null
        activityBinding = null
    }

    /**
     * Activity 因配置变更（如屏幕旋转）重新附加时的回调
     *
     * @param binding Activity 绑定上下文
     */
    override fun onReattachedToActivityForConfigChanges(binding: ActivityPluginBinding) {
        this.activity = binding.activity
        this.activityBinding = binding
        binding.addRequestPermissionsResultListener(this)
        initializeBlePlugin()
    }

    /**
     * Activity 因配置变更临时分离时的回调
     */
    override fun onDetachedFromActivityForConfigChanges() {
        activityBinding?.removeRequestPermissionsResultListener(this)
        blePlugin?.dispose()
        blePlugin = null
        activity = null
        activityBinding = null
    }

    /**
     * 初始化 BLE 通道插件实例
     *
     * 依赖当前有效的 Activity 和 BinaryMessenger，若缺失则跳过
     */
    private fun initializeBlePlugin() {
        val act = activity
        val messenger = binaryMessenger
        if (act == null || messenger == null) {
            JL_Log.w(TAG, "Cannot initialize BlePlugin: missing activity or messenger")
            return
        }
        try {
            blePlugin = BlePlugin(
                binaryMessenger = messenger,
                activity = act,
                plugin = this,
                lifecycleOwner = act as? LifecycleOwner
            )
            JL_Log.d(TAG, "BlePlugin initialized successfully")
        } catch (e: Exception) {
            JL_Log.e(TAG, "Failed to initialize BLE plugin", e.toString())
        }
    }

    /**
     * 动态申请缺失的权限
     *
     * 首先检查列表中的权限是否均已获得；若已全部授权则立即触发成功回调，否则向系统发起权限请求弹窗。
     *
     * @param permissions 待申请的权限数组（如蓝牙扫描、连接或定位权限）
     * @param callback 权限申请结果回调（true 表示全部满足）
     */
    fun requestMissingPermissions(permissions: Array<String>, callback: (Boolean) -> Unit) {
        val act = activity ?: return
        val allGranted = permissions.all { permission ->
            ContextCompat.checkSelfPermission(act, permission) == PackageManager.PERMISSION_GRANTED
        }
        if (allGranted) {
            callback(true)
            return
        }
        permissionCallback = callback
        act.requestPermissions(permissions, PERMISSION_REQUEST_CODE)
    }

    /**
     * 权限请求结果系统回调
     *
     * @param requestCode 请求识别码
     * @param permissions 申请的权限列表
     * @param grantResults 各权限授权结果数组
     * @return true 表示已拦截处理该权限结果
     */
    override fun onRequestPermissionsResult(
        requestCode: Int,
        permissions: Array<out String>,
        grantResults: IntArray
    ): Boolean {
        when (requestCode) {
            PERMISSION_REQUEST_CODE -> {
                permissionCallback?.invoke(isPermissionRequestSatisfied(permissions, grantResults))
                permissionCallback = null
                return true
            }
        }
        return false
    }

    /**
     * 校验权限申请结果是否满足要求
     *
     * 对定位权限做兼容判断（精确定位与模糊定位任一授权均可），
     * 其他权限（如蓝牙扫描、连接）必须全部获得授权。
     *
     * @param permissions 请求的权限列表
     * @param grantResults 授权结果数组
     * @return true 表示权限要求已满足
     */
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
}
