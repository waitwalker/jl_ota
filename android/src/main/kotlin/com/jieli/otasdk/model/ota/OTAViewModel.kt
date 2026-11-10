package com.jieli.otasdk.model.ota

import android.bluetooth.BluetoothDevice
import android.content.Context
import android.os.Handler
import android.os.Looper
import android.util.Log
import androidx.lifecycle.MutableLiveData
import com.jieli.otasdk.R
import com.jieli.jl_bt_ota.constant.ErrorCode
import com.jieli.jl_bt_ota.constant.StateCode
import com.jieli.jl_bt_ota.interfaces.BtEventCallback
import com.jieli.jl_bt_ota.interfaces.IUpgradeCallback
import com.jieli.jl_bt_ota.model.base.BaseError
import com.jieli.jl_bt_ota.model.response.TargetInfoResponse
import com.jieli.jl_bt_ota.util.BluetoothUtil
import com.jieli.jl_bt_ota.util.CHexConver
import com.jieli.jl_bt_ota.util.JL_Log
import com.jieli.otasdk.data.model.device.DeviceConnection
import com.jieli.otasdk.data.model.ota.OTAEnd
import com.jieli.otasdk.data.model.ota.OTAReconnect
import com.jieli.otasdk.data.model.ota.OTAStart
import com.jieli.otasdk.data.model.ota.OTAState
import com.jieli.otasdk.data.model.ota.OTAWorking
import com.jieli.otasdk.model.connect.base.BluetoothViewModel
import com.jieli.otasdk.tool.ota.OTAManager

/**
 * OTA 固件升级业务模型类
 *
 * 继承自 [BluetoothViewModel]，封装杰理底层 [OTAManager] 升级管理器的全部核心逻辑。
 * 负责 OTA 回调分发、升级流程启动与取消、升级中间重连处理，以及升级进度与状态 LiveData 的通知分发。
 */
class OTAViewModel : BluetoothViewModel() {
    companion object {
        /** 执行成功错误码 */
        private const val ERR_SUCCESS = 0
        /** 执行失败错误码 */
        private const val ERR_FAILED = 1
        /** 无效参数错误码 */
        private const val ERR_INVALID_PARAM = 2
        /** 任务已在进行中错误码 */
        private const val ERR_TASK_IN_PROGRESS = 3
        /** 用户取消错误码 */
        private const val ERR_USE_CANCEL = 4

        /** 设备未连接提示文本 */
        private const val DEVICE_DISCONNECTED = "Device is disconnected"
        /** OTA 正在进行中提示文本 */
        private const val OTA_IS_RUNNING = "Ota is running."

        @Volatile
        private var instance: OTAViewModel? = null

        /**
         * 获取 [OTAViewModel] 线程安全单例
         *
         * @return [OTAViewModel] 实例
         */
        fun getInstance(): OTAViewModel {
            return instance ?: synchronized(this) {
                instance ?: OTAViewModel().also { instance = it }
            }
        }

        /**
         * 销毁单例并释放相关资源
         */
        fun destroy() {
            instance?.let {
                it.destroy()
            }
            instance = null
        }
    }

    /** 杰理底层 OTA 升级核心管理器 */
    val otaManager = OTAManager(getContext())

    /** OTA 期间设备连接状态通知流 */
    val otaConnectionMLD = MutableLiveData<DeviceConnection>()

    /** 设备强制升级事件通知流 */
    val mandatoryUpgradeMLD = MutableLiveData<BluetoothDevice>()

    /** OTA 升级全生命周期状态流（包含开始、进度、重连、完成、错误等状态） */
    val otaStateMLD = MutableLiveData<OTAState>()

    /**
     * 底层蓝牙事件回调监听器，用于监控 OTA 过程中的连接断开与强制升级触发
     */
    private val bluetoothCallback = object : BtEventCallback() {
        override fun onConnection(device: BluetoothDevice?, status: Int) {
            JL_Log.i(tag, "onConnection", "device : $device, status : $status")
            if (status == StateCode.CONNECTION_FAILED || status == StateCode.CONNECTION_DISCONNECT) {
                getConnectedDevice()?.let { connectedDevice ->
                    bluetoothHelper.disconnectDevice(connectedDevice)
                }
            }
            otaConnectionMLD.value = DeviceConnection(device, status)
        }

        override fun onMandatoryUpgrade(device: BluetoothDevice?) {
            mandatoryUpgradeMLD.postValue(device!!)
        }
    }

    init {
        otaManager.registerBluetoothCallback(bluetoothCallback)
    }

    /**
     * ViewModel 销毁回调，自动执行资源清理
     */
    override fun onCleared() {
        super.onCleared()
        destroy()
    }

    /**
     * 释放与清理 OTA 相关资源
     *
     * 取消进行中的升级任务，注销蓝牙回调，并释放 [OTAManager] 实例
     */
    override fun destroy() {
        super.destroy()
        cancelOTA()
        otaManager.unregisterBluetoothCallback(bluetoothCallback)
        otaManager.release()
    }

    /**
     * 查询是否使用自定义回连方式
     *
     * @return true 表示使用自定义回连，false 表示使用 SDK 默认回连
     */
    fun isUseReconnectWay(): Boolean = configHelper.isUseCustomReConnectWay()

    /**
     * 查询是否开启 OTA 自动测试模式
     *
     * @return true 表示启用自动压测
     */
    fun isAutoTestOTA(): Boolean = configHelper.isAutoTest()

    /**
     * 查询当前是否处于 OTA 升级过程中
     *
     * @return true 表示正在升级
     */
    fun isOTA(): Boolean = otaManager.isOTA

    /**
     * 查询连接设备时是否开启设备认证流程
     *
     * @return true 表示开启认证
     */
    fun isUseAuthDevice(): Boolean = configHelper.isUseDeviceAuth()

    /**
     * 校验指定设备是否处于已连接状态
     *
     * 优先判断基础蓝牙连接状态，若不一致则进一步核对是否为 OTA 目标设备
     *
     * @param device 待检测的目标蓝牙设备
     * @return true 表示已连接
     */
    override fun isDeviceConnected(device: BluetoothDevice?): Boolean {
        return super.isDeviceConnected(device) || BluetoothUtil.deviceEquals(
            device,
            otaManager.targetDevice
        )
    }

    /**
     * 获取当前连接设备的目标信息（包含固件版本号、协议版本、电量等）
     *
     * @return 目标设备信息实体，未获取到或未连接则返回 null
     */
    fun getDeviceInfo(): TargetInfoResponse? = otaManager.getDeviceInfo(getConnectedDevice())

    /**
     * 开始 OTA 固件升级
     *
     * @param filePath 固件文件的本地绝对路径
     */
    fun startOTA(filePath: String) {
        JL_Log.i(tag, "startOTA , file path = $filePath")
        val device = getConnectedDevice()
        if (device == null) {
            JL_Log.w(tag, "startOTA : no connected device.")
            otaStateMLD.value =
                OTAEnd(getConnectedDevice(), ERR_FAILED, DEVICE_DISCONNECTED)
            return
        }
        if (otaManager.isOTA) {
            otaStateMLD.value = OTAEnd(device, ERR_TASK_IN_PROGRESS, OTA_IS_RUNNING)
            return
        }
        otaManager.bluetoothOption.firmwareFilePath = filePath
        otaManager.startOTA(
            CustomUpdateCallback(
                getContext(), device, otaManager, this
            )
        )
    }

    /**
     * 取消当前正在执行的 OTA 升级
     */
    private fun cancelOTA() {
        if (isOTA()) {
            otaManager.cancelOTA()
        }
    }

    /**
     * 处理 OTA 升级过程中的设备变地址重连
     *
     * 杰理芯片升级阶段可能会进入 Loader/UBOOT 模式，广播地址会发生偏移（如 MAC 末位加 1）。
     * 此方法计算新地址并通知底层发起精准重连。
     *
     * @param devAddr 原始设备蓝牙 MAC 地址
     * @param isUseNewAdv 是否采用新版广播过滤策略进行回连
     */
    fun reconnectDev(devAddr: String?, isUseNewAdv: Boolean) {
        // 第一步：计算目标新地址（例如 MAC 末尾字节自增 1）
        JL_Log.i(tag, "change addr before : $devAddr")
        val data = BluetoothUtil.addressCovertToByteArray(devAddr)
        val value = CHexConver.byteToInt(data[data.size - 1]) + 1
        data[data.size - 1] = CHexConver.intToByte(value)
        val newAddr = BluetoothUtil.hexDataCovetToAddress(data)
        JL_Log.i(tag, "change addr after: $newAddr")

        // 第二步：配置底层回连的目标新地址
        otaManager.setReconnectAddr(newAddr)

        // 第三步：由蓝牙连接助手发起主动回连
        bluetoothHelper.reconnectDevice(devAddr, isUseNewAdv)
    }

    /**
     * 固件升级过程回调处理器
     *
     * 实现 [IUpgradeCallback] 接口，处理升级过程中的状态迁移、进度更新、重连通知、成功及失败结果。
     *
     * @property context 上下文对象
     * @property device 升级的目标设备
     * @property otaManager OTA 管理器引用
     * @property viewModel 宿主 [OTAViewModel] 实例
     */
    private class CustomUpdateCallback(
        val context: Context,
        val device: BluetoothDevice?,
        val otaManager: OTAManager,
        val viewModel: OTAViewModel
    ) : IUpgradeCallback {

        /**
         * 升级正式启动回调
         */
        override fun onStartOTA() {
            viewModel.otaStateMLD.value = OTAStart(device)
        }

        /**
         * 升级过程中芯片重启并需要重连回调
         *
         * @param addr 待重连的目标地址
         * @param isNewReconnectWay 是否采用新版广播重连策略
         */
        override fun onNeedReconnect(addr: String?, isNewReconnectWay: Boolean) {
            // 如果开启自动回连设备，且回连设备需要开启设备认证流程，进行动态配置同步
            otaManager.bluetoothOption.apply {
                if (isAutoConnectBle) {
                    if (!isUseAuthDevice && viewModel.isUseAuthDevice()) {
                        isUseAuthDevice = true
                    }
                }
            }

            viewModel.otaStateMLD.value = OTAReconnect(device, addr, isNewReconnectWay)
            if (viewModel.isUseReconnectWay()) {
                viewModel.reconnectDev(addr, isNewReconnectWay)
            }
        }

        /**
         * 升级传输进度更新回调
         *
         * @param type 传输数据阶段类型
         * @param progress 当前升级进度百分比 (0.0 ~ 100.0)
         */
        override fun onProgress(type: Int, progress: Float) {
            viewModel.otaStateMLD.value = OTAWorking(device, type, progress)
        }

        /**
         * 升级成功完成回调
         */
        override fun onStopOTA() {
            viewModel.otaStateMLD.value =
                OTAEnd(device, ErrorCode.ERR_NONE, context.getString(R.string.ota_complete))
            val handler = Handler(Looper.getMainLooper())
            handler.postDelayed({
                // 设备在升级完成后自动重启变回普通地址，延时安全断开残留连接
                if (viewModel.bluetoothHelper.isConnected()) {
                    Log.d("ZHM", "onStopOTA: disconnectDevice")
                    viewModel.bluetoothHelper.disconnectDevice(viewModel.otaManager.connectedDevice)
                }
            }, 500)
        }

        /**
         * 升级被用户或系统取消回调
         */
        override fun onCancelOTA() {
            viewModel.otaStateMLD.value =
                OTAEnd(
                    device,
                    ErrorCode.ERR_UNKNOWN,
                    context.getString(R.string.ota_upgrade_cancel)
                )
        }

        /**
         * 升级发生异常错误回调
         *
         * @param error 错误详情包装对象 [BaseError]
         */
        override fun onError(error: BaseError?) {
            error?.let {
                viewModel.otaStateMLD.value = OTAEnd(device, it.subCode, it.message)
            }
            viewModel.bluetoothHelper.disconnectDevice(viewModel.otaManager.connectedDevice) // 升级失败断开连接，便于后续重试
        }
    }
}