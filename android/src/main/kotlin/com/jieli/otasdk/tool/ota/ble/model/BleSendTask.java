package com.jieli.otasdk.tool.ota.ble.model;

import android.bluetooth.BluetoothGatt;
import androidx.annotation.NonNull;
import androidx.annotation.Nullable;

import com.jieli.otasdk.tool.ota.ble.interfaces.OnWriteDataCallback;

import java.util.Arrays;
import java.util.Objects;
import java.util.UUID;

/**
 * BleSendTask
 *
 * @author zhongzhuocheng
 * email: zhongzhuocheng@zh-jieli.com
 * create: 2025/10/30
 * note: BLE发送任务
 */
public class BleSendTask {

    @Nullable
    private BluetoothGatt bleGatt;

    @Nullable
    private UUID serviceUUID;

    @Nullable
    private UUID characteristicUUID;

    @Nullable
    private byte[] data;

    @Nullable
    private OnWriteDataCallback callback;

    private volatile int status = -1;

    // Full constructor
    public BleSendTask(@Nullable BluetoothGatt gatt,
                       @Nullable UUID serviceUUID,
                       @Nullable UUID characteristicUUID,
                       @Nullable byte[] data,
                       @Nullable OnWriteDataCallback callback) {
        this.bleGatt = gatt;
        this.serviceUUID = serviceUUID;
        this.characteristicUUID = characteristicUUID;
        this.data = data != null ? data.clone() : null; // Defensive copy
        this.callback = callback;
    }

    /**
     * Check if the task contains valid data for sending
     */
    public boolean isValid() {
        return bleGatt != null &&
                serviceUUID != null &&
                characteristicUUID != null &&
                data != null &&
                data.length > 0;
    }

    /**
     * Check if the task parameters match the given ones
     */
    public boolean matches(@Nullable BluetoothGatt gatt,
                           @Nullable UUID serviceUuid,
                           @Nullable UUID characteristicUuid) {
        return Objects.equals(bleGatt, gatt) &&
                Objects.equals(serviceUUID, serviceUuid) &&
                Objects.equals(characteristicUUID, characteristicUuid);
    }

    @Nullable
    public BluetoothGatt getBleGatt() {
        return bleGatt;
    }

    /**
     * Set BluetoothGatt instance
     * @deprecated Consider using immutable pattern or builder instead
     */
    @Deprecated
    public void setBleGatt(@Nullable BluetoothGatt gatt) {
        this.bleGatt = gatt;
    }

    // Legacy method for backward compatibility
    @Deprecated
    public void setDevice(@Nullable BluetoothGatt gatt) {
        this.bleGatt = gatt;
    }

    @Nullable
    public UUID getServiceUUID() {
        return serviceUUID;
    }

    public void setServiceUUID(@Nullable UUID serviceUUID) {
        this.serviceUUID = serviceUUID;
    }

    @Nullable
    public UUID getCharacteristicUUID() {
        return characteristicUUID;
    }

    public void setCharacteristicUUID(@Nullable UUID characteristicUUID) {
        this.characteristicUUID = characteristicUUID;
    }

    /**
     * Get data as defensive copy to prevent external modification
     */
    @Nullable
    public byte[] getData() {
        return data != null ? data.clone() : null;
    }

    /**
     * Set data with defensive copy
     */
    public void setData(@Nullable byte[] data) {
        this.data = data != null ? data.clone() : null;
    }

    @Nullable
    public OnWriteDataCallback getCallback() {
        return callback;
    }

    public void setCallback(@Nullable OnWriteDataCallback callback) {
        this.callback = callback;
    }

    public int getStatus() {
        return status;
    }

    public void setStatus(int status) {
        this.status = status;
    }

    /**
     * Create a copy of this task with updated status
     */
    @NonNull
    public BleSendTask copyWithStatus(int newStatus) {
        BleSendTask copy = new BleSendTask(bleGatt, serviceUUID, characteristicUUID, data, callback);
        copy.setStatus(newStatus);
        return copy;
    }

    /**
     * Create a shallow copy of this task
     */
    @NonNull
    public BleSendTask copy() {
        return new BleSendTask(bleGatt, serviceUUID, characteristicUUID, data, callback);
    }

    @Override
    public boolean equals(@Nullable Object obj) {
        if (this == obj) return true;
        if (obj == null || getClass() != obj.getClass()) return false;

        BleSendTask that = (BleSendTask) obj;

        return Objects.equals(bleGatt, that.bleGatt) &&
                Objects.equals(serviceUUID, that.serviceUUID) &&
                Objects.equals(characteristicUUID, that.characteristicUUID);
    }

    @Override
    public int hashCode() {
        return Objects.hash(bleGatt, serviceUUID, characteristicUUID);
    }

    @NonNull
    @Override
    public String toString() {
        return "BleSendTask{" +
                "mGatt=" + bleGatt +
                ", serviceUUID=" + serviceUUID +
                ", characteristicUUID=" + characteristicUUID +
                ", data=" + (null != data ? data.length : 0) +
                ", status=" + status +
                ", mCallback=" + callback +
                '}';
    }
}