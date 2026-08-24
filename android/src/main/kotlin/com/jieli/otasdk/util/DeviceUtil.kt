package com.jieli.otasdk.util

import android.annotation.SuppressLint
import android.bluetooth.BluetoothDevice
import android.content.Context
import com.jieli.otasdk.R
import com.jieli.otasdk.data.constant.OtaConstant
import com.jieli.otasdk.data.model.device.ScanDevice

/**
 * DeviceUtil
 * @author zqjasonZhong
 * @since 2025/1/14
 * @email zhongzhuocheng@zh-jieli.com
 * @desc 设备工具类
 */
object DeviceUtil {

    /**
     * 获取设备名称。
     *
     * @param context 应用上下文。
     * @param device  蓝牙设备。
     * @return 设备名称，如果无法获取则返回 "N/A"。
     */
    @SuppressLint("MissingPermission")
    fun getDeviceName(context: Context, device: BluetoothDevice?): String {
        if (!PermissionUtil.hasBluetoothConnectPermission(context) || device == null) return "N/A"
        return device.name ?: "N/A"
    }

    /**
     * 获取蓝牙设备类型描述。
     *
     * @param context 应用上下文。
     * @param device  蓝牙设备。
     * @return 设备类型描述字符串。
     */
    @SuppressLint("MissingPermission")
    fun getBtDeviceTypeString(context: Context, device: BluetoothDevice?): String {
        if (!PermissionUtil.hasBluetoothConnectPermission(context) || device == null) return ""
        return when (device.type) {
            BluetoothDevice.DEVICE_TYPE_CLASSIC -> context.getString(R.string.classic_device_type)
            BluetoothDevice.DEVICE_TYPE_LE -> context.getString(R.string.ble_device_type)
            BluetoothDevice.DEVICE_TYPE_DUAL -> context.getString(R.string.dual_mode)
            BluetoothDevice.DEVICE_TYPE_UNKNOWN -> context.getString(R.string.unknown_device)
            else -> ""
        }
    }

    /**
     * 获取设备描述信息。
     *
     * @param device 扫描到的设备模型。
     * @return 设备描述信息，格式为 "rssi: [RSSI], address: [地址]"。
     */
    fun getDeviceDesc(device: ScanDevice?): String {
        return device?.let {
            OtaConstant.formatString("rssi: %d, address: %s", it.rssi, it.device.address)
        } ?: ""
    }
}