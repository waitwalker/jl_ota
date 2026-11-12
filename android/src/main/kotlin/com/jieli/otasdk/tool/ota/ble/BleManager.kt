package com.jieli.otasdk.tool.ota.ble

import android.annotation.SuppressLint
import android.bluetooth.BluetoothAdapter
import android.bluetooth.BluetoothDevice
import android.bluetooth.BluetoothGatt
import android.bluetooth.BluetoothGattCallback
import android.bluetooth.BluetoothGattCharacteristic
import android.bluetooth.BluetoothGattDescriptor
import android.bluetooth.BluetoothGattService
import android.bluetooth.BluetoothManager
import android.bluetooth.BluetoothProfile
import android.bluetooth.BluetoothStatusCodes
import android.bluetooth.le.BluetoothLeScanner
import android.bluetooth.le.ScanCallback
import android.bluetooth.le.ScanFilter
import android.bluetooth.le.ScanResult
import android.bluetooth.le.ScanSettings
import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.content.IntentFilter
import android.os.Build
import android.os.Handler
import android.os.Looper
import android.os.Message
import android.os.SystemClock
import android.text.TextUtils
import com.jieli.jl_bt_ota.constant.BluetoothConstant
import com.jieli.jl_bt_ota.util.BluetoothUtil
import com.jieli.jl_bt_ota.util.CHexConver
import com.jieli.jl_bt_ota.util.CommonUtil
import com.jieli.jl_bt_ota.util.JL_Log
import com.jieli.jl_bt_ota.util.UuidUtil
import com.jieli.otasdk.OtaRuntime
import com.jieli.otasdk.tool.config.ConfigHelper
import com.jieli.otasdk.tool.ota.ble.interfaces.BleEventCallback
import com.jieli.otasdk.tool.ota.ble.interfaces.OnWriteDataCallback
import com.jieli.otasdk.tool.ota.ble.model.BleConnectParam
import com.jieli.otasdk.tool.ota.ble.model.BleDevice
import com.jieli.otasdk.tool.ota.ble.model.BleScanInfo
import com.jieli.otasdk.tool.ota.ble.model.BleSendTask
import com.jieli.otasdk.util.AppUtil
import com.jieli.otasdk.util.ReConnectHelper
import java.util.Locale
import java.util.UUID

/**
 * BLE 低功耗蓝牙底层连接管理核心类
 *
 * 负责 BLE 扫描（BluetoothLeScanner）、连接与断开生命周期管理、
 * GATT 服务发现、特征值通知使能（Descriptor 写入重试）、MTU 协商、数据异步发送及断开重连。
 *
 * @param context 上下文对象
 */
class BleManager private constructor(context: Context) {
    /** 应用程序 Application 上下文引用 */
    private val mContext: Context = CommonUtil.checkNotNull(context)

    /** 全局配置助手单例引用 */
    private val configHelper = ConfigHelper.getInstance()

    /** 系统底层蓝牙适配器 */
    private val mBluetoothAdapter: BluetoothAdapter? = AppUtil.getBluetoothAdapter(mContext)

    /**
     * 取当前 BLE 扫描器。
     *
     * 蓝牙关闭时 [BluetoothAdapter.getBluetoothLeScanner] 返回 null，不能在构造时缓存。
     */
    private fun bluetoothLeScanner(): BluetoothLeScanner? = mBluetoothAdapter?.bluetoothLeScanner

    /** 当前缓存的所有 BLE 已连接/连接中设备映射表（以 MAC 地址为 Key） */
    private val mBleDeviceMap = HashMap<String, BleDevice>()

    /** 本次扫描生命周期中已捕获发现的设备缓存列表（用于排重） */
    private val mDiscoveredBleDevices = ArrayList<BluetoothDevice>()

    /** BLE 事件观察者回调管理器 */
    private val mCallbackManager = BleEventCallbackManager()

    /** 标志位：当前是否处于 BLE 扫描中 */
    @Volatile
    private var bleScanningFlag = false

    /** 监听系统蓝牙状态广播接收器 */
    private var mAdapterReceiver: BaseBtAdapterReceiver? = null

    /** 特征值通知开启 Runnable，用于失败后重试 */
    private var mNotifyCharacteristicRunnable: NotifyCharacteristicRunnable? = null

    /** 异步同步系统已连接 BLE 设备的后台线程 */
    private var checkSystemBleThread: CheckSystemBleThread? = null

    /**
     * BluetoothLeScanner 扫描回调
     */
    private val mScanCallback = object : ScanCallback() {
        override fun onScanResult(callbackType: Int, result: ScanResult) {
            val record = result.scanRecord ?: return
            val device = result.device
            var isBleEnableConnect = true
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                isBleEnableConnect = result.isConnectable
            }
            filterDevice(device, result.rssi, record.bytes, isBleEnableConnect)
        }

        override fun onScanFailed(errorCode: Int) {
            JL_Log.w(TAG, "onScanFailed", "code : $errorCode")
            if (errorCode == SCAN_FAILED_ALREADY_STARTED) return
            stopLeScan()
        }
    }

    /**
     * 系统 BluetoothGattCallback 核心回调处理
     *
     * 监控连接状态变更、服务发现完成、特征值写入完成、特征值变化通知、Descriptor 写入及 MTU 变更
     */
    private val mBluetoothGattCallback = object : BluetoothGattCallback() {
        /**
         * 隐藏 API。编译桩里没有这个方法，运行时由系统按同名签名回调连接参数更新
         */
        fun onConnectionUpdated(gatt: BluetoothGatt?, interval: Int, latency: Int, timeout: Int, status: Int) {
            if (gatt == null || !AppUtil.checkHasConnectPermission(mContext)) return
            val device = gatt.device ?: return
            JL_Log.e(
                TAG,
                "onConnectionUpdated",
                "device : " + printDeviceInfo(device) + ", interval : " +
                    interval + ", latency : " + latency + ", timeout : " + timeout + ", status : " + status,
            )
            mCallbackManager.onConnectionUpdated(device, interval, latency, timeout, status)
        }

        @SuppressLint("MissingPermission")
        override fun onConnectionStateChange(gatt: BluetoothGatt, status: Int, newState: Int) {
            val device = gatt.device ?: return
            val bleDevice = getBleDevice(device) ?: return
            JL_Log.i(
                TAG,
                "onConnectionStateChange",
                CommonUtil.formatString(
                    "device : %s, status = %d, newState = %s.\n%s",
                    printDeviceInfo(device),
                    status,
                    BluetoothUtil.printBtConnectionState(newState),
                    bleDevice,
                ),
            )
            if (newState == BluetoothProfile.STATE_DISCONNECTED || newState == BluetoothProfile.STATE_DISCONNECTING ||
                newState == BluetoothProfile.STATE_CONNECTED
            ) {
                removeTimeTask(MSG_CONNECT_BLE_TIMEOUT)
                if (newState == BluetoothProfile.STATE_CONNECTED) {
                    bleDevice.setGatt(gatt)
                    startTimeoutTask(MSG_DISCOVER_SERVICES_TIMEOUT, device, CALLBACK_TIMEOUT)
                    val ret = gatt.discoverServices()
                    JL_Log.d(TAG, "onConnectionStateChange", "discoverServices : $ret")
                    if (!ret) {
                        disconnectBleDevice(device)
                    }
                    return
                } else {
                    removeTimeTask(MSG_DISCOVER_SERVICES_TIMEOUT)
                    removeTimeTask(MSG_DISCONNECT_BLE_TIMEOUT)
                    if (newState == BluetoothProfile.STATE_DISCONNECTED) {
                        closeGatt(gatt)
                        if (!bleDevice.isConnected()) {
                            val usedConnectTime = System.currentTimeMillis() - bleDevice.getConnectedTime()
                            val needReconnect = bleDevice.isNeedReconnect() || (bleDevice.getParam().isNeedReconnect() &&
                                status != 19 && usedConnectTime > 0 && usedConnectTime < MIN_CONNECT_TIME)
                            JL_Log.d(
                                TAG,
                                "onConnectionStateChange",
                                "usedConnectTime = " + usedConnectTime + ", limit time = " + MIN_CONNECT_TIME +
                                    ", isNeedReconnect = " + needReconnect,
                            )
                            if (needReconnect) {
                                bleDevice.setNeedReconnect(false)
                                if (!bleDevice.isOverReconnectLimit()) {
                                    JL_Log.i(TAG, "onConnectionStateChange", "reconnectBleDevice")
                                    connectBleDevice(device, bleDevice.getParam())
                                    return
                                }
                            }
                        }
                        handleBleConnection(device, BluetoothProfile.STATE_DISCONNECTED)
                    }
                }
            }
        }

        @SuppressLint("MissingPermission")
        override fun onServicesDiscovered(gatt: BluetoothGatt, status: Int) {
            val device = gatt.device ?: return
            val bleDevice = getBleDevice(device) ?: return
            val isSuccess = status == BluetoothGatt.GATT_SUCCESS
            JL_Log.i(
                TAG,
                "onServicesDiscovered",
                CommonUtil.formatString(
                    "device : %s, status = %d, isSuccess = %s",
                    printDeviceInfo(device),
                    status,
                    isSuccess,
                ),
            )
            removeTimeTask(MSG_DISCOVER_SERVICES_TIMEOUT)
            AppUtil.printBleGattServices(mContext, device, gatt, status)
            if (!isSuccess) {
                disconnectBleDevice(device)
                return
            }
            mCallbackManager.onBleServiceDiscovery(device, status, gatt.services)
            val serviceUuid = bleDevice.getParam().getOtaServiceUUID()
            val notificationUuid = bleDevice.getParam().getOtaNotifyCharacteristicUUID()
            if (serviceUuid != null && notificationUuid != null) {
                val notifyRunnable = NotifyCharacteristicRunnable(gatt, serviceUuid, notificationUuid)
                mNotifyCharacteristicRunnable = notifyRunnable
                mHandler.post(notifyRunnable)
            } else {
                handleBleConnection(device, BluetoothProfile.STATE_CONNECTED)
            }
        }

        override fun onCharacteristicChanged(
            gatt: BluetoothGatt,
            characteristic: BluetoothGattCharacteristic,
            value: ByteArray,
        ) {
            dispatchCharacteristicChanged(gatt, characteristic, value)
        }

        @Deprecated("Deprecated in Java")
        @Suppress("DEPRECATION", "OVERRIDE_DEPRECATION")
        override fun onCharacteristicChanged(gatt: BluetoothGatt, characteristic: BluetoothGattCharacteristic) {
            dispatchCharacteristicChanged(gatt, characteristic, characteristic.value)
        }

        private fun dispatchCharacteristicChanged(
            gatt: BluetoothGatt,
            characteristic: BluetoothGattCharacteristic,
            value: ByteArray?,
        ) {
            val device = gatt.device ?: return
            var serviceUuid: UUID? = null
            val characteristicUuid = characteristic.uuid
            val bluetoothGattService = characteristic.service
            if (bluetoothGattService != null) {
                serviceUuid = bluetoothGattService.uuid
            }
            JL_Log.d(
                TAG,
                "onCharacteristicChanged",
                CommonUtil.formatString(
                    "device : %s, serviceUuid : %s, characteristicUuid : %s, \nvalue : [%s]",
                    printDeviceInfo(device),
                    UuidUtil.read16BitUUID(serviceUuid),
                    UuidUtil.read16BitUUID(characteristicUuid),
                    CHexConver.byte2HexStr(value),
                ),
            )
            mCallbackManager.onBleDataNotification(device, serviceUuid, characteristicUuid, value)
        }

        override fun onCharacteristicWrite(gatt: BluetoothGatt, characteristic: BluetoothGattCharacteristic, status: Int) {
            val device = gatt.device ?: return
            var serviceUuid: UUID? = null
            val characteristicUuid = characteristic.uuid
            val bluetoothGattService = characteristic.service
            if (bluetoothGattService != null) {
                serviceUuid = bluetoothGattService.uuid
            }
            val value = getBleDevice(device)?.peekLastWritePayload()
            JL_Log.d(
                TAG,
                "onCharacteristicWrite",
                CommonUtil.formatString(
                    "device : %s, serviceUuid : %s, characteristicUuid : %s, status : %d, \nvalue : [%s]",
                    printDeviceInfo(device),
                    UuidUtil.read16BitUUID(serviceUuid),
                    UuidUtil.read16BitUUID(characteristicUuid),
                    status,
                    CHexConver.byte2HexStr(value),
                ),
            )
            wakeupSendThread(gatt, serviceUuid, characteristicUuid, status, value)
            mCallbackManager.onBleWriteStatus(device, serviceUuid, characteristicUuid, value, status)
        }

        @SuppressLint("MissingPermission")
        override fun onDescriptorWrite(gatt: BluetoothGatt, descriptor: BluetoothGattDescriptor, status: Int) {
            val device = gatt.device ?: return
            var serviceUuid: UUID? = null
            var characteristicUuid: UUID? = null
            val descriptorUuid = descriptor.uuid
            val characteristic = descriptor.characteristic
            if (characteristic != null) {
                characteristicUuid = characteristic.uuid
                val bluetoothGattService = characteristic.service
                if (bluetoothGattService != null) {
                    serviceUuid = bluetoothGattService.uuid
                }
            }
            JL_Log.i(
                TAG,
                "onDescriptorWrite",
                CommonUtil.formatString(
                    "device : %s, serviceUuid = %s, characteristicUuid = %s," +
                        " descriptorUuid = %s, status = %d",
                    device,
                    UuidUtil.read16BitUUID(serviceUuid),
                    UuidUtil.read16BitUUID(characteristicUuid),
                    UuidUtil.read16BitUUID(descriptorUuid),
                    status,
                ),
            )
            mCallbackManager.onBleNotificationStatus(device, serviceUuid, characteristicUuid, status)
            val notifyRunnable = mNotifyCharacteristicRunnable
            if (notifyRunnable != null && notifyRunnable.isSame(device, serviceUuid, characteristicUuid, descriptorUuid)) {
                if (status == BluetoothGatt.GATT_SUCCESS) {
                    mNotifyCharacteristicRunnable = null
                    val bleDevice = getBleDevice(device) ?: return
                    var requestMTU = bleDevice.getParam().getRequestMtu()
                    if (requestMTU > 509) {
                        requestMTU = 509
                    }
                    if (bleDevice.isConnectGattOverBrEdr()) {
                        bleDevice.setMtu(requestMTU)
                        mCallbackManager.onBleDataBlockChanged(device, requestMTU + 3, status)
                        handleBleConnection(device, BluetoothProfile.STATE_CONNECTED)
                        return
                    }
                    startChangeMtu(gatt, requestMTU)
                    return
                }
                var num = notifyRunnable.retryNum
                if (num < 3) {
                    notifyRunnable.retryNum = ++num
                    mHandler.postDelayed(notifyRunnable, 100)
                } else {
                    mNotifyCharacteristicRunnable = null
                    disconnectBleDevice(device)
                }
            }
        }

        @SuppressLint("MissingPermission")
        override fun onMtuChanged(gatt: BluetoothGatt, mtu: Int, status: Int) {
            val device = gatt.device ?: return
            JL_Log.d(
                TAG,
                "onMtuChanged",
                CommonUtil.formatString("device : %s, mtu = %d, status = %d", printDeviceInfo(device), mtu, status),
            )
            mCallbackManager.onBleDataBlockChanged(device, mtu, status)
            val bleDevice = getBleDevice(device) ?: return
            if (mHandler.hasMessages(MSG_CHANGE_BLE_MTU_TIMEOUT)) {
                val bleMtu = if (status == BluetoothGatt.GATT_SUCCESS) mtu - 3 else BluetoothConstant.BLE_MTU_MIN
                stopChangeMtu()
                bleDevice.setMtu(bleMtu)
                JL_Log.i(TAG, "onMtuChanged", "MTU modified successfully")
                handleBleConnection(device, BluetoothProfile.STATE_CONNECTED)
            }
        }
    }

    /** 主线程 Handler，分发处理各类超时与延时任务 */
    private val mHandler = Handler(Looper.getMainLooper()) { msg -> onHandleMessage(msg) }

    /** 回连辅助类实例 */
    private lateinit var mReConnectHelper: ReConnectHelper

    init {
        if (CommonUtil.getMainContext() == null) {
            CommonUtil.setMainContext(context)
        }
        mReConnectHelper = ReConnectHelper(context, this)
        registerReceiver()
    }

    /**
     * 查询当前是否正在执行 BLE 扫描
     */
    val isBleScanning: Boolean
        get() = bleScanningFlag

    /**
     * 获取当前处于已连接且正在使用中的 BLE 蓝牙物理设备
     */
    val connectedBtDevice: BluetoothDevice?
        get() {
            val connectedBleDevices = getConnectedDeviceList()
            for (device in connectedBleDevices) {
                val bleDevice = getBleDevice(device) ?: continue
                if (bleDevice.isConnected() && bleDevice.isUsing()) {
                    return device
                }
            }
            return null
        }

    /**
     * 获取当前处于正在连接中状态的蓝牙设备
     */
    val connectingDevice: BluetoothDevice?
        get() {
            if (mBleDeviceMap.isEmpty()) return null
            for (bleDevice in mBleDeviceMap.values) {
                if (bleDevice.getConnection() == BluetoothProfile.STATE_CONNECTING) {
                    return bleDevice.getDevice()
                }
            }
            return null
        }

    /**
     * 查询当前是否有设备正处于连接过程中
     */
    val isConnecting: Boolean
        get() = connectingDevice != null

    /**
     * 销毁并清理 BLE 管理器全部资源
     *
     * 注销广播、断开并清空所有已连接设备、停止扫描、释放回连助手与回调管理器，并将单例置空。
     */
    fun destroy() {
        JL_Log.w(TAG, "destroy", "instance : $instance")
        unregisterReceiver()
        clearConnectedBleDevices()
        if (isBleScanning) stopLeScan()
        setBleScanning(false, 0)
        mDiscoveredBleDevices.clear()
        mReConnectHelper.release()
        mCallbackManager.release()
        mHandler.removeCallbacksAndMessages(null)
        instance = null
    }

    /**
     * 注册 BLE 事件监听回调
     *
     * @param callback 实现了 [BleEventCallback] 的观察者
     */
    fun registerBleEventCallback(callback: BleEventCallback?) {
        mCallbackManager.addCallback(callback)
    }

    /**
     * 注销 BLE 事件监听回调
     *
     * @param callback 待移除的观察者
     */
    fun unregisterBleEventCallback(callback: BleEventCallback?) {
        mCallbackManager.removeCallback(callback)
    }

    /**
     * 查询系统蓝牙硬件开关是否开启
     *
     * @return true 表示系统蓝牙已打开
     */
    fun isBluetoothEnable(): Boolean {
        val adapter = mBluetoothAdapter ?: return false
        return adapter.isEnabled
    }

    /**
     * 启动低功耗蓝牙 (BLE) 扫描
     *
     * 校验权限与环境就绪后，使用 [BluetoothLeScanner] 发起扫描。
     *
     * @param timeout 扫描超时时间（毫秒）
     * @return true 表示成功提交扫描启动指令
     */
    @SuppressLint("MissingPermission")
    fun startLeScan(timeout: Long): Boolean {
        if (!checkScanEnv("startLeScan")) return false
        if (!AppUtil.isHasLocationPermission(mContext)) {
            JL_Log.w(TAG, "startLeScan", "Missing location permissions.")
            return false
        }
        var scanTimeout = timeout
        if (scanTimeout <= 0) scanTimeout = SCAN_BLE_TIMEOUT
        if (isBleScanning) {
            JL_Log.i(TAG, "startLeScan", "BLE is searching.")
            bluetoothLeScanner()?.flushPendingScanResults(mScanCallback)
            setBleScanning(true, scanTimeout)
            syncSystemBleDevice()
            return true
        }
        val scanner = bluetoothLeScanner()
        if (scanner == null) {
            JL_Log.w(TAG, "startLeScan", "BluetoothLeScanner is null.")
            return false
        }
        val scanMode = ScanSettings.SCAN_MODE_LOW_LATENCY
        val scanSettings = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
            val builder = ScanSettings.Builder()
                .setScanMode(scanMode)
                .setMatchMode(ScanSettings.MATCH_MODE_AGGRESSIVE)
                .setNumOfMatches(ScanSettings.MATCH_NUM_MAX_ADVERTISEMENT)
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                builder.setPhy(ScanSettings.PHY_LE_ALL_SUPPORTED)
            }
            builder.build()
        } else {
            ScanSettings.Builder()
                .setScanMode(scanMode)
                .build()
        }
        val filters = ArrayList<ScanFilter>()
        scanner.startScan(filters, scanSettings, mScanCallback)
        val ret = true
        JL_Log.i(TAG, "startLeScan", CommonUtil.formatString("%s. timeout : %d.", ret, scanTimeout))
        setBleScanning(ret, scanTimeout)
        if (ret) {
            syncSystemBleDevice()
        }
        return ret
    }

    /**
     * 停止正在进行的 BLE 扫描
     *
     * @return true 表示成功停止扫描
     */
    @SuppressLint("MissingPermission")
    fun stopLeScan(): Boolean {
        if (!checkScanEnv("stopLeScan")) return false
        if (!isBleScanning) return false
        try {
            bluetoothLeScanner()?.stopScan(mScanCallback)
        } catch (ignore: Exception) {
        }
        removeTimeTask(MSG_SCAN_BLE_TIMEOUT)
        mHandler.removeMessages(MSG_SCAN_HID_DEVICE)
        setBleScanning(false, 0)
        return true
    }

    /**
     * 获取指定蓝牙设备已连接的 BluetoothGatt 实例
     *
     * @param device 目标蓝牙物理设备
     * @return [BluetoothGatt] 句柄；若未建立连接则返回 null
     */
    fun getConnectedBtGatt(device: BluetoothDevice?): BluetoothGatt? {
        val bleDevice = getBleDevice(device) ?: return null
        return bleDevice.getGatt()
    }

    /**
     * 根据设备蓝牙 MAC 地址在已连接列表中查找物理设备
     *
     * @param address 目标蓝牙 MAC 地址字符串
     * @return 匹配的 [BluetoothDevice]；未找到返回 null
     */
    fun getConnectedBLEDevice(address: String?): BluetoothDevice? {
        if (address == null || !BluetoothAdapter.checkBluetoothAddress(address)) return null
        val devices = getConnectedDeviceList()
        if (devices.isEmpty()) return null
        for (device in devices) {
            if (device.address == address) {
                return device
            }
        }
        return null
    }

    /**
     * 获取当前所有处于已连接状态的 BLE 物理设备列表
     *
     * @return 包含所有连接中设备的列表
     */
    fun getConnectedDeviceList(): List<BluetoothDevice> {
        if (mBleDeviceMap.isEmpty()) return ArrayList()
        val bleDevices = getSortList()
        val devices = ArrayList<BluetoothDevice>()
        for (bleDevice in bleDevices) {
            val gatt = bleDevice.getGatt()
            if (gatt == null || bleDevice.getConnection() != BluetoothProfile.STATE_CONNECTED) continue
            val device = gatt.device ?: continue
            devices.add(device)
        }
        return devices
    }

    /**
     * 发起目标设备的重连任务
     *
     * @param address 目标设备 MAC 地址
     * @param isUseAdv 是否采用新版广播过滤策略回连
     */
    fun reconnectDevice(address: String?, isUseAdv: Boolean) {
        JL_Log.d(TAG, "reconnectDevice", "address = $address, isUseAdv = $isUseAdv")
        val ret = mReConnectHelper.putParam(ReConnectHelper.ReconnectParam(address!!, isUseAdv))
        JL_Log.d(TAG, "reconnectDevice", "" + ret)
    }

    /**
     * 校验待匹配地址是否属于回连目标
     *
     * @param address 原始源地址
     * @param matchAddress 待匹配地址
     * @return true 表示匹配命中
     */
    fun isMatchReConnectDevice(address: String, matchAddress: String): Boolean {
        return mReConnectHelper.isMatchAddress(address, matchAddress)
    }

    /**
     * 校验指定设备是否正在连接中
     *
     * @param device 待检测设备
     * @return true 表示正在连接
     */
    fun isConnectingDevice(device: BluetoothDevice?): Boolean {
        return BluetoothUtil.deviceEquals(connectingDevice, device)
    }

    /**
     * 校验指定设备是否已成功建立 BLE 连接
     *
     * @param device 待检测设备
     * @return true 表示已连接且 Gatt 非空
     */
    fun isConnectedDevice(device: BluetoothDevice?): Boolean {
        val bleDevice = getBleDevice(device) ?: return false
        return bleDevice.isConnected() && bleDevice.getGatt() != null
    }

    /**
     * 校验指定设备是否通过 BR/EDR 通道建立 GATT 连接且已连接
     *
     * @param device 目标设备
     * @return true 表示为 GATT over BR/EDR
     */
    fun isConnectedGattOverBrEdrDevice(device: BluetoothDevice?): Boolean {
        val bleDevice = getBleDevice(device) ?: return false
        return bleDevice.isConnectGattOverBrEdr() && bleDevice.isConnected()
    }

    /**
     * 获取指定连接设备的有效分包 MTU 尺寸
     *
     * @param device 目标设备
     * @return MTU 大小（字节）
     */
    fun getBleMtu(device: BluetoothDevice?): Int {
        val bleDevice = getBleDevice(device) ?: return 0
        return bleDevice.getMtu()
    }

    /**
     * 按照自定义连接参数连接指定的 BLE 设备
     *
     * @param device 目标蓝牙物理设备
     * @param param 连接参数实体 [BleConnectParam]
     * @return true 表示成功提交连接请求
     */
    @SuppressLint("MissingPermission")
    fun connectBleDevice(device: BluetoothDevice?, param: BleConnectParam): Boolean {
        if (device == null || !checkConnectEnv("connectBleDevice", device) || !isBluetoothEnable()) {
            return false
        }
        if (isConnectedDevice(device)) {
            JL_Log.i(TAG, "connectBLEDevice", CommonUtil.formatString("Device(%s) is connected.", printDeviceInfo(device)))
            mCallbackManager.onBleConnection(device, BluetoothProfile.STATE_CONNECTED)
            return true
        }
        val connecting = connectingDevice
        if (connecting != null) {
            val isSameDevice = BluetoothUtil.deviceEquals(connecting, device)
            JL_Log.e(
                TAG,
                "connectBleDevice",
                CommonUtil.formatString("Device(%s) is connecting, please wait.", printDeviceInfo(connecting)),
            )
            if (isSameDevice) return true
            disconnectBleDevice(connecting)
            SystemClock.sleep(300)
        }
        if (isBleScanning) {
            stopLeScan()
        }
        val bleDevice = addBleDevice(device, param)
        startTimeoutTask(MSG_CONNECT_BLE_TIMEOUT, device, CONNECT_BLE_TIMEOUT)
        handleBleConnection(device, BluetoothProfile.STATE_CONNECTING)
        if (bleDevice.getParam().isConnectGattOverBrEdr() && device.bondState != BluetoothDevice.BOND_BONDED) {
            bleDevice.setWaitBoundResult(true)
            if (device.bondState == BluetoothDevice.BOND_NONE) {
                val ret = BluetoothUtil.createBond(device)
                JL_Log.d(
                    TAG,
                    "connectBleDevice",
                    if (ret) {
                        CommonUtil.formatString("Preparing to start the device(%s) pairing process.", printDeviceInfo(device))
                    } else {
                        CommonUtil.formatString("Device(%s) pairing process failed to start.", printDeviceInfo(device))
                    },
                )
                if (!ret) {
                    handleBleConnection(device, BluetoothProfile.STATE_DISCONNECTED)
                }
                return ret
            }
            return true
        }
        val gatt = connectBluetoothGatt(device, param)
        val ret = gatt != null
        bleDevice.setGatt(gatt)
        JL_Log.d(
            TAG,
            "connectBleDevice",
            if (ret) {
                CommonUtil.formatString("Prepare to connect to BLE(%s)", printDeviceInfo(device))
            } else {
                CommonUtil.formatString("Failed to connect to BLE(%s)", printDeviceInfo(device))
            },
        )
        if (!ret) {
            handleBleConnection(device, BluetoothProfile.STATE_DISCONNECTED)
        }
        return ret
    }

    /**
     * 使用默认参数连接指定的 BLE 设备
     *
     * 自动从 [ConfigHelper] 读取请求 MTU 并配置标准 OTA 服务与特征值 UUID
     *
     * @param device 目标蓝牙物理设备
     * @return true 表示成功提交连接请求
     */
    fun connectBleDevice(device: BluetoothDevice?): Boolean {
        return connectBleDevice(
            device,
            BleConnectParam()
                .setRequestMtu(configHelper.getBleRequestMtu())
                .setOtaUUID(BLE_UUID_SERVICE, BLE_UUID_WRITE, BLE_UUID_NOTIFICATION),
        )
    }

    /**
     * 断开指定 BLE 设备的连接并释放相关资源
     *
     * @param device 目标蓝牙设备
     */
    @SuppressLint("MissingPermission")
    fun disconnectBleDevice(device: BluetoothDevice?) {
        if (device == null || !checkConnectEnv("disconnectBleDevice", device)) return
        val bleDevice = getBleDevice(device)
        JL_Log.d(TAG, "disconnectBleDevice", "device: " + printDeviceInfo(device) + ", " + bleDevice)
        if (bleDevice == null) return
        val gatt = bleDevice.getGatt()
        if (!isBluetoothEnable()) {
            bleDevice.setConnection(BluetoothProfile.STATE_DISCONNECTED)
        }
        when (bleDevice.getConnection()) {
            BluetoothProfile.STATE_CONNECTED -> {
                if (gatt != null) {
                    JL_Log.d(TAG, "disconnectBleDevice", "Gatt#disconnect")
                    startTimeoutTask(MSG_DISCONNECT_BLE_TIMEOUT, device, CALLBACK_TIMEOUT)
                    gatt.disconnect()
                }
            }
            BluetoothProfile.STATE_CONNECTING -> {
                if (gatt != null) {
                    gatt.disconnect()
                    closeGatt(gatt)
                }
                handleBleConnection(device, BluetoothProfile.STATE_DISCONNECTED)
            }
            else -> {
                removeConnectedBle(device)
                mCallbackManager.onBleConnection(device, BluetoothProfile.STATE_DISCONNECTED)
            }
        }
    }

    /**
     * 异步向指定设备的特征值写入数据
     *
     * @param device 目标设备
     * @param serviceUUID 服务 UUID
     * @param characteristicUUID 写入特征值 UUID
     * @param data 原始字节数组
     * @param callback 写入完成异步结果监听回调
     */
    fun writeDataByBleAsync(
        device: BluetoothDevice?,
        serviceUUID: UUID?,
        characteristicUUID: UUID?,
        data: ByteArray?,
        callback: OnWriteDataCallback?,
    ) {
        addSendTask(device, serviceUUID, characteristicUUID, data, callback)
    }

    /**
     * 内部 Handler 消息处理中心
     *
     * 统一处理扫描超时、连接超时、服务发现超时、特征值通知使能超时、MTU 修改超时及系统同步超时
     *
     * @param msg 消息对象
     * @return true 表示消息已处理
     */
    private fun onHandleMessage(msg: Message): Boolean {
        when (msg.what) {
            MSG_SCAN_BLE_TIMEOUT -> {
                JL_Log.i(TAG, "MSG_SCAN_BLE_TIMEOUT", "")
                stopLeScan()
            }
            MSG_CONNECT_BLE_TIMEOUT -> {
                val device = msg.obj as? BluetoothDevice ?: return false
                JL_Log.i(TAG, "MSG_CONNECT_BLE_TIMEOUT", "device : " + printDeviceInfo(device))
                disconnectBleDevice(device)
            }
            MSG_SCAN_HID_DEVICE -> findHidDevice()
            MSG_NOTIFY_BLE_TIMEOUT -> {
                val device = msg.obj as? BluetoothDevice ?: return false
                JL_Log.i(TAG, "MSG_NOTIFY_BLE_TIMEOUT", "device : " + printDeviceInfo(device))
                disconnectBleDevice(device)
            }
            MSG_CHANGE_BLE_MTU_TIMEOUT -> {
                val device = msg.obj as? BluetoothDevice ?: return false
                val bleDevice = getBleDevice(device)
                JL_Log.i(TAG, "MSG_CHANGE_BLE_MTU_TIMEOUT", "device : " + printDeviceInfo(device) + ", " + bleDevice)
                if (bleDevice == null) return false
                bleDevice.setMtu(BluetoothConstant.BLE_MTU_MIN)
                handleBleConnection(device, BluetoothProfile.STATE_CONNECTED)
            }
            MSG_DISCOVER_SERVICES_TIMEOUT -> {
                val device = msg.obj as? BluetoothDevice ?: return false
                val bleDevice = getBleDevice(device)
                JL_Log.i(TAG, "MSG_DISCOVER_SERVICES_TIMEOUT", "device : " + printDeviceInfo(device) + ", " + bleDevice)
                if (bleDevice == null) return false
                val gatt = bleDevice.getGatt()
                if (gatt != null) {
                    val services = gatt.services
                    if (services.isNotEmpty()) {
                        mBluetoothGattCallback.onServicesDiscovered(gatt, BluetoothGatt.GATT_SUCCESS)
                        return true
                    }
                }
                if (!bleDevice.isOverReconnectLimit()) {
                    JL_Log.i(TAG, "MSG_DISCOVER_SERVICES_TIMEOUT", "reconnectBleDevice")
                    bleDevice.setNeedReconnect(true)
                }
                disconnectBleDevice(device)
            }
            MSG_DISCONNECT_BLE_TIMEOUT -> {
                val device = msg.obj as? BluetoothDevice ?: return false
                val gatt = getConnectedBtGatt(device)
                JL_Log.d(TAG, "MSG_DISCONNECT_BLE_TIMEOUT", "device : " + printDeviceInfo(device) + ", gatt : " + gatt)
                if (gatt == null) return false
                closeGatt(gatt)
                handleBleConnection(device, BluetoothProfile.STATE_DISCONNECTED)
            }
            MSG_CHECK_SYSTEM_BLE_TIMEOUT -> stopCheckSystemBleThread()
        }
        return true
    }

    /**
     * 设置扫描状态标志并触发状态事件通知
     *
     * @param isScanning 是否扫描中
     * @param timeout 超时时长
     */
    private fun setBleScanning(isScanning: Boolean, timeout: Long) {
        bleScanningFlag = isScanning
        if (isScanning) {
            mDiscoveredBleDevices.clear()
            startTimeoutTask(MSG_SCAN_BLE_TIMEOUT, null, timeout)
        }
        mCallbackManager.onDiscoveryBleChange(isScanning)
        if (bleScanningFlag && configHelper.isHidDevice()) {
            mHandler.sendEmptyMessage(MSG_SCAN_HID_DEVICE)
        }
    }

    /**
     * 校验扫描前置环境（适配器是否可用、是否有扫描权限、蓝牙是否打开）
     *
     * @param method 调用方法标识名
     * @return true 表示环境就绪
     */
    private fun checkScanEnv(method: String): Boolean {
        if (mBluetoothAdapter == null) {
            JL_Log.w(TAG, method, "No support for Bluetooth function.")
            return false
        }
        if (!CommonUtil.checkHasScanPermission(mContext)) {
            JL_Log.w(TAG, method, "Missing permission to search Bluetooth.")
            return false
        }
        if (!isBluetoothEnable()) {
            JL_Log.w(TAG, method, "Bluetooth is close.")
            return false
        }
        return true
    }

    /**
     * 校验连接前置环境（连接权限及设备非空）
     *
     * @param method 调用方法标识名
     * @param device 待连接设备
     * @return true 表示环境就绪
     */
    private fun checkConnectEnv(method: String, device: BluetoothDevice?): Boolean {
        if (!CommonUtil.checkHasConnectPermission(mContext)) {
            JL_Log.w(TAG, method, "Missing permission to search Bluetooth.")
            return false
        }
        if (device == null) {
            JL_Log.w(TAG, method, "Device is null.")
            return false
        }
        return true
    }

    /**
     * 根据设备物理对象获取已缓存的 [BleDevice]
     *
     * @param device 蓝牙设备
     * @return 对应的 [BleDevice] 实体；未缓存则返回 null
     */
    private fun getBleDevice(device: BluetoothDevice?): BleDevice? {
        if (device == null) return null
        return mBleDeviceMap[device.address]
    }

    /**
     * 添加或获取设备的 [BleDevice] 缓存包装
     *
     * @param device 蓝牙设备
     * @param param 连接参数
     * @return [BleDevice] 实例
     */
    private fun addBleDevice(device: BluetoothDevice, param: BleConnectParam): BleDevice {
        var cacheDevice = getBleDevice(device)
        if (cacheDevice == null) {
            cacheDevice = BleDevice(device, param)
            mBleDeviceMap[device.address] = cacheDevice
        }
        return cacheDevice
    }

    /**
     * 从缓存字典中移除设备连接实体
     *
     * @param device 目标设备
     * @return 移除的实体
     */
    private fun removeConnectedBle(device: BluetoothDevice?): BleDevice? {
        if (device == null) return null
        return removeConnectedBle(device.address)
    }

    /**
     * 根据 MAC 地址从缓存字典中移除设备实体
     *
     * @param address 设备 MAC 地址
     * @return 移除的 [BleDevice] 实体
     */
    private fun removeConnectedBle(address: String): BleDevice? {
        if (!BluetoothAdapter.checkBluetoothAddress(address)) return null
        val bleDevice = mBleDeviceMap.remove(address)
        JL_Log.i(TAG, "removeConnectedBle", "address : $address, $bleDevice")
        if (bleDevice == null) return null
        val connectedDeviceList = getConnectedDeviceList()
        JL_Log.d(TAG, "removeConnectedBle", "connectedDeviceList size : " + connectedDeviceList.size)
        if (connectedDeviceList.isEmpty()) {
            setConnectedBtDevice(null)
        } else if (BluetoothUtil.deviceEquals(bleDevice.getDevice(), connectedBtDevice)) {
            setConnectedBtDevice(connectedDeviceList[0])
        }
        return bleDevice
    }

    /**
     * 根据系统版本兼容调用 connectGatt 建立底层连接
     *
     * @param device 蓝牙设备
     * @param param 连接参数
     * @return 建立的 [BluetoothGatt] 实例
     */
    @SuppressLint("MissingPermission")
    private fun connectBluetoothGatt(device: BluetoothDevice, param: BleConnectParam): BluetoothGatt? {
        val transport = param.getTransport()
        val phyMask = 1
        JL_Log.d(TAG, "connectBluetoothGatt", "device : $device, $param")
        val bluetoothGatt = if (Build.VERSION.SDK_INT > Build.VERSION_CODES.O) {
            device.connectGatt(mContext, false, mBluetoothGattCallback, transport, phyMask, mHandler)
        } else if (Build.VERSION.SDK_INT == Build.VERSION_CODES.O) {
            device.connectGatt(mContext, false, mBluetoothGattCallback, transport, phyMask)
        } else if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
            device.connectGatt(mContext, false, mBluetoothGattCallback, transport)
        } else {
            device.connectGatt(mContext, false, mBluetoothGattCallback)
        }
        if (bluetoothGatt == null) {
            JL_Log.i(TAG, "connectBluetoothGatt", "Failed to connect ble.")
            return null
        }
        return bluetoothGatt
    }

    /**
     * 获取按连接时间倒序排列的设备列表
     *
     * @return 排序后的 [BleDevice] 列表
     */
    private fun getSortList(): List<BleDevice> {
        if (mBleDeviceMap.isEmpty()) return ArrayList()
        val bleDevices = ArrayList(mBleDeviceMap.values)
        if (bleDevices.size > 1) {
            bleDevices.sortWith { o1, o2 ->
                o2.getConnectedTime().compareTo(o1.getConnectedTime())
            }
        }
        return bleDevices
    }

    /**
     * 断开并关闭当前缓存中的所有已连接 BLE 设备
     */
    @SuppressLint("MissingPermission")
    private fun clearConnectedBleDevices() {
        if (mBleDeviceMap.isNotEmpty()) {
            val clone = HashMap(mBleDeviceMap)
            for (bleDevice in clone.values) {
                val gatt = bleDevice.getGatt() ?: continue
                if (BluetoothUtil.isBluetoothEnable()) {
                    gatt.disconnect()
                    closeGatt(gatt)
                }
                mCallbackManager.onBleConnection(bleDevice.getDevice(), BluetoothProfile.STATE_DISCONNECTED)
            }
            mBleDeviceMap.clear()
        }
    }

    /**
     * 安全关闭底层的 BluetoothGatt 实例
     *
     * @param gatt 目标 GATT 句柄
     */
    @SuppressLint("MissingPermission")
    private fun closeGatt(gatt: BluetoothGatt?) {
        if (gatt == null) return
        JL_Log.i(TAG, "closeGatt", "gatt : $gatt")
        // AppUtil.refreshBleDeviceCache(mContext, gatt); // 强制更新缓存
        gatt.close()
    }

    /**
     * 设置当前处于活动激活状态的蓝牙设备
     *
     * @param device 目标设备
     */
    private fun setConnectedBtDevice(device: BluetoothDevice?) {
        val connectedDevice = connectedBtDevice
        if (device != null && !BluetoothUtil.deviceEquals(connectedDevice, device)) {
            val oldDevice = getBleDevice(connectedDevice)
            if (oldDevice != null) {
                oldDevice.setUsing(false)
            }
            val bleDevice = getBleDevice(device)
            var isSwitch = false
            if (bleDevice != null) {
                bleDevice.setUsing(true)
                isSwitch = true
            }
            if (isSwitch) {
                mCallbackManager.onSwitchBleDevice(device)
            }
        }
    }

    /**
     * 过滤扫描命中的设备并触发发现回调
     *
     * @param device 扫描到的物理设备
     * @param rssi 信号强度
     * @param scanRecord 广播字节包
     * @param isBleEnableConnect 是否允许连接
     */
    @SuppressLint("MissingPermission")
    private fun filterDevice(device: BluetoothDevice?, rssi: Int, scanRecord: ByteArray?, isBleEnableConnect: Boolean) {
        if (device != null && AppUtil.checkHasConnectPermission(mContext) && isBluetoothEnable() && !TextUtils.isEmpty(device.name)) {
            handleDiscoveryBle(device, BleScanInfo().setRawData(scanRecord).setRssi(rssi).setEnableConnect(isBleEnableConnect))
        }
    }

    /**
     * 启动延时超时检测任务
     *
     * @param what 消息标识
     * @param device 关联的目标设备
     * @param timeout 超时毫秒数
     */
    private fun startTimeoutTask(what: Int, device: BluetoothDevice?, timeout: Long) {
        removeTimeTask(what)
        if (device == null) {
            mHandler.sendEmptyMessageDelayed(what, timeout)
            return
        }
        mHandler.sendMessageDelayed(mHandler.obtainMessage(what, device), timeout)
    }

    /**
     * 移除指定的超时检测任务
     *
     * @param what 消息标识
     */
    private fun removeTimeTask(what: Int) {
        mHandler.removeMessages(what)
    }

    /**
     * 启动异步线程同步系统当前已连接的 BLE 设备
     */
    @SuppressLint("MissingPermission")
    private fun syncSystemBleDevice() {
        stopCheckSystemBleThread()
        startTimeoutTask(MSG_CHECK_SYSTEM_BLE_TIMEOUT, null, CALLBACK_TIMEOUT)
        checkSystemBleThread = CheckSystemBleThread()
        checkSystemBleThread!!.start()
    }

    /**
     * 停止系统已连接设备检测线程
     */
    private fun stopCheckSystemBleThread() {
        removeTimeTask(MSG_CHECK_SYSTEM_BLE_TIMEOUT)
        if (checkSystemBleThread != null) {
            checkSystemBleThread!!.interrupt()
            checkSystemBleThread = null
        }
    }

    /**
     * 周期性检索系统已绑定的已连接 HID 设备并模拟发现回调
     */
    @SuppressLint("MissingPermission")
    private fun findHidDevice() {
        val lists = BluetoothUtil.getSystemConnectedBtDeviceList(mContext)
        if (lists != null && AppUtil.checkHasConnectPermission(mContext)) {
            for (device in lists) {
                if (isConnectedDevice(device)) continue
                if (device.type != BluetoothDevice.DEVICE_TYPE_CLASSIC &&
                    device.bondState == BluetoothDevice.BOND_BONDED
                ) {
                    handleDiscoveryBle(device, BleScanInfo().setEnableConnect(true))
                }
            }
        }
        if (isBleScanning) {
            mHandler.sendEmptyMessageDelayed(MSG_SCAN_HID_DEVICE, 1000)
        }
    }

    /**
     * 向目标设备的专属发送队列添加发送任务
     *
     * @param device 目标设备
     * @param serviceUUID 服务 UUID
     * @param characteristicUUID 特征值 UUID
     * @param data 待发送数据
     * @param callback 异步回调
     */
    private fun addSendTask(
        device: BluetoothDevice?,
        serviceUUID: UUID?,
        characteristicUUID: UUID?,
        data: ByteArray?,
        callback: OnWriteDataCallback?,
    ) {
        var ret = false
        val bleDevice = getBleDevice(device)
        if (bleDevice != null) {
            ret = bleDevice.addSendTask(serviceUUID, characteristicUUID, data, callback)
        }
        if (!ret && callback != null) {
            callback.onBleResult(device, serviceUUID, characteristicUUID, false, data)
        }
    }

    /**
     * 唤醒目标设备的数据发送线程并更新执行状态
     *
     * @param gatt 目标 GATT 句柄
     * @param serviceUUID 服务 UUID
     * @param characteristicUUID 特征值 UUID
     * @param status 写入执行状态
     * @param data 写入的数据
     */
    private fun wakeupSendThread(gatt: BluetoothGatt, serviceUUID: UUID?, characteristicUUID: UUID?, status: Int, data: ByteArray?) {
        val bleDevice = getBleDevice(gatt.device)
        if (bleDevice != null) {
            val task = BleSendTask(gatt, serviceUUID, characteristicUUID, data, null)
            task.status = status
            bleDevice.wakeupSendThread(task)
        }
    }

    /**
     * 处理扫描命中新设备（排重后向外部派发）
     *
     * @param device 扫描到的蓝牙设备
     * @param bleScanInfo 广播元数据包装
     */
    private fun handleDiscoveryBle(device: BluetoothDevice, bleScanInfo: BleScanInfo) {
        if (!mDiscoveredBleDevices.contains(device)) {
            mDiscoveredBleDevices.add(device)
            JL_Log.d(TAG, "handleDiscoveryBle", "onDiscoveryBle " + printDeviceInfo(device) + ", " + bleScanInfo)
            mCallbackManager.onDiscoveryBle(device, bleScanInfo)
        }
    }

    /**
     * 处理 BLE 连接状态迁移并通知所有观察者
     *
     * @param device 目标设备
     * @param status 最新的连接状态码
     */
    private fun handleBleConnection(device: BluetoothDevice, status: Int) {
        val bleDevice = getBleDevice(device) ?: return
        val prevState = bleDevice.getConnection()
        JL_Log.i(
            TAG,
            "handleBleConnection",
            CommonUtil.formatString(
                "device : " + printDeviceInfo(device) +
                    ", prevState : " + BluetoothUtil.printBtConnectionState(prevState) +
                    ", status : " + BluetoothUtil.printBtConnectionState(status),
            ),
        )
        if (prevState == status) return
        bleDevice.setConnection(status)
        if (status != BluetoothProfile.STATE_CONNECTING) {
            removeTimeTask(MSG_NOTIFY_BLE_TIMEOUT)
        }
        when (status) {
            BluetoothProfile.STATE_CONNECTED -> {
                if (connectedBtDevice == null) {
                    setConnectedBtDevice(device)
                }
            }
            BluetoothProfile.STATE_DISCONNECTED -> removeConnectedBle(device)
        }
        mCallbackManager.onBleConnection(device, status)
    }

    /**
     * 注册系统蓝牙状态及 ACL 连接广播接收器
     */
    private fun registerReceiver() {
        if (mAdapterReceiver == null) {
            mAdapterReceiver = BaseBtAdapterReceiver()
            val intentFilter = IntentFilter(BluetoothAdapter.ACTION_STATE_CHANGED)
            intentFilter.addAction(BluetoothDevice.ACTION_ACL_CONNECTED)
            intentFilter.addAction(BluetoothDevice.ACTION_ACL_DISCONNECTED)
            intentFilter.addAction(BluetoothDevice.ACTION_BOND_STATE_CHANGED)
            mContext.registerReceiver(mAdapterReceiver, intentFilter)
        }
    }

    /**
     * 注销系统蓝牙状态广播接收器
     */
    private fun unregisterReceiver() {
        if (mAdapterReceiver != null) {
            mContext.unregisterReceiver(mAdapterReceiver)
            mAdapterReceiver = null
        }
    }

    /**
     * 开启指定特征值的通知 (Notification/Indication)
     *
     * @param gatt 目标 GATT 句柄
     * @param serviceUUID 服务 UUID
     * @param characteristicUUID 特征值 UUID
     * @return true 表示成功提交 Descriptor 写入请求
     */
    @SuppressLint("MissingPermission")
    private fun enableBLEDeviceNotification(gatt: BluetoothGatt?, serviceUUID: UUID?, characteristicUUID: UUID?): Boolean {
        if (gatt == null || !AppUtil.checkHasConnectPermission(mContext)) {
            JL_Log.w(TAG, "enableBLEDeviceNotification", "Missing permission to connect Bluetooth.")
            return false
        }
        if (!isBluetoothEnable()) {
            JL_Log.w(TAG, "enableBLEDeviceNotification", "Bluetooth is close.")
            return false
        }
        if (serviceUUID == null) {
            JL_Log.w(TAG, "enableBLEDeviceNotification", "BluetoothGattService is null. uuid = $serviceUUID")
            return false
        }
        val gattService = gatt.getService(serviceUUID)
        if (gattService == null) {
            JL_Log.w(TAG, "enableBLEDeviceNotification", "BluetoothGattService is null. uuid = $serviceUUID")
            return false
        }
        if (characteristicUUID == null) {
            JL_Log.w(TAG, "enableBLEDeviceNotification", "BluetoothGattCharacteristic is null. uuid = $characteristicUUID")
            return false
        }
        val characteristic = gattService.getCharacteristic(characteristicUUID)
        if (characteristic == null) {
            JL_Log.w(TAG, "enableBLEDeviceNotification", "BluetoothGattCharacteristic is null. uuid = $characteristicUUID")
            return false
        }
        var bRet = gatt.setCharacteristicNotification(characteristic, true)
        if (bRet) {
            bRet = false
            val descriptors = characteristic.descriptors
            for (descriptor in descriptors) {
                if (BLE_UUID_NOTIFICATION_DESCRIPTOR != descriptor.uuid) continue
                bRet = tryToWriteDescriptor(gatt, descriptor, 0, false)
                if (!bRet) {
                    JL_Log.w(TAG, "enableBLEDeviceNotification", "(tryToWriteDescriptor) ---> failed")
                } else {
                    break
                }
            }
        } else {
            JL_Log.w(TAG, "enableBLEDeviceNotification", "(setCharacteristicNotification) ---> failed.")
        }
        JL_Log.d(
            TAG,
            "enableBLEDeviceNotification",
            bRet.toString() + ", serviceUUID : " + UuidUtil.read16BitUUID(serviceUUID) +
                ", characteristicUUID : " + UuidUtil.read16BitUUID(characteristicUUID),
        )
        return bRet
    }

    /**
     * 尝试向 Descriptor 写入通知使能值，失败自动递归重试（最多 3 次）
     *
     * @param bluetoothGatt 目标 GATT 句柄
     * @param descriptor 目标 Descriptor
     * @param retryCount 当前重试次数
     * @param isSkipSetValue 是否跳过 setValue 步骤
     * @return 最终写入提交结果
     */
    @SuppressLint("MissingPermission")
    private fun tryToWriteDescriptor(
        bluetoothGatt: BluetoothGatt,
        descriptor: BluetoothGattDescriptor,
        retryCount: Int,
        isSkipSetValue: Boolean,
    ): Boolean {
        if (!AppUtil.checkHasConnectPermission(mContext)) return false
        var count = retryCount
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
            val status = bluetoothGatt.writeDescriptor(descriptor, BluetoothGattDescriptor.ENABLE_NOTIFICATION_VALUE)
            val ret = status == BluetoothStatusCodes.SUCCESS
            JL_Log.i(TAG, "tryToWriteDescriptor", "writeDescriptor : $ret")
            if (!ret) {
                count++
                if (count >= 3) {
                    return false
                }
                JL_Log.i(TAG, "tryToWriteDescriptor", "writeDescriptor failed. retryCount : $count")
                SystemClock.sleep(50)
                tryToWriteDescriptor(bluetoothGatt, descriptor, count, true)
            }
            return ret
        }
        var ret = isSkipSetValue
        if (!ret) {
            @Suppress("DEPRECATION")
            ret = descriptor.setValue(BluetoothGattDescriptor.ENABLE_NOTIFICATION_VALUE)
            JL_Log.i(TAG, "tryToWriteDescriptor", "setValue : $ret")
            if (!ret) {
                count++
                if (count >= 3) {
                    return false
                } else {
                    JL_Log.i(TAG, "tryToWriteDescriptor", "setValue failed. retryCount : $count")
                    SystemClock.sleep(50)
                    tryToWriteDescriptor(bluetoothGatt, descriptor, count, false)
                }
            } else {
                count = 0
            }
        }
        if (ret) {
            @Suppress("DEPRECATION")
            ret = bluetoothGatt.writeDescriptor(descriptor)
            JL_Log.i(TAG, "tryToWriteDescriptor", "writeDescriptor : $ret")
            if (!ret) {
                count++
                if (count >= 3) {
                    return false
                } else {
                    JL_Log.i(TAG, "tryToWriteDescriptor", "writeDescriptor failed. retryCount : $count")
                    SystemClock.sleep(50)
                    tryToWriteDescriptor(bluetoothGatt, descriptor, count, true)
                }
            }
        }
        return ret
    }

    /**
     * 发起 BLE MTU 大小调整协商
     *
     * @param gatt 目标 GATT 句柄
     * @param mtu 期望协商的 MTU 大小
     */
    @SuppressLint("MissingPermission")
    private fun startChangeMtu(gatt: BluetoothGatt?, mtu: Int) {
        if (gatt == null || !AppUtil.checkHasConnectPermission(mContext)) {
            JL_Log.w(TAG, "startChangeMtu", "Gatt is null.")
            return
        }
        if (mHandler.hasMessages(MSG_CHANGE_BLE_MTU_TIMEOUT)) {
            JL_Log.w(TAG, "startChangeMtu", "Adjusting the MTU for BLE")
            return
        }
        val device = gatt.device
        if (device == null) {
            JL_Log.w(TAG, "startChangeMtu", "device is null.")
            return
        }
        var ret = false
        if (mtu > BluetoothConstant.BLE_MTU_MIN) {
            startTimeoutTask(MSG_CHANGE_BLE_MTU_TIMEOUT, device, CALLBACK_TIMEOUT)
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.LOLLIPOP) {
                ret = gatt.requestMtu(mtu + 3)
            }
        }
        JL_Log.d(TAG, "startChangeMtu", "requestMtu : $ret, mtu : $mtu")
        if (!ret) {
            stopChangeMtu()
            handleBleConnection(device, BluetoothProfile.STATE_CONNECTED)
        }
    }

    /**
     * 停止 MTU 协商超时检测
     */
    private fun stopChangeMtu() {
        removeTimeTask(MSG_CHANGE_BLE_MTU_TIMEOUT)
    }

    /**
     * 格式化打印设备调试信息
     *
     * @param device 目标设备
     * @return 格式化描述字符串
     */
    private fun printDeviceInfo(device: BluetoothDevice?): String {
        return BluetoothUtil.printBtDeviceInfo(mContext, device)
    }

    /**
     * 系统蓝牙状态广播监听接收器内部类
     *
     * 监听系统蓝牙开关、ACL 连接/断开以及设备配对绑定状态变更
     */
    private inner class BaseBtAdapterReceiver : BroadcastReceiver() {
        @SuppressLint("MissingPermission")
        override fun onReceive(context: Context?, intent: Intent?) {
            if (intent == null || intent.action == null) {
                return
            }
            when (val action = intent.action) {
                BluetoothAdapter.ACTION_STATE_CHANGED -> handleAdapterStateChanged(intent)
                BluetoothDevice.ACTION_ACL_CONNECTED,
                BluetoothDevice.ACTION_ACL_DISCONNECTED,
                -> handleAclConnection(intent, action)
                BluetoothDevice.ACTION_BOND_STATE_CHANGED -> handleBondStateChanged(intent)
                else -> JL_Log.d(TAG, "Unhandled action: $action")
            }
        }

        /**
         * 处理系统蓝牙开关变更广播
         */
        private fun handleAdapterStateChanged(intent: Intent) {
            val currentState = getCurrentAdapterState(intent)
            val previousState = intent.getIntExtra(BluetoothAdapter.EXTRA_PREVIOUS_STATE, -1)
            if (currentState == previousState) {
                return
            }
            when (currentState) {
                BluetoothAdapter.STATE_OFF -> onBluetoothOff()
                BluetoothAdapter.STATE_ON -> onBluetoothOn()
                else -> JL_Log.d(TAG, "Adapter state changed to: $currentState")
            }
        }

        private fun getCurrentAdapterState(intent: Intent): Int {
            var state = intent.getIntExtra(BluetoothAdapter.EXTRA_STATE, -1)
            if (state == -1 && mBluetoothAdapter != null) {
                state = mBluetoothAdapter.state
            }
            return state
        }

        private fun onBluetoothOff() {
            setBleScanning(false, 0)
            mDiscoveredBleDevices.clear()
            clearConnectedBleDevices()
            mCallbackManager.onAdapterChange(false)
        }

        private fun onBluetoothOn() {
            mCallbackManager.onAdapterChange(true)
        }

        private fun handleAclConnection(intent: Intent, action: String?) {
            val device = extractDeviceFromIntent(intent)
            val eventType = if (BluetoothDevice.ACTION_ACL_CONNECTED == action) "CONNECTED" else "DISCONNECTED"
            JL_Log.i(TAG, "ACTION_ACL_$eventType", "device: " + printDeviceInfo(device))
        }

        /**
         * 处理蓝牙设备配对绑定状态变更广播
         */
        private fun handleBondStateChanged(intent: Intent) {
            val device = extractDeviceFromIntent(intent)
            if (device == null) {
                JL_Log.w(TAG, "ACTION_BOND_STATE_CHANGED", "Device is null")
                return
            }
            val bondState = getBondStateFromIntent(intent, device)
            val bleDevice = getBleDevice(device)
            logBondStateChange(device, bondState, bleDevice)
            if (!shouldProcessBondStateChange(bleDevice)) {
                return
            }
            processFinalBondResult(device, bondState, bleDevice!!)
        }

        private fun extractDeviceFromIntent(intent: Intent): BluetoothDevice? {
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
                return intent.getParcelableExtra(BluetoothDevice.EXTRA_DEVICE, BluetoothDevice::class.java)
            }
            @Suppress("DEPRECATION")
            return intent.getParcelableExtra(BluetoothDevice.EXTRA_DEVICE)
        }

        @SuppressLint("MissingPermission")
        private fun getBondStateFromIntent(intent: Intent, device: BluetoothDevice): Int {
            var bondState = intent.getIntExtra(BluetoothDevice.EXTRA_BOND_STATE, -1)
            if (bondState == -1) {
                bondState = device.bondState
            }
            return bondState
        }

        private fun logBondStateChange(device: BluetoothDevice, bondState: Int, bleDevice: BleDevice?) {
            JL_Log.i(
                TAG,
                "ACTION_BOND_STATE_CHANGED",
                String.format(
                    Locale.US,
                    "device: %s, bond: %s, bleDevice: %s",
                    printDeviceInfo(device),
                    BluetoothUtil.printBoundState(bondState),
                    if (bleDevice != null) bleDevice.toString() else "null",
                ),
            )
        }

        private fun shouldProcessBondStateChange(bleDevice: BleDevice?): Boolean {
            return bleDevice != null && bleDevice.isWaitBoundResult()
        }

        private fun processFinalBondResult(device: BluetoothDevice, bondState: Int, bleDevice: BleDevice) {
            if (bondState != BluetoothDevice.BOND_BONDED && bondState != BluetoothDevice.BOND_NONE) {
                return
            }
            bleDevice.setWaitBoundResult(false)
            val isBondSuccess = bondState == BluetoothDevice.BOND_BONDED
            var connectResult = false
            if (isBondSuccess) {
                bleDevice.setConnection(BluetoothProfile.STATE_DISCONNECTED)
                connectResult = connectBleDevice(device, bleDevice.getParam())
            }
            if (!connectResult) {
                handleBleConnection(device, BluetoothProfile.STATE_DISCONNECTED)
            }
        }
    }

    /**
     * 开启特征值通知 Runnable
     *
     * 负责开启并等待 Descriptor 写入，如果写入失败可重试最多 3 次
     *
     * @param bluetoothGatt 目标 GATT 句柄
     * @param serviceUUID 服务 UUID
     * @param characteristicUUID 特征值 UUID
     */
    private inner class NotifyCharacteristicRunnable(
        private val bluetoothGatt: BluetoothGatt?,
        private val serviceUUID: UUID?,
        private val characteristicUUID: UUID?,
    ) : Runnable {
        val descriptorUUID: UUID = BLE_UUID_NOTIFICATION_DESCRIPTOR
        var retryNum: Int = 0

        /**
         * 校验当前任务目标是否与入参完全相同
         */
        fun isSame(device: BluetoothDevice?, serviceUUID: UUID?, characteristicUUID: UUID?, descriptorUUID: UUID?): Boolean {
            return BluetoothUtil.deviceEquals(getBleDevice(), device) &&
                UuidUtil.equalUUID(this.serviceUUID, serviceUUID) &&
                UuidUtil.equalUUID(this.characteristicUUID, characteristicUUID) &&
                UuidUtil.equalUUID(this.descriptorUUID, descriptorUUID)
        }

        fun getBleDevice(): BluetoothDevice? {
            if (bluetoothGatt == null) return null
            return bluetoothGatt.device
        }

        override fun run() {
            val device = getBleDevice() ?: return
            startTimeoutTask(MSG_NOTIFY_BLE_TIMEOUT, device, CALLBACK_TIMEOUT)
            val ret = enableBLEDeviceNotification(bluetoothGatt, serviceUUID, characteristicUUID)
            JL_Log.i(
                TAG,
                "enableBLEDeviceNotification",
                CommonUtil.formatString(
                    "%s, service uuid = %s, characteristic uuid = %s",
                    ret,
                    UuidUtil.read16BitUUID(serviceUUID),
                    UuidUtil.read16BitUUID(characteristicUUID),
                ),
            )
            if (!ret) {
                removeTimeTask(MSG_NOTIFY_BLE_TIMEOUT)
                disconnectBleDevice(device)
            }
        }
    }

    /**
     * 异步检测系统当前已建立 GATT 连接的 BLE 设备线程
     */
    private inner class CheckSystemBleThread : Thread() {
        @SuppressLint("MissingPermission")
        override fun run() {
            if (!AppUtil.checkHasConnectPermission(mContext)) return
            val btManager = mContext.getSystemService(Context.BLUETOOTH_SERVICE) as? BluetoothManager ?: return
            try {
                val sysConnectedBleList = btManager.getConnectedDevices(BluetoothProfile.GATT) ?: return
                for (bleDev in sysConnectedBleList) {
                    if (isConnectedDevice(bleDev)) continue
                    handleDiscoveryBle(bleDev, BleScanInfo().setEnableConnect(true))
                }
                removeTimeTask(MSG_CHECK_SYSTEM_BLE_TIMEOUT)
            } catch (ignore: Exception) {
            }
        }
    }

    companion object {
        /** 日志标识 TAG */
        private const val TAG = "BleManager"

        /** 判定为闪断并触发自动重连的最小连接时长阈值 (8 秒) */
        private const val MIN_CONNECT_TIME = 8 * 1000L

        /** 杰理 OTA 标准服务 UUID */
        @JvmField
        val BLE_UUID_SERVICE: UUID = BluetoothConstant.UUID_SERVICE

        /** 杰理 OTA 固件数据写特征值 UUID */
        @JvmField
        val BLE_UUID_WRITE: UUID = BluetoothConstant.UUID_WRITE

        /** 杰理 OTA 设备通知特征值 UUID */
        @JvmField
        val BLE_UUID_NOTIFICATION: UUID = BluetoothConstant.UUID_NOTIFICATION

        /** 标准客户端特征配置描述符 (CCCD) UUID (0x2902) */
        @JvmField
        val BLE_UUID_NOTIFICATION_DESCRIPTOR: UUID = UUID.fromString("00002902-0000-1000-8000-00805F9B34FB")

        /** 单包数据发送等待 ACK 的最大超时时间 (毫秒) */
        const val SEND_DATA_MAX_TIMEOUT = 8000

        /** 默认 BLE 扫描超时时长 (12 秒) */
        private const val SCAN_BLE_TIMEOUT = 12 * 1000L

        /** BLE 建立连接超时时长 (40 秒) */
        private const val CONNECT_BLE_TIMEOUT = 40 * 1000L

        /** 通用回调响应超时时长 (6 秒) */
        private const val CALLBACK_TIMEOUT = 6000L

        @Suppress("unused")
        private const val RECONNECT_BLE_DELAY = 2000

        /** 消息类型：BLE 扫描超时 */
        private const val MSG_SCAN_BLE_TIMEOUT = 0x1010

        /** 消息类型：BLE 连接超时 */
        private const val MSG_CONNECT_BLE_TIMEOUT = 0x1011

        /** 消息类型：扫描 HID 设备定时轮询 */
        private const val MSG_SCAN_HID_DEVICE = 0x1012

        /** 消息类型：特征值通知使能超时 */
        private const val MSG_NOTIFY_BLE_TIMEOUT = 0x1013

        /** 消息类型：修改 BLE MTU 超时 */
        private const val MSG_CHANGE_BLE_MTU_TIMEOUT = 0x1014

        /** 消息类型：GATT 服务发现超时 */
        private const val MSG_DISCOVER_SERVICES_TIMEOUT = 0x1015

        /** 消息类型：BLE 断开连接超时 */
        private const val MSG_DISCONNECT_BLE_TIMEOUT = 0x1016

        /** 消息类型：检测系统 BLE 设备超时 */
        private const val MSG_CHECK_SYSTEM_BLE_TIMEOUT = 0x1017

        /** 单例静态引用句柄 */
        @SuppressLint("StaticFieldLeak")
        @Volatile
        private var instance: BleManager? = null

        /**
         * 获取 [BleManager] 全局单例
         *
         * @return [BleManager] 实例
         */
        @JvmStatic
        fun getInstance(): BleManager {
            if (instance == null) {
                synchronized(BleManager::class.java) {
                    if (instance == null) {
                        instance = BleManager(OtaRuntime.getContext())
                        JL_Log.w(TAG, "init", "instance : $instance")
                    }
                }
            }
            return instance!!
        }
    }
}
