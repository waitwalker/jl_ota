package com.jieli.otasdk

import android.content.Context
import android.content.Intent
import android.provider.Settings
import com.jieli.jl_bt_ota.interfaces.IActionCallback
import com.jieli.jl_bt_ota.util.BluetoothUtil
import com.jieli.otasdk.util.PermissionUtil

/**
 * Des: 检查蓝牙环境的工具类
 * author: lifang
 * date: 2025/07/22
 * Copyright: Jieli Technology
 * Modify date: 2025/08/05
 * Modified by: lifang
 */
object BluetoothEnvironmentChecker {

    /**
     * 检查蓝牙环境：
     * 1. 蓝牙权限
     * 2. 定位权限
     * 3. 蓝牙是否启用
     * 4. 定位服务是否启用
     *
     * @param context 上下文
     * @param callback 回调接口
     */
    fun checkBluetoothEnvironment(context: Context): CheckResult {
        return CheckResult(
            hasBluetoothPermission = PermissionUtil.hasBluetoothPermission(context),
            hasLocationPermission = PermissionUtil.hasLocationPermission(context),
            isBluetoothEnabled = BluetoothUtil.isBluetoothEnable(),
            isLocationServiceEnabled = PermissionUtil.isLocationServiceEnabled(context)
        )
    }

    data class CheckResult(
        val hasBluetoothPermission: Boolean,
        val hasLocationPermission: Boolean,
        val isBluetoothEnabled: Boolean,
        val isLocationServiceEnabled: Boolean
    ) {
        val isAllReady: Boolean
            get() = hasBluetoothPermission && hasLocationPermission &&
                    isBluetoothEnabled && isLocationServiceEnabled
    }

//    fun checkBluetoothEnvironment(context: Context, callback: IActionCallback<Boolean>) {
//        if (!PermissionUtil.hasBluetoothPermission(context)) {
//            //ToastUtil.showToastShort(context.getString(R.string.grant_bluetooth_permission))
//            openBluetoothSettings(context)
//            callback.onSuccess(false)
//            return
//        }
//        if (!PermissionUtil.hasLocationPermission(context)) {
//            //ToastUtil.showToastShort(context.getString(R.string.grant_location_permission))
//            openLocationSettings(context)
//            callback.onSuccess(false)
//            return
//        }
//        if (!BluetoothUtil.isBluetoothEnable()) {
//            //ToastUtil.showToastShort(context.getString(R.string.open_bluetooth_tip))
//            openBluetoothSettings(context)
//            callback.onSuccess(false)
//            return
//        }
//        if (!PermissionUtil.isLocationServiceEnabled(context)) {
//            //ToastUtil.showToastShort(context.getString(R.string.open_gpg_tip))
//            openLocationSettings(context)
//            callback.onSuccess(false)
//            return
//        }
//        callback.onSuccess(true)
//    }

    /**
     * 跳转到蓝牙设置
     */
    fun openBluetoothSettings(context: Context) {
        context.startActivity(Intent(Settings.ACTION_BLUETOOTH_SETTINGS))
    }

    /**
     * 跳转到定位服务设置
     */
    fun openLocationSettings(context: Context) {
        context.startActivity(Intent(Settings.ACTION_LOCATION_SOURCE_SETTINGS))
    }
}
