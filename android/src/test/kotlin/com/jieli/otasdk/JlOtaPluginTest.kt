package com.jieli.otasdk

import android.app.Activity
import android.app.Application
import android.os.Handler
import android.os.Looper
import android.os.Process
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import kotlin.test.Test
import kotlin.test.assertEquals
import org.mockito.ArgumentCaptor
import org.mockito.Mockito

internal class JlOtaPluginTest {
    @Test
    fun embeddedHostCannotCloseActivitiesOrScheduleProcessExit() {
        val activity = activityWith(Mockito.mock(Application::class.java))
        withHandler(activity) { handler, handlers ->
            val result = callExit(handler)

            Mockito.verify(result)
                .error(
                    "UNSUPPORTED_OPERATION",
                    "Embedded applications must handle their own exit",
                    null,
                )
            Mockito.verifyNoMoreInteractions(result)
            Mockito.verify(activity, Mockito.never()).finishAndRemoveTask()
            Mockito.verify(activity, Mockito.never()).finish()
            assertEquals(1, handlers.size)
        }
    }

    @Test
    fun hostSubclassCannotOptIntoProcessExitByInheritingMyApplication() {
        val activity = activityWith(Mockito.mock(HostApplication::class.java))
        withHandler(activity) { handler, handlers ->
            val result = callExit(handler)

            Mockito.verify(result)
                .error(
                    "UNSUPPORTED_OPERATION",
                    "Embedded applications must handle their own exit",
                    null,
                )
            Mockito.verifyNoMoreInteractions(result)
            Mockito.verify(activity, Mockito.never()).finishAndRemoveTask()
            Mockito.verify(activity, Mockito.never()).finish()
            assertEquals(1, handlers.size)
        }
    }

    @Test
    fun standaloneExitClosesActivitiesAndSchedulesProcessExit() {
        val activity = activityWith(Mockito.mock(MyApplication::class.java))
        withHandler(activity) { handler, handlers ->
            val result = callExit(handler)
            val task = ArgumentCaptor.forClass(Runnable::class.java)

            Mockito.verify(activity).finishAndRemoveTask()
            Mockito.verify(activity, Mockito.never()).finish()
            Mockito.verify(result).success(true)
            Mockito.verifyNoMoreInteractions(result)
            assertEquals(2, handlers.size)
            Mockito.verify(handlers[0], Mockito.never())
                .postDelayed(Mockito.any(Runnable::class.java), Mockito.anyLong())
            Mockito.verify(handlers[1]).postDelayed(task.capture(), Mockito.eq(500L))

            Mockito.mockStatic(Process::class.java).use { process ->
                process.`when`<Int> { Process.myPid() }.thenReturn(1234)
                task.value.run()
                process.verify { Process.killProcess(1234) }
            }
        }
    }

    @Test
    fun standaloneNonRootActivityDoesNotRemoveTheCallersTask() {
        val activity = activityWith(Mockito.mock(MyApplication::class.java), taskRoot = false)
        withHandler(activity) { handler, handlers ->
            val result = callExit(handler)

            Mockito.verify(result).success(true)
            Mockito.verifyNoMoreInteractions(result)
            Mockito.verify(activity).finish()
            Mockito.verify(activity, Mockito.never()).finishAndRemoveTask()
            assertEquals(2, handlers.size)
        }
    }

    @Test
    fun repeatedExitRequestDoesNotScheduleAnotherProcessExit() {
        val activity = activityWith(Mockito.mock(MyApplication::class.java))
        withHandler(activity) { handler, handlers ->
            val first = callExit(handler)
            Mockito.`when`(activity.isFinishing).thenReturn(true)
            val second = callExit(handler)

            Mockito.verify(first).success(true)
            Mockito.verify(second).success(true)
            Mockito.verifyNoMoreInteractions(first, second)
            Mockito.verify(activity).finishAndRemoveTask()
            assertEquals(2, handlers.size)
            Mockito.verify(handlers[1])
                .postDelayed(Mockito.any(Runnable::class.java), Mockito.eq(500L))
        }
    }

    @Test
    fun destroyedActivityCannotScheduleExit() {
        assertUnavailableActivity(destroyed = true)
    }

    @Test
    fun finishingActivityCannotScheduleExit() {
        assertUnavailableActivity(destroyed = false)
    }

    @Test
    fun failedActivityFinishCancelsProcessExitAndAllowsRetry() {
        val activity = activityWith(Mockito.mock(MyApplication::class.java))
        Mockito.doThrow(IllegalStateException("Cannot finish"))
            .doNothing()
            .`when`(activity)
            .finishAndRemoveTask()
        withHandler(activity) { handler, handlers ->
            val failed = callExit(handler)
            val task = ArgumentCaptor.forClass(Runnable::class.java)

            Mockito.verify(failed)
                .error(
                    "POP_ALL_ACTIVITY_FAILED",
                    "Failed to close application activities",
                    "Cannot finish",
                )
            Mockito.verifyNoMoreInteractions(failed)
            Mockito.verify(handlers[1]).postDelayed(task.capture(), Mockito.eq(500L))
            Mockito.verify(handlers[1]).removeCallbacks(task.value)

            val retried = callExit(handler)
            Mockito.verify(retried).success(true)
            Mockito.verifyNoMoreInteractions(retried)
            Mockito.verify(activity, Mockito.times(2)).finishAndRemoveTask()
            assertEquals(3, handlers.size)
        }
    }

    @Test
    fun rejectedExitScheduleDoesNotCloseActivitiesAndAllowsRetry() {
        val activity = activityWith(Mockito.mock(MyApplication::class.java))
        withHandler(activity, scheduleAccepted = false) { handler, handlers ->
            val failed = callExit(handler)

            Mockito.verify(failed)
                .error(
                    "POP_ALL_ACTIVITY_FAILED",
                    "Failed to schedule application exit",
                    null,
                )
            Mockito.verifyNoMoreInteractions(failed)
            Mockito.verify(activity, Mockito.never()).finishAndRemoveTask()
            Mockito.verify(activity, Mockito.never()).finish()

            val retried = callExit(handler)
            Mockito.verify(retried)
                .error(
                    "POP_ALL_ACTIVITY_FAILED",
                    "Failed to schedule application exit",
                    null,
                )
            assertEquals(3, handlers.size)
        }
    }

    private fun assertUnavailableActivity(destroyed: Boolean) {
        val activity = activityWith(Mockito.mock(MyApplication::class.java))
        Mockito.`when`(activity.isDestroyed).thenReturn(destroyed)
        Mockito.`when`(activity.isFinishing).thenReturn(!destroyed)
        withHandler(activity) { handler, handlers ->
            val result = callExit(handler)

            Mockito.verify(result)
                .error(
                    "ACTIVITY_NULL",
                    if (destroyed) "Activity is destroyed" else "Activity is finishing",
                    null,
                )
            Mockito.verifyNoMoreInteractions(result)
            Mockito.verify(activity, Mockito.never()).finishAndRemoveTask()
            Mockito.verify(activity, Mockito.never()).finish()
            assertEquals(1, handlers.size)
        }
    }

    private class HostApplication : MyApplication()

    private fun activityWith(application: Application, taskRoot: Boolean = true): Activity {
        val activity = Mockito.mock(Activity::class.java)
        Mockito.`when`(activity.application).thenReturn(application)
        Mockito.`when`(activity.isTaskRoot).thenReturn(taskRoot)
        return activity
    }

    private fun callExit(handler: MethodChannelHandler): MethodChannel.Result {
        val result = Mockito.mock(MethodChannel.Result::class.java)
        handler.onMethodCall(MethodCall("popAllActivity", null), result)
        return result
    }

    private fun withHandler(
        activity: Activity,
        scheduleAccepted: Boolean = true,
        block: (MethodChannelHandler, List<Handler>) -> Unit,
    ) {
        val looper = Mockito.mock(Looper::class.java)
        Mockito.mockStatic(Looper::class.java).use { loopers ->
            loopers.`when`<Looper> { Looper.getMainLooper() }.thenReturn(looper)
            Mockito.mockConstruction(Handler::class.java) { handler, _ ->
                    Mockito.`when`(
                            handler.postDelayed(
                                Mockito.any(Runnable::class.java),
                                Mockito.anyLong(),
                            ),
                        )
                        .thenReturn(scheduleAccepted)
                }
                .use { handlers ->
                    val handler =
                        MethodChannelHandler(activity, Mockito.mock(JlOtaPlugin::class.java), null)
                    block(handler, handlers.constructed())
                }
        }
    }
}
