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
    }

    private var logFiles: List<File>? = null
    private val handler = Handler(Looper.getMainLooper())
    private var eventSink: EventChannel.EventSink? = null
    private val isReading = AtomicBoolean(false)

    /**
     * 加载日志文件列表
     */
    fun loadLogFiles() {
        val dir = File(MyApplication.getInstance().logFileDir)
        if (!dir.exists() || !dir.isDirectory) {
            handler.post {
                eventSink?.error(
                    LogHelperConstants.ERROR_CODE_LOG_HELPER_ERROR,
                    LogHelperConstants.ERROR_MESSAGE_LOG_DIRECTORY_NOT_FOUND,
                    null
                )
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
                eventSink?.error(
                    LogHelperConstants.ERROR_CODE_LOG_HELPER_ERROR,
                    LogHelperConstants.ERROR_MESSAGE_NO_LOG_FILES_FOUND,
                    null
                )
            }
        }
    }

    /**
     * 处理日志文件索引，读取文件内容
     * @param index 文件索引
     */
    fun handleLogFileIndex(index: Int) {
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
                eventSink?.error(
                    LogHelperConstants.ERROR_CODE_LOG_HELPER_ERROR,
                    String.format(Locale.getDefault(), LogHelperConstants.ERROR_MESSAGE_FILE_PATH_NULL, index),
                    null
                )
            }
            isReading.set(false)
            return
        }

        Thread {
            try {
                BufferedReader(FileReader(file)).use { reader ->
                    val content = StringBuilder()
                    var line: String?

                    while (!Thread.currentThread().isInterrupted) {
                        line = reader.readLine() ?: break

                        content.append(line).append("\n")
                        if (content.length > LogHelperConstants.MAX_CONTENT_LENGTH) {
                            sendContentToFlutter(content.toString())
                            content.clear()
                            Thread.sleep(LogHelperConstants.READ_INTERVAL_MS)
                        }
                    }

                    if (content.isNotEmpty()) {
                        sendContentToFlutter(content.toString())
                    }
                }
            } catch (e: IOException) {
                JL_Log.e(LogHelperConstants.TAG, "Error reading log file: ${e.message}")
                handler.post {
                    eventSink?.error(
                        LogHelperConstants.ERROR_CODE_LOG_HELPER_ERROR,
                        LogHelperConstants.ERROR_MESSAGE_ERROR_READING_LOG_FILE,
                        null
                    )
                }
            } catch (_: InterruptedException) {
                JL_Log.w(LogHelperConstants.TAG, "Log reading interrupted")
            } finally {
                isReading.set(false)
            }
        }.start()
    }

    /**
     * Share log file
     * @param context Context
     * @param logFileIndex file index
     */
    fun shareLogFile(context: Context, logFileIndex: Int) {
        logFiles?.getOrNull(logFileIndex)?.let { file ->
            shareLogFile(context, file)
        } ?: run {
            JL_Log.e(
                LogHelperConstants.TAG,
                String.format(Locale.getDefault(), LogHelperConstants.ERROR_MESSAGE_INVALID_LOG_FILE_INDEX, logFileIndex)
            )
            handler.post {
                eventSink?.error(
                    LogHelperConstants.ERROR_CODE_LOG_HELPER_ERROR,
                    String.format(Locale.getDefault(), LogHelperConstants.ERROR_MESSAGE_INVALID_LOG_FILE_INDEX, logFileIndex),
                    null
                )
            }
        }
    }

    /**
     * 设置事件通道的sink
     * @param sink 事件sink
     */
    fun setEventSink(sink: EventChannel.EventSink?) {
        eventSink = sink
    }

    /**
     * 清理资源
     */
    fun cleanup() {
        eventSink = null
        isReading.set(false)
    }

    /**
     * 分享日志文件
     * @param context 上下文
     * @param file 要分享的文件
     */
    private fun shareLogFile(context: Context, file: File) {
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
            JL_Log.e(LogHelperConstants.TAG, "Error sharing log file: ${e.message}")
            handler.post {
                eventSink?.error(
                    LogHelperConstants.ERROR_CODE_LOG_HELPER_ERROR,
                    LogHelperConstants.ERROR_MESSAGE_ERROR_SHARING_LOG_FILE,
                    null
                )
            }
        }
    }

    /**
     * 发送文件列表到Flutter
     * @param files 文件列表
     */
    private fun sendFilesToFlutter(files: List<Map<String, String>>) {
        handler.post {
            eventSink?.success(
                mapOf(
                    LogHelperConstants.KEY_TYPE to LogHelperConstants.TYPE_LOG_FILES,
                    LogHelperConstants.KEY_FILES to files
                )
            )
        }
    }

    /**
     * 发送文件内容到Flutter
     * @param content 文件内容
     */
    private fun sendContentToFlutter(content: String) {
        handler.post {
            eventSink?.success(
                mapOf(
                    LogHelperConstants.KEY_TYPE to LogHelperConstants.TYPE_LOG_DETAIL_FILES,
                    LogHelperConstants.KEY_FILES to listOf(content)
                )
            )
        }
    }
}