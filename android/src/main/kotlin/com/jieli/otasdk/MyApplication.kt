package com.jieli.otasdk

import android.annotation.SuppressLint
import android.app.Application
import android.os.Handler
import android.os.Looper
import com.jieli.component.ActivityManager
import com.jieli.component.utils.ToastUtil
import com.jieli.jl_bt_ota.util.CommonUtil
import com.jieli.jl_bt_ota.util.JL_Log
import com.jieli.otasdk.util.FileUtil

/**
 * Des:
 * author: lifang
 * date: 2025/07/18
 * Copyright: Jieli Technology
 * Modify date:
 * Modified by:
 */
open class MyApplication : Application() {
    companion object {
        @SuppressLint("StaticFieldLeak")
        @Volatile
        private var instance: MyApplication? = null

        fun getInstance(): MyApplication {
            return instance ?: throw IllegalStateException("MyApplication not initialized!")
        }
    }

    /**
     * 是否调试模式
     */
    private val isDebug = true

    /**
     * OTA文件夹路径
     */
    lateinit var otaFileDir: String
        private set

    /**
     * 日志文件夹路径
     */
    lateinit var logFileDir: String
        private set

    @Throws(Throwable::class)
    protected fun finalize() {
        handleLog(false)
    }

    override fun onCreate() {
        super.onCreate()
        instance = this
        init()
        ActivityManager.init(this)
        ToastUtil.init(this)
        CommonUtil.setMainContext(this)
    }

    fun init() {
        otaFileDir = FileUtil.createFilePath(this, FileUtil.DIR_UPGRADE)
        logFileDir = JL_Log.getSaveLogPath(instance)
        handleLog(isDebug)
    }

    private fun handleLog(isDebug: Boolean) {
        JL_Log.setLog(isDebug)
        JL_Log.setIsSaveLogFile(this, isDebug)
    }
}