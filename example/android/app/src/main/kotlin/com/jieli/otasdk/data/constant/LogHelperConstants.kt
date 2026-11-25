package com.jieli.otasdk.data.constant

import android.content.Intent

/**
 * Des：定义了与日志助手（LogHelper）相关的常量，包括日志记录、文件操作、Intent分享等常量。
 * author: lifang
 * date: 2025/07/30
 * Copyright: Jieli Technology
 * Modify date:
 * Modified by:
 */
object LogHelperConstants {
    /**
     * 用于日志记录的标签。
     */
    const val TAG = "LogHelper"

    /**
     * 当文件路径为空时的错误信息模板。
     */
    const val ERROR_FILE_PATH_NULL = "File path is null for index: %d"

    /**
     * 读取日志内容时的最大长度限制。
     */
    const val MAX_CONTENT_LENGTH = 40000

    /**
     * 读取日志文件时的间隔时间（毫秒）。
     */
    const val READ_INTERVAL_MS = 1000L

    // Intent相关常量
    /**
     * 用于分享文件的Intent动作。
     */
    const val INTENT_ACTION_SEND = Intent.ACTION_SEND

    /**
     * 表示所有文件类型的MIME类型。
     */
    const val INTENT_TYPE_ALL_FILES = "*/*"

    /**
     * 用于分享文件的Intent额外数据键。
     */
    const val INTENT_EXTRA_STREAM = Intent.EXTRA_STREAM

    /**
     * 分享文件时选择器的标题。
     */
    const val SHARE_CHOOSER_TITLE = "Share"

    // 事件类型
    /**
     * 表示日志文件列表的事件类型。
     */
    const val TYPE_LOG_FILES = "logFiles"

    /**
     * 表示日志文件详细信息的事件类型。
     */
    const val TYPE_LOG_DETAIL_FILES = "logDetailFiles"

    // 负载键
    /**
     * 用于标识事件类型的键。
     */
    const val KEY_TYPE = "type"

    /**
     * 用于标识文件列表的键。
     */
    const val KEY_FILES = "files"

    /**
     * 用于标识文件名称的键。
     */
    const val KEY_NAME = "name"

    // 文件提供者
    /**
     * 文件提供者后缀。
     */
    const val FILE_PROVIDER_SUFFIX = ".provider"

    // 错误代码和消息
    /**
     * 日志助手错误的事件代码。
     */
    const val ERROR_CODE_LOG_HELPER_ERROR = "error"

    /**
     * 日志目录未找到的错误信息。
     */
    const val ERROR_MESSAGE_LOG_DIRECTORY_NOT_FOUND = "Log directory not found"

    /**
     * 未找到日志文件的错误信息。
     */
    const val ERROR_MESSAGE_NO_LOG_FILES_FOUND = "No log files found"

    /**
     * 文件路径为空的错误信息模板。
     */
    const val ERROR_MESSAGE_FILE_PATH_NULL = "File path is null for index: %d"

    /**
     * 读取日志文件时发生错误的错误信息。
     */
    const val ERROR_MESSAGE_ERROR_READING_LOG_FILE = "Error reading log file"

    /**
     * 日志文件索引无效的错误信息模板。
     */
    const val ERROR_MESSAGE_INVALID_LOG_FILE_INDEX = "Invalid log file index: %d"

    /**
     * 分享日志文件时发生错误的错误信息。
     */
    const val ERROR_MESSAGE_ERROR_SHARING_LOG_FILE = "Error sharing log file"
}