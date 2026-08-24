package com.jieli.otasdk

import android.Manifest
import android.bluetooth.BluetoothDevice
import android.os.Build
import android.os.Handler
import android.os.Looper
import android.os.Process
import androidx.lifecycle.DefaultLifecycleObserver
import androidx.lifecycle.LifecycleOwner
import com.jieli.otasdk.data.constant.MethodChannelConstants
import com.jieli.otasdk.data.constant.OtaConstant
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
import com.jieli.jl_bt_ota.constant.Command
import com.jieli.jl_bt_ota.constant.JL_Constant
import com.jieli.jl_bt_ota.interfaces.IActionCallback
import com.jieli.jl_bt_ota.model.base.BaseError
import com.jieli.jl_bt_ota.model.base.CommandBase
import com.jieli.jl_bt_ota.model.command.CustomCmd
import com.jieli.jl_bt_ota.util.JL_Log
import com.jieli.otasdk.model.connect.ConnectViewModel
import com.jieli.otasdk.tool.bluetooth.BluetoothHelper
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import java.io.File
import java.lang.ref.WeakReference
import kotlin.system.exitProcess

/**
 * Des:
 * author: lifang
 * date: 2025/07/29
 * Copyright: Jieli Technology
 * Modify date:
 * Modified by:
 */
class MethodChannelHandler(
    activity: MainActivity,
    private val lifecycleOwner: LifecycleOwner
) : MethodChannel.MethodCallHandler, DefaultLifecycleObserver {

    private val activityRef = WeakReference(activity)

    private val connectVM by lazy { ConnectViewModel.getInstance() }
    private val configHelper by lazy { ConfigHelper.getInstance() }
    private val logHelper by lazy { LogHelper.getInstance() }
    private val bluetoothHelper: BluetoothHelper by lazy { BluetoothHelper.getInstance() }

    private var downloadFileViewModel: DownloadFileViewModel? = null
    private var otaViewModel: OTAViewModel? = null

    private val mainHandler = Handler(Looper.getMainLooper())
    private var timeoutRunnable: Runnable? = null
    private var permissionCallback: ((Boolean) -> Unit)? = null
    private var filePickCallback: IActionCallback<Boolean>? = null
    private var storageCallback: IActionCallback<Boolean>? = null

    init {
        lifecycleOwner.lifecycle.addObserver(this)
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
            MethodChannelConstants.METHOD_START_OTA -> startOTA(call, result)
            MethodChannelConstants.METHOD_DELETE_ALL_LOG_FILE -> deleteAllLogFiles(result)
            MethodChannelConstants.METHOD_GET_WIFI_IP_ADDRESS -> getWifiIpAddress(result)
            MethodChannelConstants.METHOD_GET_LOG_FILE_DIR_PATH -> getLogFileDirPath(result)
            MethodChannelConstants.METHOD_POP_ALL_ACTIVITY -> popAllActivity(result)
            MethodChannelConstants.METHOD_HANDLE_FILE_PICKED -> handleFilePicked(call, result)
            MethodChannelConstants.METHOD_SEND_CUSTOM_COMMAND -> sendCustomCmd(call, result)
            else -> result.notImplemented()
        }
    }

    override fun onDestroy(owner: LifecycleOwner) {
        cleanup()
        lifecycleOwner.lifecycle.removeObserver(this)
    }

    fun cleanup() {
        // Clean up all Handler callbacks
        timeoutRunnable?.let { mainHandler.removeCallbacks(it) }
        timeoutRunnable = null

        // Clean up all callbacks
        permissionCallback = null
        filePickCallback = null
        storageCallback = null

        // Clean up ViewModel references
        downloadFileViewModel = null
        otaViewModel = null

        // Clean up LogHelper
        logHelper.cleanUp()

        // Remove all pending messages from Handler
        mainHandler.removeCallbacksAndMessages(null)

        // Stop scanning
        if (connectVM.isScanning()) {
            connectVM.stopScan()
            connectVM.clearScanDeviceList()
        }

        // Clean up ConnectVM
        connectVM.cleanUp()

        // Clean up storage permission helper callback
        val activity = activityRef.get()
        activity?.storagePermissionHelper?.callback = null

        // Clear static Uri
        MainActivity.clearSelectedUri()
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

        if (!checkResult.hasLocationPermission) {
            permissionsToRequest.add(Manifest.permission.ACCESS_FINE_LOCATION)
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

            activity.requestMissingPermissions(permissionsToRequest.toTypedArray()) { granted ->
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

    private fun getAppVersion(): String {
        val activity = activityRef.get()
        if (activity == null) {
            return "Unknown"
        }
        val appVersionName = ViewUtil.getAppVersionName(activity)
        val appVersionCode = ViewUtil.getAppVersion(activity)
        return OtaConstant.formatString("V%s(%d)", appVersionName, appVersionCode)
    }

    private fun downloadFile(call: MethodCall, result: MethodChannel.Result) {
        val httpUrl = call.argument<String>(MethodChannelConstants.ARG_HTTP_URL)
        if (httpUrl != null) {
            downloadFileViewModel = DownloadFileViewModel.getInstance()
            downloadFileViewModel?.downloadFile(httpUrl)
            result.success(null)
        } else {
            result.error("INVALID_ARGUMENT", "httpUrl must not be null", null)
        }
    }

    private fun isOTa(result: MethodChannel.Result) {
        otaViewModel = OTAViewModel.getInstance()
        result.success(otaViewModel?.isOTA() ?: false)
    }

    private fun readFileList(result: MethodChannel.Result) {
        otaViewModel = OTAViewModel.getInstance()
        otaViewModel?.readFileList()
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
        val activity = activityRef.get()
        if (activity == null) {
            result.error("ACTIVITY_NULL", "Activity is destroyed", null)
            return
        }

        // Clean up old timeoutRunnable
        timeoutRunnable?.let { mainHandler.removeCallbacks(it) }

        timeoutRunnable = Runnable {
            if (activity.storagePermissionHelper.callback != null) {
                activity.storagePermissionHelper.callback = null
                result.error("PERMISSION_TIMEOUT", "Permission request timeout", null)
            }
            timeoutRunnable = null
        }

        mainHandler.postDelayed(timeoutRunnable!!, 10000)

        storageCallback = object : IActionCallback<Boolean> {
            override fun onSuccess(granted: Boolean) {
                timeoutRunnable?.let { mainHandler.removeCallbacks(it) }
                timeoutRunnable = null
                storageCallback = null
                result.success(granted)
            }

            override fun onError(error: BaseError?) {
                timeoutRunnable?.let { mainHandler.removeCallbacks(it) }
                timeoutRunnable = null
                storageCallback = null
                JL_Log.e("MethodChannelHandler", "Error checking storage environment: ${error?.message}")
                result.error("STORAGE_PERMISSION_DENIED", "Storage permission denied", null)
            }
        }

        activity.storagePermissionHelper.tryToCheckStorageEnvironment(storageCallback!!)
    }

    private fun startOTA(call: MethodCall, result: MethodChannel.Result) {
        val path = call.argument<String>(MethodChannelConstants.ARG_PATH)
        if (path != null) {
            otaViewModel?.startOTA(path)
            result.success(true)
        } else {
            result.error("INVALID_ARGUMENT", "path must not be null", null)
        }
    }

    private fun deleteAllLogFiles(result: MethodChannel.Result) {
        FileUtil.deleteFile(File(MyApplication.getInstance().logFileDir))
        result.success(true)
    }

    private fun getWifiIpAddress(result: MethodChannel.Result) {
        val activity = activityRef.get()
        if (activity == null) {
            result.error("ACTIVITY_NULL", "Activity is destroyed", null)
            return
        }

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
            mainHandler.postDelayed({
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
        if (fileName.isNullOrBlank()) {
            result.error("INVALID_ARGUMENT", "fileName must not be null or blank", null)
            return
        }

        val selectedUri = MainActivity.getSelectedUri()
        if (selectedUri == null) {
            result.error("NO_SELECTED_URI", "No file selected", null)
            return
        }

        MainActivity.clearSelectedUri()

        // Wrap result with WeakReference to prevent callbacks after Activity is destroyed
        val resultRef = WeakReference(result)

        val callback = object : IActionCallback<Boolean> {
            override fun onSuccess(message: Boolean?) {
                val r = resultRef.get()
                if (r != null) {
                    OTAViewModel.getInstance().readFileList()
                    r.success(true)
                }
                filePickCallback = null
            }

            override fun onError(error: BaseError?) {
                val r = resultRef.get()
                if (r != null) {
                    val errorMsg = error?.message ?: "Unknown error"
                    JL_Log.e("MethodChannelHandler", "File transfer error: $errorMsg")
                    r.error("FILE_TRANSFER_ERROR", "Error handling file transfer: $errorMsg", null)
                }
                filePickCallback = null
            }
        }

        filePickCallback = callback

        FileTransferUtil.handleSelectFile(
            MyApplication.getInstance(),
            selectedUri,
            fileName,
            callback
        )
    }

    private fun sendCustomCmd(
        call: MethodCall,
        result: MethodChannel.Result?
    ) {
        // Extract and validate arguments from Flutter method call
        val arguments = call.arguments as? Map<*, *> ?: run {
            result?.error("INVALID_ARGUMENTS", "Arguments are missing or invalid", null)
            return
        }

        // Extract custom data payload from arguments
        val data = arguments[MethodChannelConstants.ARG_CUSTOM_DATA] as? ByteArray
        if (data == null) {
            result?.error("INVALID_DATA", "Custom data is missing or invalid", null)
            return
        }

        bluetoothHelper.writeDataToDevice(bluetoothHelper.getConnectedDevice(),data)
    }

    private fun formatBleMtu(mtu: Int): Int {
        return when {
            mtu < BluetoothConstant.BLE_MTU_MIN -> BluetoothConstant.BLE_MTU_MIN
            mtu > BluetoothConstant.BLE_MTU_MAX -> BluetoothConstant.BLE_MTU_MAX
            else -> mtu
        }
    }

    private fun getSelectedItems(): MutableList<String> {
        val clone = mutableListOf<String>()
        otaViewModel?.selectedFilePaths?.forEach { path ->
            File(path).takeIf { it.exists() && it.isFile }?.let {
                clone.add(path)
            }
        }
        return clone
    }

    private fun isSelectedOtaFile(file: File?): Boolean {
        if (file == null) return false
        return otaViewModel?.selectedFilePaths?.contains(file.path) == true
    }

    private fun setSelectedOtaIndex(pos: Int) {
        val viewModel = otaViewModel ?: return
        val files = viewModel.getFiles()
        if (pos !in files.indices) return

        val file = files[pos]
        if (isSelectedOtaFile(file)) {
            viewModel.selectedFilePaths.remove(file.path)
        } else {
            if (viewModel.selectedFilePaths.size == 1) {
                viewModel.selectedFilePaths.clear()
            }
            viewModel.selectedFilePaths.add(file.path)
        }
        viewModel.selectedFilePathsMLD.postValue(viewModel.selectedFilePaths)
    }

    private fun deleteOtaFileIndex(pos: Int) {
        val viewModel = otaViewModel ?: return
        val files = viewModel.getFiles()
        if (pos !in files.indices) return

        val file = files[pos]
        if (file.exists()) {
            file.delete()
        }
        viewModel.readFileList()
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
        val activity = activityRef.get()
        if (activity == null) {
            result.error("ACTIVITY_NULL", "Activity is destroyed", null)
            return
        }

        val logFileIndex = call.argument<Int>(MethodChannelConstants.ARG_LOG_FILE_INDEX) ?: -1
        logHelper.shareLogFile(activity, logFileIndex)
        result.success(true)
    }

    private fun pickFile(result: MethodChannel.Result) {
        val activity = activityRef.get()
        if (activity == null) {
            result.error("ACTIVITY_NULL", "Activity is destroyed", null)
            return
        }
        activity.pickFile()
        result.success(null)
    }
}