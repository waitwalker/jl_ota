package com.jieli.otasdk

import android.Manifest
import android.os.Build
import android.os.Handler
import android.os.Looper
import android.os.Process
import com.jieli.otasdk.data.constant.MethodChannelConstants
import com.jieli.otasdk.data.constant.OtaConstant
import com.jieli.otasdk.model.connect.ConnectViewModel
import com.jieli.otasdk.model.ota.DownloadFileViewModel
import com.jieli.otasdk.model.ota.OTAViewModel
import com.jieli.otasdk.tool.config.ConfigHelper
import com.jieli.otasdk.util.FileTransferUtil
import com.jieli.otasdk.util.FileUtil
import com.jieli.otasdk.util.NetworkUtil
import com.jieli.otasdk.util.ViewUtil
import com.jieli.component.ActivityManager
import com.jieli.jlFileTransfer.Constants
import com.jieli.jl_bt_ota.constant.BluetoothConstant
import com.jieli.jl_bt_ota.constant.JL_Constant
import com.jieli.jl_bt_ota.interfaces.IActionCallback
import com.jieli.jl_bt_ota.model.base.BaseError
import com.jieli.jl_bt_ota.util.JL_Log
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import java.io.File
import kotlin.system.exitProcess

/**
 * Des:
 * author: lifang
 * date: 2025/07/29
 * Copyright: Jieli Technology
 * Modify date:
 * Modified by:
 */
class MethodChannelHandler(private val activity: MainActivity) : MethodChannel.MethodCallHandler {
    private val connectVM by lazy { ConnectViewModel.getInstance() }
    private val configHelper by lazy { ConfigHelper.getInstance() }
    private val logHelper by lazy { LogHelper.getInstance() }
    private lateinit var downloadFileViewModel: DownloadFileViewModel
    private lateinit var otaViewModel: OTAViewModel
    private val storagePermissionHelper get() = activity.storagePermissionHelper

    override fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
        when (call.method) {
            MethodChannelConstants.METHOD_IS_SCANNING -> result.success(connectVM.isScanning())
            MethodChannelConstants.METHOD_START_SCAN -> startScan(result)
            MethodChannelConstants.METHOD_STOP_SCAN -> stopScan(result)
            MethodChannelConstants.METHOD_GET_SCAN_FILTER -> result.success(connectVM.getScanFilter())
            MethodChannelConstants.METHOD_SET_SCAN_FILTER -> setScanFilter(call, result)
            MethodChannelConstants.METHOD_CONNECT_DEVICE -> connectDevice(call, result)
            MethodChannelConstants.METHOD_DISCONNECT_BT_DEVICE -> disconnectDevice(call, result)
            MethodChannelConstants.METHOD_IS_BLE_WAY -> result.success(configHelper.isBleWay())
            MethodChannelConstants.METHOD_SET_BLE_WAY -> setBleWay(call, result)
            MethodChannelConstants.METHOD_IS_USE_DEVICE_AUTH -> result.success(configHelper.isUseDeviceAuth())
            MethodChannelConstants.METHOD_SET_USE_DEVICE_AUTH -> setUseDeviceAuth(call, result)
            MethodChannelConstants.METHOD_IS_HID_DEVICE -> result.success(configHelper.isHidDevice())
            MethodChannelConstants.METHOD_SET_HID_DEVICE -> setHidDevice(call, result)
            MethodChannelConstants.METHOD_IS_USE_CUSTOM_RECONNECT_WAY -> result.success(configHelper.isUseCustomReConnectWay())
            MethodChannelConstants.METHOD_SET_USE_CUSTOM_RECONNECT_WAY -> setUseCustomReConnectWay(call, result)
            MethodChannelConstants.METHOD_GET_BLE_REQUEST_MTU -> result.success(configHelper.getBleRequestMtu())
            MethodChannelConstants.METHOD_SET_BLE_REQUEST_MTU -> setBleRequestMtu(call, result)
            MethodChannelConstants.METHOD_GET_SDK_VERSION -> result.success(getSdkVersion())
            MethodChannelConstants.METHOD_GET_APP_VERSION -> result.success(getAppVersion())
            MethodChannelConstants.METHOD_GET_LOG_FILES -> getLogFiles(result)
            MethodChannelConstants.METHOD_LOG_FILE_INDEX -> setLogFileIndex(call, result)
            MethodChannelConstants.METHOD_SHARE_LOG_FILE -> shareLogFile(call, result)
            MethodChannelConstants.METHOD_DOWNLOAD_FILE -> downloadFile(call, result)
            MethodChannelConstants.METHOD_TYPE_IS_OTA -> isOTa(result)
            MethodChannelConstants.METHOD_READ_FILE_LIST -> readFileList(result)
            MethodChannelConstants.METHOD_SET_SELECTED_INDEX -> setSelectedIndex(call, result)
            MethodChannelConstants.METHOD_DELETE_OTA_FILE_INDEX -> deleteOtaFileIndex(call, result)
            MethodChannelConstants.METHOD_TRY_TO_CHECK_STORAGE_ENVIRONMENT -> tryToCheckStorageEnvironment(result)
            MethodChannelConstants.METHOD_PICK_FILE -> pickFile(result)
            MethodChannelConstants.METHOD_START_OTA -> startOTA(call,result)
            MethodChannelConstants.METHOD_DELETE_ALL_LOG_FILE -> deleteAllLogFiles(result)
            MethodChannelConstants.METHOD_GET_WIFI_IP_ADDRESS -> getWifiIpAddress(result)
            MethodChannelConstants.METHOD_GET_LOG_FILE_DIR_PATH -> getLogFileDirPath(result)
            MethodChannelConstants.METHOD_POP_ALL_ACTIVITY -> popAllActivity(result)
            MethodChannelConstants.METHOD_HANDLE_FILE_PICKED -> handleFilePicked(call, result)
            else -> result.notImplemented()
        }
    }

//    private fun checkBluetoothEnvironment(result: MethodChannel.Result) {
//        BluetoothEnvironmentChecker.checkBluetoothEnvironment(activity, object : IActionCallback<Boolean> {
//            override fun onSuccess(resultValue: Boolean?) {
//                result.success(resultValue)
//            }
//
//            override fun onError(p0: BaseError?) {
//                result.error("BLUETOOTH_ENVIRONMENT_CHECK_FAILED", "Bluetooth environment check failed", null)
//            }
//        })
//    }

    private fun startScan(result: MethodChannel.Result) {
        val checkResult = BluetoothEnvironmentChecker.checkBluetoothEnvironment(activity)

        if (!checkResult.hasBluetoothPermission || !checkResult.hasLocationPermission) {
            // 请求缺失的权限
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
     * 请求缺失的权限
     */
    private fun requestMissingPermissions(checkResult: BluetoothEnvironmentChecker.CheckResult, result: MethodChannel.Result) {
        val permissionsToRequest = mutableListOf<String>()

        // 添加蓝牙权限（Android 12+）
        if (!checkResult.hasBluetoothPermission && Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
            permissionsToRequest.add(Manifest.permission.BLUETOOTH_SCAN)
            permissionsToRequest.add(Manifest.permission.BLUETOOTH_CONNECT)
        }

        // 添加定位权限
        if (!checkResult.hasLocationPermission) {
            permissionsToRequest.add(Manifest.permission.ACCESS_FINE_LOCATION)
        }

        if (permissionsToRequest.isNotEmpty()) {
            // 通过Activity请求权限
            activity.requestMissingPermissions(permissionsToRequest.toTypedArray()) { granted ->
                if (granted) {
                    // 权限授予成功，重新检查环境
                    val newCheckResult = BluetoothEnvironmentChecker.checkBluetoothEnvironment(activity)
                    if (newCheckResult.isAllReady) {
                        connectVM.startScan()
                        result.success(true)
                    } else {
                        handleUnreadyEnvironment(newCheckResult, result)
                    }
                } else {
                    // 权限被拒绝
                    result.error("PERMISSION_DENIED", "Required permissions were denied", null)
                }
            }
        } else {
            result.error("PERMISSION_CHECK_FAILED", "Permission check failed unexpectedly", null)
        }
    }

    /**
     * 处理环境未就绪的情况
     */
    private fun handleUnreadyEnvironment(checkResult: BluetoothEnvironmentChecker.CheckResult, result: MethodChannel.Result) {
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
        // Check if device is not connected
        if (connectVM.isConnected()) {
            // Multiple device connections are not allowed, so return
            return
        }
        val scanDevice = connectVM.scanDeviceList[index]
        connectVM.connectBtDevice(scanDevice.device)
        result.success(true)
    }

    private fun disconnectDevice(call: MethodCall, result: MethodChannel.Result) {
        val index = call.argument<Int>(MethodChannelConstants.ARG_INDEX) ?: -1

        // 检查索引是否在有效范围内
        if (index !in connectVM.scanDeviceList.indices) {
            // 如果索引无效，返回错误信息
            result.error("INVALID_INDEX", "index=$index", null)
            return
        }

        // 获取指定索引的设备
        val scanDevice = connectVM.scanDeviceList[index]

        // 断开设备连接
        connectVM.disconnectBtDevice(scanDevice.device)

        // 返回成功结果
        result.success(true)
    }

    private fun setBleWay(call: MethodCall, result: MethodChannel.Result) {
        val isBle = call.argument<Boolean>(MethodChannelConstants.ARG_IS_BLE) ?: true
        configHelper.setBleWay(isBle)
        result.success(true)
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

    private fun getAppVersion(): String {
        val appVersionName = ViewUtil.getAppVersionName(activity)
        val appVersionCode = ViewUtil.getAppVersion(activity)
        return OtaConstant.formatString("V%s(%d)", appVersionName, appVersionCode)
    }

    private fun downloadFile(call: MethodCall, result: MethodChannel.Result) {
        val httpUrl = call.argument<String>(MethodChannelConstants.ARG_HTTP_URL)
        if (httpUrl != null) {
            downloadFileViewModel = DownloadFileViewModel.getInstance()
            downloadFileViewModel.downloadFile(httpUrl)
            result.success(null)
        } else {
            result.error("INVALID_ARGUMENT", "httpUrl must not be null", null)
        }
    }

    private  fun isOTa(result: MethodChannel.Result) {
        otaViewModel = OTAViewModel.getInstance()
        result.success(otaViewModel.isOTA())
    }

    private fun readFileList(result: MethodChannel.Result) {
        otaViewModel = OTAViewModel.getInstance()
        otaViewModel.readFileList()
        result.success(null)
    }

    private fun setSelectedIndex(call: MethodCall, result: MethodChannel.Result) {
        val pos = call.argument<Int>(MethodChannelConstants.ARG_POS) ?: -1
        if (pos >= 0) {
            setSelectedOtaIndex(pos)
            result.success(null)
        } else {
            result.error("INVALID_INDEX", "Index must be non-negative", null)
        }
    }

    private fun deleteOtaFileIndex(call: MethodCall, result: MethodChannel.Result) {
        val pos = call.argument<Int>(MethodChannelConstants.ARG_POS) ?: -1
        if (pos >= 0) {
            deleteOtaFileIndex(pos)
            result.success(null)
        } else {
            result.error("INVALID_INDEX", "Index must be non-negative", null)
        }
    }

    private fun tryToCheckStorageEnvironment(result: MethodChannel.Result) {
        // 添加超时处理
        val timeoutRunnable = Runnable {
            if (storagePermissionHelper.callback != null) {
                storagePermissionHelper.callback = null
                result.error("PERMISSION_TIMEOUT", "Permission request timeout", null)
            }
        }

        val handler = Handler(Looper.getMainLooper())
        handler.postDelayed(timeoutRunnable, 10000) // 10秒超时

        storagePermissionHelper.tryToCheckStorageEnvironment(object : IActionCallback<Boolean> {
            override fun onSuccess(granted: Boolean) {
                handler.removeCallbacks(timeoutRunnable)
                result.success(granted)
            }

            override fun onError(error: BaseError?) {
                handler.removeCallbacks(timeoutRunnable)
                JL_Log.e("storageEnvironmentChecker", "Error checking storage environment")
                result.error("STORAGE_PERMISSION_DENIED", "Storage permission denied", null)
            }
        })
    }

    private fun startOTA(call: MethodCall, result: MethodChannel.Result) {
        val path = call.argument<String>(MethodChannelConstants.ARG_PATH)
        if (path != null) {
            otaViewModel.startOTA(path)
            result.success(true)
        }else {
            result.error("INVALID_INDEX", "Index must be non-negative", null)
        }
    }

    private fun deleteAllLogFiles(result: MethodChannel.Result) {
        FileUtil.deleteFile(File(MyApplication.getInstance().logFileDir))
        result.success(true)
    }

    private fun getWifiIpAddress(result: MethodChannel.Result) {
        try {
            val ipAddress = NetworkUtil.getWifiIpAddress(activity)
            val url = if (ipAddress.isNullOrEmpty()) {
                activity.getString(R.string.connect_wifi_tips)
            } else {
                "http://$ipAddress:${Constants.HTTP_PORT}"
            }
            result.success(url)
        } catch (e: Exception) {
            result.error("WIFI_IP_ERROR", "Failed to get WiFi IP address", e.localizedMessage)
        }
    }

    private fun getLogFileDirPath(result: MethodChannel.Result) {
        val logFileDirPath = MyApplication.getInstance().logFileDir
        result.success(logFileDirPath)
    }

    private fun popAllActivity(result: MethodChannel.Result) {
        try {
            ActivityManager.getInstance().popAllActivity()
            Handler(Looper.getMainLooper()).postDelayed({
                Process.killProcess(Process.myPid())
                exitProcess(0)
            }, 500)
            result.success(true)
        } catch (e: Exception) {
            result.error("POP_ALL_ACTIVITY_FAILED", "Failed to pop all activities", e.message)
        }
    }

    private fun handleFilePicked(call: MethodCall, result: MethodChannel.Result) {
        val fileName = call.argument<String>(MethodChannelConstants.ARG_FILE_NAME)
        if (fileName != null) {
            MainActivity.selectedUri?.let {
                FileTransferUtil.handleSelectFile(
                    MyApplication.getInstance(),
                    it,fileName,
                    object : IActionCallback<Boolean> {
                        override fun onSuccess(message: Boolean?) {
                            OTAViewModel.getInstance().readFileList()
                            result.success(true)
                        }

                        override fun onError(error: BaseError?) {
                            result.error("FILE_TRANSFER_ERROR", "Error handling file transfer", null)
                        }
                    }
                )
            }
        } else {
            result.error("INVALID_ARGUMENT", "fileName must not be null", null)
        }
    }


    private fun formatBleMtu(mtu: Int): Int {
        return if (mtu < BluetoothConstant.BLE_MTU_MIN) {
            BluetoothConstant.BLE_MTU_MIN
        } else if (mtu > BluetoothConstant.BLE_MTU_MAX) {
            BluetoothConstant.BLE_MTU_MAX
        } else {
            mtu
        }
    }

    private fun getSelectedItems(): MutableList<String> {
        val clone = mutableListOf<String>()
        for (path in OTAViewModel.getInstance().selectedFilePaths) {
            File(path).run {
                if (this.exists() && this.isFile) {
                    clone.add(path)
                }
            }
        }
        return clone
    }

    private fun isSelectedOtaFile(file: File?): Boolean {
        if (file == null) return false
        return OTAViewModel.getInstance().selectedFilePaths.contains(file.path)
    }

    private fun setSelectedOtaIndex(pos: Int) {
        val file = otaViewModel.getFiles()[pos]
        if (isSelectedOtaFile(file)) {
            OTAViewModel.getInstance().selectedFilePaths.remove(file.path)
        } else {
            if (OTAViewModel.getInstance().selectedFilePaths.size == 1) {
                OTAViewModel.getInstance().selectedFilePaths.clear()
            }
            OTAViewModel.getInstance().selectedFilePaths.add(file.path)
        }
        OTAViewModel.getInstance().selectedFilePathsMLD.postValue(OTAViewModel.getInstance().selectedFilePaths)
    }

    private fun deleteOtaFileIndex(pos: Int) {
        val file = otaViewModel.getFiles()[pos]
        if (file.exists()) {
            file.delete()
        }
        OTAViewModel.getInstance().readFileList()
    }

    private fun getLogFiles(result: MethodChannel.Result) {
        logHelper.loadLogFiles()
        result.success(true)
    }

    private fun setLogFileIndex(call: MethodCall, result: MethodChannel.Result) {
        val logFileIndex = call.argument<Int>(MethodChannelConstants.ARG_LOG_FILE_INDEX) ?: -1
        logHelper.handleLogFileIndex(logFileIndex)
        result.success(true)
    }

    private fun shareLogFile(call: MethodCall, result: MethodChannel.Result) {
        val logFileIndex = call.argument<Int>(MethodChannelConstants.ARG_LOG_FILE_INDEX) ?: -1
        logHelper.shareLogFile(activity, logFileIndex)
        result.success(true)
    }

    private fun pickFile(result: MethodChannel.Result) {
        activity.pickFile()
        result.success(null)
    }
}
