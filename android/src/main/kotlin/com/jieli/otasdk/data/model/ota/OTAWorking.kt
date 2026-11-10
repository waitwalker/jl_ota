package com.jieli.otasdk.data.model.ota

import android.bluetooth.BluetoothDevice

/**
 * OTA 固件数据校验与传输工作状态模型
 *
 * 封装当前升级所处阶段（如文件校验阶段或数据块烧录阶段）以及当前进度百分比。
 *
 * @param device 执行升级的目标蓝牙设备
 * @param type 数据传输阶段类型（如文件校验或固件传输）
 * @param progress 当前升级传输进度 (0.0F - 100.0F)
 */
class OTAWorking(device: BluetoothDevice?, var type: Int, var progress: Float) :
    OTAState(OTA_STATE_WORKING, device) {

    override fun toString(): String {
        return "OTAWorking(type=$type, progress=$progress)"
    }
}
