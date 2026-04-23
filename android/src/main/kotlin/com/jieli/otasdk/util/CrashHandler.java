package com.jieli.otasdk.util;

import android.annotation.SuppressLint;
import android.content.Context;
import android.content.pm.PackageInfo;
import android.content.pm.PackageManager;
import android.os.Build;

import com.jieli.jl_bt_ota.util.JL_Log;

import java.io.PrintWriter;
import java.io.StringWriter;
import java.io.Writer;
import java.lang.reflect.Field;
import java.util.HashMap;
import java.util.Map;

/**
 * Crash handler for uncaught exceptions.
 *
 * @author zqjasonZhong
 * @since 2020/5/22
 */
public class CrashHandler implements Thread.UncaughtExceptionHandler {
    private static final String TAG = CrashHandler.class.getSimpleName();
    private Thread.UncaughtExceptionHandler mDefaultHandler;
    @SuppressLint("StaticFieldLeak")
    private static volatile CrashHandler INSTANCE;
    private Context mContext;
    private final Map<String, String> infos = new HashMap<>();
    private OnExceptionListener mOnExceptionListener;

    private CrashHandler() {
    }

    /**
     * Gets the singleton instance of CrashHandler.
     *
     * @return The CrashHandler instance.
     */
    public static CrashHandler getInstance() {
        if (INSTANCE == null) {
            synchronized (CrashHandler.class) {
                if (INSTANCE == null) {
                    INSTANCE = new CrashHandler();
                }
            }
        }
        return INSTANCE;
    }

    /**
     * Initializes the crash handler.
     *
     * @param context The application context.
     */
    public void init(Context context) {
        mContext = context;
        if (mDefaultHandler == null) {
            mDefaultHandler = Thread.getDefaultUncaughtExceptionHandler();
            Thread.setDefaultUncaughtExceptionHandler(this);
        }
    }

    /**
     * Sets the exception listener.
     *
     * @param listener The exception listener.
     */
    public void setOnExceptionListener(OnExceptionListener listener) {
        mOnExceptionListener = listener;
    }

    @Override
    public void uncaughtException(Thread t, Throwable e) {
        if (t == null || e == null) return;
        if (!handleException(e) && mDefaultHandler != null) {
            mDefaultHandler.uncaughtException(t, e);
        } else {
            try {
                Thread.sleep(3000);
            } catch (InterruptedException ex) {
                JL_Log.e(TAG, "InterruptedException error: " + getExceptionMsg(ex));
            }
            mDefaultHandler = null;
            mContext = null;
            android.os.Process.killProcess(android.os.Process.myPid());
            System.exit(0);
        }
    }

    /**
     * Handles the exception and collects device information.
     *
     * @param ex The exception.
     * @return True if the exception is handled.
     */
    private boolean handleException(Throwable ex) {
        if (ex == null) return false;
        if (mOnExceptionListener != null) {
            mOnExceptionListener.onException(ex);
        }
        collectDeviceInfo(mContext);
        saveCrashInfo2File(ex);
        return true;
    }

    /**
     * Collects device information.
     *
     * @param ctx The application context.
     */
    private void collectDeviceInfo(Context ctx) {
        try {
            if (ctx == null) return;
            PackageManager pm = ctx.getPackageManager();
            if (pm == null) return;
            PackageInfo pi = pm.getPackageInfo(ctx.getPackageName(), PackageManager.GET_ACTIVITIES);
            if (pi != null) {
                String versionName = pi.versionName == null ? "null" : pi.versionName;
                String versionCode = String.valueOf(pi.versionCode);
                infos.put("versionName", versionName);
                infos.put("versionCode", versionCode);
            }
        } catch (PackageManager.NameNotFoundException e) {
            JL_Log.e(TAG, "Error collecting package info: " + getExceptionMsg(e));
        }
        Field[] fields = Build.class.getDeclaredFields();
        for (Field field : fields) {
            try {
                field.setAccessible(true);
                Object value = field.get(null);
                if (value != null) {
                    infos.put(field.getName(), value.toString());
                    JL_Log.d(TAG, field.getName() + ": " + value);
                }
            } catch (Exception e) {
                JL_Log.e(TAG, "Error collecting crash info: " + getExceptionMsg(e));
            }
        }
    }

    /**
     * Saves the crash information to a file.
     *
     * @param ex The exception.
     * @return The file name.
     */
    private String saveCrashInfo2File(Throwable ex) {
        StringBuilder sb = new StringBuilder();
        for (Map.Entry<String, String> entry : infos.entrySet()) {
            sb.append(entry.getKey()).append("=").append(entry.getValue()).append("\n");
        }

        Writer writer = new StringWriter();
        PrintWriter printWriter = new PrintWriter(writer);
        ex.printStackTrace(printWriter);
        Throwable cause = ex.getCause();
        while (cause != null) {
            cause.printStackTrace(printWriter);
            cause = cause.getCause();
        }
        printWriter.close();
        String result = writer.toString();
        sb.append(result);
        JL_Log.e(TAG, sb.toString());
        return null; // Return the file name if needed
    }

    /**
     * Gets the exception message.
     *
     * @param e The exception.
     * @return The exception message.
     */
    private String getExceptionMsg(Exception e) {
        return e == null ? null : e.toString();
    }

    /**
     * Listener for exceptions.
     */
    public interface OnExceptionListener {
        void onException(Throwable ex);
    }
}