package com.jieli.otasdk.tool.ota.ble.model

import android.bluetooth.BluetoothGatt
import com.jieli.otasdk.tool.ota.ble.interfaces.OnWriteDataCallback
import java.util.UUID

/**
 * BLE 数据发送任务模型
 *
 * 封装单次向目标 GATT 特征值发送的数据分包、异步回调及发送状态码。
 * 针对入参和返回的二进制数据均执行防御性拷贝以保证线程安全。
 *
 * @param gatt 目标设备 [BluetoothGatt] 句柄
 * @param serviceUUID 目标服务 UUID
 * @param characteristicUUID 目标特征值 UUID
 * @param payload 待发送的原始字节数组
 * @param callback 异步写入结果监听回调
 */
class BleSendTask(
    gatt: BluetoothGatt?,
    serviceUUID: UUID?,
    characteristicUUID: UUID?,
    payload: ByteArray?,
    callback: OnWriteDataCallback?,
) {
    /** 目标设备底层 GATT 句柄 */
    var bleGatt: BluetoothGatt? = gatt

    /** 目标服务 UUID */
    var serviceUUID: UUID? = serviceUUID

    /** 目标特征值 UUID */
    var characteristicUUID: UUID? = characteristicUUID

    /** 发送结果回调接口 */
    var callback: OnWriteDataCallback? = callback

    /** 内部持有的数据副本 */
    private var rawData: ByteArray? = payload?.clone()

    /**
     * 获取或设置发送的数据字节数组（自动进行防御性克隆）
     */
    var data: ByteArray?
        get() = rawData?.clone()
        set(value) {
            rawData = value?.clone()
        }

    /** 当前任务执行状态码（-1 为初始/未执行状态，GATT_SUCCESS 为成功） */
    @Volatile
    var status: Int = -1

    /**
     * 校验当前任务是否具备所有必要的非空有效参数
     *
     * @return true 表示参数完全有效可执行发送
     */
    fun isValid(): Boolean {
        val bytes = rawData
        return bleGatt != null && serviceUUID != null && characteristicUUID != null && bytes != null && bytes.isNotEmpty()
    }

    /**
     * 校验当前任务的目标设备、服务及特征值是否与给定参数一致
     *
     * @param gatt 比较的 GATT 句柄
     * @param serviceUuid 比较的服务 UUID
     * @param characteristicUuid 比较的特征值 UUID
     * @return true 表示匹配命中
     */
    fun matches(gatt: BluetoothGatt?, serviceUuid: UUID?, characteristicUuid: UUID?): Boolean {
        return bleGatt == gatt && serviceUUID == serviceUuid && characteristicUUID == characteristicUuid
    }

    /**
     * 设置目标设备 GATT 句柄
     *
     * @param gatt GATT 句柄
     */
    @Deprecated("Use bleGatt")
    fun setDevice(gatt: BluetoothGatt?) {
        bleGatt = gatt
    }

    /**
     * 创建任务克隆副本并附带最新状态码
     *
     * @param newStatus 最新状态码
     * @return 新建的 [BleSendTask] 实例
     */
    fun copyWithStatus(newStatus: Int): BleSendTask {
        val copy = copy()
        copy.status = newStatus
        return copy
    }

    /**
     * 创建当前任务的浅拷贝副本
     *
     * @return 新任务实例
     */
    fun copy(): BleSendTask {
        return BleSendTask(bleGatt, serviceUUID, characteristicUUID, rawData, callback)
    }

    override fun equals(other: Any?): Boolean {
        if (this === other) return true
        if (other == null || other.javaClass != javaClass) return false
        other as BleSendTask
        return bleGatt == other.bleGatt &&
            serviceUUID == other.serviceUUID &&
            characteristicUUID == other.characteristicUUID
    }

    override fun hashCode(): Int {
        var result = 1
        result = 31 * result + (bleGatt?.hashCode() ?: 0)
        result = 31 * result + (serviceUUID?.hashCode() ?: 0)
        result = 31 * result + (characteristicUUID?.hashCode() ?: 0)
        return result
    }

    override fun toString(): String {
        return "BleSendTask{" +
            "mGatt=" + bleGatt +
            ", serviceUUID=" + serviceUUID +
            ", characteristicUUID=" + characteristicUUID +
            ", data=" + (rawData?.size ?: 0) +
            ", status=" + status +
            ", mCallback=" + callback +
            '}'
    }
}
