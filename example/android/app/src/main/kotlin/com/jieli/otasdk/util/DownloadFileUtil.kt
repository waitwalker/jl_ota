package com.jieli.otasdk.util

import android.util.Log
import okhttp3.Call
import okhttp3.Callback
import okhttp3.OkHttpClient
import okhttp3.Request
import okhttp3.Response
import java.io.File
import java.io.FileOutputStream
import java.io.IOException
import java.io.InputStream
import java.util.concurrent.ExecutorService
import java.util.concurrent.Executors

/**
 * 把固件从 HTTP 下载到指定路径，并通过事件回调进度。
 */
object DownloadFileUtil {
    private val executor: ExecutorService = Executors.newSingleThreadExecutor()

    @JvmStatic
    fun release() {
        if (!executor.isShutdown) {
            executor.shutdownNow()
        }
    }

    class DownloadFileEvent {
        @JvmField var type: String? = null
        @JvmField var progress: Float? = null
        @JvmField var errorCode: Int? = null
        @JvmField var errorMsg: String? = null
    }

    @JvmStatic
    fun downloadFile(url: String, outPath: String, callback: (DownloadFileEvent) -> Unit) {
        if (!executor.isShutdown) {
            executor.submit(DownloadTask(url, outPath, callback))
        }
    }

    private class DownloadTask(
        private val url: String,
        private val outPath: String,
        private val callback: (DownloadFileEvent) -> Unit,
    ) : Thread() {
        override fun run() {
            val startTime = System.currentTimeMillis()
            Log.i("DOWNLOAD", "startTime=$startTime")
            val client = OkHttpClient()
            val request = Request.Builder().url(url).build()
            client.newCall(request).enqueue(object : Callback {
                override fun onResponse(call: Call, response: Response) {
                    val startEvent = DownloadFileEvent()
                    startEvent.type = "onStart"
                    callback(startEvent)
                    var input: InputStream? = null
                    var output: FileOutputStream? = null
                    val buffer = ByteArray(2048)
                    try {
                        val body = response.body ?: throw NullPointerException()
                        input = body.byteStream()
                        val total = body.contentLength()
                        output = FileOutputStream(File(outPath))
                        var sum = 0L
                        while (true) {
                            val len = input.read(buffer)
                            if (len == -1) break
                            output.write(buffer, 0, len)
                            sum += len
                            val progress = (sum * 1.0f / total * 100).toInt()
                            val progressEvent = DownloadFileEvent()
                            progressEvent.type = "onProgress"
                            progressEvent.progress = progress.toFloat()
                            Log.d("tAG", "progress: $progress")
                            callback(progressEvent)
                        }
                        output.flush()
                        val stopEvent = DownloadFileEvent()
                        stopEvent.type = "onStop"
                        callback(stopEvent)
                        Log.i("DOWNLOAD", "download success")
                        Log.i("DOWNLOAD", "totalTime=${System.currentTimeMillis() - startTime}")
                    } catch (e: Exception) {
                        e.printStackTrace()
                        val errorEvent = DownloadFileEvent()
                        errorEvent.type = "onError"
                        errorEvent.errorCode = -1
                        errorEvent.errorMsg = e.message
                        callback(errorEvent)
                        Log.i("DOWNLOAD", "download failed")
                    } finally {
                        try {
                            input?.close()
                        } catch (e: IOException) {
                        }
                        try {
                            output?.close()
                        } catch (e: IOException) {
                        }
                    }
                }

                override fun onFailure(call: Call, e: IOException) {
                    e.printStackTrace()
                    val errorEvent = DownloadFileEvent()
                    errorEvent.type = "onError"
                    errorEvent.errorCode = -1
                    errorEvent.errorMsg = e.message
                    callback(errorEvent)
                    Log.i("DOWNLOAD", "download failed")
                }
            })
        }
    }
}
