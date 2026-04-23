package com.jieli.otasdk.tool.ota.spp.interfaces;

import android.bluetooth.BluetoothDevice;
import java.util.UUID;

/**
 * Callback interface for SPP (Serial Port Profile) events.
 * <p>
 * Implement this interface to receive notifications about Bluetooth SPP related events
 * including adapter state changes, device discovery, connection state changes, and data reception.
 * </p>
 *
 * @author zqjasonZhong
 * @since 2021/1/13
 */
public interface ISppEventCallback {

    /**
     * Called when Bluetooth adapter state changes.
     *
     * @param enabled {@code true} if Bluetooth adapter is enabled, {@code false} otherwise
     */
    void onAdapterChange(boolean enabled);

    /**
     * Called when device discovery state changes.
     *
     * @param started {@code true} if discovery has started, {@code false} if discovery has stopped
     */
    void onDiscoveryDeviceChange(boolean started);

    /**
     * Called when a new Bluetooth device is discovered.
     *
     * @param device The discovered Bluetooth device
     * @param rssi The received signal strength indicator (in dBm)
     */
    void onDiscoveryDevice(BluetoothDevice device, int rssi);

    /**
     * Called when SPP connection state changes.
     *
     * @param device The Bluetooth device whose connection state changed
     * @param uuid The UUID of the SPP service
     * @param status The new connection state, one of:
     *  <p>
     *  参考{@link android.bluetooth.BluetoothProfile#STATE_DISCONNECTED} : 未连接<br>
     *  {@link android.bluetooth.BluetoothProfile#STATE_CONNECTING} : 连接中<br>
     *  {@link android.bluetooth.BluetoothProfile#STATE_CONNECTED} : 已连接<br>
     *  {@link android.bluetooth.BluetoothProfile#STATE_DISCONNECTING} : 正在断开<br>
     *  </p>
     */
    void onSppConnection(BluetoothDevice device, UUID uuid, int status);

    /**
     * Called when data is received through an SPP connection.
     *
     * @param device The Bluetooth device that sent the data
     * @param uuid The UUID of the SPP service
     * @param data The received data bytes
     */
    void onReceiveSppData(BluetoothDevice device, UUID uuid, byte[] data);
}