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
        this.callback = callback
        checkExternalStorageEnvironment()
    }

    private fun checkExternalStorageEnvironment() {
        when (context) {
//            is AppCompatActivity -> registerLauncher(context)
//            is FragmentActivity -> registerLauncher(context)
            is FlutterActivity -> requestPermissionsForFlutterActivity(context)
            else -> {
                callback?.onSuccess(false)
                callback = null
            }
        }
    }

//    private fun registerLauncher(activity: FragmentActivity) {
//        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.TIRAMISU &&
//            !PermissionUtil.hasReadStoragePermission(activity)) {
//
//            val launcher = activity.registerForActivityResult(
//                ActivityResultContracts.RequestMultiplePermissions()
//            ) { permissions ->
//                val granted = permissions.all { it.value == true }
//                callback?.onSuccess(granted)
//                callback = null
//            }
//
//            launcher.launch(
//                arrayOf(
//                    Manifest.permission.READ_EXTERNAL_STORAGE
//                )
//            )
//        } else {
//            callback?.onSuccess(true)
//            callback = null
//        }
//    }

    private fun requestPermissionsForFlutterActivity(activity: FlutterActivity) {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.TIRAMISU &&
            !PermissionUtil.hasReadStoragePermission(activity)) {

            ActivityCompat.requestPermissions(
                activity,
                arrayOf(Manifest.permission.READ_EXTERNAL_STORAGE),
                REQUEST_CODE_READ_EXTERNAL_STORAGE
            )
        } else {
            callback?.onSuccess(true)
            callback = null
        }
    }

    fun onRequestPermissionsResult(requestCode: Int, grantResults: IntArray) {
        if (requestCode == REQUEST_CODE_READ_EXTERNAL_STORAGE) {
            val granted = grantResults.isNotEmpty() &&
                    grantResults[0] == PackageManager.PERMISSION_GRANTED
            callback?.onSuccess(granted)
            callback = null
        }
    }

    companion object {
        const val REQUEST_CODE_READ_EXTERNAL_STORAGE = 1001
    }
}