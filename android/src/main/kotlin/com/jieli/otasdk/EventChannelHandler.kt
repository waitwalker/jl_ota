package com.jieli.otasdk

import android.annotation.SuppressLint
import android.app.Activity
import android.bluetooth.BluetoothDevice
import android.os.Handler
import android.os.Looper
import android.view.WindowManager
import androidx.lifecycle.Observer
import com.jieli.jl_bt_ota.constant.Command
import com.jieli.otasdk.data.constant.EventChannelConstants
import com.jieli.otasdk.data.constant.OtaConstant
import com.jieli.otasdk.data.model.ScanResult
import com.jieli.otasdk.data.model.device.DeviceConnection
import com.jieli.otasdk.data.model.device.ScanDevice
import com.jieli.otasdk.data.model.ota.OTAEnd
import com.jieli.otasdk.data.model.ota.OTAState
import com.jieli.otasdk.data.model.ota.OTAWorking
import com.jieli.otasdk.model.ota.DownloadFileViewModel
import com.jieli.otasdk.model.ota.OTAViewModel
import com.jieli.otasdk.util.DeviceUtil
import com.jieli.otasdk.util.DownloadFileUtil
import com.jieli.otasdk.util.FileUtil
import com.jieli.jl_bt_ota.constant.ErrorCode
import com.jieli.jl_bt_ota.constant.JL_Constant
import com.jieli.jl_bt_ota.constant.StateCode
import com.jieli.jl_bt_ota.util.BluetoothUtil
import com.jieli.jl_bt_ota.util.CHexConver
import com.jieli.jl_bt_ota.util.JL_Log
import com.jieli.jl_bt_ota.interfaces.rcsp.OnRcspCallback
import com.jieli.jl_bt_ota.model.base.CommandBase
import com.jieli.jl_bt_ota.model.command.CustomCmd
import com.jieli.jl_bt_ota.model.parameter.CustomParam
import com.jieli.otasdk.model.connect.ConnectViewModel
import com.jieli.otasdk.tool.bluetooth.BluetoothHelper
import io.flutter.embedding.android.FlutterActivity
import io.flutter.plugin.common.EventChannel
import kotlin.math.roundToInt

/**
 * Des:
 * author: lifang
 * date: 2025/07/29
 * Copyright: Jieli Technology
 * Modify date:
 * Modified by:
 */
class EventChannelHandler(private val activity: Activity) : EventChannel.StreamHandler {
    private var eventSink: EventChannel.EventSink? = null
    private val handler = Handler(Looper.getMainLooper())
    private val connectVM by lazy { ConnectViewModel.getInstance() }
    private val otaViewModel by lazy { OTAViewModel.getInstance() }
    private val downloadFileVM by lazy { DownloadFileViewModel.getInstance() }
    private val logHelper by lazy { LogHelper.getInstance() }
    private val bluetoothHelper: BluetoothHelper by lazy { BluetoothHelper.getInstance() }
    private var rcspCallback: OnRcspCallback? = null

    private val bluetoothStateObserver = Observer<Boolean> { isOpen ->
        if (!isOpen) {
            connectVM.scanDeviceList.clear()
        }
        sendEvent(
            EventChannelConstants.TYPE_BLUETOOTH_STATE, mapOf(
                EventChannelConstants.KEY_STATE to isOpen
            )
        )
    }

    private val deviceConnectionObserver = Observer<DeviceConnection> { deviceConnection ->
        sendEvent(
            EventChannelConstants.TYPE_DEVICE_CONNECTION, mapOf(
                EventChannelConstants.KEY_STATE to deviceConnection.state
            )
        )
        updateDeviceConnection(deviceConnection)
    }

    private val scanResultObserver = Observer<ScanResult> { result ->
        handleScanResult(result)
    }

    private fun handleScanResult(result: ScanResult) {
        when (result.state) {
            ScanResult.SCAN_STATUS_SCANNING -> handleScanningState()
            ScanResult.SCAN_STATUS_FOUND_DEV -> handleFoundDeviceState(result)
            ScanResult.SCAN_STATUS_IDLE -> handleIdleState()
        }
    }

    private fun handleScanningState() {
        connectVM.scanDeviceList.clear()
        sendScanDeviceList(ScanResult.SCAN_STATUS_SCANNING)
    }

    private fun handleFoundDeviceState(result: ScanResult) {
        val device = result.device ?: return
        val filter = connectVM.getScanFilter() ?: ""

        if (shouldAddDevice(device, filter)) {
            addAndSortDevice(device)
            sendScanDeviceList(ScanResult.SCAN_STATUS_FOUND_DEV)
        }
    }

    private fun shouldAddDevice(device: ScanDevice, filter: String): Boolean {
        val currentList = connectVM.scanDeviceList
        return !currentList.contains(device) && isValidDevice(device, filter)
    }

    private fun addAndSortDevice(device: ScanDevice) {
        val currentList = connectVM.scanDeviceList.toMutableList()
        currentList.add(device)
        currentList.sortWith { o1, o2 -> o2.rssi.compareTo(o1.rssi) }
        connectVM.scanDeviceList = currentList
    }

    private fun handleIdleState() {
        sendScanDeviceList(ScanResult.SCAN_STATUS_IDLE)
    }

    private val otaConnectionObserver = Observer<DeviceConnection> { otaConnection ->
        sendEvent(
            EventChannelConstants.TYPE_OTA_CONNECTION, mapOf(
                EventChannelConstants.KEY_STATE to otaConnection.state,
                EventChannelConstants.KEY_DEVICE_TYPE to DeviceUtil.getBtDeviceTypeString(
                    activity,
                    otaConnection.device
                )
            )
        )
    }

    private val downloadStatusObserver = Observer<DownloadFileUtil.DownloadFileEvent?> { downloadEvent ->
        sendDownloadStatusEvent(downloadEvent)
    }

    private val fileListObserver = Observer<List<java.io.File>> { files ->
        sendEvent(
            EventChannelConstants.TYPE_OTA_FILE_LIST, mapOf(
                EventChannelConstants.KEY_LIST to files.map { file ->
                    mapOf(
                        EventChannelConstants.KEY_NAME to FileUtil.getFileMsg(file),
                        EventChannelConstants.KEY_PATH to file.path
                    )
                }
            )
        )
    }

    private val selectedFilePathsObserver = Observer<List<String>> { selectedPaths ->
        sendEvent(
            EventChannelConstants.TYPE_SELECTED_FILE_PATHS, mapOf(
                EventChannelConstants.KEY_LIST to selectedPaths
            )
        )
    }

    private val mandatoryUpgradeObserver = Observer<BluetoothDevice?> { device ->
        sendEvent(
            EventChannelConstants.TYPE_MANDATORY_UPGRADE, mapOf(
                EventChannelConstants.KEY_IS_REQUIRED to (device != null)
            )
        )
        // if (!otaViewModel.isOTA()) {
        //     ToastUtil.showToastShort(R.string.device_must_mandatory_upgrade)
        // }
    }

    private val otaStateObserver = Observer<OTAState?> { otaState ->
        handleOtaState(otaState)
    }

    override fun onListen(arguments: Any?, sink: EventChannel.EventSink) {
        eventSink = sink
        logHelper.setEventSink(eventSink)

        connectVM.bluetoothStateMLD.observeForever(bluetoothStateObserver)
        connectVM.deviceConnectionMLD.observeForever(deviceConnectionObserver)
        connectVM.scanResultMLD.observeForever(scanResultObserver)
        otaViewModel.otaConnectionMLD.observeForever(otaConnectionObserver)
        downloadFileVM.downloadStatusMLD.observeForever(downloadStatusObserver)
        otaViewModel.fileListMLD.observeForever(fileListObserver)
        otaViewModel.selectedFilePathsMLD.observeForever(selectedFilePathsObserver)
        otaViewModel.mandatoryUpgradeMLD.observeForever(mandatoryUpgradeObserver)
        otaViewModel.otaStateMLD.observeForever(otaStateObserver)

        rcspCallback = object : OnRcspCallback() {
            override fun onRcspCommand(device: BluetoothDevice, cmd: CommandBase<*, *>) {
                if (cmd.id != Command.CMD_EXTRA_CUSTOM || cmd !is CustomCmd) return
                handleReceivedCustomCommand(bluetoothHelper.getConnectedDevice(),cmd)
            }
        }

        rcspCallback?.let {
            otaViewModel.otaManager.addOnRcspCallback(it)
        }
    }

    override fun onCancel(arguments: Any?) {
        connectVM.bluetoothStateMLD.removeObserver(bluetoothStateObserver)
        connectVM.deviceConnectionMLD.removeObserver(deviceConnectionObserver)
        connectVM.scanResultMLD.removeObserver(scanResultObserver)
        otaViewModel.otaConnectionMLD.removeObserver(otaConnectionObserver)
        downloadFileVM.downloadStatusMLD.removeObserver(downloadStatusObserver)
        otaViewModel.fileListMLD.removeObserver(fileListObserver)
        otaViewModel.selectedFilePathsMLD.removeObserver(selectedFilePathsObserver)
        otaViewModel.mandatoryUpgradeMLD.removeObserver(mandatoryUpgradeObserver)
        otaViewModel.otaStateMLD.removeObserver(otaStateObserver)

        handler.removeCallbacksAndMessages(null)
        otaViewModel.otaManager.removeRcspCallback(rcspCallback)

        eventSink = null
        logHelper.cleanUp()
    }

    private fun sendEvent(type: String, data: Map<String, Any>) {
        handler.post {
            eventSink?.success(
                mapOf(
                    EventChannelConstants.KEY_TYPE to type,
                    EventChannelConstants.KEY_VALUE to data
                )
            )
        }
    }

    private fun sendScanDeviceList(scanStatus: Int) {
        val scanState = when (scanStatus) {
            ScanResult.SCAN_STATUS_SCANNING -> EventChannelConstants.SCAN_STATE_SCANNING
            ScanResult.SCAN_STATUS_FOUND_DEV -> EventChannelConstants.SCAN_STATE_FOUND_DEV
            ScanResult.SCAN_STATUS_IDLE -> EventChannelConstants.SCAN_STATE_IDLE
            else -> EventChannelConstants.SCAN_STATE_IDLE
        }
        sendEvent(
            EventChannelConstants.TYPE_SCAN_DEVICE_LIST, mapOf(
                EventChannelConstants.KEY_STATE to scanState,
                EventChannelConstants.KEY_LIST to connectVM.scanDeviceList.map { deviceToMap(it) }
            )
        )
    }

    private fun sendDownloadStatusEvent(downloadEvent: DownloadFileUtil.DownloadFileEvent?) {
        val eventMap = when (downloadEvent?.type) {
            EventChannelConstants.STATUS_ON_PROGRESS -> mapOf(
                EventChannelConstants.KEY_STATUS to EventChannelConstants.STATUS_ON_PROGRESS,
                EventChannelConstants.KEY_PROGRESS to downloadEvent.progress.toInt()
            )

            EventChannelConstants.STATUS_ON_STOP -> mapOf(
                EventChannelConstants.KEY_STATUS to EventChannelConstants.STATUS_ON_STOP
            )

            EventChannelConstants.STATUS_ON_ERROR -> mapOf(
                EventChannelConstants.KEY_STATUS to EventChannelConstants.STATUS_ON_ERROR,
                EventChannelConstants.KEY_MESSAGE to downloadEvent.errorMsg
            )

            EventChannelConstants.STATUS_ON_START -> mapOf(
                EventChannelConstants.KEY_STATUS to EventChannelConstants.STATUS_ON_START
            )

            else -> mapOf(
                EventChannelConstants.KEY_STATUS to EventChannelConstants.STATUS_UNKNOWN
            )
        }
        sendEvent(EventChannelConstants.TYPE_DOWNLOAD_STATUS, eventMap)
    }


    /**
     * 从原始 BLE 广播包 (scanRecord) 中解析并提取纯 0xFF 厂商自定义数据
     */
    private fun extractManufacturerData(scanRecord: ByteArray?): ByteArray? {
        if (scanRecord == null || scanRecord.isEmpty()) return null
        var index = 0
        while (index < scanRecord.size) {
            val length = scanRecord[index].toInt() and 0xFF
            if (length == 0 || index + 1 + length > scanRecord.size) break

            val type = scanRecord[index + 1].toInt() and 0xFF
            if (type == 0xFF && length >= 3) {
                // 命中 0xFF 厂商数据，截取 0xFF 之后、长度为 length - 1 的纯厂商数据
                return scanRecord.copyOfRange(index + 2, index + 1 + length)
            }
            index += 1 + length
        }
        return null
    }

    /**
     * 从原始 BLE 广播包 (scanRecord) 中解析设备名称 (Type 0x08 Shortened 或 0x09 Complete Local Name)
     */
    private fun extractLocalName(scanRecord: ByteArray?): String? {
        if (scanRecord == null || scanRecord.isEmpty()) return null
        var index = 0
        while (index < scanRecord.size) {
            val length = scanRecord[index].toInt() and 0xFF
            if (length == 0 || index + 1 + length > scanRecord.size) break

            val type = scanRecord[index + 1].toInt() and 0xFF
            if ((type == 0x08 || type == 0x09) && length > 1) {
                return try {
                    String(scanRecord, index + 2, length - 1, Charsets.UTF_8).trim()
                } catch (e: Exception) {
                    null
                }
            }
            index += 1 + length
        }
        return null
    }

    private fun deviceToMap(item: ScanDevice): Map<String, Any?> {
        // 优先提取纯 0xFF 厂商数据；若不是标准 TLV 则回退使用 item.data
        val mfgBytes = extractManufacturerData(item.data) ?: item.data
        val rawHex = if (mfgBytes != null && mfgBytes.isNotEmpty()) {
            CHexConver.byte2HexStr(mfgBytes)
        } else {
            ""
        }

        // 优先使用系统名称，若为空则从广播包中提取 Local Name 兜底
        val localName = extractLocalName(item.data)
        val bleName = item.device.name?.takeIf { it.isNotBlank() } ?: localName ?: ""

        val advData = mutableMapOf<String, Any?>()
        advData["manufacturer_data"] = rawHex
        advData["ble_name"] = bleName

        val devName = DeviceUtil.getDeviceName(activity, item.device).takeIf { it != "N/A" && it.isNotBlank() }
            ?: localName
            ?: "N/A"

        return mapOf(
            EventChannelConstants.KEY_NAME to devName,
            EventChannelConstants.KEY_DESC to DeviceUtil.getDeviceDesc(item),
            EventChannelConstants.KEY_STATUS to item.isDevConnected(),
            "adv_data" to advData
        )
    }


    @SuppressLint("MissingPermission")
    private fun isValidDevice(scanDevice: ScanDevice, filterStr: String): Boolean {
        if (filterStr.isBlank()) return true
        val content = scanDevice.device.name
            ?.takeIf { it.isNotBlank() }
            ?: scanDevice.device.address
        return content.startsWith(filterStr, ignoreCase = true)
    }

    private fun handleOtaState(otaState: OTAState?) {
        if (otaState == null) return

        when (otaState.state) {
            OTAState.OTA_STATE_START -> {
                // 设置屏幕常亮
                setKeepScreenOn(true)
                sendEvent(
                    EventChannelConstants.TYPE_OTA_STATE, mapOf(
                        EventChannelConstants.KEY_STATE to EventChannelConstants.STATE_START
                    )
                )
            }

            OTAState.OTA_STATE_RECONNECT -> {
                sendEvent(
                    EventChannelConstants.TYPE_OTA_STATE, mapOf(
                        EventChannelConstants.KEY_STATE to EventChannelConstants.STATE_RECONNECT
                    )
                )
            }

            OTAState.OTA_STATE_WORKING -> {
                val otaWorking = otaState as OTAWorking
                sendEvent(
                    EventChannelConstants.TYPE_OTA_STATE, mapOf(
                        EventChannelConstants.KEY_STATE to EventChannelConstants.STATE_WORKING,
                        EventChannelConstants.KEY_TYPE to if (otaWorking.type == JL_Constant.TYPE_CHECK_FILE) EventChannelConstants.MSG_CHECKING_FILE else EventChannelConstants.MSG_UPGRADING,
                        EventChannelConstants.KEY_PROGRESS to otaWorking.progress.roundToInt()
                    )
                )
            }

            OTAState.OTA_STATE_IDLE -> {
                // 清除屏幕常亮
                setKeepScreenOn(false)
                val otaEnd = otaState as OTAEnd
                val isUpgradeSuccess = otaEnd.code == ErrorCode.ERR_NONE

                val otaMsg = when (otaEnd.code) {
                    ErrorCode.ERR_NONE -> EventChannelConstants.MSG_SUCCESS
                    ErrorCode.ERR_UNKNOWN -> EventChannelConstants.MSG_UNKNOWN_ERROR
                    ErrorCode.SUB_ERR_OTA_IN_HANDLE -> EventChannelConstants.MSG_OTA_IN_PROGRESS
                    ErrorCode.SUB_ERR_DATA_NOT_FOUND -> {
                        otaViewModel.readFileList()
                        EventChannelConstants.MSG_NO_OTA_FILE
                    }

                    else -> OtaConstant.formatString(
                        "code: %d(0x%X), %s", otaEnd.code, otaEnd.code, otaEnd.message
                    )
                }

                sendEvent(
                    EventChannelConstants.TYPE_OTA_STATE, mapOf(
                        EventChannelConstants.KEY_STATE to EventChannelConstants.STATE_IDLE,
                        EventChannelConstants.KEY_SUCCESS to isUpgradeSuccess,
                        EventChannelConstants.KEY_CODE to otaEnd.code,
                        EventChannelConstants.KEY_MESSAGE to otaMsg
                    )
                )
            }

            else -> {
                sendEvent(
                    EventChannelConstants.TYPE_OTA_STATE, mapOf(
                        EventChannelConstants.KEY_STATE to EventChannelConstants.STATE_UNKNOWN
                    )
                )
            }
        }
    }

    /**
     * Sets or clears the screen always-on flag
     * @param keepOn true: Keep screen always on, false: Allow screen to turn off
     */
    private fun setKeepScreenOn(keepOn: Boolean) {
        try {
            if (activity is FlutterActivity) {
                val flutterActivity = activity
                if (keepOn) {
                    // Set screen always-on flag
                    flutterActivity.window.addFlags(WindowManager.LayoutParams.FLAG_KEEP_SCREEN_ON)
                } else {
                    // Clear screen always-on flag
                    flutterActivity.window.clearFlags(WindowManager.LayoutParams.FLAG_KEEP_SCREEN_ON)
                }
            }
        } catch (e: Exception) {
            JL_Log.e("EventChannelHandler", "setKeepScreenOn fail: ${e.message}")
        }
    }

    private fun updateDeviceConnection(connection: DeviceConnection) {
        val item = findItemByDevice(connection.device) ?: return
        if (item.state != connection.state) {
            item.state = connection.state
            sendScanDeviceList(ScanResult.SCAN_STATUS_IDLE)
        }
    }

    private fun findItemByDevice(device: BluetoothDevice?): ScanDevice? {
        if (null == device) return null
        for (item in connectVM.scanDeviceList) {
            if (BluetoothUtil.deviceEquals(device, item.device)) {
                return item
            }
        }
        return null
    }

    private fun handleReceivedCustomCommand(device: BluetoothDevice?, cmd: CustomCmd) {
        val param = cmd.param
        val isNeedResponse = cmd.isResponseRequired

        param?.data?.let { data ->
            notifyCustomDataReceived(data)
        }

        if (isNeedResponse) {
            sendResponseToDevice(bluetoothHelper.getConnectedDevice(), cmd)
        }
    }

    private fun notifyCustomDataReceived(data: ByteArray) {
        val dataList = data.map { it.toInt() }.toList()

        val eventData = mapOf<String, Any>(
            EventChannelConstants.KEY_CUSTOM_DATA to dataList
        )

        sendEvent(
            EventChannelConstants.TYPE_CUSTOM_DATA_UPDATE,
            eventData
        )
    }

    private fun sendResponseToDevice(device: BluetoothDevice?, cmd: CustomCmd) {
        val responseData = generateResponseData(cmd)
        bluetoothHelper.writeDataToDevice(device,responseData)
    }

    private fun generateResponseData(cmd: CustomCmd): ByteArray {
        return byteArrayOf()
    }

    private val CommandBase<*, *>.isResponseRequired: Boolean
        get() = type == CommandBase.FLAG_HAVE_PARAMETER_AND_RESPONSE ||
                type == CommandBase.FLAG_NO_PARAMETER_AND_RESPONSE
}