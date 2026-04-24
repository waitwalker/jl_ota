package com.jieli.otasdk

import android.annotation.SuppressLint
import android.app.Application
import android.content.Context
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
            return instance ?: throw IllegalStateException("MyApplication not initialized! Call MyApplication.initWith(context) first.")
        }

        /**
         * 允许从外部注入 applicationContext 来初始化，
         * 不需要宿主应用继承 MyApplication。
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
        ActivityManager.init(this)
        ToastUtil.init(this)
        CommonUtil.setMainContext(this)
    }

    fun init() {
        otaFileDir = FileUtil.createFilePath(this, FileUtil.DIR_UPGRADE)
        logFileDir = JL_Log.getSaveLogPath(instance)
        handleLog(isDebug)
    }

    /**
     * 从外部 Context 初始化（非 Application 子类场景）
     */
    private fun initFromContext(appContext: Context) {
        // 必须先 attachBaseContext，让 wrapper 拥有完整的 Context 能力，
        // 否则 JL_Log 等组件内部调用 getExternalFilesDir() 会因 mBase 为 null 而 NPE。
        try {
            attachBaseContext(appContext)
        } catch (_: Exception) {
            // attachBaseContext 只能调用一次，如果已经调用过则忽略
        }
        otaFileDir = FileUtil.createFilePath(appContext, FileUtil.DIR_UPGRADE)
        logFileDir = JL_Log.getSaveLogPath(appContext)
        handleLog(isDebug)
        // 初始化第三方组件
        ActivityManager.init(appContext as? Application ?: return)
        ToastUtil.init(appContext as? Application ?: return)
        CommonUtil.setMainContext(appContext)
    }

    private fun handleLog(isDebug: Boolean) {
        JL_Log.setLog(isDebug)
        JL_Log.setIsSaveLogFile(instance ?: return, isDebug)
    }
}