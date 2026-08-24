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
import java.lang.ref.WeakReference

/**
 * Des:
 * author: lifang
 * date: 2025/07/22
 * Copyright: Jieli Technology
 * Modify date: 2025/07/29
 * Modified by:
 */
class MainViewModel private constructor() : ViewModel() {

    private var isCleaned = false
    private var webServiceContextRef: WeakReference<Context>? = null

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
            val instance = getInstance()
            if (instance.isCleaned) return

            try {
                // Use application context to prevent memory leaks
                val appContext = context.applicationContext

                // Store weak reference to context for cleanup
                instance.webServiceContextRef = WeakReference(appContext)

                // Start file transfer service
                val folderList = ArrayList<TransferFolder>()

                // OTA folder configuration
                folderList.add(TransferFolder().apply {
                    id = FOLDER_ID_OTA
                    folder = File(MyApplication.getInstance().otaFileDir)
                    describe = appContext.getString(R.string.update_file)
                    fileType = FOLDER_FILE_TYPE_UFW
                    callback = createTransferFolderCallback()
                })

                // Log folder configuration
                folderList.add(TransferFolder().apply {
                    id = FOLDER_ID_LOG
                    folder = File(MyApplication.getInstance().logFileDir)
                    describe = appContext.getString(R.string.log_file)
                    fileType = FOLDER_FILE_TYPE_TXT
                    callback = createTransferFolderCallback()
                })

                WebService.setTransferFolderList(folderList)
                WebService.start(appContext)
            } catch (e: Exception) {
                e.printStackTrace()
            }
        }

        fun stopWebService(context: Context) {
            try {
                val appContext = context.applicationContext
                appContext.stopService(Intent(appContext, WebService::class.java))
            } catch (e: Exception) {
                e.printStackTrace()
            }
        }

        /**
         * Create TransferFolderCallback without holding external references
         * Uses a static inner class to avoid memory leaks
         */
        private fun createTransferFolderCallback(): TransferFolderCallback {
            return TransferFolderCallbackImpl()
        }

        /**
         * Static inner class implementation to prevent memory leaks
         * Does not hold reference to MainViewModel
         */
        private class TransferFolderCallbackImpl : TransferFolderCallback {
            @Deprecated("Deprecated in Java")
            override fun onCreateFile(file: File?): Boolean {
                return true
            }

            override fun onDeleteFile(file: File?): Boolean {
                return file?.delete() == true
            }
        }
    }

    /**
     * Check if the ViewModel has been cleaned up
     */
    fun isCleaned(): Boolean = isCleaned

    fun destroy() {
        if (isCleaned) return
        isCleaned = true

        // Stop web service
        webServiceContextRef?.get()?.let { context ->
            stopWebService(context)
        }
        webServiceContextRef = null

        // Destroy BluetoothHelper
        BluetoothHelper.getInstance().destroy()
    }
}