package io.github.sadiqueiqbal0786.flutter_app_version_upgrader

import android.app.Activity
import android.content.ActivityNotFoundException
import android.content.Context
import android.content.Intent
import android.content.SharedPreferences
import android.content.pm.PackageManager
import android.net.Uri
import android.os.Build
import io.flutter.embedding.engine.plugins.FlutterPlugin
import io.flutter.embedding.engine.plugins.activity.ActivityAware
import io.flutter.embedding.engine.plugins.activity.ActivityPluginBinding
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import io.flutter.plugin.common.MethodChannel.MethodCallHandler
import io.flutter.plugin.common.MethodChannel.Result

/**
 * Native half of `flutter_app_version_upgrader`.
 *
 * Exposes only what Dart cannot do on its own:
 *  - `getAppInfo`   : package name, versionName and versionCode
 *  - `readCache` / `writeCache` / `clearCache` : SharedPreferences-backed cache
 *  - `openStore`    : opens a URL, or the Play Store listing of this app
 */
class FlutterAppVersionUpgraderPlugin :
    FlutterPlugin,
    ActivityAware,
    MethodCallHandler {

    companion object {
        const val CHANNEL_NAME = "flutter_app_version_upgrader"
        const val PREFS_NAME = "flutter_app_version_upgrader"
    }

    private lateinit var channel: MethodChannel
    private var context: Context? = null
    private var activity: Activity? = null

    override fun onAttachedToEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        context = binding.applicationContext
        channel = MethodChannel(binding.binaryMessenger, CHANNEL_NAME)
        channel.setMethodCallHandler(this)
    }

    override fun onDetachedFromEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        channel.setMethodCallHandler(null)
        context = null
    }

    override fun onAttachedToActivity(binding: ActivityPluginBinding) {
        activity = binding.activity
    }

    override fun onDetachedFromActivityForConfigChanges() {
        activity = null
    }

    override fun onReattachedToActivityForConfigChanges(binding: ActivityPluginBinding) {
        activity = binding.activity
    }

    override fun onDetachedFromActivity() {
        activity = null
    }

    override fun onMethodCall(call: MethodCall, result: Result) {
        val ctx = context
        if (ctx == null) {
            result.error("no_context", "Plugin is not attached to an engine.", null)
            return
        }
        try {
            when (call.method) {
                "getAppInfo" -> result.success(getAppInfo(ctx))
                "readCache" -> {
                    val key = requireKey(call)
                    result.success(prefs(ctx).getString(key, null))
                }
                "writeCache" -> {
                    val key = requireKey(call)
                    val value = call.argument<String>("value")
                        ?: throw IllegalArgumentException("Missing 'value'")
                    prefs(ctx).edit().putString(key, value).apply()
                    result.success(null)
                }
                "clearCache" -> {
                    val key = requireKey(call)
                    prefs(ctx).edit().remove(key).apply()
                    result.success(null)
                }
                "openStore" -> {
                    val url = call.argument<String>("url")
                    val packageName = call.argument<String>("packageName") ?: ctx.packageName
                    result.success(openStore(ctx, url, packageName))
                }
                else -> result.notImplemented()
            }
        } catch (e: IllegalArgumentException) {
            result.error("invalid_argument", e.message, null)
        } catch (e: Exception) {
            result.error("native_error", e.message, e.javaClass.name)
        }
    }

    private fun requireKey(call: MethodCall): String =
        call.argument<String>("key") ?: throw IllegalArgumentException("Missing 'key'")

    private fun prefs(ctx: Context): SharedPreferences =
        ctx.getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)

    internal fun getAppInfo(ctx: Context): Map<String, Any?> {
        val pm = ctx.packageManager
        val packageName = ctx.packageName
        val info = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
            pm.getPackageInfo(packageName, PackageManager.PackageInfoFlags.of(0))
        } else {
            @Suppress("DEPRECATION")
            pm.getPackageInfo(packageName, 0)
        }
        val versionCode: Long = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.P) {
            info.longVersionCode
        } else {
            @Suppress("DEPRECATION")
            info.versionCode.toLong()
        }
        return mapOf(
            "packageName" to packageName,
            "versionName" to (info.versionName ?: ""),
            "buildNumber" to versionCode,
            "platform" to "android",
        )
    }

    /**
     * Opens [url] when provided. Otherwise tries the `market://` deep link
     * and falls back to the Play Store web URL when no store app handles it.
     */
    private fun openStore(ctx: Context, url: String?, packageName: String): Boolean {
        val candidates = if (url != null) {
            listOf(url)
        } else {
            listOf(
                "market://details?id=$packageName",
                "https://play.google.com/store/apps/details?id=$packageName",
            )
        }
        for (candidate in candidates) {
            if (launch(ctx, candidate)) return true
        }
        return false
    }

    private fun launch(ctx: Context, url: String): Boolean {
        val intent = Intent(Intent.ACTION_VIEW, Uri.parse(url))
        val launcher: Context = activity ?: ctx.also {
            intent.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
        }
        return try {
            launcher.startActivity(intent)
            true
        } catch (e: ActivityNotFoundException) {
            false
        } catch (e: Exception) {
            // e.g. SecurityException from a restricted profile: try the next
            // candidate rather than failing the whole call.
            false
        }
    }
}
