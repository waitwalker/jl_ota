package com.jieli.otasdk

import android.content.Context
import com.jieli.jl_bt_ota.util.JL_Log

/**
 * Process-wide application context for the plugin.
 * Hosts do not declare an Application subclass. The example app calls [init]
 * from its own Application, and [com.jieli.otasdk.JlOtaPlugin] calls it again
 * when the engine attaches. The second call is a no-op.
 *
 * SDK logs stay off until [setLogEnabled] is called. Upgrade files and toasts
 * are not initialized here.
 */
object OtaRuntime {
    @Volatile
    private var appContext: Context? = null

    fun getContext(): Context {
        return appContext ?: throw IllegalStateException(
            "OtaRuntime not initialized. Call OtaRuntime.init(context) first.",
        )
    }

    fun init(context: Context) {
        if (appContext != null) return
        synchronized(this) {
            if (appContext != null) return
            appContext = context.applicationContext
        }
    }

    /** SDK 日志默认关闭。需要控制台输出和日志文件时再打开。 */
    fun setLogEnabled(context: Context, enabled: Boolean = false) {
        JL_Log.setLog(enabled)
        JL_Log.setIsSaveLogFile(context.applicationContext, enabled)
    }
}
