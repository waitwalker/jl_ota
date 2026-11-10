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
 * Des:
 * author: lifang
 * date: 2025/07/29
 * Copyright: Jieli Technology
 * Modify date:
 * Modified by:
 */
class MethodChannelHandler(
    activity: Activity,
    private val plugin: JlOtaPlugin,
    private val lifecycleOwner: LifecycleOwner?
) : MethodChannel.MethodCallHandler, DefaultLifecycleObserver {

    private val activityRef = WeakReference(activity)

    private val connectVM by lazy { ConnectViewModel.getInstance() }
    private val configHelper by lazy { ConfigHelper.getInstance() }

    private var otaViewModel: OTAViewModel? = null
    private var permissionCallback: ((Boolean) -> Unit)? = null

    init {
        lifecycleOwner?.lifecycle?.addObserver(this)
    }

    override fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
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

    override fun onDestroy(owner: LifecycleOwner) {
        cleanup()
        lifecycleOwner?.lifecycle?.removeObserver(this)
    }

    fun cleanup() {
        permissionCallback = null
        otaViewModel = null

        if (connectVM.isScanning()) {
            connectVM.stopScan()
            connectVM.clearScanDeviceList()
        }
        connectVM.cleanUp()
    }

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

    private fun stopScan(result: MethodChannel.Result) {
        connectVM.stopScan()
        result.success(true)
    }

    private fun setScanFilter(call: MethodCall, result: MethodChannel.Result) {
        val filter = call.argument<String>(MethodChannelConstants.ARG_FILTER)
        connectVM.setScanFilter(filter)
        result.success(true)
    }

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

    private fun setConnectWay(call: MethodCall, result: MethodChannel.Result) {
        val connectWay = call.argument<Int>(MethodChannelConstants.ARG_CONNECT_WAY)
        if (connectWay != null) {
            configHelper.setConnectWay(connectWay)
            result.success(true)
        } else {
            result.error("INVALID_ARGUMENT", "connectWay must not be null", null)
        }
    }

    private fun setUseDeviceAuth(call: MethodCall, result: MethodChannel.Result) {
        val isAuth = call.argument<Boolean>(MethodChannelConstants.ARG_IS_AUTH) ?: true
        configHelper.setUseDeviceAuth(isAuth)
        result.success(true)
    }

    private fun setHidDevice(call: MethodCall, result: MethodChannel.Result) {
        val isHid = call.argument<Boolean>(MethodChannelConstants.ARG_IS_HID) ?: false
        configHelper.setHidDevice(isHid)
        result.success(true)
    }

    private fun setUseCustomReConnectWay(call: MethodCall, result: MethodChannel.Result) {
        val isCustom = call.argument<Boolean>(MethodChannelConstants.ARG_IS_CUSTOM) ?: false
        configHelper.setUseCustomReConnectWay(isCustom)
        result.success(true)
    }

    private fun setBleRequestMtu(call: MethodCall, result: MethodChannel.Result) {
        val mtu = call.argument<Int>(MethodChannelConstants.ARG_MTU) ?: BluetoothConstant.BLE_MTU_MAX
        val newMtu = formatBleMtu(mtu)
        configHelper.setBleRequestMtu(newMtu)
        result.success(true)
    }

    private fun getSdkVersion(): String {
        val libVersionName = JL_Constant.getLibVersionName()
        val libVersionCode = JL_Constant.getLibVersionCode()
        return OtaConstant.formatString("V%s(%d)", libVersionName, libVersionCode)
    }

    private fun isOTa(result: MethodChannel.Result) {
        result.success(requireOtaViewModel().isOTA())
    }

    private fun requireOtaViewModel(): OTAViewModel {
        val vm = otaViewModel ?: OTAViewModel.getInstance()
        otaViewModel = vm
        return vm
    }

    private fun startOTA(call: MethodCall, result: MethodChannel.Result) {
        val path = call.argument<String>(MethodChannelConstants.ARG_PATH)
        if (path != null) {
            requireOtaViewModel().startOTA(path)
            result.success(true)
        } else {
            result.error("INVALID_ARGUMENT", "path must not be null", null)
        }
    }

    private fun formatBleMtu(mtu: Int): Int {
        return when {
            mtu < BluetoothConstant.BLE_MTU_MIN -> BluetoothConstant.BLE_MTU_MIN
            mtu > BluetoothConstant.BLE_MTU_MAX -> BluetoothConstant.BLE_MTU_MAX
            else -> mtu
        }
    }
}
