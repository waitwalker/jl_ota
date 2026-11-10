package com.jieli.otasdk.data.model.ota

import android.bluetooth.BluetoothDevice

/**
 * OTA 升级完成/结束状态模型
 *
 * 表示固件升级结束（可能成功完成，或发生错误/用户取消）。
 *
 * @param device 执行升级的目标蓝牙设备
 * @param code 结果码或错误码（0 表示成功，非 0 为异常错误码）
 * @param message 结果描述或错误提示信息
 */
class OTAEnd(device: BluetoothDevice?, val code: Int, var message: String?) :
    OTAState(OTA_STATE_IDLE, device) {

    override fun toString(): String {
        return "OTAEnd(code=$code, message=$message)"
    }
}
