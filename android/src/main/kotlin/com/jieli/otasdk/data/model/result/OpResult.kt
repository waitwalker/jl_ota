package com.jieli.otasdk.data.model.result

/**
 * 通用异步操作结果泛型包装类
 *
 * @param T 操作附带的数据实体类型
 * @property op 操作类型标识
 * @property code 执行状态码，0 通常表示操作成功
 * @property message 执行结果描述或错误提示信息
 * @property data 操作返回的具体数据载荷
 */
open class OpResult<T>(
    var op: Int = 0,
    var code: Int = -1,
    var message: String = "",
    var data: T? = null
) {
    /**
     * 判断操作是否成功完成
     *
     * @return true 表示状态码为 0
     */
    fun isSuccess(): Boolean = code == 0

    override fun toString(): String {
        return "OpResult(op=$op, code=$code, message='$message', data=$data)"
    }
}
