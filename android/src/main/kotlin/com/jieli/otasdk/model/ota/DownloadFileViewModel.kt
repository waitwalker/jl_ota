package com.jieli.otasdk.model.ota

import androidx.lifecycle.MutableLiveData
import androidx.lifecycle.ViewModel
import com.jieli.otasdk.MyApplication
import com.jieli.otasdk.util.DownloadFileUtil
import java.io.File

/**
 * @ClassName: DownloadFileViewModel
 * @Description: ViewModel for handling file download operations.
 * @Author: ZhangHuanMing
 * @CreateDate: 2023/4/25 14:41
 */
class DownloadFileViewModel : ViewModel() {
    private var httpUrl: String? = null
    val downloadStatusMLD = MutableLiveData<DownloadFileUtil.DownloadFileEvent>()

    companion object {
        @Volatile
        private var instance: DownloadFileViewModel? = null
        private const val DEFAULT_FILE_NAME = "upgrade.ufw"

        fun getInstance(): DownloadFileViewModel {
            return instance ?: synchronized(this) {
                instance ?: DownloadFileViewModel().also { instance = it }
            }
        }

        fun destroy() {
            instance = null
        }
    }

    fun getHttpUrl(): String? {
        return this.httpUrl
    }

    fun downloadFile(httpUrl: String) {
        this.httpUrl = httpUrl

        val parentFile = MyApplication.getInstance().otaFileDir
        val originalFileName = DEFAULT_FILE_NAME
        val targetFileName = generateUniqueFileName(parentFile, originalFileName)
        val targetPath = File(parentFile, targetFileName).absolutePath

        DownloadFileUtil.downloadFile(httpUrl, targetPath) { event ->
            downloadStatusMLD.postValue(event)
        }
    }

    private fun generateUniqueFileName(parentDir: String, originalName: String): String {
        val file = File(parentDir, originalName)
        if (!file.exists()) return originalName

        val (baseName, extension) = splitFileName(originalName)
        val timestamp = System.currentTimeMillis()

        return "${baseName}_${timestamp}${extension}"
    }

    private fun splitFileName(fileName: String): Pair<String, String> {
        val lastDotIndex = fileName.lastIndexOf(".")
        return if (lastDotIndex == -1) {
            Pair(fileName, "")
        } else {
            Pair(fileName.substring(0, lastDotIndex), fileName.substring(lastDotIndex))
        }
    }
}