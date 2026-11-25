package com.jieli.otasdk.tool.ota.ble.model

import com.jieli.jl_bt_ota.constant.BluetoothConstant
import java.util.UUID

/**
 * BLE 设备连接配置参数模型
 *
 * 封装连接超时、自动重连开关、底层传输层类型 (LE/BR-EDR)、期望请求协商的 MTU，
 * 以及 OTA 所需的服务 UUID、写特征值 UUID 与通知特征值 UUID。
 * 支持链式调用 (Fluent API)。
 *
 * @property timeout 连接超时时间（毫秒），默认为 [BluetoothConstant.CONNECT_TIMEOUT]
 */
class BleConnectParam @JvmOverloads constructor(
    val timeout: Long = BluetoothConstant.CONNECT_TIMEOUT.toLong(),
) {
    /** 意外断开时是否需要尝试自动回连 */
    private var needReconnect = true

    /** 底层物理传输通道类型，默认为 [TRANSPORT_LE] */
    private var transportValue = TRANSPORT_LE

    /** 期望请求协商的 BLE MTU 大小，默认为 [BluetoothConstant.BLE_MTU_MIN] */
    private var requestMtuValue = BluetoothConstant.BLE_MTU_MIN

    /** 缓存 OTA 相关的服务与特征值 UUID 映射字典 */
    private val otaUUIDMap = HashMap<String, UUID>()

    init {
        setOtaUUID(BluetoothConstant.UUID_SERVICE, BluetoothConstant.UUID_WRITE, BluetoothConstant.UUID_NOTIFICATION)
    }

    /**
     * 查询是否开启断开自动重连
     *
     * @return true 表示开启重连
     */
    fun isNeedReconnect(): Boolean = needReconnect

    /**
     * 设置断开时是否自动重连
     *
     * @param needReconnect 是否开启重连
     * @return 当前对象实例，支持链式调用
     */
    fun setNeedReconnect(needReconnect: Boolean): BleConnectParam {
        this.needReconnect = needReconnect
        return this
    }

    /**
     * 获取当前配置的物理传输通道类型
     *
     * @return 传输通道类型常量（如 [TRANSPORT_AUTO]、[TRANSPORT_BREDR]、[TRANSPORT_LE]）
     */
    fun getTransport(): Int = transportValue

    /**
     * 设置底层物理传输通道类型
     *
     * @param transport 传输通道类型
     * @return 当前对象实例，支持链式调用
     */
    fun setTransport(transport: Int): BleConnectParam {
        transportValue = transport
        return this
    }

    /**
     * 获取期望请求协商的 BLE MTU 大小
     *
     * @return 期望的 MTU 大小（字节）
     */
    fun getRequestMtu(): Int = requestMtuValue

    /**
     * 设置期望请求协商的 BLE MTU 大小
     *
     * @param requestMtu 目标 MTU 取值
     * @return 当前对象实例，支持链式调用
     */
    fun setRequestMtu(requestMtu: Int): BleConnectParam {
        requestMtuValue = requestMtu
        return this
    }

    /**
     * 配置 OTA 固件升级所需的关键服务与特征值 UUID
     *
     * @param serviceUUID OTA 主服务 UUID
     * @param writeCharacteristicUUID 固件数据写入特征值 UUID
     * @param notifyCharacteristicUUID 设备状态通知特征值 UUID
     * @return 当前对象实例，支持链式调用
     */
    fun setOtaUUID(serviceUUID: UUID, writeCharacteristicUUID: UUID, notifyCharacteristicUUID: UUID): BleConnectParam {
        otaUUIDMap[KEY_OTA_SERVICE_UUID] = serviceUUID
        otaUUIDMap[KEY_OTA_WRITE_CHARACTERISTIC_UUID] = writeCharacteristicUUID
        otaUUIDMap[KEY_OTA_NOTIFY_CHARACTERISTIC_UUID] = notifyCharacteristicUUID
        return this
    }

    /**
     * 获取 OTA 主服务 UUID
     *
     * @return 服务 UUID
     */
    fun getOtaServiceUUID(): UUID? = otaUUIDMap[KEY_OTA_SERVICE_UUID]

    /**
     * 获取 OTA 固件数据写入特征值 UUID
     *
     * @return 写特征值 UUID
     */
    fun getOtaWriteCharacteristicUUID(): UUID? = otaUUIDMap[KEY_OTA_WRITE_CHARACTERISTIC_UUID]

    /**
     * 获取 OTA 设备状态通知特征值 UUID
     *
     * @return 通知特征值 UUID
     */
    fun getOtaNotifyCharacteristicUUID(): UUID? = otaUUIDMap[KEY_OTA_NOTIFY_CHARACTERISTIC_UUID]

    /**
     * 查询是否通过 BR/EDR 经典蓝牙通道建立 GATT 连接
     *
     * @return true 表示为 GATT over BR/EDR
     */
    fun isConnectGattOverBrEdr(): Boolean = transportValue == TRANSPORT_BREDR

    override fun toString(): String {
        return "BleConnectParam{" +
            "timeout=" + timeout +
            ", isNeedReconnect=" + needReconnect +
            ", transport=" + printBleTransport(transportValue) +
            ", requestMtu=" + requestMtuValue +
            ", otaUUIDMap=" + otaUUIDMap +
            '}'
    }

    companion object {
        /** 自动选择传输通道 */
        const val TRANSPORT_AUTO = 0

        /** 经典蓝牙 BR/EDR 传输通道 */
        const val TRANSPORT_BREDR = 1

        /** 低功耗蓝牙 LE 传输通道 */
        const val TRANSPORT_LE = 2

        /** OTA 服务 UUID 缓存键 */
        private const val KEY_OTA_SERVICE_UUID = "ota_service_uuid"

        /** OTA 写特征值 UUID 缓存键 */
        private const val KEY_OTA_WRITE_CHARACTERISTIC_UUID = "ota_write_characteristic_uuid"

        /** OTA 通知特征值 UUID 缓存键 */
        private const val KEY_OTA_NOTIFY_CHARACTERISTIC_UUID = "ota_notify_characteristic_uuid"

        /**
         * 格式化打印传输层类型的描述文本
         *
         * @param transport 传输通道类型常量
         * @return 可读描述字符串
         */
        @JvmStatic
        fun printBleTransport(transport: Int): String {
            return when (transport) {
                TRANSPORT_AUTO -> "TRANSPORT_AUTO(0)"
                TRANSPORT_BREDR -> "TRANSPORT_BREDR(1)"
                TRANSPORT_LE -> "TRANSPORT_LE(2)"
                else -> "UNKNOWN_TRANSPORT : $transport"
            }
        }
    }
}
