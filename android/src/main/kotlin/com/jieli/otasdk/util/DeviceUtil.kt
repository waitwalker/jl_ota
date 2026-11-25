package com.jieli.otasdk.util

import android.annotation.SuppressLint
import android.bluetooth.BluetoothDevice
import android.content.Context
import com.jieli.otasdk.R
import com.jieli.otasdk.data.constant.OtaConstant
import com.jieli.otasdk.data.model.device.ScanDevice

/**
 * 蓝牙设备信息显示辅助工具类
 *
 * 提供获取蓝牙设备名称、设备物理类型（经典蓝牙、BLE、双模）字符串描述以及扫描摘要信息的快捷方法。
 */
object DeviceUtil {

    /**
     * 安全获取蓝牙设备的系统广播/配对名称
     *
     * 校验权限后再读取名称，无权限或获取失败时返回 "N/A"
     *
     * @param context 上下文对象
     * @param device 目标蓝牙物理设备
     * @return 设备名称，如果无法获取则返回 "N/A"
     */
    @SuppressLint("MissingPermission")
    fun getDeviceName(context: Context, device: BluetoothDevice?): String {
        if (!PermissionUtil.hasBluetoothConnectPermission(context) || device == null) return "N/A"
        return device.name ?: "N/A"
    }

    /**
     * 获取蓝牙设备物理类型（经典蓝牙、BLE、双模蓝牙）的本地化描述字符串
     *
     * @param context 上下文对象
     * @param device 目标蓝牙物理设备
     * @return 设备类型描述字符串（如 "BLE 设备"、"经典蓝牙设备" 等）
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
     * 获取扫描到的设备的摘要描述信息
     *
     * @param device 扫描到的设备包装模型 [ScanDevice]
     * @return 格式化后的描述文本，形如 "rssi: -65, address: 11:22:33:44:55:66"
     */
    fun getDeviceDesc(device: ScanDevice?): String {
        return device?.let {
            OtaConstant.formatString("rssi: %d, address: %s", it.rssi, it.device.address)
        } ?: ""
    }
}
