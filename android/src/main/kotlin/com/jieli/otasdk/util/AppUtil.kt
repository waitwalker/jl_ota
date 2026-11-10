package com.jieli.otasdk.util

import android.Manifest
import android.annotation.SuppressLint
import android.bluetooth.BluetoothAdapter
import android.bluetooth.BluetoothDevice
import android.bluetooth.BluetoothGatt
import android.bluetooth.BluetoothProfile
import android.content.Context
import android.content.pm.PackageManager
import android.os.Build
import android.os.ParcelUuid
import android.text.TextUtils
import androidx.core.app.ActivityCompat
import com.jieli.jl_bt_ota.constant.StateCode
import com.jieli.jl_bt_ota.util.BluetoothUtil
import com.jieli.jl_bt_ota.util.CHexConver
import com.jieli.jl_bt_ota.util.JL_Log
import com.jieli.otasdk.OtaRuntime
import java.util.Date
import java.util.Locale
import java.util.UUID

/**
 * 应用程序与蓝牙通用工具类
 *
 * 提供系统动态权限检查、UI 点击防重与多连击计数判定、蓝牙适配器控制与底层 GATT 服务缓存刷新、
 * 设备信息格式化解析与连接状态码转换等常用工具方法。
 */
object AppUtil {
    /** 快速双击判定默认时间间隔（毫秒，2000ms） */
    private const val DOUBLE_CLICK_INTERVAL = 2000L

    /** 双击及单次连续点击上次触发的时间戳（毫秒） */
    private var lastClickTime = 0L

    /** 当前连续点击累计计数值 */
    private var clickCount = 0

    /** 定次连击判定上次触发的时间戳（毫秒） */
    private var theLastClickTime = 0L

    /** 定次连击当前累计计数值 */
    private var theClickCount = 0

    /**
     * 检查当前应用是否已被授予指定的系统权限
     *
     * @param context 上下文对象
     * @param permission 待检测的系统权限字符串（例如 [Manifest.permission.ACCESS_FINE_LOCATION]）
     * @return true 表示权限已被授予，false 表示未授予或 context 为空
     */
    @JvmStatic
    fun isHasPermission(context: Context?, permission: String): Boolean {
        return context != null && ActivityCompat.checkSelfPermission(context, permission) == PackageManager.PERMISSION_GRANTED
    }

    /**
     * 检查当前应用是否已被授予位置定位权限
     *
     * Android 12 (API 31) 及以上系统蓝牙扫描可声明 `neverForLocation`，无需定位权限直接返回 true；
     * 低于 Android 12 的设备则必须具备粗略定位或精确定位权限中的至少一项。
     *
     * @param context 上下文对象
     * @return true 表示具备定位权限或系统版本高于 Android 12，false 表示缺少定位权限
     */
    @JvmStatic
    fun isHasLocationPermission(context: Context?): Boolean {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
            return true
        }
        return isHasPermission(context, Manifest.permission.ACCESS_COARSE_LOCATION) ||
            isHasPermission(context, Manifest.permission.ACCESS_FINE_LOCATION)
    }

    /**
     * 检查当前应用是否已被授予外部存储读写权限
     *
     * Android 9.0 (API 28) 及以上仅需读取权限；低于 Android 9.0 则需同时具备读写权限。
     *
     * @param context 上下文对象
     * @return true 表示已具备存储权限，false 表示未具备
     */
    @JvmStatic
    fun isHasStoragePermission(context: Context?): Boolean {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.P) {
            return isHasPermission(context, Manifest.permission.READ_EXTERNAL_STORAGE)
        }
        return isHasPermission(context, Manifest.permission.WRITE_EXTERNAL_STORAGE) &&
            isHasPermission(context, Manifest.permission.READ_EXTERNAL_STORAGE)
    }

    /**
     * 检查应用是否具备 Android 12+ 的蓝牙连接权限 [Manifest.permission.BLUETOOTH_CONNECT]
     *
     * 低于 Android 12 的设备默认具备该权限，直接返回 true。
     *
     * @param context 上下文对象
     * @return true 表示具备蓝牙连接权限，false 表示未具备
     */
    @JvmStatic
    fun checkHasConnectPermission(context: Context?): Boolean {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
            return isHasPermission(context, "android.permission.BLUETOOTH_CONNECT")
        }
        return true
    }

    /**
     * 检查应用是否具备 Android 12+ 的蓝牙扫描权限 [Manifest.permission.BLUETOOTH_SCAN]
     *
     * 低于 Android 12 的设备默认具备该权限，直接返回 true。
     *
     * @param context 上下文对象
     * @return true 表示具备蓝牙扫描权限，false 表示未具备
     */
    @JvmStatic
    fun checkHasScanPermission(context: Context?): Boolean {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
            return isHasPermission(context, "android.permission.BLUETOOTH_SCAN")
        }
        return true
    }

    /**
     * 使用默认时间间隔（2000毫秒）判断本次点击是否属于快速重复点击
     *
     * @return true 表示属于快速连击（应拦截），false 表示正常单次点击
     */
    @JvmStatic
    fun isFastDoubleClick(): Boolean = isFastDoubleClick(DOUBLE_CLICK_INTERVAL)

    /**
     * 在指定的时间间隔内判断本次点击是否属于快速重复点击
     *
     * @param interval 连击防抖时间阈值（毫秒）
     * @return true 表示点击时间间隔在阈值内（属于连击），false 表示超出阈值（记录本次时间并允许通过）
     */
    @JvmStatic
    fun isFastDoubleClick(interval: Long): Boolean {
        val currentTime = Date().time
        if (currentTime - lastClickTime <= interval) {
            return true
        }
        lastClickTime = currentTime
        return false
    }

    /**
     * 在指定的时间间隔内累计快速连续点击的次数
     *
     * 若两次点击间隔在阈值内则累计次数 +1；超出阈值则计数重置为 1。
     *
     * @param interval 连击判定时间阈值（毫秒）
     * @return 当前连续点击的累计计数值
     */
    @JvmStatic
    fun isFastContinuousClick(interval: Long): Int {
        val currentTime = Date().time
        clickCount = if (currentTime - lastClickTime <= interval) clickCount + 1 else 1
        lastClickTime = currentTime
        return clickCount
    }

    /**
     * 判定在指定的时间间隔内是否达到了指定的连续点击目标次数（例如触发彩蛋或开发者模式）
     *
     * 达到目标次数后将清空计数器并返回 true。
     *
     * @param interval 连击有效间隔阈值（毫秒）
     * @param times 目标连续点击次数
     * @return true 表示恰好达成目标次数，false 表示未达到或已超时重置
     */
    @JvmStatic
    fun isFastContinuousClick(interval: Long, times: Int): Boolean {
        val currentTime = Date().time
        theClickCount = if (currentTime - theLastClickTime <= interval) theClickCount + 1 else 1
        theLastClickTime = currentTime
        val state = theClickCount == times
        if (state) {
            theLastClickTime = 0
            theClickCount = 0
        }
        return state
    }

    /**
     * 开启系统蓝牙适配器
     *
     * 需具备蓝牙连接权限；若当前未开启则调用底层系统 API 开启。
     *
     * @param context 上下文对象
     * @return true 表示开启成功或原本已是开启状态，false 表示缺少权限或设备不支持蓝牙
     */
    @JvmStatic
    @SuppressLint("MissingPermission")
    fun enableBluetooth(context: Context?): Boolean {
        if (!checkHasConnectPermission(context)) return false
        val bluetoothAdapter = BluetoothAdapter.getDefaultAdapter() ?: return false
        var ret = bluetoothAdapter.isEnabled
        if (!ret) {
            ret = bluetoothAdapter.enable()
        }
        return ret
    }

    /**
     * 通过反射调用 Android 隐藏私有 API `BluetoothGatt#refresh()` 清空 BLE GATT 服务本地缓存
     *
     * 在设备 OTA 重启或服务 UUID 变更时，Android 系统内部可能会缓存旧的 Services，
     * 调用该方法可以强制驱动系统重新走服务发现。
     *
     * @param context 上下文对象
     * @param bluetoothGatt 目标设备的 [BluetoothGatt] 实例
     * @return true 表示反射刷新方法调用成功并返回 true，false 表示调用失败或缺少权限
     */
    @JvmStatic
    @SuppressLint("MissingPermission")
    fun refreshBleDeviceCache(context: Context?, bluetoothGatt: BluetoothGatt?): Boolean {
        if (bluetoothGatt == null || !checkHasConnectPermission(context)) return false
        try {
            val refreshMethod = bluetoothGatt.javaClass.getMethod("refresh")
            return refreshMethod.invoke(bluetoothGatt) as Boolean
        } catch (e: Exception) {
            e.printStackTrace()
        }
        return false
    }

    /**
     * 检查目标蓝牙设备是否广播或包含指定 UUID 的 Profile（服务）
     *
     * @param context 上下文对象
     * @param device 待检测的目标蓝牙设备
     * @param uuid 待匹配的服务 [UUID]
     * @return true 表示包含该服务 UUID，false 表示不包含、缺少权限或参数无效
     */
    @JvmStatic
    @SuppressLint("MissingPermission")
    fun deviceHasProfile(context: Context?, device: BluetoothDevice?, uuid: UUID?): Boolean {
        if (!BluetoothUtil.isBluetoothEnable() || device == null || uuid == null ||
            TextUtils.isEmpty(uuid.toString()) || !checkHasConnectPermission(context)
        ) {
            return false
        }
        val uuids: Array<ParcelUuid>? = device.uuids
        if (uuids == null) return false
        for (uid in uuids) {
            if (uuid.toString().lowercase(Locale.getDefault()).equals(uid.toString(), ignoreCase = true)) {
                return true
            }
        }
        return false
    }

    /**
     * 获取蓝牙设备的广播或本地名称
     *
     * @param context 上下文对象
     * @param device 目标蓝牙设备
     * @return 设备名称字符串，若名称为空或缺少权限则返回 "N/A"
     */
    @JvmStatic
    @SuppressLint("MissingPermission")
    fun getDeviceName(context: Context?, device: BluetoothDevice?): String {
        if (device == null || !checkHasConnectPermission(context)) return "N/A"
        val name = device.name
        return if (TextUtils.isEmpty(name)) "N/A" else name
    }

    /**
     * 获取蓝牙设备的类型
     *
     * @param context 上下文对象
     * @param device 目标蓝牙设备
     * @return 设备类型常量，可能为 [BluetoothDevice.DEVICE_TYPE_CLASSIC]、[BluetoothDevice.DEVICE_TYPE_LE]、
     *         [BluetoothDevice.DEVICE_TYPE_DUAL] 或 [BluetoothDevice.DEVICE_TYPE_UNKNOWN]
     */
    @JvmStatic
    @SuppressLint("MissingPermission")
    fun getDeviceType(context: Context?, device: BluetoothDevice?): Int {
        if (device == null || !checkHasConnectPermission(context)) {
            return BluetoothDevice.DEVICE_TYPE_UNKNOWN
        }
        return device.type
    }

    /**
     * 格式化输出蓝牙设备的基本信息（MAC 地址、名称、类型等）
     *
     * @param device 目标蓝牙设备
     * @return 格式化后的描述文本
     */
    @JvmStatic
    fun printBtDeviceInfo(device: BluetoothDevice?): String {
        return BluetoothUtil.printBtDeviceInfo(OtaRuntime.getContext(), device)
    }

    /**
     * 遍历并详细输出 [BluetoothGatt] 中发现的全部服务、特征值及其描述符信息到日志中
     *
     * 仅在开启 SDK 日志（[JL_Log.isIsLog]）且具备连接权限时执行打印。
     *
     * @param context 上下文对象
     * @param device 目标蓝牙设备
     * @param gatt 目标设备对应的 GATT 客户端对象
     * @param status 服务发现状态码（通常 [BluetoothGatt.GATT_SUCCESS]）
     */
    @JvmStatic
    @SuppressLint("MissingPermission")
    fun printBleGattServices(context: Context?, device: BluetoothDevice?, gatt: BluetoothGatt?, status: Int) {
        if (device == null || gatt == null || !checkHasConnectPermission(context) || !JL_Log.isIsLog()) {
            return
        }
        val tag = "ble"
        JL_Log.d(
            tag,
            String.format(
                Locale.getDefault(),
                "[[============================Bluetooth[%s], Discovery Services status[%d]=================================]]\n",
                BluetoothUtil.printBtDeviceInfo(context, device),
                status,
            ),
        )
        val services = gatt.services
        if (services != null) {
            JL_Log.d(tag, "[[======Service Size:" + services.size + "======================\n")
            for (service in services) {
                if (service == null) continue
                JL_Log.d(tag, "[[======Service:" + service.uuid + "======================\n")
                val characteristics = service.characteristics ?: continue
                JL_Log.d(tag, "[[[[=============characteristics Size:" + characteristics.size + "======================\n")
                for (characteristic in characteristics) {
                    if (characteristic == null) continue
                    JL_Log.d(
                        tag,
                        "[[[[=============characteristic:" + characteristic.uuid +
                            ", write type : " + characteristic.writeType + "======================\n",
                    )
                    val descriptors = characteristic.descriptors ?: continue
                    JL_Log.d(tag, "[[[[[[=============descriptors Size:" + descriptors.size + "======================\n")
                    for (descriptor in descriptors) {
                        if (descriptor == null) continue
                        JL_Log.d(
                            tag,
                            "[[[[[[=============descriptor:" + descriptor.uuid + ", permission:" + descriptor.permissions +
                                "\nvalue : " + CHexConver.byte2HexStr(descriptor.value) + "======================\n",
                        )
                    }
                }
            }
        }
        JL_Log.d(
            tag,
            "[[============================Bluetooth[" + BluetoothUtil.printBtDeviceInfo(context, device) +
                "] Services show End=================================]]\n",
        )
    }

    /**
     * 将 Android 系统原生 [BluetoothProfile] 的连接状态转换为 SDK 统一的 [StateCode] 状态码
     *
     * @param status Android 系统原生连接状态（如 [BluetoothProfile.STATE_CONNECTED]、[BluetoothProfile.STATE_CONNECTING] 等）
     * @return 对应的 SDK 状态码（[StateCode.CONNECTION_OK]、[StateCode.CONNECTION_CONNECTING] 或 [StateCode.CONNECTION_DISCONNECT]）
     */
    @JvmStatic
    fun changeConnectStatus(status: Int): Int {
        return when (status) {
            BluetoothProfile.STATE_CONNECTED -> StateCode.CONNECTION_OK
            BluetoothProfile.STATE_CONNECTING -> StateCode.CONNECTION_CONNECTING
            else -> StateCode.CONNECTION_DISCONNECT
        }
    }
}

