package com.jieli.otasdk.home

import android.content.Context
import android.content.Intent
import androidx.lifecycle.ViewModel
import com.jieli.jlFileTransfer.TransferFolder
import com.jieli.jlFileTransfer.TransferFolderCallback
import com.jieli.jlFileTransfer.WebService
import com.jieli.otasdk.MyApplication
import com.jieli.otasdk.R
import com.jieli.otasdk.tool.bluetooth.BluetoothHelper
import java.io.File

/**
 * Des:
 * author: lifang
 * date: 2025/07/22
 * Copyright: Jieli Technology
 * Modify date: 2025/07/29
 * Modified by:
 */
class MainViewModel : ViewModel() {

    fun destroy() {
        BluetoothHelper.getInstance().destroy()
    }

    companion object {
        @Volatile
        private var instance: MainViewModel? = null

        private const val FOLDER_ID_OTA = 0
        private const val FOLDER_ID_LOG = 1
        private const val FOLDER_FILE_TYPE_UFW = ".ufw"
        private const val FOLDER_FILE_TYPE_TXT = ".txt"

        fun getInstance(): MainViewModel {
            return instance ?: synchronized(this) {
                instance ?: MainViewModel().also { instance = it }
            }
        }

        fun destroyInstance() {
            instance?.destroy()
            instance = null
        }

        fun startWebService(context: Context) {
            try {
                // 开启传文件服务
                val folderList = ArrayList<TransferFolder>()
                folderList.add(TransferFolder().run {
                    this.id = FOLDER_ID_OTA
                    this.folder = File(MyApplication.getInstance().otaFileDir)
                    this.describe = context.getString(R.string.update_file)
                    this.fileType = FOLDER_FILE_TYPE_UFW
                    this.callback = object : TransferFolderCallback {
                        override fun onCreateFile(file: File?): Boolean {
                            return true
                        }

                        override fun onDeleteFile(file: File?): Boolean {
                            return file?.delete() == true
                        }
                    }
                    this
                })
                folderList.add(TransferFolder().run {
                    this.id = FOLDER_ID_LOG
                    this.folder = File(MyApplication.getInstance().logFileDir)
                    this.describe = context.getString(R.string.log_file)
                    this.fileType = FOLDER_FILE_TYPE_TXT
                    this.callback = object : TransferFolderCallback {
                        override fun onCreateFile(file: File?): Boolean {
                            return true
                        }

                        override fun onDeleteFile(file: File?): Boolean {
                            return file?.delete() == true
                        }
                    }
                    this
                })
                WebService.setTransferFolderList(folderList)
                WebService.start(context)
            } catch (e: Exception) {
                e.printStackTrace() // 打印异常信息
            }
        }

        fun stopWebService(context: Context) {
            context.stopService(Intent(context, WebService::class.java))
        }
    }
}