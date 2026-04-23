package com.jieli.otasdk.util;

import android.Manifest;
import android.annotation.SuppressLint;
import android.bluetooth.BluetoothAdapter;
import android.bluetooth.BluetoothDevice;
import android.bluetooth.BluetoothGatt;
import android.bluetooth.BluetoothGattCharacteristic;
import android.bluetooth.BluetoothGattDescriptor;
import android.bluetooth.BluetoothGattService;
import android.bluetooth.BluetoothProfile;
import android.content.Context;
import android.content.pm.PackageManager;
import android.os.Build;
import android.os.Environment;
import android.os.ParcelUuid;
import android.text.TextUtils;

import androidx.core.app.ActivityCompat;

import com.jieli.otasdk.MyApplication;
import com.jieli.jl_bt_ota.constant.StateCode;
import com.jieli.jl_bt_ota.util.BluetoothUtil;
import com.jieli.jl_bt_ota.util.CHexConver;
import com.jieli.jl_bt_ota.util.JL_Log;

import java.io.File;
import java.lang.reflect.Method;
import java.util.Date;
import java.util.List;
import java.util.Locale;
import java.util.UUID;

/**
 * @author zqjasonZhong
 * @since 2020/7/16
 */
public class AppUtil {

    private static final long DOUBLE_CLICK_INTERVAL = 2000; // 2 seconds
    private static long lastClickTime = 0;
    private static int clickCount = 0;
    private static long theLastClickTime = 0;
    private static int theClickCount = 0;

    /**
     * Checks if the app has the specified permission.
     *
     * @param context    The application context.
     * @param permission The permission to check.
     * @return True if the permission is granted, false otherwise.
     */
    public static boolean isHasPermission(Context context, String permission) {
        return context != null && ActivityCompat.checkSelfPermission(context, permission) == PackageManager.PERMISSION_GRANTED;
    }

    /**
     * Checks if the app has location permissions.
     *
     * @param context The application context.
     * @return True if either coarse or fine location permission is granted.
     */
    public static boolean isHasLocationPermission(Context context) {
        return isHasPermission(context, Manifest.permission.ACCESS_COARSE_LOCATION)
                || isHasPermission(context, Manifest.permission.ACCESS_FINE_LOCATION);
    }

    /**
     * Checks if the app has storage permissions.
     *
     * @param context The application context.
     * @return True if both read and write storage permissions are granted.
     */
    public static boolean isHasStoragePermission(Context context) {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.P) {
            return isHasPermission(context, Manifest.permission.READ_EXTERNAL_STORAGE);
        }
        return isHasPermission(context, Manifest.permission.WRITE_EXTERNAL_STORAGE)
                && isHasPermission(context, Manifest.permission.READ_EXTERNAL_STORAGE);
    }

    /**
     * Checks if the app has Bluetooth connect permission.
     *
     * @param context The application context.
     * @return True if the permission is granted.
     */
    public static boolean checkHasConnectPermission(Context context) {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
            return isHasPermission(context, "android.permission.BLUETOOTH_CONNECT");
        }
        return true;
    }

    /**
     * Checks if the app has Bluetooth scan permission.
     *
     * @param context The application context.
     * @return True if the permission is granted.
     */
    public static boolean checkHasScanPermission(Context context) {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
            return isHasPermission(context, "android.permission.BLUETOOTH_SCAN");
        }
        return true;
    }

    /**
     * Checks if the click is a fast double-click.
     *
     * @return True if the click is within the double-click interval.
     */
    public static boolean isFastDoubleClick() {
        return isFastDoubleClick(DOUBLE_CLICK_INTERVAL);
    }

    /**
     * Checks if the click is a fast double-click within a specified interval.
     *
     * @param interval The interval in milliseconds.
     * @return True if the click is within the specified interval.
     */
    public static boolean isFastDoubleClick(long interval) {
        long currentTime = new Date().getTime();
        if (currentTime - lastClickTime <= interval) {
            return true;
        }
        lastClickTime = currentTime;
        return false;
    }

    /**
     * Checks if the click is a fast continuous click.
     *
     * @param interval The interval in milliseconds.
     * @return The number of continuous clicks within the interval.
     */
    public static int isFastContinuousClick(long interval) {
        long currentTime = new Date().getTime();
        if (currentTime - lastClickTime <= interval) {
            clickCount++;
        } else {
            clickCount = 1;
        }
        lastClickTime = currentTime;
        return clickCount;
    }

    /**
     * Checks if the click is a fast continuous click with a specified number of times.
     *
     * @param interval The interval in milliseconds.
     * @param times    The number of times to check.
     * @return True if the specified number of clicks occur within the interval.
     */
    public static boolean isFastContinuousClick(long interval, int times) {
        long currentTime = new Date().getTime();
        if (currentTime - theLastClickTime <= interval) {
            theClickCount++;
        } else {
            theClickCount = 1;
        }
        theLastClickTime = currentTime;
        boolean state = theClickCount == times;
        if (state) {
            theLastClickTime = 0;
            theClickCount = 0;
        }
        return state;
    }

    /**
     * Enables Bluetooth on the device.
     *
     * @param context The application context.
     * @return True if Bluetooth is enabled successfully.
     */
    @SuppressLint("MissingPermission")
    public static boolean enableBluetooth(Context context) {
        if (!checkHasConnectPermission(context)) return false;
        BluetoothAdapter bluetoothAdapter = BluetoothAdapter.getDefaultAdapter();
        if (bluetoothAdapter == null) return false;
        boolean ret = bluetoothAdapter.isEnabled();
        if (!ret) {
            ret = bluetoothAdapter.enable();
        }
        return ret;
    }

    /**
     * Refreshes the BLE device cache.
     *
     * @param context       The application context.
     * @param bluetoothGatt The BluetoothGatt instance.
     * @return True if the refresh is successful.
     */
    @SuppressLint("MissingPermission")
    public static boolean refreshBleDeviceCache(Context context, BluetoothGatt bluetoothGatt) {
        if (bluetoothGatt == null || !checkHasConnectPermission(context)) return false;
        try {
            Method refreshMethod = bluetoothGatt.getClass().getMethod("refresh");
            return (Boolean) refreshMethod.invoke(bluetoothGatt);
        } catch (Exception e) {
            e.printStackTrace();
        }
        return false;
    }

    /**
     * Checks if the device has the specified Bluetooth profile.
     *
     * @param context The application context.
     * @param device  The Bluetooth device.
     * @param uuid    The UUID of the profile.
     * @return True if the device has the profile.
     */
    @SuppressLint("MissingPermission")
    public static boolean deviceHasProfile(Context context, BluetoothDevice device, UUID uuid) {
        if (!BluetoothUtil.isBluetoothEnable() || device == null || uuid == null || TextUtils.isEmpty(uuid.toString())
                || !checkHasConnectPermission(context)) {
            return false;
        }
        ParcelUuid[] uuids = device.getUuids();
        if (uuids == null) return false;
        for (ParcelUuid uid : uuids) {
            if (uuid.toString().toLowerCase(Locale.getDefault()).equalsIgnoreCase(uid.toString())) {
                return true;
            }
        }
        return false;
    }

    /**
     * Gets the device name.
     *
     * @param context The application context.
     * @param device  The Bluetooth device.
     * @return The device name.
     */
    @SuppressLint("MissingPermission")
    public static String getDeviceName(Context context, BluetoothDevice device) {
        if (device == null || !checkHasConnectPermission(context)) return "N/A";
        String name = device.getName();
        return TextUtils.isEmpty(name) ? "N/A" : name;
    }

    /**
     * Gets the device type.
     *
     * @param context The application context.
     * @param device  The Bluetooth device.
     * @return The device type.
     */
    @SuppressLint("MissingPermission")
    public static int getDeviceType(Context context, BluetoothDevice device) {
        if (device == null || !checkHasConnectPermission(context))
            return BluetoothDevice.DEVICE_TYPE_UNKNOWN;
        return device.getType();
    }

    /**
     * Prints the Bluetooth device information.
     *
     * @param device The Bluetooth device.
     * @return The device information string.
     */
    public static String printBtDeviceInfo(BluetoothDevice device) {
        return BluetoothUtil.printBtDeviceInfo(MyApplication.Companion.getInstance(), device);
    }

    /**
     * Prints the BLE GATT services information.
     *
     * @param context The application context.
     * @param device  The Bluetooth device.
     * @param gatt     The BluetoothGatt instance.
     * @param status   The connection status.
     */
    @SuppressLint("MissingPermission")
    public static void printBleGattServices(Context context, BluetoothDevice device, BluetoothGatt gatt, int status) {
        if (device == null || gatt == null || !checkHasConnectPermission(context) || !JL_Log.isIsLog()) {
            return;
        }
        String TAG = "ble";
        JL_Log.d(TAG, String.format(Locale.getDefault(), "[[============================Bluetooth[%s], " +
                "Discovery Services status[%d]=================================]]\n", BluetoothUtil.printBtDeviceInfo(context, device), status));
        List<BluetoothGattService> services = gatt.getServices();
        if (services != null) {
            JL_Log.d(TAG, "[[======Service Size:" + services.size() + "======================\n");
            for (BluetoothGattService service : services) {
                if (service != null) {
                    JL_Log.d(TAG, "[[======Service:" + service.getUuid() + "======================\n");
                    List<BluetoothGattCharacteristic> characteristics = service.getCharacteristics();
                    if (characteristics != null) {
                        JL_Log.d(TAG, "[[[[=============characteristics Size:" + characteristics.size() + "======================\n");
                        for (BluetoothGattCharacteristic characteristic : characteristics) {
                            if (characteristic != null) {
                                JL_Log.d(TAG, "[[[[=============characteristic:" + characteristic.getUuid()
                                        + ", write type : " + characteristic.getWriteType() + "======================\n");
                                List<BluetoothGattDescriptor> descriptors = characteristic.getDescriptors();
                                if (descriptors != null) {
                                    JL_Log.d(TAG, "[[[[[[=============descriptors Size:" + descriptors.size() + "======================\n");
                                    for (BluetoothGattDescriptor descriptor : descriptors) {
                                        if (descriptor != null) {
                                            JL_Log.d(TAG, "[[[[[[=============descriptor:" + descriptor.getUuid() + ", permission:" + descriptor.getPermissions()
                                                    + "\nvalue : " + CHexConver.byte2HexStr(descriptor.getValue()) + "======================\n");
                                        }
                                    }
                                }
                            }
                        }
                    }
                }
            }
        }
        JL_Log.d(TAG, "[[============================Bluetooth[" + BluetoothUtil.printBtDeviceInfo(context, device) + "] Services show End=================================]]\n");
    }

    /**
     * Converts the connection status to the OTA library status.
     *
     * @param status The connection status.
     * @return The OTA library status.
     */
    public static int changeConnectStatus(int status) {
        switch (status) {
            case BluetoothProfile.STATE_CONNECTED:
                return StateCode.CONNECTION_OK;
            case BluetoothProfile.STATE_CONNECTING:
                return StateCode.CONNECTION_CONNECTING;
            default:
                return StateCode.CONNECTION_DISCONNECT;
        }
    }

    /**
     * Creates a file path.
     *
     * @param context  The application context.
     * @param dirNames The directory names.
     * @return The file path.
     */
    public static String createFilePath(Context context, String... dirNames) {
        if (context == null || dirNames == null || dirNames.length == 0) return null;
        File file = context.getExternalFilesDir(null);
        if (file == null || !file.exists()) return null;
        StringBuilder filePath = new StringBuilder(file.getAbsolutePath());
        for (String dirName : dirNames) {
            filePath.append(File.separator).append(dirName);
            file = new File(filePath.toString());
            if (!file.exists() || file.isFile()) {
                if (!file.mkdirs()) {
                    JL_Log.w("jieli", "create dir failed. filePath = " + filePath);
                    return null;
                }
            }
        }
        return filePath.toString();
    }

    /**
     * Creates a download folder file path.
     *
     * @param context The application context.
     * @return The download folder path.
     */
    public static String createDownloadFolderFilePath(Context context) {
        File downloadFile = Environment.getExternalStorageDirectory();
        String filePath = downloadFile.getAbsolutePath() + File.separator + Environment.DIRECTORY_DOWNLOADS + File.separator + "JieLiOTA" + File.separator + "upgrade";
        File file = new File(filePath);
        if (!file.exists()) {
            if (!file.mkdirs()) {
                JL_Log.w("jieli", "create dir failed. filePath = " + filePath);
            }
        }
        return filePath;
    }

    /**
     * Extracts the file name from a file path.
     *
     * @param filePath The file path.
     * @return The file name.
     */
    public static String getFileNameByPath(String filePath) {
        if (TextUtils.isEmpty(filePath)) return filePath;
        if (!filePath.contains(File.separator)) return filePath;
        return filePath.substring(filePath.lastIndexOf(File.separator) + 1);
    }
}