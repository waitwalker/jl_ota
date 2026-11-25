package com.jieli.otasdk.data.model.setting

import android.os.Parcel
import android.os.Parcelable
import com.jieli.otasdk.data.constant.OtaConstant
import com.jieli.jl_bt_ota.constant.BluetoothConstant

/**
 * 杰理 OTA 综合配置参数模型
 *
 * 实现了 [Parcelable] 接口，封装通用配置（认证、HID、回连、开发者模式）、
 * 测试容错配置以及通信通道配置参数（BLE/SPP、MTU）。
 */
class OtaConfiguration() : Parcelable {
    /*<<<--- 通用配置 --->>>*/
    /** 是否启用设备认证流程（RCSP 协议认证） */
    private var isUseDeviceAuth: Boolean = false

    /** 是否配置为 HID 模式连接与回连 */
    private var isHidDevice: Boolean = false

    /** 是否采用自定义设备回连策略 */
    private var isCustomReconnect: Boolean = false

    /** 是否开启开发者调试模式 */
    private var isDevelopMode: Boolean = false

    /*<<<--- 测试容错配置 --->>>*/
    /** 是否开启 OTA 自动化压测模式 */
    private var isAutoTest: Boolean = false

    /** 自动化压测设定的目标轮数 */
    private var autoTestCount: Int = OtaConstant.AUTO_TEST_COUNT

    /** 自动化压测期间是否允许异常容错重试 */
    private var isAllowFaultTolerant = false

    /** 容错重试的最大允许次数 */
    private var faultTolerantCount = OtaConstant.AUTO_FAULT_TOLERANT_COUNT

    /*<<<--- 通讯配置 --->>>*/
    /** 蓝牙连接与通信协议方式（默认为 BLE 协议） */
    private var connectionWay: Int = BluetoothConstant.PROTOCOL_TYPE_BLE

    /** BLE 连接请求协商的目标 MTU 大小 */
    private var bleMtu: Int = BluetoothConstant.BLE_MTU_MAX

    /**
     * Parcel 反序列化构造函数
     *
     * @param parcel 包含打包数据的 Parcel 实例
     */
    constructor(parcel: Parcel) : this() {
        isUseDeviceAuth = parcel.readByte() != 0.toByte()
        isHidDevice = parcel.readByte() != 0.toByte()
        isCustomReconnect = parcel.readByte() != 0.toByte()
        isDevelopMode = parcel.readByte() != 0.toByte()
        isAutoTest = parcel.readByte() != 0.toByte()
        autoTestCount = parcel.readInt()
        isAllowFaultTolerant = parcel.readByte() != 0.toByte()
        faultTolerantCount = parcel.readInt()
        connectionWay = parcel.readInt()
        bleMtu = parcel.readInt()
    }

    /**
     * 将配置数据序列化写入 Parcel
     *
     * @param parcel 写入目标的 Parcel
     * @param flags 附加标记位
     */
    override fun writeToParcel(parcel: Parcel, flags: Int) {
        parcel.writeByte(if (isUseDeviceAuth) 1 else 0)
        parcel.writeByte(if (isHidDevice) 1 else 0)
        parcel.writeByte(if (isCustomReconnect) 1 else 0)
        parcel.writeByte(if (isDevelopMode) 1 else 0)
        parcel.writeByte(if (isAutoTest) 1 else 0)
        parcel.writeInt(autoTestCount)
        parcel.writeByte(if (isAllowFaultTolerant) 1 else 0)
        parcel.writeInt(faultTolerantCount)
        parcel.writeInt(connectionWay)
        parcel.writeInt(bleMtu)
    }

    /**
     * 获取 Parcelable 特殊对象内容描述
     *
     * @return 默认返回 0
     */
    override fun describeContents(): Int {
        return 0
    }

    /**
     * 查询当前通信方式是否为 BLE 低功耗蓝牙
     *
     * @return true 表示采用 BLE 协议
     */
    fun isBleWay(): Boolean = connectionWay == BluetoothConstant.PROTOCOL_TYPE_BLE

    override fun toString(): String {
        return "OtaConfiguration(isUseDeviceAuth=$isUseDeviceAuth, isHidDevice=$isHidDevice, isCustomReconnect=$isCustomReconnect, isDevelopMode=$isDevelopMode, " +
                "isAutoTest=$isAutoTest, autoTestCount=$autoTestCount, isAllowFaultTolerant=$isAllowFaultTolerant, faultTolerantCount=$faultTolerantCount, " +
                "connectionWay=$connectionWay, bleMtu=$bleMtu)"
    }

    /**
     * Parcelable 序列化创建器伴生对象
     */
    companion object CREATOR : Parcelable.Creator<OtaConfiguration> {
        override fun createFromParcel(parcel: Parcel): OtaConfiguration {
            return OtaConfiguration(parcel)
        }

        override fun newArray(size: Int): Array<OtaConfiguration?> {
            return arrayOfNulls(size)
        }
    }
}
