package com.jieli.otasdk.data.model.ota

import android.bluetooth.BluetoothDevice

/**
 * OTA 启动状态实体类
 *
 * 表示底层 SDK 已正式开始执行固件升级流程。
 *
 * @param device 正在启动升级的目标蓝牙设备
 */
class OTAStart(device: BluetoothDevice?) : OTAState(OTA_STATE_START, device)
