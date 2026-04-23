package com.jieli.otasdk.tool.ota.ble.model;

import android.os.Parcel;
import android.os.Parcelable;
import androidx.annotation.NonNull;
import androidx.annotation.Nullable;
import com.jieli.jl_bt_ota.util.CHexConver;

/**
 * BLE (蓝牙低功耗) 设备扫描信息类
 *
 * <p>该类封装了BLE设备扫描过程中获取的信息，包括原始数据、信号强度(RSSI)和连接许可标志。
 * 实现了Parcelable接口以便于在Android组件间传递。</p>
 *
 * <p>创建者：zqjasonzhong
 * 创建时间：2018/10/17</p>
 */
public class BleScanInfo implements Parcelable {
    /**
     * 扫描获取的原始数据字节数组
     * <p>可能包含设备的广播数据、服务UUID等信息</p>
     */
    @Nullable
    private byte[] rawData;

    /**
     * 接收信号强度指示(Received Signal Strength Indicator)
     * <p>表示设备信号的强度，单位dBm，值越大表示信号越强</p>
     */
    private int rssi;

    /**
     * 是否允许连接标志
     * <p>默认值为true，表示允许连接该设备</p>
     */
    private boolean isEnableConnect = true;

    /**
     * 默认构造函数
     */
    public BleScanInfo() {
        // 默认构造函数
    }

    /**
     * Parcel构造函数
     * @param in 包含对象数据的Parcel对象
     */
    protected BleScanInfo(@NonNull Parcel in) {
        // 从Parcel读取原始数据
        rawData = in.createByteArray();
        // 从Parcel读取RSSI值
        rssi = in.readInt();
        // 从Parcel读取连接许可标志
        isEnableConnect = in.readByte() != 0;
    }

    /**
     * Parcelable CREATOR，用于从Parcel创建对象
     */
    public static final Creator<BleScanInfo> CREATOR = new Creator<BleScanInfo>() {
        /**
         * 从Parcel创建BleScanInfo对象
         * @param in 包含对象数据的Parcel
         * @return 新创建的BleScanInfo对象
         */
        @NonNull
        @Override
        public BleScanInfo createFromParcel(@NonNull Parcel in) {
            return new BleScanInfo(in);
        }

        /**
         * 创建指定大小的BleScanInfo数组
         * @param size 数组大小
         * @return 新创建的BleScanInfo数组
         */
        @NonNull
        @Override
        public BleScanInfo[] newArray(int size) {
            return new BleScanInfo[size];
        }
    };

    /**
     * 获取原始扫描数据
     * @return 原始数据字节数组，可能为null
     */
    @Nullable
    public byte[] getRawData() {
        return rawData;
    }

    /**
     * 设置原始扫描数据
     * @param rawData 要设置的原始数据字节数组，可以为null
     * @return 当前对象实例，支持方法链式调用
     */
    @NonNull
    public BleScanInfo setRawData(@Nullable byte[] rawData) {
        this.rawData = rawData;
        return this;
    }

    /**
     * 获取信号强度(RSSI)
     * @return RSSI值，单位dBm
     */
    public int getRssi() {
        return rssi;
    }

    /**
     * 设置信号强度(RSSI)
     * @param rssi 要设置的RSSI值，单位dBm
     * @return 当前对象实例，支持方法链式调用
     */
    @NonNull
    public BleScanInfo setRssi(int rssi) {
        this.rssi = rssi;
        return this;
    }

    /**
     * 检查是否允许连接该设备
     * @return true表示允许连接，false表示不允许
     */
    public boolean isEnableConnect() {
        return isEnableConnect;
    }

    /**
     * 设置是否允许连接该设备
     * @param enableConnect true表示允许连接，false表示不允许
     * @return 当前对象实例，支持方法链式调用
     */
    @NonNull
    public BleScanInfo setEnableConnect(boolean enableConnect) {
        isEnableConnect = enableConnect;
        return this;
    }

    /**
     * 描述内容类型(继承自Parcelable)
     * @return 通常返回0，表示没有特殊内容类型描述
     */
    @Override
    public int describeContents() {
        return 0;
    }

    /**
     * 将对象数据写入Parcel(继承自Parcelable)
     * @param dest 目标Parcel对象
     * @param flags 写入标志
     */
    @Override
    public void writeToParcel(@NonNull Parcel dest, int flags) {
        // 写入原始数据
        dest.writeByteArray(rawData);
        // 写入RSSI值
        dest.writeInt(rssi);
        // 写入连接许可标志
        dest.writeByte((byte) (isEnableConnect ? 1 : 0));
    }

    /**
     * 返回对象的字符串表示形式
     * @return 包含所有字段值的字符串
     */
    @NonNull
    @Override
    public String toString() {
        return "BleScanMessage{" +
                "rawData=" + (rawData != null ? CHexConver.byte2HexStr(rawData) : "null") +
                ", rssi=" + rssi +
                ", isEnableConnect=" + isEnableConnect +
                '}';
    }

    /**
     * 比较两个对象是否相等
     * @param o 要比较的对象
     * @return true表示相等，false表示不相等
     */
    @Override
    public boolean equals(Object o) {
        // 如果是同一对象直接返回true
        if (this == o) return true;
        // 如果对象为null或类型不同返回false
        if (o == null || getClass() != o.getClass()) return false;

        BleScanInfo that = (BleScanInfo) o;

        // 比较RSSI值
        if (rssi != that.rssi) return false;
        // 比较连接许可标志
        if (isEnableConnect != that.isEnableConnect) return false;
        // 比较原始数据数组
        return java.util.Arrays.equals(rawData, that.rawData);
    }

    /**
     * 计算对象的哈希码
     * @return 哈希码值
     */
    @Override
    public int hashCode() {
        // 计算原始数据的哈希码
        int result = java.util.Arrays.hashCode(rawData);
        // 加入RSSI值的哈希计算
        result = 31 * result + rssi;
        // 加入连接许可标志的哈希计算
        result = 31 * result + (isEnableConnect ? 1 : 0);
        return result;
    }
}