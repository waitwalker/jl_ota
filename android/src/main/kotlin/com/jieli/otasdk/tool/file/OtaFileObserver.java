package com.jieli.otasdk.tool.file;

import android.os.FileObserver;
import androidx.annotation.NonNull;
import androidx.annotation.Nullable;

/**
 * @author zqjasonZhong
 * @email zhongzhuocheng@zh-jieli.com
 * @desc  文件监听类
 * @since 2021/5/31
 */
public class OtaFileObserver extends FileObserver {

    @Nullable
    private FileObserverCallback mFileObserverCallback;

    /**
     * Constructs a new OtaFileObserver for the specified path.
     * @param path The path to observe
     */
    public OtaFileObserver(@NonNull String path) {
        super(path);
    }

    /**
     * Sets the callback that will receive file change events.
     * @param fileObserverCallback The callback interface
     */
    public void setFileObserverCallback(@Nullable FileObserverCallback fileObserverCallback) {
        this.mFileObserverCallback = fileObserverCallback;
    }

    @Override
    public void onEvent(int event, @Nullable String path) {
        final FileObserverCallback callback = mFileObserverCallback;
        if (callback != null && path != null) {
            callback.onChange(event, path);
        }
    }

    /**
     * Releases resources and clears the callback to prevent memory leaks.
     */
    public void release() {
        stopWatching();
        mFileObserverCallback = null;
    }
}