package com.jieli.otasdk.util

import android.Manifest
import android.content.Context
import android.content.pm.PackageManager
import android.location.LocationManager
import android.os.Build
import androidx.core.content.ContextCompat

/**
 * Bluetooth and location permission checks used before scan and connect.
 */
object PermissionUtil {

    fun hasLocationPermission(context: Context): Boolean {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
            return true
        }
        return context.hasSelfPermission(Manifest.permission.ACCESS_FINE_LOCATION) ||
            context.hasSelfPermission(Manifest.permission.ACCESS_COARSE_LOCATION)
    }

    fun hasBluetoothConnectPermission(context: Context): Boolean {
        return if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
            context.hasSelfPermission(Manifest.permission.BLUETOOTH_CONNECT)
        } else {
            true
        }
    }

    fun hasBluetoothScanPermission(context: Context): Boolean {
        return if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
            context.hasSelfPermission(Manifest.permission.BLUETOOTH_SCAN)
        } else {
            true
        }
    }

    fun hasBluetoothPermission(context: Context): Boolean {
        return hasBluetoothScanPermission(context) && hasBluetoothConnectPermission(context)
    }

    fun isLocationServiceEnabled(context: Context): Boolean {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
            return true
        }
        val locationManager = context.getSystemService(Context.LOCATION_SERVICE) as LocationManager
        return locationManager.isProviderEnabled(LocationManager.GPS_PROVIDER) ||
            locationManager.isProviderEnabled(LocationManager.NETWORK_PROVIDER)
    }

    private fun Context.hasSelfPermission(permission: String): Boolean {
        return ContextCompat.checkSelfPermission(this, permission) == PackageManager.PERMISSION_GRANTED
    }
}
