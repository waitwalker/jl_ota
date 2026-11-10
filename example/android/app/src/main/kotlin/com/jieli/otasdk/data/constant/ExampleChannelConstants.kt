package com.jieli.otasdk.data.constant

/**
 * Method and event names for the example channel.
 * The host OTA channel does not use these.
 */
object ExampleChannelConstants {
    const val METHOD_GET_APP_VERSION = "getAppVersion"
    const val METHOD_GET_LOG_FILES = "getLogFiles"
    const val METHOD_LOG_FILE_INDEX = "logFileIndex"
    const val METHOD_SHARE_LOG_FILE = "shareLogFile"
    const val METHOD_DOWNLOAD_FILE = "downloadFile"
    const val METHOD_READ_FILE_LIST = "readFileList"
    const val METHOD_DELETE_OTA_FILE_INDEX = "deleteOtaFileIndex"
    const val METHOD_TRY_TO_CHECK_STORAGE_ENVIRONMENT = "tryToCheckStorageEnvironment"
    const val METHOD_PICK_FILE = "pickFile"
    const val METHOD_DELETE_ALL_LOG_FILE = "deleteAllLogFile"
    const val METHOD_GET_WIFI_IP_ADDRESS = "getWifiIpAddress"
    const val METHOD_GET_LOG_FILE_DIR_PATH = "getLogFileDirPath"
    const val METHOD_POP_ALL_ACTIVITY = "popAllActivity"
    const val METHOD_ON_FILE_PICKED = "onFilePicked"
    const val METHOD_HANDLE_FILE_PICKED = "handleFilePicked"
    const val METHOD_SEND_CUSTOM_COMMAND = "sendCustomCommand"

    const val ARG_LOG_FILE_INDEX = "logFileIndex"
    const val ARG_HTTP_URL = "httpUrl"
    const val ARG_POS = "pos"
    const val ARG_FILE_NAME = "fileName"
    const val ARG_CUSTOM_DATA = "customData"

    const val TYPE_DOWNLOAD_STATUS = "downloadStatus"
    const val TYPE_OTA_FILE_LIST = "otaFileList"
    const val TYPE_CUSTOM_DATA_UPDATE = "customDataUpdate"

    const val STATUS_ON_PROGRESS = "onProgress"
    const val STATUS_ON_STOP = "onStop"
    const val STATUS_ON_ERROR = "onError"
    const val STATUS_ON_START = "onStart"
    const val STATUS_UNKNOWN = "unknown"

    const val KEY_CUSTOM_DATA = "customData"
}
