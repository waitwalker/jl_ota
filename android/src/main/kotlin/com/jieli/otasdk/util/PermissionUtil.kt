package com.jieli.otasdk.util

import android.Manifest
import android.content.Context
import android.content.pm.PackageManager
import android.location.LocationManager
import android.os.Build
import androidx.core.content.ContextCompat

/**
 * 蓝牙与定位权限及系统服务检测工具类
 *
 * 封装 Android 12 (API 31) 细分权限（BLUETOOTH_SCAN, BLUETOOTH_CONNECT）与低版本定位权限（ACCESS_FINE_LOCATION, ACCESS_COARSE_LOCATION）的兼容性校验，
 * 以及 GPS/网络定位服务开关状态检测。
 */
object PermissionUtil {

    /**
     * 检测应用是否具备定位权限
     *
     * Android 12 (API 31) 及以上系统蓝牙扫描无需定位权限（返回 true）；低版本需要粗略或精确定位权限。
     *
     * @param context 上下文对象
     * @return true 表示定位权限已满足
     */
    fun hasLocationPermission(context: Context): Boolean {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
            return true
        }
        return context.hasSelfPermission(Manifest.permission.ACCESS_FINE_LOCATION) ||
            context.hasSelfPermission(Manifest.permission.ACCESS_COARSE_LOCATION)
    }

    /**
     * 检测应用是否具备蓝牙连接权限
     *
     * Android 12 (API 31) 及以上需校验 [Manifest.permission.BLUETOOTH_CONNECT]；低版本默认返回 true。
     *
     * @param context 上下文对象
     * @return true 表示具备连接权限
     */
    fun hasBluetoothConnectPermission(context: Context): Boolean {
        return if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
            context.hasSelfPermission(Manifest.permission.BLUETOOTH_CONNECT)
        } else {
            true
        }
    }

    /**
     * 检测应用是否具备蓝牙扫描权限
     *
     * Android 12 (API 31) 及以上需校验 [Manifest.permission.BLUETOOTH_SCAN]；低版本默认返回 true。
     *
     * @param context 上下文对象
     * @return true 表示具备扫描权限
     */
    fun hasBluetoothScanPermission(context: Context): Boolean {
        return if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
            context.hasSelfPermission(Manifest.permission.BLUETOOTH_SCAN)
        } else {
            true
        }
    }

    /**
     * 综合检测应用是否已获得所有必需的蓝牙运行权限（扫描与连接）
     *
     * @param context 上下文对象
     * @return true 表示全部蓝牙权限均已获取
     */
    fun hasBluetoothPermission(context: Context): Boolean {
        return hasBluetoothScanPermission(context) && hasBluetoothConnectPermission(context)
    }

    /**
     * 检测系统定位服务总开关是否开启（GPS 或网络定位）
     *
     * Android 12 及以上免定位直接返回 true；低版本校验 LocationManager 服务开关。
     *
     * @param context 上下文对象
     * @return true 表示定位服务已开启
     */
    fun isLocationServiceEnabled(context: Context): Boolean {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
            return true
        }
        val locationManager = context.getSystemService(Context.LOCATION_SERVICE) as LocationManager
        return locationManager.isProviderEnabled(LocationManager.GPS_PROVIDER) ||
            locationManager.isProviderEnabled(LocationManager.NETWORK_PROVIDER)
    }

    /**
     * 扩展函数：检测当前 Context 是否已获得指定的系统权限
     *
     * @param permission 权限常量字符串
     * @return true 表示已获得授权
     */
    private fun Context.hasSelfPermission(permission: String): Boolean {
        return ContextCompat.checkSelfPermission(this, permission) == PackageManager.PERMISSION_GRANTED
    }
}
