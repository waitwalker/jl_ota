package com.jieli.otasdk.tool.config

import android.annotation.SuppressLint
import android.content.Context
import androidx.annotation.IntRange
import androidx.core.content.edit
import com.jieli.component.utils.SystemUtil
import com.jieli.jl_bt_ota.constant.BluetoothConstant
import com.jieli.otasdk.MyApplication
import com.jieli.otasdk.data.constant.OtaConstant

/**
 * @author zqjasonZhong
 * @since 2022/9/8
 * @email zhongzhuocheng@zh-jieli.com
 * @desc Configuration helper class
 */
open class ConfigHelper private constructor(context: Context) {

    companion object {
        /**
         * Latest protocol APP version number
         */
        private const val LATEST_POLICY_APP_VERSION = 10800

        // Download folder
        private const val KEY_DOWNLOAD_URI = "download_uri"

        // Agreed policy version number
        private const val KEY_AGREE_POLICY_VERSION = "agree_policy_version"

        // Communication method
        private const val KEY_COMMUNICATION_WAY = "communication_way"

        // Whether to use device authentication
        private const val KEY_IS_USE_DEVICE_AUTH = "is_use_device_auth"

        // Whether it is a HID device
        private const val KEY_IS_HID_DEVICE = "is_hid_device"

        // Whether to use custom reconnection method
        private const val KEY_USE_CUSTOM_RECONNECT_WAY = "use_custom_reconnect_way"

        // BLE MTU request value
        private const val KEY_BLE_MTU_VALUE = "ble_mtu_value"

        // Whether to enable SPP multi-channel
        private const val KEY_SPP_MULTIPLE_CHANNEL = "spp_multiple_channel"

        // Custom SPP channel
        private const val KEY_SPP_CUSTOM_UUID = "spp_custom_uuid"

        // Whether to auto-test OTA
        private const val KEY_AUTO_TEST_OTA = "auto_test_ota"

        // Auto-test count
        private const val KEY_AUTO_TEST_COUNT = "auto_test_count"

        // Whether to allow fault tolerance during auto-test OTA
        private const val KEY_FAULT_TOLERANT = "fault_tolerant"

        // Fault tolerance count
        private const val KEY_FAULT_TOLERANT_COUNT = "fault_tolerant_count"

        // Scan filter parameter
        private const val KEY_SCAN_FILTER_STRING = "scan_filter_string"

        // Developer mode
        private const val KEY_DEVELOP_MODE = "develop_mode"

        // Broadcast box mode
        private const val KEY_BROADCAST_BOX = "broadcast_box_switch"

        @Volatile
        private var instance: ConfigHelper? = null

        fun getInstance(): ConfigHelper {
            return instance ?: synchronized(this) {
                instance ?: ConfigHelper(MyApplication.getInstance()).also { instance = it }
            }
        }

        /**
         * Destroy the singleton instance and release resources
         * This should be called during application shutdown or when the config is no longer needed
         */
        fun destroyInstance() {
            instance = null
        }
    }

    // Use application context to prevent memory leaks
    private val appContext = context.applicationContext
    private val preferences = appContext.getSharedPreferences("ota_config_data", Context.MODE_PRIVATE)

    fun isAgreePolicy(): Boolean {
        val cacheVersion = preferences.getInt(KEY_AGREE_POLICY_VERSION, 0)
        if (cacheVersion <= 0) return false
        return cacheVersion >= LATEST_POLICY_APP_VERSION
    }

    fun setAgreePolicyVersion(context: Context) {
        val appVersion = SystemUtil.getVersion(context)
        preferences.edit { putInt(KEY_AGREE_POLICY_VERSION, appVersion) }
    }

    fun isBleWay(): Boolean = getConnectWay() == BluetoothConstant.PROTOCOL_TYPE_BLE

    fun isSppWay(): Boolean = getConnectWay() == BluetoothConstant.PROTOCOL_TYPE_SPP

    fun getConnectWay(): Int = preferences.getInt(KEY_COMMUNICATION_WAY, OtaConstant.CURRENT_PROTOCOL)

    fun setConnectWay(connectWay: Int) {
        preferences.edit { putInt(KEY_COMMUNICATION_WAY, connectWay) }
    }

    fun isUseDeviceAuth(): Boolean = preferences.getBoolean(KEY_IS_USE_DEVICE_AUTH, OtaConstant.IS_NEED_DEVICE_AUTH)

    fun setUseDeviceAuth(isAuth: Boolean) {
        preferences.edit { putBoolean(KEY_IS_USE_DEVICE_AUTH, isAuth) }
    }

    fun isHidDevice(): Boolean = preferences.getBoolean(KEY_IS_HID_DEVICE, OtaConstant.HID_DEVICE_WAY)

    fun setHidDevice(isHid: Boolean) {
        preferences.edit { putBoolean(KEY_IS_HID_DEVICE, isHid) }
    }

    fun isUseCustomReConnectWay(): Boolean = preferences.getBoolean(
        KEY_USE_CUSTOM_RECONNECT_WAY,
        OtaConstant.NEED_CUSTOM_RECONNECT_WAY
    )

    fun setUseCustomReConnectWay(isCustom: Boolean) {
        preferences.edit { putBoolean(KEY_USE_CUSTOM_RECONNECT_WAY, isCustom) }
    }

    fun getBleRequestMtu(): Int = preferences.getInt(KEY_BLE_MTU_VALUE, BluetoothConstant.BLE_MTU_MAX)

    fun setBleRequestMtu(@IntRange(from = 20, to = 509) mtu: Int) {
        preferences.edit { putInt(KEY_BLE_MTU_VALUE, mtu) }
    }

    fun isUseMultiSppChannel(): Boolean = preferences.getBoolean(
        KEY_SPP_MULTIPLE_CHANNEL,
        OtaConstant.USE_SPP_MULTIPLE_CHANNEL
    )

    fun setUseMultiSppChannel(isUseMulti: Boolean) {
        preferences.edit { putBoolean(KEY_SPP_MULTIPLE_CHANNEL, isUseMulti) }
    }

    fun getCustomSppChannel(): String? = preferences.getString(KEY_SPP_CUSTOM_UUID, OtaConstant.UUID_SPP.toString())

    fun setCustomSppChannel(uuid: String?) {
        preferences.edit { putString(KEY_SPP_CUSTOM_UUID, uuid) }
    }

    fun isAutoTest(): Boolean = preferences.getBoolean(KEY_AUTO_TEST_OTA, OtaConstant.AUTO_TEST_OTA)

    fun setAutoTest(isAutoTest: Boolean) {
        preferences.edit { putBoolean(KEY_AUTO_TEST_OTA, isAutoTest) }
    }

    fun getAutoTestCount(): Int = preferences.getInt(KEY_AUTO_TEST_COUNT, OtaConstant.AUTO_TEST_COUNT)

    fun setAutoTestCount(count: Int) {
        if (!isAutoTest()) return
        preferences.edit { putInt(KEY_AUTO_TEST_COUNT, count) }
    }

    fun isFaultTolerant(): Boolean = preferences.getBoolean(KEY_FAULT_TOLERANT, OtaConstant.AUTO_FAULT_TOLERANT)

    fun setFaultTolerant(isFaultTolerant: Boolean) {
        preferences.edit { putBoolean(KEY_FAULT_TOLERANT, isFaultTolerant) }
    }

    fun getFaultTolerantCount(): Int = preferences.getInt(KEY_FAULT_TOLERANT_COUNT, OtaConstant.AUTO_FAULT_TOLERANT_COUNT)

    fun setFaultTolerantCount(count: Int) {
        if (!isFaultTolerant()) return
        preferences.edit { putInt(KEY_FAULT_TOLERANT_COUNT, count) }
    }

    fun getScanFilter(): String? = preferences.getString(KEY_SCAN_FILTER_STRING, "")

    fun setScanFilter(scanFilter: String?) {
        preferences.edit { putString(KEY_SCAN_FILTER_STRING, scanFilter) }
    }

    fun isDevelopMode(): Boolean = preferences.getBoolean(KEY_DEVELOP_MODE, false)

    fun setDevelopMode(developMode: Boolean) {
        preferences.edit { putBoolean(KEY_DEVELOP_MODE, developMode) }
    }

    fun isEnableBroadcastBox(): Boolean = preferences.getBoolean(KEY_BROADCAST_BOX, false)

    fun enableBroadcastBox(enable: Boolean) {
        preferences.edit { putBoolean(KEY_BROADCAST_BOX, enable) }
    }

    /**
     * Clear all configuration data
     * Use with caution - this will reset all saved preferences
     */
    fun clearAllConfig() {
        preferences.edit { clear() }
    }
}