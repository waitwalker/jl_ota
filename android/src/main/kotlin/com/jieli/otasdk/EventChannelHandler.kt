package com.jieli.otasdk

import android.annotation.SuppressLint
import android.app.Activity
import android.bluetooth.BluetoothDevice
import android.os.Handler
import android.os.Looper
import android.view.WindowManager
import androidx.lifecycle.Observer
import com.jieli.otasdk.data.constant.EventChannelConstants
import com.jieli.otasdk.data.constant.OtaConstant
import com.jieli.otasdk.data.model.ScanResult
import com.jieli.otasdk.data.model.device.DeviceConnection
import com.jieli.otasdk.data.model.device.ScanDevice
import com.jieli.otasdk.data.model.ota.OTAEnd
import com.jieli.otasdk.data.model.ota.OTAState
import com.jieli.otasdk.data.model.ota.OTAWorking
import com.jieli.otasdk.model.ota.OTAViewModel
import com.jieli.otasdk.util.DeviceUtil
import com.jieli.jl_bt_ota.constant.ErrorCode
import com.jieli.jl_bt_ota.constant.JL_Constant
import com.jieli.jl_bt_ota.util.BluetoothUtil
import com.jieli.jl_bt_ota.util.CHexConver
import com.jieli.jl_bt_ota.util.JL_Log
import com.jieli.otasdk.model.connect.ConnectViewModel
import io.flutter.embedding.android.FlutterActivity
import io.flutter.plugin.common.EventChannel
import kotlin.math.roundToInt

/**
 * Flutter EventChannel 事件流分发处理器
 *
 * 负责监听底层蓝牙状态、扫描发现设备、设备连接状态以及 OTA 升级全生命周期的状态变化，
 * 并将其统一转换为结构化字典数据，实时推送给 Flutter 端的事件监听流。
 *
 * @param activity 宿主 Activity 实例，用于访问窗口管理器（如屏幕常亮）以及设备名称解析
 */
class EventChannelHandler(private val activity: Activity) : EventChannel.StreamHandler {
    /** Flutter 事件流的下发通道接收器，当外部开始监听时赋值，取消监听时置空 */
    private var eventSink: EventChannel.EventSink? = null

    /** 主线程 Handler，确保所有事件统一在主线程推送到 Flutter 端 */
    private val handler = Handler(Looper.getMainLooper())

    /** 蓝牙连接与扫描业务模型单例 */
    private val connectVM by lazy { ConnectViewModel.getInstance() }

    /** OTA 固件升级业务模型单例 */
    private val otaViewModel by lazy { OTAViewModel.getInstance() }

    /**
     * 蓝牙适配器开启/关闭状态观察者
     *
     * 当蓝牙关闭时自动清空已扫描设备列表，并向 Flutter 推送蓝牙最新开关状态
     */
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

    /**
     * 蓝牙设备连接状态变化观察者
     *
     * 向 Flutter 派发连接状态变化事件，并同步刷新扫描列表中对应设备的状态
     */
    private val deviceConnectionObserver = Observer<DeviceConnection> { deviceConnection ->
        sendEvent(
            EventChannelConstants.TYPE_DEVICE_CONNECTION, mapOf(
                EventChannelConstants.KEY_STATE to deviceConnection.state
            )
        )
        updateDeviceConnection(deviceConnection)
    }

    /**
     * 蓝牙设备扫描结果事件观察者
     */
    private val scanResultObserver = Observer<ScanResult> { result ->
        handleScanResult(result)
    }

    /**
     * 分发处理扫描状态变化
     *
     * @param result 扫描状态或发现的新设备数据
     */
    private fun handleScanResult(result: ScanResult) {
        when (result.state) {
            ScanResult.SCAN_STATUS_SCANNING -> handleScanningState()
            ScanResult.SCAN_STATUS_FOUND_DEV -> handleFoundDeviceState(result)
            ScanResult.SCAN_STATUS_IDLE -> handleIdleState()
        }
    }

    /**
     * 处理开始扫描状态：清空历史列表并下发空列表与扫描中状态
     */
    private fun handleScanningState() {
        connectVM.scanDeviceList.clear()
        sendScanDeviceList(ScanResult.SCAN_STATUS_SCANNING)
    }

    /**
     * 处理扫描到新设备状态：根据过滤规则过滤并按信号强度降序排序后推送到 Flutter
     *
     * @param result 包含扫描发现设备的扫描结果
     */
    private fun handleFoundDeviceState(result: ScanResult) {
        val device = result.device ?: return
        val filter = connectVM.getScanFilter() ?: ""

        if (shouldAddDevice(device, filter)) {
            addAndSortDevice(device)
            sendScanDeviceList(ScanResult.SCAN_STATUS_FOUND_DEV)
        }
    }

    /**
     * 校验新发现的设备是否应当加入展示列表（排重以及关键字匹配）
     *
     * @param device 待校验的扫描设备
     * @param filter 过滤关键字
     * @return true 表示符合条件且未曾添加
     */
    private fun shouldAddDevice(device: ScanDevice, filter: String): Boolean {
        val currentList = connectVM.scanDeviceList
        return !currentList.contains(device) && isValidDevice(device, filter)
    }

    /**
     * 将新设备添加进缓存列表，并按信号强度 (RSSI) 降序排序
     *
     * @param device 待加入列表的扫描设备
     */
    private fun addAndSortDevice(device: ScanDevice) {
        val currentList = connectVM.scanDeviceList.toMutableList()
        currentList.add(device)
        currentList.sortWith { o1, o2 -> o2.rssi.compareTo(o1.rssi) }
        connectVM.scanDeviceList = currentList
    }

    /**
     * 处理扫描结束（空闲）状态
     */
    private fun handleIdleState() {
        sendScanDeviceList(ScanResult.SCAN_STATUS_IDLE)
    }

    /**
     * OTA 阶段设备连接状态观察者，向 Flutter 派发 OTA 连接状态与设备类型
     */
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

    /**
     * 目标设备强制升级通知观察者，向 Flutter 派发是否需要强制升级
     */
    private val mandatoryUpgradeObserver = Observer<BluetoothDevice?> { device ->
        sendEvent(
            EventChannelConstants.TYPE_MANDATORY_UPGRADE, mapOf(
                EventChannelConstants.KEY_IS_REQUIRED to (device != null)
            )
        )
    }

    /**
     * OTA 升级生命周期状态变化观察者
     */
    private val otaStateObserver = Observer<OTAState?> { otaState ->
        handleOtaState(otaState)
    }

    /**
     * Flutter 开始监听事件流时的回调
     *
     * 保存 EventSink 句柄，并注册所有 ViewModel 的 LiveData 观察者
     *
     * @param arguments Flutter 端传递的监听入参
     * @param sink 用于向下游 Flutter 发送事件的数据槽
     */
    override fun onListen(arguments: Any?, sink: EventChannel.EventSink) {
        eventSink = sink

        connectVM.bluetoothStateMLD.observeForever(bluetoothStateObserver)
        connectVM.deviceConnectionMLD.observeForever(deviceConnectionObserver)
        connectVM.scanResultMLD.observeForever(scanResultObserver)
        otaViewModel.otaConnectionMLD.observeForever(otaConnectionObserver)
        otaViewModel.mandatoryUpgradeMLD.observeForever(mandatoryUpgradeObserver)
        otaViewModel.otaStateMLD.observeForever(otaStateObserver)
    }

    /**
     * Flutter 取消监听事件流时的回调
     *
     * 注销所有 LiveData 观察者，清空 Handler 消息队列并置空 EventSink
     *
     * @param arguments Flutter 端传递的取消参数
     */
    override fun onCancel(arguments: Any?) {
        connectVM.bluetoothStateMLD.removeObserver(bluetoothStateObserver)
        connectVM.deviceConnectionMLD.removeObserver(deviceConnectionObserver)
        connectVM.scanResultMLD.removeObserver(scanResultObserver)
        otaViewModel.otaConnectionMLD.removeObserver(otaConnectionObserver)
        otaViewModel.mandatoryUpgradeMLD.removeObserver(mandatoryUpgradeObserver)
        otaViewModel.otaStateMLD.removeObserver(otaStateObserver)

        handler.removeCallbacksAndMessages(null)
        eventSink = null
    }

    /**
     * 统一向 Flutter 端派发封装后的结构化事件字典
     *
     * 保证派发动作在 Android 主线程执行
     *
     * @param type 事件大类标识（参考 [EventChannelConstants]）
     * @param data 事件携带的键值对数据
     */
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

    /**
     * 向 Flutter 派发当前扫描状态与完整已扫描设备列表
     *
     * @param scanStatus 扫描状态标识（如正在扫描、发现设备或空闲）
     */
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

    /**
     * 从原始 BLE 广播包 (scanRecord) 中解析并提取纯 0xFF 厂商自定义数据
     *
     * @param scanRecord 原始扫描广播字节数组
     * @return 提取出的厂商自定义数据 ByteArray；若未命中则返回 null
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
     *
     * @param scanRecord 原始扫描广播字节数组
     * @return 解析出的广播名称；若未命中则返回 null
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

    /**
     * 将扫描到的设备模型 [ScanDevice] 序列化转换为供 Flutter 消费的 Map
     *
     * 包含设备名称、描述、连接状态、广播自定义数据 Hex、广播名称等字段。
     *
     * @param item 扫描到的设备实体
     * @return 序列化后的 Map 结构
     */
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

    /**
     * 判断设备是否满足名称或 MAC 地址前缀过滤条件
     *
     * @param scanDevice 待校验设备
     * @param filterStr 过滤关键字
     * @return true 表示符合过滤条件
     */
    @SuppressLint("MissingPermission")
    private fun isValidDevice(scanDevice: ScanDevice, filterStr: String): Boolean {
        if (filterStr.isBlank()) return true
        val content = scanDevice.device.name
            ?.takeIf { it.isNotBlank() }
            ?: scanDevice.device.address
        return content.startsWith(filterStr, ignoreCase = true)
    }

    /**
     * 处理并派发 OTA 升级各状态事件
     *
     * 负责开启/关闭屏幕常亮、转换各阶段（开始、回连、传输进度、结束与异常信息）并推送到 Flutter
     *
     * @param otaState 升级状态包装实体
     */
    private fun handleOtaState(otaState: OTAState?) {
        if (otaState == null) return

        when (otaState.state) {
            OTAState.OTA_STATE_START -> {
                // 设置屏幕常亮，防止系统休眠中断升级
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
                    ErrorCode.SUB_ERR_DATA_NOT_FOUND -> EventChannelConstants.MSG_NO_OTA_FILE

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
     * 设置或清除屏幕常亮标志，避免 OTA 传输过程中手机息屏休眠导致蓝牙断连
     *
     * @param keepOn true 为保持屏幕常亮，false 为恢复系统默认息屏行为
     */
    private fun setKeepScreenOn(keepOn: Boolean) {
        try {
            if (activity is FlutterActivity) {
                val flutterActivity = activity
                if (keepOn) {
                    // 设置屏幕常亮 Flag
                    flutterActivity.window.addFlags(WindowManager.LayoutParams.FLAG_KEEP_SCREEN_ON)
                } else {
                    // 清除屏幕常亮 Flag
                    flutterActivity.window.clearFlags(WindowManager.LayoutParams.FLAG_KEEP_SCREEN_ON)
                }
            }
        } catch (e: Exception) {
            JL_Log.e("EventChannelHandler", "setKeepScreenOn fail: ${e.message}")
        }
    }

    /**
     * 收到设备连接状态变化时，同步更新已扫描设备列表中对应项的连接状态
     *
     * @param connection 最新的设备连接实体
     */
    private fun updateDeviceConnection(connection: DeviceConnection) {
        val item = findItemByDevice(connection.device) ?: return
        if (item.state != connection.state) {
            item.state = connection.state
            sendScanDeviceList(ScanResult.SCAN_STATUS_IDLE)
        }
    }

    /**
     * 根据蓝牙物理设备在已扫描列表中查找匹配的 [ScanDevice] 项
     *
     * @param device 待查找的蓝牙设备
     * @return 匹配的 [ScanDevice]，未找到则返回 null
     */
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
