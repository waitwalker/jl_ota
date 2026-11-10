package com.jieli.otasdk.tool.file

import com.jieli.otasdk.OtaRuntime
import java.io.File
import java.io.IOException
import java.util.Locale


/**
 * FileManager
 * @author zqjasonZhong
 * @since 2025/4/9
 * @email zhongzhuocheng@zh-jieli.com
 * @desc 文件管理器
 */
object FileManager {

    fun isUpgradeFile(fileName: String): Boolean =
        fileName.endsWith(".ufw", true) || fileName.endsWith(".bfu", true)

    fun readUpgradeFile(): MutableList<File> {
        try {
            val files = mutableListOf<File>()
            val otaPath = OtaRuntime.otaFileDir
            //读取私有空间下Upgrade文件夹的升级文件列表
            val folder = File(otaPath)
            if (folder.exists() && folder.isDirectory) {
                folder.listFiles()?.forEach { file ->
                    if (file.isFile && isUpgradeFile(file.name)) {
                        if (!files.contains(file)) {
                            files.add(file)
                        }
                    }
                }
            }
            return files.sortedByDescending { it.length() }.toMutableList()
        } catch (e: IOException) {
            e.printStackTrace()
        }
        return mutableListOf()
    }

    fun deleteTree(file: File): Boolean {
        if (!file.exists()) return false
        if (file.isFile) return file.delete()
        return file.listFiles()?.all { deleteTree(it) } == true && file.delete()
    }

    fun fileMessage(file: File?): String {
        return file?.let {
            val fileSize = it.length() / 1024f / 1024f
            String.format(Locale.getDefault(), "%s\t\t%.2fMb", it.name, fileSize)
        } ?: ""
    }
}