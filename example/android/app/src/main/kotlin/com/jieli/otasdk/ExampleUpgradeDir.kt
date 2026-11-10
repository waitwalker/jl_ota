package com.jieli.otasdk

import android.content.Context
import java.io.File

/**
 * Example-only cabinet for local upgrade files.
 * The plugin OTA entry takes a file path and does not create this directory.
 */
object ExampleUpgradeDir {
    private const val DIR_NAME = "upgrade"

    lateinit var otaFileDir: String
        private set

    fun init(context: Context) {
        val root = context.applicationContext.getExternalFilesDir(null)
        if (root == null) {
            otaFileDir = ""
            return
        }
        val dir = File(root, DIR_NAME)
        if (!dir.exists() && !dir.mkdirs()) {
            otaFileDir = ""
            return
        }
        otaFileDir = dir.absolutePath
    }
}
