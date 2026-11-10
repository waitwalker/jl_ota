package com.jieli.otasdk.util

import android.content.Context
import com.jieli.jl_bt_ota.util.JL_Log
import java.io.File

/**
 * Upgrade-directory helper used by [com.jieli.otasdk.OtaRuntime].
 */
object FileUtil {

    private const val TAG = "FileUtil"

    const val DIR_UPGRADE = "upgrade"

    /**
     * 创建文件夹路径
     *
     * @param context  上下文
     * @param dirNames 文件夹名称
     * @return 文件夹路径
     */
    fun createFilePath(context: Context?, vararg dirNames: String?): String {
        if (context == null || dirNames.isEmpty()) return ""
        val rootDir = context.getExternalFilesDir(null) ?: return ""
        var filePath = StringBuilder(rootDir.path)
        if (filePath.toString().endsWith("/")) {
            filePath = StringBuilder(filePath.substring(0, filePath.lastIndexOf("/")))
        }
        for (dirName in dirNames) {
            filePath.append("/").append(dirName)
            val file = File(filePath.toString())
            if (!file.exists() && !file.mkdirs()) {
                JL_Log.w(TAG, "createFilePath", "create dir failed. filePath = $filePath")
                return ""
            }
        }
        return filePath.toString()
    }
}
