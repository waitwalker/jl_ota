package com.jieli.otasdk

import android.bluetooth.BluetoothDevice
import android.content.pm.PackageManager
import android.os.Build
import android.os.Handler
import android.os.Looper
import android.os.Process
import androidx.lifecycle.Observer
import com.jieli.jlFileTransfer.Constants
import com.jieli.jl_bt_ota.constant.Command
import com.jieli.jl_bt_ota.interfaces.IActionCallback
import com.jieli.jl_bt_ota.interfaces.rcsp.OnRcspCallback
import com.jieli.jl_bt_ota.model.base.BaseError
import com.jieli.jl_bt_ota.model.base.CommandBase
import com.jieli.jl_bt_ota.model.command.CustomCmd
import com.jieli.jl_bt_ota.util.JL_Log
import com.jieli.otasdk.data.constant.EventChannelConstants
import com.jieli.otasdk.data.constant.ExampleChannelConstants
import com.jieli.otasdk.data.constant.OtaConstant
import com.jieli.otasdk.example.R
import com.jieli.otasdk.model.ota.DownloadFileViewModel
import com.jieli.otasdk.model.ota.OTAViewModel
import com.jieli.otasdk.tool.bluetooth.BluetoothHelper
import com.jieli.otasdk.tool.file.FileManager
import com.jieli.otasdk.util.DownloadFileUtil
import com.jieli.otasdk.util.FileTransferUtil
import com.jieli.otasdk.util.NetworkUtil
import io.flutter.plugin.common.BinaryMessenger
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import java.io.File
import java.lang.ref.WeakReference

/**
 * Example-only channel. Logs, file cabinet, download, Wi-Fi transfer and
 * process exit stay off the host OTA channel.
 */
class ExampleChannelHandler(
    private val activity: MainActivity,
    messenger: BinaryMessenger,
) : MethodChannel.MethodCallHandler, EventChannel.StreamHandler {

    private val methodChannel = MethodChannel(messenger, METHOD_CHANNEL)
    private val eventChannel = EventChannel(messenger, EVENT_CHANNEL)
    private val mainHandler = Handler(Looper.getMainLooper())
    private val logHelper by lazy { LogHelper.getInstance() }
    private val downloadFileViewModel by lazy { DownloadFileViewModel.getInstance() }
    private val bluetoothHelper by lazy { BluetoothHelper.getInstance() }
    private var eventSink: EventChannel.EventSink? = null
    private var files: MutableList<File> = mutableListOf()
    private var filePickCallback: IActionCallback<Boolean>? = null
    private var rcspCallback: OnRcspCallback? = null
    private var exitRequested = false

    private val downloadStatusObserver = Observer<DownloadFileUtil.DownloadFileEvent?> { event ->
        sendDownloadStatusEvent(event)
    }

    init {
        methodChannel.setMethodCallHandler(this)
        eventChannel.setStreamHandler(this)
    }

    fun dispose() {
        methodChannel.setMethodCallHandler(null)
        eventChannel.setStreamHandler(null)
        onCancel(null)
        filePickCallback = null
        logHelper.cleanUp()
    }

    fun notifyFilePicked(fileName: String?) {
        methodChannel.invokeMethod(
            ExampleChannelConstants.METHOD_ON_FILE_PICKED,
            mapOf(ExampleChannelConstants.ARG_FILE_NAME to fileName),
        )
    }

    override fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
        when (call.method) {
            ExampleChannelConstants.METHOD_GET_APP_VERSION -> result.success(appVersion())
            ExampleChannelConstants.METHOD_GET_LOG_FILES -> {
                logHelper.loadLogFiles()
                result.success(true)
            }
            ExampleChannelConstants.METHOD_LOG_FILE_INDEX -> {
                val index = call.argument<Int>(ExampleChannelConstants.ARG_LOG_FILE_INDEX) ?: -1
                logHelper.handleLogFileIndex(index)
                result.success(true)
            }
            ExampleChannelConstants.METHOD_SHARE_LOG_FILE -> {
                val index = call.argument<Int>(ExampleChannelConstants.ARG_LOG_FILE_INDEX) ?: -1
                logHelper.shareLogFile(activity, index)
                result.success(true)
            }
            ExampleChannelConstants.METHOD_DELETE_ALL_LOG_FILE -> {
                FileManager.deleteTree(File(JL_Log.getSaveLogPath(OtaRuntime.getContext())))
                result.success(true)
            }
            ExampleChannelConstants.METHOD_GET_LOG_FILE_DIR_PATH -> result.success(JL_Log.getSaveLogPath(OtaRuntime.getContext()))
            ExampleChannelConstants.METHOD_DOWNLOAD_FILE -> downloadFile(call, result)
            ExampleChannelConstants.METHOD_READ_FILE_LIST -> {
                publishFileList()
                result.success(null)
            }
            ExampleChannelConstants.METHOD_DELETE_OTA_FILE_INDEX -> deleteOtaFile(call, result)
            ExampleChannelConstants.METHOD_TRY_TO_CHECK_STORAGE_ENVIRONMENT -> result.success(true)
            ExampleChannelConstants.METHOD_PICK_FILE -> {
                activity.pickFile()
                result.success(null)
            }
            ExampleChannelConstants.METHOD_GET_WIFI_IP_ADDRESS -> wifiAddress(result)
            ExampleChannelConstants.METHOD_POP_ALL_ACTIVITY -> popAllActivity(result)
            ExampleChannelConstants.METHOD_HANDLE_FILE_PICKED -> handleFilePicked(call, result)
            ExampleChannelConstants.METHOD_SEND_CUSTOM_COMMAND -> sendCustomCommand(call, result)
            else -> result.notImplemented()
        }
    }

    override fun onListen(arguments: Any?, sink: EventChannel.EventSink) {
        eventSink = sink
        logHelper.setEventSink(sink)
        downloadFileViewModel.downloadStatusMLD.observeForever(downloadStatusObserver)
        rcspCallback = object : OnRcspCallback() {
            override fun onRcspCommand(device: BluetoothDevice, cmd: CommandBase<*, *>) {
                if (cmd.id != Command.CMD_EXTRA_CUSTOM || cmd !is CustomCmd) return
                handleReceivedCustomCommand(cmd)
            }
        }
        rcspCallback?.let { OTAViewModel.getInstance().otaManager.addOnRcspCallback(it) }
    }

    override fun onCancel(arguments: Any?) {
        downloadFileViewModel.downloadStatusMLD.removeObserver(downloadStatusObserver)
        rcspCallback?.let { OTAViewModel.getInstance().otaManager.removeRcspCallback(it) }
        rcspCallback = null
        logHelper.setEventSink(null)
        eventSink = null
    }

    private fun appVersion(): String {
        val versionName = try {
            val info = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
                activity.packageManager.getPackageInfo(
                    activity.packageName,
                    PackageManager.PackageInfoFlags.of(0),
                )
            } else {
                activity.packageManager.getPackageInfo(activity.packageName, 0)
            }
            info.versionName ?: "0.0.0"
        } catch (e: PackageManager.NameNotFoundException) {
            "0.0.0"
        }
        val versionCode = try {
            val info = activity.packageManager.getPackageInfo(activity.packageName, 0)
            if (Build.VERSION.SDK_INT >= 28) info.longVersionCode.toInt() else info.versionCode
        } catch (e: PackageManager.NameNotFoundException) {
            0
        }
        return OtaConstant.formatString("V%s(%d)", versionName, versionCode)
    }

    private fun downloadFile(call: MethodCall, result: MethodChannel.Result) {
        val httpUrl = call.argument<String>(ExampleChannelConstants.ARG_HTTP_URL)
        if (httpUrl == null) {
            result.error("INVALID_ARGUMENT", "httpUrl must not be null", null)
            return
        }
        downloadFileViewModel.downloadFile(httpUrl)
        result.success(null)
    }

    private fun publishFileList() {
        files = FileManager.readUpgradeFile()
        sendEvent(
            ExampleChannelConstants.TYPE_OTA_FILE_LIST,
            mapOf(
                EventChannelConstants.KEY_LIST to files.map { file ->
                    mapOf(
                        EventChannelConstants.KEY_NAME to FileManager.fileMessage(file),
                        EventChannelConstants.KEY_PATH to file.path,
                    )
                },
            ),
        )
    }

    private fun deleteOtaFile(call: MethodCall, result: MethodChannel.Result) {
        val pos = call.argument<Int>(ExampleChannelConstants.ARG_POS) ?: -1
        if (pos !in files.indices) {
            result.error("INVALID_INDEX", "Index must be non-negative", null)
            return
        }
        val file = files[pos]
        if (file.exists()) {
            file.delete()
        }
        publishFileList()
        result.success(null)
    }

    private fun wifiAddress(result: MethodChannel.Result) {
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

    private fun popAllActivity(result: MethodChannel.Result) {
        if (activity.isDestroyed) {
            result.error("ACTIVITY_NULL", "Activity is destroyed", null)
            return
        }
        if (exitRequested) {
            result.success(true)
            return
        }
        if (activity.isFinishing) {
            result.error("ACTIVITY_NULL", "Activity is finishing", null)
            return
        }
        val exitHandler = Handler(Looper.getMainLooper())
        val exitTask = Runnable { Process.killProcess(Process.myPid()) }
        try {
            if (!exitHandler.postDelayed(exitTask, 500L)) {
                result.error("POP_ALL_ACTIVITY_FAILED", "Failed to schedule application exit", null)
                return
            }
            if (activity.isTaskRoot) {
                activity.finishAndRemoveTask()
            } else {
                activity.finish()
            }
            exitRequested = true
        } catch (e: Exception) {
            exitHandler.removeCallbacks(exitTask)
            result.error("POP_ALL_ACTIVITY_FAILED", "Failed to close application activities", e.message)
            return
        }
        result.success(true)
    }

    private fun handleFilePicked(call: MethodCall, result: MethodChannel.Result) {
        val fileName = call.argument<String>(ExampleChannelConstants.ARG_FILE_NAME)
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
        val resultRef = WeakReference(result)
        val callback = object : IActionCallback<Boolean> {
            override fun onSuccess(message: Boolean?) {
                publishFileList()
                resultRef.get()?.success(true)
                filePickCallback = null
            }

            override fun onError(error: BaseError?) {
                val errorMsg = error?.message ?: "Unknown error"
                JL_Log.e("ExampleChannelHandler", "File transfer error: $errorMsg")
                resultRef.get()?.error("FILE_TRANSFER_ERROR", "Error handling file transfer: $errorMsg", null)
                filePickCallback = null
            }
        }
        filePickCallback = callback
        FileTransferUtil.handleSelectFile(OtaRuntime.getContext(), selectedUri, fileName, callback)
    }

    private fun sendCustomCommand(call: MethodCall, result: MethodChannel.Result) {
        val arguments = call.arguments as? Map<*, *>
        val data = arguments?.get(ExampleChannelConstants.ARG_CUSTOM_DATA) as? ByteArray
        if (data == null) {
            result.error("INVALID_DATA", "Custom data is missing or invalid", null)
            return
        }
        bluetoothHelper.writeDataToDevice(bluetoothHelper.getConnectedDevice(), data)
        result.success(null)
    }

    private fun handleReceivedCustomCommand(cmd: CustomCmd) {
        cmd.param?.data?.let { notifyCustomDataReceived(it) }
        val needsResponse = cmd.type == CommandBase.FLAG_HAVE_PARAMETER_AND_RESPONSE ||
            cmd.type == CommandBase.FLAG_NO_PARAMETER_AND_RESPONSE
        if (needsResponse) {
            bluetoothHelper.writeDataToDevice(bluetoothHelper.getConnectedDevice(), byteArrayOf())
        }
    }

    private fun notifyCustomDataReceived(data: ByteArray) {
        sendEvent(
            ExampleChannelConstants.TYPE_CUSTOM_DATA_UPDATE,
            mapOf(ExampleChannelConstants.KEY_CUSTOM_DATA to data.map { it.toInt() }),
        )
    }

    private fun sendDownloadStatusEvent(downloadEvent: DownloadFileUtil.DownloadFileEvent?) {
        val eventMap = when (downloadEvent?.type) {
            ExampleChannelConstants.STATUS_ON_PROGRESS -> mapOf(
                EventChannelConstants.KEY_STATUS to ExampleChannelConstants.STATUS_ON_PROGRESS,
                EventChannelConstants.KEY_PROGRESS to downloadEvent.progress.toInt(),
            )
            ExampleChannelConstants.STATUS_ON_STOP -> mapOf(
                EventChannelConstants.KEY_STATUS to ExampleChannelConstants.STATUS_ON_STOP,
            )
            ExampleChannelConstants.STATUS_ON_ERROR -> mapOf(
                EventChannelConstants.KEY_STATUS to ExampleChannelConstants.STATUS_ON_ERROR,
                EventChannelConstants.KEY_MESSAGE to downloadEvent.errorMsg,
            )
            ExampleChannelConstants.STATUS_ON_START -> mapOf(
                EventChannelConstants.KEY_STATUS to ExampleChannelConstants.STATUS_ON_START,
            )
            else -> mapOf(EventChannelConstants.KEY_STATUS to ExampleChannelConstants.STATUS_UNKNOWN)
        }
        sendEvent(ExampleChannelConstants.TYPE_DOWNLOAD_STATUS, eventMap)
    }

    private fun sendEvent(type: String, data: Map<String, Any>) {
        mainHandler.post {
            eventSink?.success(
                mapOf(
                    EventChannelConstants.KEY_TYPE to type,
                    EventChannelConstants.KEY_VALUE to data,
                ),
            )
        }
    }

    companion object {
        const val METHOD_CHANNEL = "com.jieli.otasdk.example/methods"
        const val EVENT_CHANNEL = "com.jieli.otasdk.example/events"
    }
}
