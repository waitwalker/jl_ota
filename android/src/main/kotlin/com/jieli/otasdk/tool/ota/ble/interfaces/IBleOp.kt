package com.jieli.otasdk.tool.ota.ble.interfaces

import android.bluetooth.BluetoothGatt
import java.util.UUID

/**
 * BLE 数据发送线程执行接口
 *
 * 供发送线程回调底层，用于获取当前分包 MTU 尺寸并实际触发 GATT 特征值写入。
 */
interface IBleOp {
    /**
     * 获取当前 BLE 链路支持的最大分包 MTU 大小
     *
     * @return 实际可用分包大小（字节）
     */
    fun getBleMtu(): Int

    /**
     * 调用系统底层 GATT 写入指定特征值
     *
     * @param gatt 目标设备 [BluetoothGatt] 句柄
     * @param serviceUUID 服务 UUID
     * @param characteristicUUID 写入特征值 UUID
     * @param data 待发送的数据字节数组
     * @return true 表示成功提交至系统底层发送队列
     */
    fun writeDataByBle(
        gatt: BluetoothGatt?,
        serviceUUID: UUID?,
        characteristicUUID: UUID?,
        data: ByteArray?,
    ): Boolean
}
