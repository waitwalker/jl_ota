package com.jieli.otasdk

import android.annotation.SuppressLint
import android.app.Activity
import android.bluetooth.BluetoothDevice
import android.os.Handler
import android.os.Looper
import android.view.WindowManager
import com.jieli.otasdk.data.constant.EventChannelConstants
import com.jieli.otasdk.data.constant.OtaConstant
import com.jieli.otasdk.data.model.ScanResult
import com.jieli.otasdk.data.model.device.DeviceConnection
import com.jieli.otasdk.data.model.device.ScanDevice
import com.jieli.otasdk.data.model.ota.OTAEnd
import com.jieli.otasdk.data.model.ota.OTAState
import com.jieli.otasdk.data.model.ota.OTAWorking
import com.jieli.otasdk.model.connect.ConnectViewModel
import com.jieli.otasdk.model.ota.DownloadFileViewModel
import com.jieli.otasdk.model.ota.OTAViewModel
import com.jieli.otasdk.util.DeviceUtil
import com.jieli.otasdk.util.DownloadFileUtil
import com.jieli.otasdk.util.FileUtil
import com.jieli.jl_bt_ota.constant.ErrorCode
import com.jieli.jl_bt_ota.constant.JL_Constant
import com.jieli.jl_bt_ota.util.BluetoothUtil
import com.jieli.jl_bt_ota.util.JL_Log
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

    override fun onListen(arguments: Any?, sink: EventChannel.EventSink) {
        eventSink = sink
        logHelper.setEventSink(eventSink)

        connectVM.bluetoothStateMLD.observeForever { isOpen ->
            if (!isOpen) {
                connectVM.scanDeviceList.clear()
            }
            sendEvent(
                EventChannelConstants.TYPE_BLUETOOTH_STATE, mapOf(
                    EventChannelConstants.KEY_STATE to isOpen
                )
            )
        }

        connectVM.deviceConnectionMLD.observeForever { deviceConnection ->
            sendEvent(
                EventChannelConstants.TYPE_DEVICE_CONNECTION, mapOf(
                    EventChannelConstants.KEY_STATE to deviceConnection.state
                )
            )

            updateDeviceConnection(deviceConnection)
        }

        connectVM.scanResultMLD.observeForever { result ->
            when (result.state) {
                ScanResult.SCAN_STATUS_SCANNING -> {
                    connectVM.scanDeviceList.clear()
                    sendScanDeviceList(ScanResult.SCAN_STATUS_SCANNING)
                }

                ScanResult.SCAN_STATUS_FOUND_DEV -> {
                    result.device?.let {
                        val currentList = connectVM.scanDeviceList.toMutableList()
                        val filter = connectVM.getScanFilter() ?: ""
                        if (!currentList.contains(it) && isValidDevice(it, filter)) {
                            currentList.add(it)
                            currentList.sortWith { o1, o2 ->
                                o2.rssi.compareTo(o1.rssi)
                            }
                            connectVM.scanDeviceList = currentList
                            sendScanDeviceList(ScanResult.SCAN_STATUS_FOUND_DEV)
                        }
                    }
                }

                ScanResult.SCAN_STATUS_IDLE -> {
                    sendScanDeviceList(ScanResult.SCAN_STATUS_IDLE)
                }
            }
        }

        otaViewModel.otaConnectionMLD.observeForever { otaConnection ->
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

        downloadFileVM.downloadStatusMLD.observeForever { downloadEvent ->
            sendDownloadStatusEvent(downloadEvent)
        }

        otaViewModel.fileListMLD.observeForever { files ->
            sendEvent(
                EventChannelConstants.TYPE_OTA_FILE_LIST, mapOf(
                EventChannelConstants.KEY_LIST to files.map { file ->
                    mapOf(
                        EventChannelConstants.KEY_NAME to FileUtil.getFileMsg(file),
                        EventChannelConstants.KEY_PATH to file.path
                    )
                }
            ))
        }

        otaViewModel.selectedFilePathsMLD.observeForever { selectedPaths ->
            sendEvent(
                EventChannelConstants.TYPE_SELECTED_FILE_PATHS, mapOf(
                    EventChannelConstants.KEY_LIST to selectedPaths
                )
            )
        }

        otaViewModel.mandatoryUpgradeMLD.observeForever { device ->
            sendEvent(
                EventChannelConstants.TYPE_MANDATORY_UPGRADE, mapOf(
                    EventChannelConstants.KEY_IS_REQUIRED to (device != null)
                )
            )

//            if (!otaViewModel.isOTA()) {
//                ToastUtil.showToastShort(R.string.device_must_mandatory_upgrade)
//            }
        }

        otaViewModel.otaStateMLD.observeForever { otaState ->
            handleOtaState(otaState)
        }
    }

    override fun onCancel(arguments: Any?) {
        eventSink = null
        logHelper.cleanup()
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
        ))
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

    private fun deviceToMap(item: ScanDevice) =
        mapOf(
            EventChannelConstants.KEY_NAME to DeviceUtil.getDeviceName(activity, item.device),
            EventChannelConstants.KEY_DESC to DeviceUtil.getDeviceDesc(item),
            EventChannelConstants.KEY_STATUS to item.isDevConnected()
        )

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
}