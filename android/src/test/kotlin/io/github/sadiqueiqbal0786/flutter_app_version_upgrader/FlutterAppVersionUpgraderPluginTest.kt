package io.github.sadiqueiqbal0786.flutter_app_version_upgrader

import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import org.mockito.Mockito
import kotlin.test.Test

/*
 * Unit tests for the Kotlin portion of the plugin. Run them with
 * `./gradlew testDebugUnitTest` from `example/android/` after building the
 * example app once.
 */
internal class FlutterAppVersionUpgraderPluginTest {
    @Test
    fun onMethodCall_withoutContext_reportsError() {
        val plugin = FlutterAppVersionUpgraderPlugin()
        val call = MethodCall("getAppInfo", null)
        val mockResult: MethodChannel.Result = Mockito.mock(MethodChannel.Result::class.java)

        plugin.onMethodCall(call, mockResult)

        Mockito.verify(mockResult).error(
            Mockito.eq("no_context"),
            Mockito.anyString(),
            Mockito.isNull(),
        )
    }
}
