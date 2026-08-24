package com.jieli.otasdk.tool.ota.spp;

import android.bluetooth.BluetoothDevice;
import android.bluetooth.BluetoothSocket;
import android.content.Context;

import com.jieli.jl_bt_ota.util.JL_Log;
import com.jieli.otasdk.util.AppUtil;

import java.io.IOException;
import java.io.InputStream;
import java.util.UUID;

/**
 * 接受Spp数据线程
 *
 * @author zqjasonZhong
 * @since 2020/8/20
 */
public class ReceiveSppDataThread extends Thread {
    private static final String TAG = ReceiveSppDataThread.class.getSimpleName();
    private static final int DEFAULT_BLOCK_SIZE = 4096;
    private static final int READ_TIMEOUT_MS = 30;

    public static final int EXIT_REASON_SUCCESS = 0;
    public static final int EXIT_REASON_PARAM_ERROR = 1;
    public static final int EXIT_REASON_IO_EXCEPTION = 2;
    public static final int EXIT_REASON_THREAD_INTERRUPTED = 3;

    private final Context mContext;
    private final BluetoothDevice mConnectedSppDev;
    private final BluetoothSocket mBluetoothSocket;
    private final int mBlockSize;
    private final OnRecvSppDataListener mOnRecvSppDataListener;
    private final UUID mSppUUID;
    private volatile boolean isRunning;
    private InputStream mInputStream;

    public ReceiveSppDataThread(Context context, BluetoothDevice device, UUID sppUUID,
                                BluetoothSocket socket, OnRecvSppDataListener listener) {
        this(context, device, sppUUID, socket, DEFAULT_BLOCK_SIZE, listener);
    }

    public ReceiveSppDataThread(Context context, BluetoothDevice device, UUID sppUUID,
                                BluetoothSocket socket, int blockSize, OnRecvSppDataListener listener) {
        super("ReceiveSppDataThread : " + device);
        // 使用ApplicationContext避免Activity内存泄漏
        mContext = context.getApplicationContext();
        mConnectedSppDev = device;
        mSppUUID = sppUUID;
        mBluetoothSocket = socket;
        mBlockSize = blockSize > 0 ? blockSize : DEFAULT_BLOCK_SIZE;
        mOnRecvSppDataListener = listener;
    }

    /**
     * 获取已连接的SPP通道
     */
    public BluetoothSocket getBluetoothSocket() {
        return mBluetoothSocket;
    }

    /**
     * 获取SPP的UUID通道
     */
    public UUID getSppUUID() {
        return mSppUUID;
    }

    /**
     * 停止线程
     * 会中断线程并关闭输入流，确保线程能够快速退出
     */
    public void stopThread() {
        JL_Log.i(TAG, "stopThread called.");
        isRunning = false;

        // 中断线程，使其从阻塞状态（read/sleep）中退出
        interrupt();

        // 关闭输入流，使read方法返回-1或抛出异常
        closeInputStream();
    }

    /**
     * 检查线程是否正在运行
     */
    public boolean isRunning() {
        return isRunning;
    }

    @Override
    public void run() {
        JL_Log.i(TAG, "ReceiveDataThread start.");
        isRunning = true;
        int exitReason = EXIT_REASON_SUCCESS;
        long threadId = getId();

        // 通知线程启动
        if (mOnRecvSppDataListener != null) {
            mOnRecvSppDataListener.onThreadStart(threadId);
        }

        // 参数校验
        if (!isValidParams()) {
            exitReason = EXIT_REASON_PARAM_ERROR;
            notifyThreadStop(threadId, exitReason);
            return;
        }

        // 执行数据接收循环
        exitReason = receiveDataLoop(threadId);

        // 清理资源并通知线程停止
        cleanup();
        notifyThreadStop(threadId, exitReason);

        JL_Log.i(TAG, "ReceiveDataThread exit with reason: " + exitReason);
    }

    /**
     * 校验参数有效性
     */
    private boolean isValidParams() {
        if (mConnectedSppDev == null) {
            JL_Log.e(TAG, "Connected device is null");
            return false;
        }
        if (!AppUtil.checkHasConnectPermission(mContext)) {
            JL_Log.e(TAG, "Missing Bluetooth connect permission");
            return false;
        }
        if (mBluetoothSocket == null) {
            JL_Log.e(TAG, "Bluetooth socket is null");
            return false;
        }
        return true;
    }

    /**
     * 数据接收主循环
     */
    private int receiveDataLoop(long threadId) {
        int exitReason = EXIT_REASON_SUCCESS;

        try {
            // 获取输入流
            mInputStream = mBluetoothSocket.getInputStream();
            if (mInputStream == null) {
                JL_Log.e(TAG, "Failed to get input stream");
                return EXIT_REASON_IO_EXCEPTION;
            }

            JL_Log.i(TAG, "Start receiving data, isRunning: " + isRunning);

            byte[] buffer = new byte[mBlockSize];

            while (isRunning && !isInterrupted()) {
                try {
                    int bytesRead = mInputStream.read(buffer);

                    if (bytesRead > 0) {
                        // 读取到有效数据
                        byte[] data = new byte[bytesRead];
                        System.arraycopy(buffer, 0, data, 0, bytesRead);

                        if (mOnRecvSppDataListener != null) {
                            mOnRecvSppDataListener.onRecvSppData(threadId, mConnectedSppDev, mSppUUID, data);
                        }
                    } else if (bytesRead == -1) {
                        // 流已结束
                        JL_Log.i(TAG, "InputStream reached end of stream");
                        break;
                    } else {
                        // bytesRead == 0，短暂休眠避免CPU空转
                        try {
                            Thread.sleep(READ_TIMEOUT_MS);
                        } catch (InterruptedException e) {
                            JL_Log.i(TAG, "Sleep interrupted");
                            Thread.currentThread().interrupt();
                            break;
                        }
                    }
                } catch (IOException e) {
                    JL_Log.e(TAG, "IO exception while reading data", e.getMessage());
                    exitReason = EXIT_REASON_IO_EXCEPTION;
                    break;
                }
            }

            // 检查是否因中断而退出
            if (isInterrupted()) {
                JL_Log.i(TAG, "Thread was interrupted");
                if (exitReason == EXIT_REASON_SUCCESS) {
                    exitReason = EXIT_REASON_THREAD_INTERRUPTED;
                }
            }

        } catch (IOException e) {
            JL_Log.e(TAG, "Failed to open input stream", e.getMessage());
            exitReason = EXIT_REASON_IO_EXCEPTION;
        } catch (SecurityException e) {
            JL_Log.e(TAG, "Security exception while accessing input stream", e.getMessage());
            exitReason = EXIT_REASON_IO_EXCEPTION;
        }

        return exitReason;
    }

    /**
     * 清理资源
     */
    private void cleanup() {
        isRunning = false;
        closeInputStream();
    }

    /**
     * 关闭输入流
     */
    private void closeInputStream() {
        if (mInputStream != null) {
            try {
                mInputStream.close();
                JL_Log.d(TAG, "Input stream closed");
            } catch (IOException e) {
                JL_Log.e(TAG, "Error closing input stream", e.getMessage());
            } finally {
                mInputStream = null;
            }
        }
    }

    /**
     * 通知线程停止
     */
    private void notifyThreadStop(long threadId, int exitReason) {
        if (mOnRecvSppDataListener != null) {
            try {
                mOnRecvSppDataListener.onThreadStop(threadId, exitReason, mConnectedSppDev, mSppUUID);
            } catch (Exception e) {
                JL_Log.e(TAG, "Error in onThreadStop callback", e.getMessage());
            }
        }
    }

    /**
     * 接收SPP数据监听器
     */
    public interface OnRecvSppDataListener {
        /**
         * 线程开始回调
         * @param threadID 线程ID
         */
        void onThreadStart(long threadID);

        /**
         * 接收到SPP数据回调
         * @param threadID 线程ID
         * @param device 蓝牙设备
         * @param sppUUID SPP UUID
         * @param data 接收到的数据
         */
        void onRecvSppData(long threadID, BluetoothDevice device, UUID sppUUID, byte[] data);

        /**
         * 线程停止回调
         * @param threadID 线程ID
         * @param reason 停止原因
         * @param device 蓝牙设备
         * @param sppUUID SPP UUID
         */
        void onThreadStop(long threadID, int reason, BluetoothDevice device, UUID sppUUID);
    }
}