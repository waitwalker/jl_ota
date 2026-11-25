package com.jieli.otasdk

import android.content.Context
import com.jieli.jl_bt_ota.util.JL_Log

/**
 * 杰理 OTA 全局进程级运行时环境对象
 *
 * 维护全局唯一的 Application 上下文 [Context]，供 SDK 内部各工具类与模型安全使用。
 * 在宿主引擎加载或 Application 启动时进行初始化，并提供 SDK 全局日志开关控制。
 */
object OtaRuntime {
    /** 全局持有的 ApplicationContext，保证多线程可见性 */
    @Volatile
    private var appContext: Context? = null

    /**
     * 获取全局 Application 上下文
     *
     * @return 应用程序上下文 [Context]
     * @throws IllegalStateException 若尚未调用 [init] 初始化则抛出异常
     */
    fun getContext(): Context {
        return appContext ?: throw IllegalStateException(
            "OtaRuntime not initialized. Call OtaRuntime.init(context) first.",
        )
    }

    /**
     * 初始化全局运行时环境
     *
     * 采用双重检查锁定机制，确保全局仅绑定一次 ApplicationContext，重复调用为无操作。
     *
     * @param context 上下文对象（内部会自动获取其 applicationContext）
     */
    fun init(context: Context) {
        if (appContext != null) return
        synchronized(this) {
            if (appContext != null) return
            appContext = context.applicationContext
        }
    }

    /**
     * 配置杰理底层 SDK 日志开关
     *
     * SDK 默认关闭日志输出以优化性能。在需要调试或排查问题时可开启控制台日志及本地日志文件持久化。
     *
     * @param context 上下文对象
     * @param enabled 是否开启日志输出及文件保存，默认为 false
     */
    fun setLogEnabled(context: Context, enabled: Boolean = false) {
        JL_Log.setLog(enabled)
        JL_Log.setIsSaveLogFile(context.applicationContext, enabled)
    }
}
