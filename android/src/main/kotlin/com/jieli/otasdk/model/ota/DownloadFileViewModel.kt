package com.jieli.otasdk.model.ota

import androidx.lifecycle.MutableLiveData
import androidx.lifecycle.ViewModel
import com.jieli.otasdk.MyApplication
import com.jieli.otasdk.util.DownloadFileUtil
import java.io.File
import java.util.Calendar

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
        val parentFilePath = MyApplication.getInstance().otaFileDir
        var fileName = DEFAULT_FILE_NAME
        val resultFile = File(parentFilePath, fileName)

        // 如果文件已存在，添加时间戳重命名
        if (resultFile.exists()) {
            val fileTypeIndex = fileName.lastIndexOf(".")
            val fileType = fileName.substring(fileTypeIndex)
            val realName = fileName.substring(0, fileTypeIndex)
            val calendar = Calendar.getInstance()
            fileName = "${realName}_${calendar.timeInMillis}$fileType"
        }

        val resultPath = File(parentFilePath, fileName).absolutePath
        DownloadFileUtil.downloadFile(httpUrl, resultPath) { event ->
            downloadStatusMLD.postValue(event)
        }
    }
}