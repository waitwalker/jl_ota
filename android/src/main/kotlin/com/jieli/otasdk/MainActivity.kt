package com.jieli.otasdk

import android.content.Intent
import android.net.Uri
import android.Manifest
import android.os.Build
import android.content.pm.PackageManager
import androidx.core.content.ContextCompat
import com.jieli.otasdk.data.constant.MethodChannelConstants
import com.jieli.otasdk.home.MainViewModel
import com.jieli.otasdk.util.StoragePermissionHelper
import com.jieli.jlFileTransfer.FileUtils
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

/**
 * 应用主Activity，负责Flutter引擎配置和系统交互
 * - 管理ViewModel生命周期
 * - 处理文件选择请求
 * - 初始化原生插件
 *
 * @author lifang
 * @date 2025/07/18
 * @copyright Jieli Technology
 */
class MainActivity : FlutterActivity() {

    companion object {
        private const val PICK_FILE_REQUEST_CODE = 1001
        private const val PERMISSION_REQUEST_CODE = 1002
        private const val METHOD_CHANNEL = "com.jieli.ble_plugin/methods"

        private const val INTENT_ACTION_GET_CONTENT = Intent.ACTION_GET_CONTENT
        private const val MIME_TYPE_OCTET_STREAM = "application/*"

        var selectedUri: Uri? = null
            private set // 限制外部修改
    }

    private var isSkipDestroyViewModel: Boolean = false
    val storagePermissionHelper by lazy { StoragePermissionHelper(this) }

    private var permissionCallback: ((Boolean) -> Unit)? = null
    private var pendingPermissions: Array<String>? = null

    /**
     * 请求缺失的权限
     */
    fun requestMissingPermissions(permissions: Array<String>, callback: (Boolean) -> Unit) {
        // 检查是否已经拥有所有权限
        if (hasAllPermissions(permissions)) {
            callback(true)
            return
        }

        permissionCallback = callback
        pendingPermissions = permissions
        requestPermissions(permissions, PERMISSION_REQUEST_CODE)
    }

    /**
     * 检查是否已经拥有所有请求的权限
     */
    private fun hasAllPermissions(permissions: Array<String>): Boolean {
        return permissions.all { permission ->
            ContextCompat.checkSelfPermission(this, permission) == PackageManager.PERMISSION_GRANTED
        }
    }

    override fun onRequestPermissionsResult(
        requestCode: Int,
        permissions: Array<out String>,
        grantResults: IntArray
    ) {
        super.onRequestPermissionsResult(requestCode, permissions, grantResults)

        when (requestCode) {
            PERMISSION_REQUEST_CODE -> {
                val allGranted = grantResults.isNotEmpty() &&
                        grantResults.all { it == PackageManager.PERMISSION_GRANTED }
                permissionCallback?.invoke(allGranted)
                permissionCallback = null
                pendingPermissions = null
            }
            else -> {
                storagePermissionHelper.onRequestPermissionsResult(requestCode, grantResults)
            }
        }
    }

    // 延迟初始化的MethodChannel
    private val methodChannel: MethodChannel? by lazy {
        flutterEngine?.dartExecutor?.binaryMessenger?.let {
            MethodChannel(it, METHOD_CHANNEL)
        }
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MainViewModel.getInstance()
    }

    override fun onResume() {
        super.onResume()
        startViewModelServices()
    }

    override fun onActivityResult(requestCode: Int, resultCode: Int, data: Intent?) {
        super.onActivityResult(requestCode, resultCode, data)

        when (requestCode) {
            PICK_FILE_REQUEST_CODE -> handleFilePickResult(resultCode, data)
        }
    }

    override fun onPause() {
        super.onPause()
        stopViewModelServices()
    }

    override fun onDestroy() {
        super.onDestroy()
        cleanupViewModel()
    }

    // region Public Methods
    fun pickFile() {
        Intent(INTENT_ACTION_GET_CONTENT).apply {
            type = MIME_TYPE_OCTET_STREAM
            addCategory(Intent.CATEGORY_OPENABLE) // 确保只返回可以打开的文件
        }.also { intent ->
            startActivityForResult(intent, PICK_FILE_REQUEST_CODE)
        }
    }

    private fun startViewModelServices() {
        MainViewModel.startWebService(this)
    }

    private fun stopViewModelServices() {
        MainViewModel.stopWebService(this)
    }

    private fun cleanupViewModel() {
        if (!isSkipDestroyViewModel) {
            MainViewModel.destroyInstance()
        } else {
            isSkipDestroyViewModel = false
        }
    }

    private fun handleFilePickResult(resultCode: Int, data: Intent?) {
        if (resultCode != RESULT_OK || data?.data == null) return

        data.data?.let { uri ->
            selectedUri = uri
            val fileName = FileUtils.getFileName(context, uri)
            notifyFilePicked(fileName)
        }
    }

    private fun notifyFilePicked(fileName: String) {
        methodChannel?.invokeMethod(
            MethodChannelConstants.METHOD_ON_FILE_PICKED,
            mapOf(MethodChannelConstants.ARG_FILE_NAME to fileName)
        )
    }
}
