package com.jieli.otasdk

import android.content.Context
import android.content.Intent
import android.net.Uri
import android.os.Build
import android.os.Handler
import android.os.Looper
import androidx.core.content.FileProvider
import com.jieli.otasdk.data.constant.LogHelperConstants
import com.jieli.jl_bt_ota.util.JL_Log
import io.flutter.plugin.common.EventChannel
import java.io.BufferedReader
import java.io.File
import java.io.FileReader
import java.io.IOException
import java.lang.ref.WeakReference
import java.util.Locale
import java.util.concurrent.atomic.AtomicBoolean

/**
 * Des:
 * author: lifang
 * date: 2025/07/29
 * Copyright: Jieli Technology
 * Modify date:
 * Modified by:
 */
class LogHelper private constructor() {
    companion object {
        @Volatile
        private var instance: LogHelper? = null

        fun getInstance(): LogHelper {
            return instance ?: synchronized(this) {
                instance ?: LogHelper().also { instance = it }
            }
        }

        /**
         * Destroy the instance
         */
        @Synchronized
        fun destroyInstance() {
            instance?.cleanUp()
            instance = null
        }
    }

    private var logFiles: List<File>? = null
    private val handler = Handler(Looper.getMainLooper())
    private var eventSink: EventChannel.EventSink? = null
    private val isReading = AtomicBoolean(false)

    // Reference to the currently running thread to allow interruption
    private var currentReadThread: Thread? = null

    // Cleanup flag
    @Volatile
    private var isCleaned = false

    /**
     * Load the list of log files
     */
    fun loadLogFiles() {
        if (isCleaned) return

        val dir = File(MyApplication.getInstance().logFileDir)
        if (!dir.exists() || !dir.isDirectory) {
            handler.post {
                if (!isCleaned) {
                    eventSink?.error(
                        LogHelperConstants.ERROR_CODE_LOG_HELPER_ERROR,
                        LogHelperConstants.ERROR_MESSAGE_LOG_DIRECTORY_NOT_FOUND,
                        null
                    )
                }
            }
            return
        }

        dir.listFiles()?.let { files ->
            logFiles = files.sortedByDescending { it.lastModified() }

            val fileList = logFiles!!.map { file ->
                mapOf(LogHelperConstants.KEY_NAME to file.name)
            }

            sendFilesToFlutter(fileList)
        } ?: run {
            handler.post {
                if (!isCleaned) {
                    eventSink?.error(
                        LogHelperConstants.ERROR_CODE_LOG_HELPER_ERROR,
                        LogHelperConstants.ERROR_MESSAGE_NO_LOG_FILES_FOUND,
                        null
                    )
                }
            }
        }
    }

    /**
     * Handle log file index and read file content
     * @param index File index
     */
    fun handleLogFileIndex(index: Int) {
        if (isCleaned) return

        if (isReading.getAndSet(true)) {
            JL_Log.w(LogHelperConstants.TAG, "Already reading a file, please wait")
            return
        }

        val file = logFiles?.getOrNull(index) ?: run {
            JL_Log.e(
                LogHelperConstants.TAG,
                String.format(Locale.getDefault(), LogHelperConstants.ERROR_FILE_PATH_NULL, index)
            )
            handler.post {
                if (!isCleaned) {
                    eventSink?.error(
                        LogHelperConstants.ERROR_CODE_LOG_HELPER_ERROR,
                        String.format(Locale.getDefault(), LogHelperConstants.ERROR_MESSAGE_FILE_PATH_NULL, index),
                        null
                    )
                }
            }
            isReading.set(false)
            return
        }

        // Interrupt the previous thread
        currentReadThread?.interrupt()

        currentReadThread = Thread {
            try {
                BufferedReader(FileReader(file)).use { reader ->
                    val content = StringBuilder()
                    var line: String?

                    while (!Thread.currentThread().isInterrupted && !isCleaned) {
                        line = reader.readLine() ?: break

                        content.append(line).append("\n")
                        if (content.length > LogHelperConstants.MAX_CONTENT_LENGTH) {
                            sendContentToFlutter(content.toString())
                            content.clear()
                            Thread.sleep(LogHelperConstants.READ_INTERVAL_MS)
                        }
                    }

                    if (content.isNotEmpty() && !Thread.currentThread().isInterrupted && !isCleaned) {
                        sendContentToFlutter(content.toString())
                    }
                }
            } catch (e: IOException) {
                if (!isCleaned) {
                    JL_Log.e(LogHelperConstants.TAG, "Error reading log file: ${e.message}")
                    handler.post {
                        if (!isCleaned) {
                            eventSink?.error(
                                LogHelperConstants.ERROR_CODE_LOG_HELPER_ERROR,
                                LogHelperConstants.ERROR_MESSAGE_ERROR_READING_LOG_FILE,
                                null
                            )
                        }
                    }
                }
            } catch (e: InterruptedException) {
                JL_Log.w(LogHelperConstants.TAG, "Log reading interrupted")
                Thread.currentThread().interrupt() // Restore interrupted status
            } finally {
                isReading.set(false)
                if (currentReadThread == Thread.currentThread()) {
                    currentReadThread = null
                }
            }
        }.apply { start() }
    }

    /**
     * Share log file
     * @param context Context
     * @param logFileIndex file index
     */
    fun shareLogFile(context: Context, logFileIndex: Int) {
        if (isCleaned) return

        logFiles?.getOrNull(logFileIndex)?.let { file ->
            shareLogFile(context, file)
        } ?: run {
            JL_Log.e(
                LogHelperConstants.TAG,
                String.format(Locale.getDefault(), LogHelperConstants.ERROR_MESSAGE_INVALID_LOG_FILE_INDEX, logFileIndex)
            )
            handler.post {
                if (!isCleaned) {
                    eventSink?.error(
                        LogHelperConstants.ERROR_CODE_LOG_HELPER_ERROR,
                        String.format(Locale.getDefault(), LogHelperConstants.ERROR_MESSAGE_INVALID_LOG_FILE_INDEX, logFileIndex),
                        null
                    )
                }
            }
        }
    }

    /**
     * Set the event sink for the event channel
     * @param sink Event sink
     */
    fun setEventSink(sink: EventChannel.EventSink?) {
        eventSink = sink
    }

    /**
     * Clean up resources
     */
    fun cleanUp() {
        isCleaned = true

        // Interrupt the currently reading thread
        currentReadThread?.interrupt()
        currentReadThread = null

        // Remove callbacks and messages from Handler
        handler.removeCallbacksAndMessages(null)

        // Clear eventSink
        eventSink = null

        // Reset flags
        isReading.set(false)

        // Clear file list
        logFiles = null
    }

    /**
     * Share log file
     * @param context Context
     * @param file File to share
     */
    private fun shareLogFile(context: Context, file: File) {
        if (isCleaned) return

        try {
            val uri = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.N) {
                FileProvider.getUriForFile(
                    context,
                    "${context.packageName}${LogHelperConstants.FILE_PROVIDER_SUFFIX}",
                    file
                )
            } else {
                Uri.fromFile(file)
            }

            Intent().apply {
                action = LogHelperConstants.INTENT_ACTION_SEND
                type = LogHelperConstants.INTENT_TYPE_ALL_FILES
                flags = Intent.FLAG_ACTIVITY_NEW_TASK
                putExtra(LogHelperConstants.INTENT_EXTRA_STREAM, uri)
            }.let { intent ->
                context.startActivity(Intent.createChooser(intent, LogHelperConstants.SHARE_CHOOSER_TITLE))
            }
        } catch (e: Exception) {
            if (!isCleaned) {
                JL_Log.e(LogHelperConstants.TAG, "Error sharing log file: ${e.message}")
                handler.post {
                    if (!isCleaned) {
                        eventSink?.error(
                            LogHelperConstants.ERROR_CODE_LOG_HELPER_ERROR,
                            LogHelperConstants.ERROR_MESSAGE_ERROR_SHARING_LOG_FILE,
                            null
                        )
                    }
                }
            }
        }
    }

    /**
     * Send file list to Flutter
     * @param files File list
     */
    private fun sendFilesToFlutter(files: List<Map<String, String>>) {
        if (isCleaned) return

        handler.post {
            if (!isCleaned) {
                eventSink?.success(
                    mapOf(
                        LogHelperConstants.KEY_TYPE to LogHelperConstants.TYPE_LOG_FILES,
                        LogHelperConstants.KEY_FILES to files
                    )
                )
            }
        }
    }

    /**
     * Send file content to Flutter
     * @param content File content
     */
    private fun sendContentToFlutter(content: String) {
        if (isCleaned) return

        handler.post {
            if (!isCleaned) {
                eventSink?.success(
                    mapOf(
                        LogHelperConstants.KEY_TYPE to LogHelperConstants.TYPE_LOG_DETAIL_FILES,
                        LogHelperConstants.KEY_FILES to listOf(content)
                    )
                )
            }
        }
    }
}