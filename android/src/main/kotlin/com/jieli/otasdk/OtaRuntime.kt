package com.jieli.otasdk

import android.app.Application
import android.content.Context
import com.jieli.component.utils.ToastUtil
import com.jieli.jl_bt_ota.util.CommonUtil
import com.jieli.jl_bt_ota.util.JL_Log
import com.jieli.otasdk.util.FileUtil

/**
 * Process-wide context and directories for the plugin.
 * Hosts do not declare an Application subclass. The example app calls [init]
 * from its own Application, and [com.jieli.otasdk.JlOtaPlugin] calls it again
 * when the engine attaches. The second call is a no-op.
 */
object OtaRuntime {
    private const val isDebug = false

    @Volatile
    private var appContext: Context? = null

    lateinit var otaFileDir: String
        private set

    fun getContext(): Context {
        return appContext ?: throw IllegalStateException(
            "OtaRuntime not initialized. Call OtaRuntime.init(context) first.",
        )
    }

    fun init(context: Context) {
        if (appContext != null) return
        synchronized(this) {
            if (appContext != null) return
            val applicationContext = context.applicationContext
            appContext = applicationContext
            otaFileDir = FileUtil.createFilePath(applicationContext, FileUtil.DIR_UPGRADE)
            JL_Log.setLog(isDebug)
            JL_Log.setIsSaveLogFile(applicationContext, isDebug)
            (applicationContext as? Application)?.let { ToastUtil.init(it) }
            CommonUtil.setMainContext(applicationContext)
        }
    }
}
