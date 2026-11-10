package com.jieli.otasdk

import android.app.Application

/**
 * Example process entry. Host applications do not use this class.
 * The plugin only keeps an application context. This demo creates its own
 * upgrade directory. SDK logs stay off until Dart calls setLogEnabled.
 */
class MyApplication : Application() {
    override fun onCreate() {
        super.onCreate()
        OtaRuntime.init(this)
        ExampleUpgradeDir.init(this)
    }
}
