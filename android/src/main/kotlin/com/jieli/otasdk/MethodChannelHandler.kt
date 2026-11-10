package com.jieli.otasdk

import android.Manifest
import android.app.Activity
import android.bluetooth.BluetoothDevice
import android.os.Build
import androidx.lifecycle.DefaultLifecycleObserver
import androidx.lifecycle.LifecycleOwner
import com.jieli.otasdk.data.constant.MethodChannelConstants
import com.jieli.otasdk.data.constant.OtaConstant
import com.jieli.otasdk.model.ota.OTAViewModel
import com.jieli.otasdk.tool.config.ConfigHelper
import com.jieli.jl_bt_ota.constant.BluetoothConstant
import com.jieli.jl_bt_ota.constant.JL_Constant
import com.jieli.otasdk.model.connect.ConnectViewModel
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import java.lang.ref.WeakReference

/**
 * Flutter MethodChannel 调用分发处理器
 *
 * 负责接收并响应 Flutter 侧通过 MethodChannel 发送的方法调用，
 * 并将其路由分发至蓝牙连接管理器 ([ConnectViewModel])、配置助手 ([ConfigHelper]) 或 OTA 升级管理器 ([OTAViewModel])。
 * 同时实现 [DefaultLifecycleObserver] 以便在宿主生命周期销毁时自动释放资源。
 *
 * @param activity 当前宿主绑定的 Android [Activity]
 * @param plugin 当前关联的 Flutter 插件实例 [JlOtaPlugin]，用于发起权限申请等交互
 * @param lifecycleOwner 宿主生命周期拥有者（通常为 [Activity]），用于自动感知并绑定生命周期
 */
class MethodChannelHandler(
    activity: Activity,
    private val plugin: JlOtaPlugin,
    private val lifecycleOwner: LifecycleOwner?
) : MethodChannel.MethodCallHandler, DefaultLifecycleObserver {

    /** 持有当前宿主 Activity 的弱引用，防止因长时间持有导致内存泄漏 */
    private val activityRef = WeakReference(activity)

    /** 蓝牙连接与扫描业务模型单例，负责处理设备扫描、连接、断开等蓝牙核心逻辑 */
    private val connectVM by lazy { ConnectViewModel.getInstance() }

    /** 插件全局配置助手单例，负责管理通信方式、设备认证、MTU、HID 等参数配置 */
    private val configHelper by lazy { ConfigHelper.getInstance() }

    /** OTA 升级业务模型引用，在首次调用 OTA 相关方法时按需获取并缓存 */
    private var otaViewModel: OTAViewModel? = null

    /** 动态权限申请结果的异步回调闭包，在权限授权完成后触发后续扫描或流程 */
    private var permissionCallback: ((Boolean) -> Unit)? = null

    init {
        lifecycleOwner?.lifecycle?.addObserver(this)
    }

    /**
     * Flutter MethodChannel 方法调用分发入口
     *
     * @param call Flutter 传递的方法调用对象，包含方法名 [MethodCall.method] 与参数 [MethodCall.arguments]
     * @param result 用于向 Flutter 异步返回执行成功或错误信息的回调接口
     */
    override fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
        if (call.method == MethodChannelConstants.METHOD_SET_LOG_ENABLED) {
            val enabled = call.argument<Boolean>(MethodChannelConstants.ARG_ENABLED) ?: false
            OtaRuntime.setLogEnabled(OtaRuntime.getContext(), enabled)
            result.success(true)
            return
        }

        val activity = activityRef.get()
        if (activity == null) {
            result.error("ACTIVITY_NULL", "Activity is destroyed", null)
            return
        }

        when (call.method) {
            MethodChannelConstants.METHOD_IS_SCANNING -> result.success(connectVM.isScanning())
            MethodChannelConstants.METHOD_START_SCAN -> startScan(result)
            MethodChannelConstants.METHOD_STOP_SCAN -> stopScan(result)
            MethodChannelConstants.METHOD_GET_SCAN_FILTER -> result.success(connectVM.getScanFilter())
            MethodChannelConstants.METHOD_SET_SCAN_FILTER -> setScanFilter(call, result)
            MethodChannelConstants.METHOD_CONNECT_DEVICE -> connectDevice(call, result)
            MethodChannelConstants.METHOD_DISCONNECT_BT_DEVICE -> disconnectDevice(call, result)
            MethodChannelConstants.METHOD_GET_CONNECT_WAY -> result.success(configHelper.getConnectWay())
            MethodChannelConstants.METHOD_SET_CONNECT_WAY -> setConnectWay(call, result)
            MethodChannelConstants.METHOD_IS_USE_DEVICE_AUTH -> result.success(configHelper.isUseDeviceAuth())
            MethodChannelConstants.METHOD_SET_USE_DEVICE_AUTH -> setUseDeviceAuth(call, result)
            MethodChannelConstants.METHOD_IS_HID_DEVICE -> result.success(configHelper.isHidDevice())
            MethodChannelConstants.METHOD_SET_HID_DEVICE -> setHidDevice(call, result)
            MethodChannelConstants.METHOD_IS_USE_CUSTOM_RECONNECT_WAY -> result.success(configHelper.isUseCustomReConnectWay())
            MethodChannelConstants.METHOD_SET_USE_CUSTOM_RECONNECT_WAY -> setUseCustomReConnectWay(call, result)
            MethodChannelConstants.METHOD_GET_BLE_REQUEST_MTU -> result.success(configHelper.getBleRequestMtu())
            MethodChannelConstants.METHOD_SET_BLE_REQUEST_MTU -> setBleRequestMtu(call, result)
            MethodChannelConstants.METHOD_GET_SDK_VERSION -> result.success(getSdkVersion())
            MethodChannelConstants.METHOD_TYPE_IS_OTA -> isOTa(result)
            MethodChannelConstants.METHOD_START_OTA -> startOTA(call, result)
            else -> result.notImplemented()
        }
    }

    /**
     * 生命周期销毁回调，当绑定的宿主 [LifecycleOwner] 销毁时自动执行资源清理
     *
     * @param owner 宿主生命周期所有者
     */
    override fun onDestroy(owner: LifecycleOwner) {
        cleanup()
        lifecycleOwner?.lifecycle?.removeObserver(this)
    }

    /**
     * 释放并清理所有持有的资源
     *
     * 重置权限回调引用、清空 ViewModel 引用，并停止正在进行的蓝牙扫描与扫描列表缓存
     */
    fun cleanup() {
        permissionCallback = null
        otaViewModel = null

        if (connectVM.isScanning()) {
            connectVM.stopScan()
            connectVM.clearScanDeviceList()
        }
        connectVM.cleanUp()
    }

    /**
     * 发起蓝牙设备扫描
     *
     * 依次校验蓝牙与位置权限、系统蓝牙开关以及系统定位服务开关：
     * 1. 若权限缺失，自动调用 [requestMissingPermissions] 进行动态申请；
     * 2. 若蓝牙未开启或定位服务未开启，引导跳转系统设置页面并向 Flutter 报错；
     * 3. 环境完全满足后，启动底层扫描。
     *
     * @param result 向 Flutter 返回操作结果
     */
    private fun startScan(result: MethodChannel.Result) {
        val activity = activityRef.get()
        if (activity == null) {
            result.error("ACTIVITY_NULL", "Activity is destroyed", null)
            return
        }

        val checkResult = BluetoothEnvironmentChecker.checkBluetoothEnvironment(activity)

        if (!checkResult.hasBluetoothPermission || !checkResult.hasLocationPermission) {
            requestMissingPermissions(checkResult, result)
            return
        }

        if (!checkResult.isBluetoothEnabled) {
            BluetoothEnvironmentChecker.openBluetoothSettings(activity)
            result.error("BLUETOOTH_DISABLED", "Bluetooth is disabled", null)
            return
        }

        if (!checkResult.isLocationServiceEnabled) {
            BluetoothEnvironmentChecker.openLocationSettings(activity)
            result.error("LOCATION_SERVICE_DISABLED", "Location service is disabled", null)
            return
        }

        connectVM.startScan()
        result.success(true)
    }

    /**
     * 针对缺失的权限进行动态申请
     *
     * 根据 Android 系统版本分别请求不同权限：
     * - Android 12 (API 31) 及以上：申请 [Manifest.permission.BLUETOOTH_SCAN] 与 [Manifest.permission.BLUETOOTH_CONNECT]；
     * - Android 12 以下：申请 [Manifest.permission.ACCESS_FINE_LOCATION] 与 [Manifest.permission.ACCESS_COARSE_LOCATION]；
     * 权限全部授予后自动触发扫描并向 Flutter 回调成功。
     *
     * @param checkResult 蓝牙环境检查结果，包含各权限具备状态
     * @param result Flutter 返回结果回调
     */
    private fun requestMissingPermissions(
        checkResult: BluetoothEnvironmentChecker.CheckResult,
        result: MethodChannel.Result
    ) {
        val activity = activityRef.get()
        if (activity == null) {
            result.error("ACTIVITY_NULL", "Activity is destroyed", null)
            return
        }

        val permissionsToRequest = mutableListOf<String>()

        if (!checkResult.hasBluetoothPermission && Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
            permissionsToRequest.add(Manifest.permission.BLUETOOTH_SCAN)
            permissionsToRequest.add(Manifest.permission.BLUETOOTH_CONNECT)
        }

        if (!checkResult.hasLocationPermission && Build.VERSION.SDK_INT < Build.VERSION_CODES.S) {
            permissionsToRequest.add(Manifest.permission.ACCESS_FINE_LOCATION)
            permissionsToRequest.add(Manifest.permission.ACCESS_COARSE_LOCATION)
        }

        if (permissionsToRequest.isNotEmpty()) {
            permissionCallback = { granted ->
                if (granted) {
                    val newCheckResult = BluetoothEnvironmentChecker.checkBluetoothEnvironment(activity)
                    if (newCheckResult.isAllReady) {
                        connectVM.startScan()
                        result.success(true)
                    } else {
                        handleUnreadyEnvironment(newCheckResult, result)
                    }
                } else {
                    result.error("PERMISSION_DENIED", "Required permissions were denied", null)
                }
                permissionCallback = null
            }

            plugin.requestMissingPermissions(permissionsToRequest.toTypedArray()) { granted ->
                permissionCallback?.invoke(granted)
            }
        } else {
            result.error("PERMISSION_CHECK_FAILED", "Permission check failed unexpectedly", null)
        }
    }

    /**
     * 处理蓝牙环境或定位开关未就绪的情况
     *
     * 打开对应系统设置页并向 Flutter 端返回明确的错误原因
     *
     * @param checkResult 检查结果
     * @param result Flutter 返回结果回调
     */
    private fun handleUnreadyEnvironment(
        checkResult: BluetoothEnvironmentChecker.CheckResult,
        result: MethodChannel.Result
    ) {
        val activity = activityRef.get() ?: return

        when {
            !checkResult.isBluetoothEnabled -> {
                BluetoothEnvironmentChecker.openBluetoothSettings(activity)
                result.error("BLUETOOTH_DISABLED", "Bluetooth is disabled", null)
            }
            !checkResult.isLocationServiceEnabled -> {
                BluetoothEnvironmentChecker.openLocationSettings(activity)
                result.error("LOCATION_SERVICE_DISABLED", "Location service is disabled", null)
            }
            else -> {
                result.error("UNKNOWN_ERROR", "Unknown environment check error", null)
            }
        }
    }

    /**
     * 停止当前的蓝牙设备扫描
     *
     * @param result 向 Flutter 返回执行成功
     */
    private fun stopScan(result: MethodChannel.Result) {
        connectVM.stopScan()
        result.success(true)
    }

    /**
     * 设置蓝牙扫描过滤规则
     *
     * @param call 包含过滤关键字参数 [MethodChannelConstants.ARG_FILTER]
     * @param result 向 Flutter 返回设置结果
     */
    private fun setScanFilter(call: MethodCall, result: MethodChannel.Result) {
        val filter = call.argument<String>(MethodChannelConstants.ARG_FILTER)
        connectVM.setScanFilter(filter)
        result.success(true)
    }

    /**
     * 连接指定的蓝牙设备
     *
     * 根据设备在扫描结果列表中的索引 [MethodChannelConstants.ARG_INDEX] 发起蓝牙连接
     *
     * @param call 包含设备列表索引参数
     * @param result 向 Flutter 返回连接触发结果；若索引越界或已连接则返回错误
     */
    private fun connectDevice(call: MethodCall, result: MethodChannel.Result) {
        val index = call.argument<Int>(MethodChannelConstants.ARG_INDEX) ?: -1
        if (index !in connectVM.scanDeviceList.indices) {
            result.error("INVALID_INDEX", "index=$index", null)
            return
        }
        if (connectVM.isConnected()) {
            result.error("ALREADY_CONNECTED", "Device is already connected", null)
            return
        }
        val scanDevice = connectVM.scanDeviceList[index]
        connectVM.connectBtDevice(scanDevice.device)
        result.success(true)
    }

    /**
     * 断开指定蓝牙设备的连接
     *
     * @param call 包含目标设备在已扫描列表中的索引参数 [MethodChannelConstants.ARG_INDEX]
     * @param result 向 Flutter 返回断开结果
     */
    private fun disconnectDevice(call: MethodCall, result: MethodChannel.Result) {
        val index = call.argument<Int>(MethodChannelConstants.ARG_INDEX) ?: -1

        if (index !in connectVM.scanDeviceList.indices) {
            result.error("INVALID_INDEX", "index=$index", null)
            return
        }

        val scanDevice = connectVM.scanDeviceList[index]
        connectVM.disconnectBtDevice(scanDevice.device)
        result.success(true)
    }

    /**
     * 设置蓝牙通信连接方式（如 BLE 方式或 SPP 方式）
     *
     * @param call 包含连接方式整型值参数 [MethodChannelConstants.ARG_CONNECT_WAY]
     * @param result 向 Flutter 返回设置结果
     */
    private fun setConnectWay(call: MethodCall, result: MethodChannel.Result) {
        val connectWay = call.argument<Int>(MethodChannelConstants.ARG_CONNECT_WAY)
        if (connectWay != null) {
            configHelper.setConnectWay(connectWay)
            result.success(true)
        } else {
            result.error("INVALID_ARGUMENT", "connectWay must not be null", null)
        }
    }

    /**
     * 设置连接设备时是否启用设备认证流程（RCSP 协议认证握手）
     *
     * @param call 包含布尔参数 [MethodChannelConstants.ARG_IS_AUTH]，默认为 true
     * @param result 向 Flutter 返回设置结果
     */
    private fun setUseDeviceAuth(call: MethodCall, result: MethodChannel.Result) {
        val isAuth = call.argument<Boolean>(MethodChannelConstants.ARG_IS_AUTH) ?: true
        configHelper.setUseDeviceAuth(isAuth)
        result.success(true)
    }

    /**
     * 设置当前目标设备是否为 HID 设备
     *
     * @param call 包含布尔参数 [MethodChannelConstants.ARG_IS_HID]，默认为 false
     * @param result 向 Flutter 返回设置结果
     */
    private fun setHidDevice(call: MethodCall, result: MethodChannel.Result) {
        val isHid = call.argument<Boolean>(MethodChannelConstants.ARG_IS_HID) ?: false
        configHelper.setHidDevice(isHid)
        result.success(true)
    }

    /**
     * 设置是否启用自定义设备回连方式
     *
     * @param call 包含布尔参数 [MethodChannelConstants.ARG_IS_CUSTOM]，默认为 false
     * @param result 向 Flutter 返回设置结果
     */
    private fun setUseCustomReConnectWay(call: MethodCall, result: MethodChannel.Result) {
        val isCustom = call.argument<Boolean>(MethodChannelConstants.ARG_IS_CUSTOM) ?: false
        configHelper.setUseCustomReConnectWay(isCustom)
        result.success(true)
    }

    /**
     * 设置 BLE 连接期望协商的 MTU 尺寸
     *
     * 自动通过 [formatBleMtu] 将传入值限制在底层有效范围（BLE_MTU_MIN ~ BLE_MTU_MAX）内
     *
     * @param call 包含期望请求的 MTU 大小参数 [MethodChannelConstants.ARG_MTU]
     * @param result 向 Flutter 返回设置结果
     */
    private fun setBleRequestMtu(call: MethodCall, result: MethodChannel.Result) {
        val mtu = call.argument<Int>(MethodChannelConstants.ARG_MTU) ?: BluetoothConstant.BLE_MTU_MAX
        val newMtu = formatBleMtu(mtu)
        configHelper.setBleRequestMtu(newMtu)
        result.success(true)
    }

    /**
     * 获取底层杰理 OTA AAR 库的版本信息
     *
     * @return 格式化后的版本号字符串，格式形如 "V1.11.0(11015)"
     */
    private fun getSdkVersion(): String {
        val libVersionName = JL_Constant.getLibVersionName()
        val libVersionCode = JL_Constant.getLibVersionCode()
        return OtaConstant.formatString("V%s(%d)", libVersionName, libVersionCode)
    }

    /**
     * 查询当前杰理设备是否正在执行 OTA 升级
     *
     * @param result 向 Flutter 返回是否正在 OTA 的布尔值
     */
    private fun isOTa(result: MethodChannel.Result) {
        result.success(requireOtaViewModel().isOTA())
    }

    /**
     * 获取或初始化 [OTAViewModel] 实例并缓存
     *
     * @return [OTAViewModel] 单例引用
     */
    private fun requireOtaViewModel(): OTAViewModel {
        val vm = otaViewModel ?: OTAViewModel.getInstance()
        otaViewModel = vm
        return vm
    }

    /**
     * 开始杰理设备固件 OTA 升级流程
     *
     * @param call 包含待升级固件文件绝对路径参数 [MethodChannelConstants.ARG_PATH]
     * @param result 向 Flutter 返回启动升级的结果
     */
    private fun startOTA(call: MethodCall, result: MethodChannel.Result) {
        val path = call.argument<String>(MethodChannelConstants.ARG_PATH)
        if (path != null) {
            requireOtaViewModel().startOTA(path)
            result.success(true)
        } else {
            result.error("INVALID_ARGUMENT", "path must not be null", null)
        }
    }

    /**
     * 校验并规范化 BLE 请求的 MTU 大小
     *
     * 确保 MTU 不低于 [BluetoothConstant.BLE_MTU_MIN] 且不高于 [BluetoothConstant.BLE_MTU_MAX]
     *
     * @param mtu 原始请求的 MTU 值
     * @return 规范化后的有效 MTU 值
     */
    private fun formatBleMtu(mtu: Int): Int {
        return when {
            mtu < BluetoothConstant.BLE_MTU_MIN -> BluetoothConstant.BLE_MTU_MIN
            mtu > BluetoothConstant.BLE_MTU_MAX -> BluetoothConstant.BLE_MTU_MAX
            else -> mtu
        }
    }
}
