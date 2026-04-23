package com.jieli.otasdk.util

import android.content.Context
import android.net.Uri
import com.jieli.otasdk.MyApplication
import com.jieli.jlFileTransfer.FileUtils
import com.jieli.jl_bt_ota.constant.ErrorCode
import com.jieli.jl_bt_ota.interfaces.IActionCallback
import com.jieli.jl_bt_ota.model.OTAError
import java.io.File
import java.io.FileNotFoundException
import java.io.IOException
import java.util.Locale

/**
 * Des:
 * author: lifang
 * date: 2025/07/24
 * Copyright: Jieli Technology
 * Modify date:
 * Modified by:
 */
class FileTransferUtil {
    companion object {
        // File related constants
        private const val DEFAULT_UPGRADE_FILE_NAME = "upgrade.ufw"
        private const val UFW_FILE_EXTENSION = ".ufw"
        private const val UFW_FILE_EXTENSION_UPPERCASE = ".UFW"
        private const val DUPLICATE_FILE_PATTERN = "(%d)$UFW_FILE_EXTENSION"

        // Error messages
        private const val ERR_PARAMETER = "Invalid file extension"
        private const val ERR_SAME_FILE = "Same file already exists"
        private const val ERR_FILE_NOT_FOUND = "File not found"
        private const val ERR_IO_EXCEPTION = "IO exception occurred"

        /**
         * 获取新升级文件名
         */
        fun getNewUpgradeFileName(oldFileName: String, parent: File): String {
            var result = DEFAULT_UPGRADE_FILE_NAME
            if (oldFileName.uppercase(Locale.ROOT).endsWith(UFW_FILE_EXTENSION_UPPERCASE)) {
                result = oldFileName
            }

            var tempResult = result
            var resultFile = File(parent, tempResult)
            var i = 0

            while (resultFile.exists()) {
                i++
                tempResult = result.removeSuffix(UFW_FILE_EXTENSION) +
                        DUPLICATE_FILE_PATTERN.format(i)
                resultFile = File(parent, tempResult)
            }
            return tempResult
        }

        /**
         * 处理文件系统选择的文件
         *
         * @param context Context 上下文
         * @param uri Uri 文件链接
         */
        fun handleSelectFile(
            context: Context,
            uri: Uri,
            newFileName:String,
            callback: IActionCallback<Boolean>? = null
        ) {
            try {
                context.contentResolver?.let { contentResolver ->
                    val parentFilePath = MyApplication.getInstance().otaFileDir
                    var fileName = FileUtils.getFileName(context, uri)
                    if (!fileName.equals(newFileName)){
                        fileName = newFileName
                    }
                    fileName = getNewUpgradeFileName(fileName, File(parentFilePath))

                    if (!fileName.endsWith(UFW_FILE_EXTENSION, true)) {
                        callback?.onError(OTAError.buildError(ErrorCode.SUB_ERR_PARAMETER, ERR_PARAMETER))
                        return
                    }

                    val resultPath = parentFilePath + File.separator + fileName
                    if (File(resultPath).exists()) {
                        callback?.onError(OTAError.buildError(ErrorCode.SUB_ERR_UPGRADE_SAME_FILE, ERR_SAME_FILE))
                        return
                    }

                    try {
                        FileUtils.copyFile(
                            contentResolver.openInputStream(uri),
                            resultPath
                        )
                        callback?.onSuccess(true)
                    } catch (_: FileNotFoundException) {
                        callback?.onError(OTAError.buildError(ErrorCode.SUB_ERR_FILE_NOT_FOUND, ERR_FILE_NOT_FOUND))
                    }
                }
            } catch (_: IOException) {
                callback?.onError(OTAError.buildError(ErrorCode.SUB_ERR_IO_EXCEPTION, ERR_IO_EXCEPTION))
            }
        }
    }
}