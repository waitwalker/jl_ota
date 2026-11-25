package com.jieli.otasdk.tool.ota.spp.interfaces

import android.bluetooth.BluetoothDevice
import java.util.UUID

/**
 * SPP 异步写数据结果监听回调函数式接口
 */
fun interface OnWriteSppDataCallback {
    /**
     * 回调 SPP 数据发送结果
     *
     * @param device 目标蓝牙物理设备
     * @param sppUUID 对应的 SPP 通道服务 UUID
     * @param result 发送是否成功（true 表示写入 socket 成功）
     * @param data 本次写入的数据字节数组
     */
    fun onSppResult(device: BluetoothDevice?, sppUUID: UUID?, result: Boolean, data: ByteArray?)
}
