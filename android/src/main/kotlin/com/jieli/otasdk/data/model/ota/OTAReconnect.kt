package com.jieli.otasdk.data.model.ota

import android.bluetooth.BluetoothDevice

/**
 * OTA 升级中途设备回连状态模型
 *
 * 杰理芯片在 OTA 阶段可能会重启进入 Loader/UBOOT 模式并改变广播地址，SDK 需要据此发起设备重新连接。
 *
 * @param device 原始蓝牙设备实例
 * @param reconnectAddress 期望回连的新目标 MAC 地址
 * @param isNewWay 是否采用新版广播过滤策略进行回连
 */
class OTAReconnect(device: BluetoothDevice?, var reconnectAddress: String?, var isNewWay: Boolean) :
    OTAState(
        OTA_STATE_RECONNECT, device
    ) {

    override fun toString(): String {
        return "OTAReconnect(reconnectAddress=$reconnectAddress, isNewWay=$isNewWay)"
    }
}
