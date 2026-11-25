package com.jieli.otasdk

import android.content.Context
import android.content.Intent
import android.os.Build
import android.provider.Settings
import com.jieli.jl_bt_ota.interfaces.IActionCallback
import com.jieli.jl_bt_ota.util.BluetoothUtil
import com.jieli.otasdk.util.PermissionUtil

/**
 * 蓝牙与定位运行环境检查工具类
 *
 * 负责检测蓝牙权限、定位权限、系统蓝牙开关以及系统定位开关是否就绪，
 * 并提供快捷跳转系统设置界面的辅助方法。
 */
object BluetoothEnvironmentChecker {

    /**
     * 检查当前设备的蓝牙与定位运行环境：
     * 1. 蓝牙扫描与连接权限
     * 2. Android 11 及以下系统的定位权限
     * 3. 系统蓝牙硬件开关是否开启
     * 4. Android 11 及以下系统的定位服务开关是否开启
     *
     * @param context 上下文对象
     * @return 包含各检测项状态的 [CheckResult] 实例
     */
    fun checkBluetoothEnvironment(context: Context): CheckResult {
        val isAndroid12OrAbove = Build.VERSION.SDK_INT >= Build.VERSION_CODES.S
        return CheckResult(
            hasBluetoothPermission = PermissionUtil.hasBluetoothPermission(context),
            hasLocationPermission = if (isAndroid12OrAbove) true else PermissionUtil.hasLocationPermission(context),
            isBluetoothEnabled = BluetoothUtil.isBluetoothEnable(),
            isLocationServiceEnabled = if (isAndroid12OrAbove) true else PermissionUtil.isLocationServiceEnabled(context)
        )
    }

    /**
     * 蓝牙环境检测结果数据模型
     *
     * @property hasBluetoothPermission 是否拥有必要的蓝牙权限（Android 12+ 为 BLUETOOTH_SCAN/CONNECT）
     * @property hasLocationPermission 是否拥有定位权限（Android 12+ 免定位返回 true）
     * @property isBluetoothEnabled 系统蓝牙开关是否已打开
     * @property isLocationServiceEnabled 系统定位服务是否已启用
     */
    data class CheckResult(
        val hasBluetoothPermission: Boolean,
        val hasLocationPermission: Boolean,
        val isBluetoothEnabled: Boolean,
        val isLocationServiceEnabled: Boolean
    ) {
        /**
         * 综合判断所有必要的前置条件是否全部就绪
         */
        val isAllReady: Boolean
            get() = hasBluetoothPermission && hasLocationPermission &&
                    isBluetoothEnabled && isLocationServiceEnabled
    }

    /**
     * 引导用户跳转至系统蓝牙设置界面
     *
     * @param context 上下文对象
     */
    fun openBluetoothSettings(context: Context) {
        context.startActivity(Intent(Settings.ACTION_BLUETOOTH_SETTINGS))
    }

    /**
     * 引导用户跳转至系统位置信息服务设置界面
     *
     * @param context 上下文对象
     */
    fun openLocationSettings(context: Context) {
        context.startActivity(Intent(Settings.ACTION_LOCATION_SOURCE_SETTINGS))
    }
}
