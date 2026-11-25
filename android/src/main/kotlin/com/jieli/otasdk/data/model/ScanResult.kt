package com.jieli.otasdk.data.model

import com.jieli.otasdk.data.model.device.ScanDevice

/**
 * 蓝牙设备扫描事件结果模型
 *
 * 包装当前扫描状态以及新扫描发现的设备实体。
 *
 * @property state 扫描状态码，默认为空闲 [SCAN_STATUS_IDLE]
 */
class ScanResult(var state: Int = SCAN_STATUS_IDLE) {
    /** 扫描发现的目标设备实例，若仅通知状态变更则可能为空 */
    var device: ScanDevice? = null

    /**
     * 携带设备实体的构造器
     *
     * @param state 扫描状态码
     * @param device 扫描到的设备实体
     */
    constructor(state: Int, device: ScanDevice?) : this(state) {
        this.device = device
    }

    companion object {
        /** 扫描处于空闲或停止状态 */
        const val SCAN_STATUS_IDLE = 0

        /** 正在执行设备扫描 */
        const val SCAN_STATUS_SCANNING = 1

        /** 扫描命中并发现新设备 */
        const val SCAN_STATUS_FOUND_DEV = 2
    }
}
