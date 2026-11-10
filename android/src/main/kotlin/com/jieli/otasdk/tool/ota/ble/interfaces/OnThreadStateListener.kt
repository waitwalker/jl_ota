package com.jieli.otasdk.tool.ota.ble.interfaces

/**
 * 线程生命周期监听回调接口
 *
 * 监听工作线程（如发送/接收线程）的启动与退出事件。
 */
interface OnThreadStateListener {
    /**
     * 线程启动运行回调
     *
     * @param id 线程 ID
     * @param name 线程名称
     */
    fun onStart(id: Long, name: String?)

    /**
     * 线程执行结束退出回调
     *
     * @param id 线程 ID
     * @param name 线程名称
     */
    fun onEnd(id: Long, name: String?)
}
