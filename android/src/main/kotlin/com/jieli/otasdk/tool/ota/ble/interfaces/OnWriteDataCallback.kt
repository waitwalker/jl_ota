package com.jieli.otasdk.tool.ota.ble.interfaces

import android.bluetooth.BluetoothDevice
import java.util.UUID

/**
 * BLE 异步写数据结果回调函数式接口
 */
fun interface OnWriteDataCallback {
    /**
     * 回调 BLE 发送结果
     *
     * @param device 目标蓝牙物理设备
     * @param serviceUUID 对应的服务 UUID
     * @param characteristicUUID 对应的特征值 UUID
     * @param result 发送是否成功（true 为成功收到 ACK，false 为超时或写入失败）
     * @param data 本次写入的数据字节数组
     */
    fun onBleResult(
        device: BluetoothDevice?,
        serviceUUID: UUID?,
        characteristicUUID: UUID?,
        result: Boolean,
        data: ByteArray?,
    )
}
