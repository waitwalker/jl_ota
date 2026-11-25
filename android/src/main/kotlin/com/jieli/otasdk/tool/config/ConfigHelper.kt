package com.jieli.otasdk.tool.config

import android.annotation.SuppressLint
import android.content.Context
import androidx.annotation.IntRange
import androidx.core.content.edit
import com.jieli.component.utils.SystemUtil
import com.jieli.jl_bt_ota.constant.BluetoothConstant
import com.jieli.otasdk.OtaRuntime
import com.jieli.otasdk.data.constant.OtaConstant

/**
 * 插件全局配置助手类
 *
 * 负责持久化存储与读取蓝牙通信方式、设备认证开关、MTU 尺寸、
 * 重连策略、扫描过滤规则以及 OTA 自动化测试等各项配置参数。
 */
open class ConfigHelper private constructor(context: Context) {

    companion object {
        /** 最新隐私协议对应的应用版本号 */
        private const val LATEST_POLICY_APP_VERSION = 10800

        /** 固件下载目录本地持久化键名 */
        private const val KEY_DOWNLOAD_URI = "download_uri"

        /** 用户已同意的隐私协议版本持久化键名 */
        private const val KEY_AGREE_POLICY_VERSION = "agree_policy_version"

        /** 蓝牙通信协议方式持久化键名 */
        private const val KEY_COMMUNICATION_WAY = "communication_way"

        /** 是否启用设备认证流程持久化键名 */
        private const val KEY_IS_USE_DEVICE_AUTH = "is_use_device_auth"

        /** 是否为 HID 设备持久化键名 */
        private const val KEY_IS_HID_DEVICE = "is_hid_device"

        /** 是否采用自定义回连方式持久化键名 */
        private const val KEY_USE_CUSTOM_RECONNECT_WAY = "use_custom_reconnect_way"

        /** BLE 协商 MTU 请求大小持久化键名 */
        private const val KEY_BLE_MTU_VALUE = "ble_mtu_value"

        /** 是否启用 SPP 多通道持久化键名 */
        private const val KEY_SPP_MULTIPLE_CHANNEL = "spp_multiple_channel"

        /** 自定义 SPP 服务 UUID 持久化键名 */
        private const val KEY_SPP_CUSTOM_UUID = "spp_custom_uuid"

        /** 是否开启 OTA 自动化压测持久化键名 */
        private const val KEY_AUTO_TEST_OTA = "auto_test_ota"

        /** OTA 自动化压测轮数持久化键名 */
        private const val KEY_AUTO_TEST_COUNT = "auto_test_count"

        /** 自动化压测期间是否允许容错重试持久化键名 */
        private const val KEY_FAULT_TOLERANT = "fault_tolerant"

        /** 容错重试最大次数持久化键名 */
        private const val KEY_FAULT_TOLERANT_COUNT = "fault_tolerant_count"

        /** 蓝牙扫描过滤关键字持久化键名 */
        private const val KEY_SCAN_FILTER_STRING = "scan_filter_string"

        /** 开发者模式开关持久化键名 */
        private const val KEY_DEVELOP_MODE = "develop_mode"

        /** 广播音箱模式开关持久化键名 */
        private const val KEY_BROADCAST_BOX = "broadcast_box_switch"

        @Volatile
        private var instance: ConfigHelper? = null

        /**
         * 获取 [ConfigHelper] 线程安全单例
         *
         * @return [ConfigHelper] 实例
         */
        fun getInstance(): ConfigHelper {
            return instance ?: synchronized(this) {
                instance ?: ConfigHelper(OtaRuntime.getContext()).also { instance = it }
            }
        }

        /**
         * 销毁单例实例并释放引用
         */
        fun destroyInstance() {
            instance = null
        }
    }

    /** 进程级 Application 上下文引用，防止 Activity 内存泄漏 */
    private val appContext = context.applicationContext

    /** 配置数据持久化 SharedPreferences 存储句柄 */
    private val preferences = appContext.getSharedPreferences("ota_config_data", Context.MODE_PRIVATE)

    /**
     * 判断当前是否已同意最新版本的隐私政策
     *
     * @return true 表示已同意最新政策
     */
    fun isAgreePolicy(): Boolean {
        val cacheVersion = preferences.getInt(KEY_AGREE_POLICY_VERSION, 0)
        if (cacheVersion <= 0) return false
        return cacheVersion >= LATEST_POLICY_APP_VERSION
    }

    /**
     * 保存用户已同意的隐私政策版本（记录当前应用版本）
     *
     * @param context 上下文对象
     */
    fun setAgreePolicyVersion(context: Context) {
        val appVersion = SystemUtil.getVersion(context)
        preferences.edit { putInt(KEY_AGREE_POLICY_VERSION, appVersion) }
    }

    /**
     * 查询当前通信方式是否为 BLE 低功耗蓝牙
     *
     * @return true 表示采用 BLE 协议通信
     */
    fun isBleWay(): Boolean = getConnectWay() == BluetoothConstant.PROTOCOL_TYPE_BLE

    /**
     * 查询当前通信方式是否为 SPP 经典蓝牙串口
     *
     * @return true 表示采用 SPP 协议通信
     */
    fun isSppWay(): Boolean = getConnectWay() == BluetoothConstant.PROTOCOL_TYPE_SPP

    /**
     * 获取当前配置的蓝牙通信方式
     *
     * @return 通信协议类型整型常量（[BluetoothConstant.PROTOCOL_TYPE_BLE] 或 [BluetoothConstant.PROTOCOL_TYPE_SPP]）
     */
    fun getConnectWay(): Int = preferences.getInt(KEY_COMMUNICATION_WAY, OtaConstant.CURRENT_PROTOCOL)

    /**
     * 设置蓝牙通信连接方式
     *
     * @param connectWay 通信方式常量（如 BLE 或 SPP）
     */
    fun setConnectWay(connectWay: Int) {
        preferences.edit { putInt(KEY_COMMUNICATION_WAY, connectWay) }
    }

    /**
     * 查询连接杰理设备时是否启用设备认证流程（RCSP 协议认证握手）
     *
     * @return true 表示开启认证，false 表示跳过认证
     */
    fun isUseDeviceAuth(): Boolean = preferences.getBoolean(KEY_IS_USE_DEVICE_AUTH, OtaConstant.IS_NEED_DEVICE_AUTH)

    /**
     * 设置连接设备时是否启用设备认证
     *
     * @param isAuth 是否启用认证流程
     */
    fun setUseDeviceAuth(isAuth: Boolean) {
        preferences.edit { putBoolean(KEY_IS_USE_DEVICE_AUTH, isAuth) }
    }

    /**
     * 查询目标设备是否配置为 HID 模式
     *
     * @return true 表示为 HID 设备
     */
    fun isHidDevice(): Boolean = preferences.getBoolean(KEY_IS_HID_DEVICE, OtaConstant.HID_DEVICE_WAY)

    /**
     * 设置目标设备是否为 HID 模式
     *
     * @param isHid 是否为 HID 设备
     */
    fun setHidDevice(isHid: Boolean) {
        preferences.edit { putBoolean(KEY_IS_HID_DEVICE, isHid) }
    }

    /**
     * 查询是否使用自定义的设备回连策略
     *
     * @return true 表示使用外部自定义回连逻辑，false 表示使用 SDK 内置回连
     */
    fun isUseCustomReConnectWay(): Boolean = preferences.getBoolean(
        KEY_USE_CUSTOM_RECONNECT_WAY,
        OtaConstant.NEED_CUSTOM_RECONNECT_WAY
    )

    /**
     * 设置是否使用自定义设备回连策略
     *
     * @param isCustom 是否开启自定义回连
     */
    fun setUseCustomReConnectWay(isCustom: Boolean) {
        preferences.edit { putBoolean(KEY_USE_CUSTOM_RECONNECT_WAY, isCustom) }
    }

    /**
     * 获取 BLE 连接期望协商的 MTU 尺寸
     *
     * @return MTU 大小（字节），默认值为 [BluetoothConstant.BLE_MTU_MAX]
     */
    fun getBleRequestMtu(): Int = preferences.getInt(KEY_BLE_MTU_VALUE, BluetoothConstant.BLE_MTU_MAX)

    /**
     * 设置 BLE 连接期望协商的 MTU 尺寸
     *
     * @param mtu 目标 MTU 取值，限定在 20 到 509 之间
     */
    fun setBleRequestMtu(@IntRange(from = 20, to = 509) mtu: Int) {
        preferences.edit { putInt(KEY_BLE_MTU_VALUE, mtu) }
    }

    /**
     * 查询是否启用 SPP 多通道并发传输
     *
     * @return true 表示启用多通道
     */
    fun isUseMultiSppChannel(): Boolean = preferences.getBoolean(
        KEY_SPP_MULTIPLE_CHANNEL,
        OtaConstant.USE_SPP_MULTIPLE_CHANNEL
    )

    /**
     * 配置是否启用 SPP 多通道并发传输
     *
     * @param isUseMulti 是否开启多通道
     */
    fun setUseMultiSppChannel(isUseMulti: Boolean) {
        preferences.edit { putBoolean(KEY_SPP_MULTIPLE_CHANNEL, isUseMulti) }
    }

    /**
     * 获取自定义 SPP 通道服务 UUID 字符串
     *
     * @return 自定义 SPP UUID
     */
    fun getCustomSppChannel(): String? = preferences.getString(KEY_SPP_CUSTOM_UUID, OtaConstant.UUID_SPP.toString())

    /**
     * 设置自定义 SPP 通道服务 UUID
     *
     * @param uuid SPP 服务 UUID 字符串
     */
    fun setCustomSppChannel(uuid: String?) {
        preferences.edit { putString(KEY_SPP_CUSTOM_UUID, uuid) }
    }

    /**
     * 查询是否开启 OTA 自动化压测模式
     *
     * @return true 表示开启自动压测
     */
    fun isAutoTest(): Boolean = preferences.getBoolean(KEY_AUTO_TEST_OTA, OtaConstant.AUTO_TEST_OTA)

    /**
     * 设置是否开启 OTA 自动化压测模式
     *
     * @param isAutoTest 是否开启自动压测
     */
    fun setAutoTest(isAutoTest: Boolean) {
        preferences.edit { putBoolean(KEY_AUTO_TEST_OTA, isAutoTest) }
    }

    /**
     * 获取 OTA 自动化测试的目标执行轮数
     *
     * @return 设定的测试总轮数
     */
    fun getAutoTestCount(): Int = preferences.getInt(KEY_AUTO_TEST_COUNT, OtaConstant.AUTO_TEST_COUNT)

    /**
     * 设置 OTA 自动化测试的目标执行轮数（仅在开启自动压测时生效）
     *
     * @param count 目标测试轮数
     */
    fun setAutoTestCount(count: Int) {
        if (!isAutoTest()) return
        preferences.edit { putInt(KEY_AUTO_TEST_COUNT, count) }
    }

    /**
     * 查询 OTA 自动化测试期间是否开启失败容错重试机制
     *
     * @return true 表示允许容错重试
     */
    fun isFaultTolerant(): Boolean = preferences.getBoolean(KEY_FAULT_TOLERANT, OtaConstant.AUTO_FAULT_TOLERANT)

    /**
     * 设置 OTA 自动化测试期间是否开启失败容错重试机制
     *
     * @param isFaultTolerant 是否允许容错重试
     */
    fun setFaultTolerant(isFaultTolerant: Boolean) {
        preferences.edit { putBoolean(KEY_FAULT_TOLERANT, isFaultTolerant) }
    }

    /**
     * 获取允许的最大容错重试次数
     *
     * @return 容错重试上限次数
     */
    fun getFaultTolerantCount(): Int = preferences.getInt(KEY_FAULT_TOLERANT_COUNT, OtaConstant.AUTO_FAULT_TOLERANT_COUNT)

    /**
     * 设置允许的最大容错重试次数（仅在启用容错模式时生效）
     *
     * @param count 容错重试上限
     */
    fun setFaultTolerantCount(count: Int) {
        if (!isFaultTolerant()) return
        preferences.edit { putInt(KEY_FAULT_TOLERANT_COUNT, count) }
    }

    /**
     * 获取当前配置的蓝牙扫描过滤字符串
     *
     * @return 扫描过滤关键字（通常匹配设备名称）
     */
    fun getScanFilter(): String? = preferences.getString(KEY_SCAN_FILTER_STRING, "")

    /**
     * 设置蓝牙扫描过滤关键字
     *
     * @param scanFilter 过滤关键字
     */
    fun setScanFilter(scanFilter: String?) {
        preferences.edit { putString(KEY_SCAN_FILTER_STRING, scanFilter) }
    }

    /**
     * 查询是否开启开发者调试模式
     *
     * @return true 表示处于开发者模式
     */
    fun isDevelopMode(): Boolean = preferences.getBoolean(KEY_DEVELOP_MODE, false)

    /**
     * 设置是否开启开发者调试模式
     *
     * @param developMode 是否启用
     */
    fun setDevelopMode(developMode: Boolean) {
        preferences.edit { putBoolean(KEY_DEVELOP_MODE, developMode) }
    }

    /**
     * 查询是否开启广播音箱功能模式
     *
     * @return true 表示已启用广播音箱模式
     */
    fun isEnableBroadcastBox(): Boolean = preferences.getBoolean(KEY_BROADCAST_BOX, false)

    /**
     * 设置是否开启广播音箱功能模式
     *
     * @param enable 是否启用
     */
    fun enableBroadcastBox(enable: Boolean) {
        preferences.edit { putBoolean(KEY_BROADCAST_BOX, enable) }
    }

    /**
     * 清空全部已保存的本地配置项
     *
     * 注意：调用此方法将重置所有选项为默认值
     */
    fun clearAllConfig() {
        preferences.edit { clear() }
    }
}