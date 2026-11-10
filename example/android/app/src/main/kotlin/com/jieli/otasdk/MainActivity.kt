package com.jieli.otasdk

import android.content.Intent
import android.content.pm.PackageManager
import android.database.Cursor
import android.net.Uri
import android.provider.OpenableColumns
import androidx.core.content.ContextCompat
import com.jieli.otasdk.home.MainViewModel
import com.jieli.otasdk.model.connect.ConnectViewModel
import com.jieli.otasdk.tool.config.ConfigHelper
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine

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

        private const val INTENT_ACTION_GET_CONTENT = Intent.ACTION_GET_CONTENT
        private const val MIME_TYPE_OCTET_STREAM = "application/*"

        private var selectedUri: Uri? = null

        fun getSelectedUri(): Uri? = selectedUri

        private fun setSelectedUri(uri: Uri?) {
            selectedUri = uri
        }

        fun clearSelectedUri() {
            selectedUri = null
        }
    }

    private var isSkipDestroyViewModel: Boolean = false
    private var exampleChannel: ExampleChannelHandler? = null

    private var permissionCallback: ((Boolean) -> Unit)? = null
    private var pendingPermissions: Array<String>? = null

    /**
     * Request missing permissions
     */
    fun requestMissingPermissions(permissions: Array<String>, callback: (Boolean) -> Unit) {
        // Check if all permissions are already granted
        if (hasAllPermissions(permissions)) {
            callback(true)
            return
        }

        permissionCallback = callback
        pendingPermissions = permissions
        requestPermissions(permissions, PERMISSION_REQUEST_CODE)
    }

    /**
     * Check if all requested permissions are already granted
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

        if (requestCode == PERMISSION_REQUEST_CODE) {
            val allGranted = grantResults.isNotEmpty() &&
                    grantResults.all { it == PackageManager.PERMISSION_GRANTED }
            permissionCallback?.invoke(allGranted)
            permissionCallback = null
            pendingPermissions = null
        }
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        exampleChannel = ExampleChannelHandler(this, flutterEngine.dartExecutor.binaryMessenger)
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
        exampleChannel?.dispose()
        exampleChannel = null
        super.onDestroy()
        cleanupViewModel()
        clearSelectedUri()
    }

    // region Public Methods
    fun pickFile() {
        Intent(INTENT_ACTION_GET_CONTENT).apply {
            type = MIME_TYPE_OCTET_STREAM
            addCategory(Intent.CATEGORY_OPENABLE) // Ensure only openable files are returned
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
            ConnectViewModel.destroyInstance()
            ConfigHelper.destroyInstance()
            LogHelper.destroyInstance()
        } else {
            isSkipDestroyViewModel = false
        }
    }

    private fun handleFilePickResult(resultCode: Int, data: Intent?) {
        if (resultCode != RESULT_OK || data?.data == null) return

        data.data?.let { uri ->
            setSelectedUri(uri)
            val fileName = displayName(uri)
            notifyFilePicked(fileName)
        }
    }

    /**
     * Same lookup as jlFileTransfer FileUtils.getFileName. The example module
     * does not compile against that AAR.
     */
    private fun displayName(uri: Uri): String? {
        var name: String? = null
        if ("content" == uri.scheme) {
            val cursor: Cursor? = contentResolver.query(uri, null, null, null, null)
            cursor.use {
                if (it != null && it.moveToFirst()) {
                    name = it.getString(it.getColumnIndex(OpenableColumns.DISPLAY_NAME))
                }
            }
        }
        if (name == null) {
            val path = uri.path
            if (path != null) {
                val separator = path.lastIndexOf('/')
                name = if (separator == -1) path else path.substring(separator + 1)
            }
        }
        return name
    }

    private fun notifyFilePicked(fileName: String?) {
        exampleChannel?.notifyFilePicked(fileName)
    }
}
