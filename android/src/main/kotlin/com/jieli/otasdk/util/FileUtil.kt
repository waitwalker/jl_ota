package com.jieli.otasdk.util

import android.content.ContentValues
import android.content.Context
import android.content.Intent
import android.net.Uri
import android.os.Build
import android.os.Environment
import android.provider.MediaStore
import androidx.core.content.FileProvider
import com.jieli.jl_bt_ota.constant.ErrorCode
import com.jieli.jl_bt_ota.interfaces.IActionCallback
import com.jieli.jl_bt_ota.model.OTAError
import com.jieli.jl_bt_ota.util.JL_Log
import java.io.*
import java.util.Locale

/**
 * FileUtil
 * @author zqjasonZhong
 * @since 2024/9/20
 * @email zhongzhuocheng@zh-jieli.com
 * @desc 文件工具类
 */
object FileUtil {

    private const val TAG = "FileUtil"

    /**
     * 杰理OTA文件夹
     */
    const val DIR_JL_OTA = "JieLiOTA"

    /**
     * 升级文件夹
     */
    const val DIR_UPGRADE = "upgrade"

    /**
     * 日志文件夹
     */
    const val DIR_LOGCAT = "logcat"

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

    /**
     * 格式化文件大小
     * @param fileSize long 文件大小
     * @return String 格式化内容
     */
    fun formatFileSize(fileSize: Long): String {
        return when {
            fileSize < 1024 -> "$fileSize Bytes"
            fileSize < 1024 * 1024 -> "%.1f KB".format(fileSize / 1024f)
            fileSize < 1024 * 1024 * 1024 -> "%.1f MB".format(fileSize / (1024f * 1024))
            else -> "%.1f GB".format(fileSize / (1024f * 1024 * 1024))
        }
    }

    /**
     * 是否分区存储
     */
    fun isScopedStorage(): Boolean =
        Environment.getExternalStorageDirectory().equals(Environment.getRootDirectory())

    /**
     * 是否是日志文件
     *
     * @param filePath String 文件路径
     * @return Boolean 结果
     */
    fun isLogFile(filePath: String): Boolean {
        val fileName = getFileNameByPath(filePath)
        return fileName.endsWith(".txt", ignoreCase = true)
    }

    /**
     * 从文件路径读取文件名
     *
     * @param filePath String 文件路径
     * @return String 文件名
     */
    fun getFileNameByPath(filePath: String): String {
        val index = filePath.lastIndexOf(File.separator)
        return if (index == -1) filePath else filePath.substring(index + 1)
    }

    /**
     * 获取Download文件夹对应文件的文件夹路径
     *
     * @param isLogFile Boolean 是否是日志文件
     * @return String 文件路径
     */
    fun getDownloadFolderPath(isLogFile: Boolean = false): String {
        return "${Environment.getExternalStoragePublicDirectory(Environment.DIRECTORY_DOWNLOADS).path}/$DIR_JL_OTA/${if (isLogFile) DIR_LOGCAT else DIR_UPGRADE}"
    }

    /**
     * 获取文件的Download文件夹路径
     *
     * @param fileName String 文件名
     * @return String 对应的Download文件夹路径
     */
    fun getDownloadFilePath(fileName: String): String {
        return "${getDownloadFolderPath(isLogFile(fileName))}/$fileName"
    }

    /**
     * 判断文件是否在Download文件夹中
     *
     * @param context Context 上下文
     * @param fileName String 文件名
     * @return Boolean 结果
     */
    fun isFileInDownload(context: Context, fileName: String): Boolean {
        if (!PermissionUtil.hasReadStoragePermission(context)) return false
        val selection = "${MediaStore.Downloads.DISPLAY_NAME} = ?"
        val args = arrayOf(fileName)
        return if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
            context.contentResolver.query(
                MediaStore.Downloads.EXTERNAL_CONTENT_URI,
                null,
                selection,
                args,
                null
            )?.use { cursor ->
                cursor.moveToFirst() && cursor.getString(cursor.getColumnIndexOrThrow(MediaStore.Downloads.DISPLAY_NAME)) == fileName
            } ?: false
        } else {
            File(getDownloadFilePath(fileName)).exists()
        }
    }

    fun getDownloadDirectoryUri(): Uri =
        Uri.parse("content://com.android.externalstorage.documents/tree/primary%3ADownload")

    fun getUriByPath(context: Context, path: String): Uri? =
        if (path.isBlank()) null else getUriByFile(context, File(path))

    fun getUriByFile(context: Context, file: File): Uri? {
        return if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.N) {
            FileProvider.getUriForFile(context, "${context.packageName}.provider", file)
        } else {
            Uri.fromFile(file)
        }
    }

    /**
     * 删除文件/文件夹
     *
     * @param file File 文件/文件夹
     * @return Boolean 结果
     */
    fun deleteFile(file: File): Boolean {
        if (!file.exists()) return false
        if (file.isFile) return file.delete()
        return file.listFiles()?.all { deleteFile(it) } == true && file.delete()
    }

    /**
     * 分享文件
     *
     * @param context Context 上下文
     * @param filePath String 文件路径
     * @param shareTitle String 分享标题
     * @param callback IActionCallback<String> 结果回调
     */
    fun shareFile(
        context: Context, filePath: String, shareTitle: String,
        callback: IActionCallback<String>
    ) {
        if (!PermissionUtil.hasReadStoragePermission(context)) {
            callback.onError(OTAError.buildError(ErrorCode.SUB_ERR_OP_FAILED))
            return
        }
        val file = File(filePath)
        if (!file.exists()) {
            callback.onError(OTAError.buildError(ErrorCode.SUB_ERR_FILE_NOT_FOUND))
            return
        }
        try {
            val uri = getUriByFile(context, file)
            Intent(Intent.ACTION_SEND).apply {
                type = "text/plain"
                putExtra(Intent.EXTRA_STREAM, uri)
                addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION)
            }.also { intent ->
                context.startActivity(Intent.createChooser(intent, shareTitle))
            }
            callback.onSuccess(filePath)
        } catch (e: Exception) {
            JL_Log.e(TAG, "shareFile", "exception : ${e.message}")
            callback.onError(OTAError.buildError(ErrorCode.SUB_ERR_IO_EXCEPTION))
        }
    }

    /**
     * 下载文件
     *
     * @param context Context 上下文
     * @param filePath String 文件路径
     * @param callback IActionCallback<String> 结果回调
     */
    fun downloadFile(
        context: Context,
        filePath: String,
        callback: IActionCallback<String>
    ) {
        if (!PermissionUtil.hasWriteStoragePermission(context)) {
            callback.onError(OTAError.buildError(ErrorCode.SUB_ERR_OP_FAILED))
            return
        }
        val file = File(filePath)
        if (!file.exists()) {
            callback.onError(OTAError.buildError(ErrorCode.SUB_ERR_FILE_NOT_FOUND))
            return
        }
        val isLogFile = isLogFile(filePath)
        val values = ContentValues().apply {
            put(MediaStore.Downloads.DISPLAY_NAME, file.name)
            put(MediaStore.Downloads.MIME_TYPE, "text/plain")
            put(MediaStore.Downloads.RELATIVE_PATH, getDownloadFolderPath(isLogFile))
        }
        val uri = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
            context.contentResolver.insert(MediaStore.Downloads.EXTERNAL_CONTENT_URI, values)
        } else {
            getUriByPath(context, getDownloadFilePath(file.name))
        }
        uri?.let {
            copyFile(context, it, filePath, callback)
            return
        }
        callback.onError(OTAError.buildError(ErrorCode.SUB_ERR_DATA_NOT_FOUND))
    }

    /**
     * 拼接文件名称和文件大小的内容
     * @param file File对象
     * @return String 包含文件名称和文件大小的字符串
     */
    fun getFileMsg(file: File?): String {
        return file?.let {
            val fileSize = it.length() / 1024f / 1024f
            String.format(Locale.getDefault(), "%s\t\t%.2fMb", it.name, fileSize)
        } ?: ""
    }

    private fun copyFile(
        context: Context,
        folderUri: Uri,
        filePath: String,
        callback: IActionCallback<String>
    ) {
        val file = File(filePath)
        if (!file.exists()) {
            callback.onError(OTAError.buildError(ErrorCode.SUB_ERR_FILE_NOT_FOUND))
            return
        }
        try {
            context.contentResolver.openOutputStream(folderUri)?.use { outputStream ->
                FileInputStream(file).use { input ->
                    val buffer = ByteArray(1024)
                    var readSize: Int
                    while (input.read(buffer).also { readSize = it } != -1) {
                        outputStream.write(buffer, 0, readSize)
                    }
                }
            }
            callback.onSuccess(filePath)
        } catch (e: IOException) {
            JL_Log.e(TAG, "copyFile", "exception : ${e.message}")
            callback.onError(OTAError.buildError(ErrorCode.SUB_ERR_IO_EXCEPTION))
        }
    }
}