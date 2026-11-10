package com.jieli.otasdk

import android.app.Application
import com.jieli.jl_bt_ota.util.JL_Log

/**
 * Example process entry. Host applications do not use this class.
 * Initialization matches the previous plugin Application.onCreate path so
 * directories and the SDK context exist before the Flutter engine attaches.
 */
class MyApplication : Application() {
    override fun onCreate() {
        super.onCreate()
        OtaRuntime.init(this)
        // Plugin init keeps SDK logs off for hosts. The second init is a no-op,
        // so the example turns file logging back on for the log page and LAN folder.
        JL_Log.setLog(true)
        JL_Log.setIsSaveLogFile(this, true)
    }
}
