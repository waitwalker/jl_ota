package com.jieli.otasdk.tool.ota.ble.model

import android.os.Parcel
import android.os.Parcelable
import com.jieli.jl_bt_ota.util.CHexConver

/**
 * BLE 扫描结果元数据模型
 *
 * 包装扫描捕获的原始广播包/扫描响应包数据、信号强度 (RSSI) 以及设备是否允许连接标志位。
 * 实现了 [Parcelable] 并支持链式赋值 (Fluent API)。
 */
class BleScanInfo() : Parcelable {
    /** 原始广播包数据字节数组 */
    private var rawDataValue: ByteArray? = null

    /** 信号强度指示 RSSI (dBm) */
    private var rssiValue: Int = 0

    /** 设备是否可连接标志位，默认为 true */
    private var enableConnect: Boolean = true

    /**
     * Parcel 反序列化构造器
     *
     * @param parcel 序列化数据包
     */
    private constructor(parcel: Parcel) : this() {
        rawDataValue = parcel.createByteArray()
        rssiValue = parcel.readInt()
        enableConnect = parcel.readByte().toInt() != 0
    }

    /**
     * 获取原始广播包数据
     */
    val rawData: ByteArray?
        get() = rawDataValue

    /**
     * 设置原始广播包数据
     *
     * @param rawData 字节数组
     * @return 当前对象实例，支持链式调用
     */
    fun setRawData(rawData: ByteArray?): BleScanInfo {
        rawDataValue = rawData
        return this
    }

    /**
     * 获取信号强度 RSSI
     */
    val rssi: Int
        get() = rssiValue

    /**
     * 设置信号强度 RSSI
     *
     * @param rssi 信号强度数值
     * @return 当前对象实例，支持链式调用
     */
    fun setRssi(rssi: Int): BleScanInfo {
        rssiValue = rssi
        return this
    }

    /**
     * 查询设备当前是否支持发起连接
     *
     * @return true 表示支持连接
     */
    fun isEnableConnect(): Boolean = enableConnect

    /**
     * 设置设备是否支持连接
     *
     * @param enableConnect 是否可连接
     * @return 当前对象实例，支持链式调用
     */
    fun setEnableConnect(enableConnect: Boolean): BleScanInfo {
        this.enableConnect = enableConnect
        return this
    }

    override fun describeContents(): Int = 0

    override fun writeToParcel(dest: Parcel, flags: Int) {
        dest.writeByteArray(rawDataValue)
        dest.writeInt(rssiValue)
        dest.writeByte(if (enableConnect) 1 else 0)
    }

    override fun toString(): String {
        return "BleScanMessage{" +
            "rawData=" + (rawDataValue?.let { CHexConver.byte2HexStr(it) } ?: "null") +
            ", rssi=" + rssiValue +
            ", isEnableConnect=" + enableConnect +
            '}'
    }

    override fun equals(other: Any?): Boolean {
        if (this === other) return true
        if (other == null || other.javaClass != javaClass) return false
        other as BleScanInfo
        if (rssiValue != other.rssiValue) return false
        if (enableConnect != other.enableConnect) return false
        return rawDataValue.contentEquals(other.rawDataValue)
    }

    override fun hashCode(): Int {
        var result = rawDataValue.contentHashCode()
        result = 31 * result + rssiValue
        result = 31 * result + if (enableConnect) 1 else 0
        return result
    }

    companion object {
        /**
         * Parcelable 序列化创建器实例
         */
        @JvmField
        val CREATOR: Parcelable.Creator<BleScanInfo> = object : Parcelable.Creator<BleScanInfo> {
            override fun createFromParcel(parcel: Parcel): BleScanInfo = BleScanInfo(parcel)

            override fun newArray(size: Int): Array<BleScanInfo?> = arrayOfNulls(size)
        }
    }
}
