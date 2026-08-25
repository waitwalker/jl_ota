package com.jieli.otasdk.util

import android.Manifest
import android.content.Context
import android.content.pm.PackageManager
import android.os.Build
import androidx.core.app.ActivityCompat
import io.flutter.embedding.android.FlutterActivity
import com.jieli.jl_bt_ota.interfaces.IActionCallback

/**
 * Des:
 * author: lifang
 * date: 2025/07/23
 * Copyright: Jieli Technology
 * Modify date:
 * Modified by:
 */
class StoragePermissionHelper(private val context: Context) {

    var callback: IActionCallback<Boolean>? = null

    fun tryToCheckStorageEnvironment(callback: IActionCallback<Boolean>) {
        callback.onSuccess(true)
    }

    fun onRequestPermissionsResult(requestCode: Int, grantResults: IntArray) {
        if (requestCode != REQUEST_CODE_READ_EXTERNAL_STORAGE) return
        val granted = grantResults.isNotEmpty() && grantResults.all { it == PackageManager.PERMISSION_GRANTED }
        callback?.onSuccess(granted)
        callback = null
    }

    companion object {
        const val REQUEST_CODE_READ_EXTERNAL_STORAGE = 1001
    }
}