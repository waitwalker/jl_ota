package com.jieli.otasdk

import android.annotation.SuppressLint
import android.app.Application
import android.content.Context
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
            return instance ?: throw IllegalStateException("MyApplication not initialized! Call MyApplication.initWith(context) first.")
        }

        /**
         * Initialize from a host application context so third-party apps
         * do not need to inherit MyApplication.
         */
        fun initWith(context: Context) {
            if (instance != null) return
            synchronized(this) {
                if (instance == null) {
                    val wrapper = MyApplication()
                    instance = wrapper
                    wrapper.initFromContext(context.applicationContext)
                }
            }
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
        // ActivityManager.init skipped: jl-component-lib NPE on late lifecycle attach (onActivityDestroyed).
        ToastUtil.init(this)
        CommonUtil.setMainContext(this)
    }

    fun init() {
        otaFileDir = FileUtil.createFilePath(this, FileUtil.DIR_UPGRADE)
        logFileDir = JL_Log.getSaveLogPath(instance)
        handleLog(isDebug)
    }

    private fun initFromContext(appContext: Context) {
        try {
            attachBaseContext(appContext)
        } catch (_: Exception) {
            // attachBaseContext can only be called once
        }
        otaFileDir = FileUtil.createFilePath(appContext, FileUtil.DIR_UPGRADE)
        logFileDir = JL_Log.getSaveLogPath(appContext)
        handleLog(isDebug)
        val application = appContext as? Application ?: return
        // Do not call ActivityManager.init here. Host Activities are often already created
        // when the Flutter plugin attaches, so activityStack stays null and any later
        // onActivityDestroyed NPEs in jl-component-lib (Crashlytics hot crash).
        // OTA scan/connect/start paths do not need the Activity stack.
        ToastUtil.init(application)
        CommonUtil.setMainContext(appContext)
    }

    private fun handleLog(isDebug: Boolean) {
        JL_Log.setLog(isDebug)
        JL_Log.setIsSaveLogFile(this, isDebug)
    }
}