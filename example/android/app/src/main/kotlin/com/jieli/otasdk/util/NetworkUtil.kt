package com.jieli.otasdk.util

import android.content.Context
import android.net.ConnectivityManager
import android.net.NetworkCapabilities
import android.net.wifi.WifiManager
import android.os.Build
import com.jieli.jl_bt_ota.util.JL_Log
import java.net.Inet4Address
import java.util.Locale

/**
 * NetworkUtil
 * @author zqjasonZhong
 * @since 2025/6/25
 * @email zhongzhuocheng@zh-jieli.com
 * @desc 网络工具
 */
object NetworkUtil {
    private const val TAG = "NetworkUtil"
    private const val UNKNOWN_IP = "0.0.0.0"
    private const val IPV4_OCTET_MASK = 0xff

    /**
     * Checks if the device is currently connected to WiFi.
     *
     * @param context The application context
     * @return true if connected to WiFi, false otherwise
     */
    fun isWifiConnected(context: Context): Boolean {
        val connectivityManager = context.getSystemService(
            Context.CONNECTIVITY_SERVICE
        ) as ConnectivityManager

        return if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
            connectivityManager.activeNetwork
                ?.let { connectivityManager.getNetworkCapabilities(it) }
                ?.hasTransport(NetworkCapabilities.TRANSPORT_WIFI) == true
        } else {
            @Suppress("DEPRECATION")
            connectivityManager.activeNetworkInfo?.type == ConnectivityManager.TYPE_WIFI
        }
    }

    // 获取Wi-Fi IP地址（仅当连接Wi-Fi时有效）
    fun getWifiIpAddress(context: Context): String? {
        if (!isWifiConnected(context)) return null
        return try {
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
                ipv4FromLinkProperties(context)
            } else {
                ipv4FromWifiManager(context)
            }
        } catch (e: Exception) {
            JL_Log.e(TAG, "getWifiIpAddress", "Error getting WiFi IP. $e")
            null
        }
    }

    private fun ipv4FromLinkProperties(context: Context): String? {
        val connectivityManager = context.applicationContext.getSystemService(
            Context.CONNECTIVITY_SERVICE,
        ) as ConnectivityManager
        val network = connectivityManager.activeNetwork ?: return null
        val addresses = connectivityManager.getLinkProperties(network)?.linkAddresses ?: return null
        return addresses
            .map { it.address }
            .filterIsInstance<Inet4Address>()
            .firstOrNull { !it.isLoopbackAddress && !it.isLinkLocalAddress }
            ?.hostAddress
    }

    @Suppress("DEPRECATION")
    private fun ipv4FromWifiManager(context: Context): String {
        val wifiManager = context.applicationContext.getSystemService(Context.WIFI_SERVICE) as WifiManager
        val ipAddress = wifiManager.connectionInfo.ipAddress
        return String.format(
            Locale.ENGLISH,
            "%d.%d.%d.%d",
            ipAddress and IPV4_OCTET_MASK,
            ipAddress shr 8 and IPV4_OCTET_MASK,
            ipAddress shr 16 and IPV4_OCTET_MASK,
            ipAddress shr 24 and IPV4_OCTET_MASK,
        )
    }
}
