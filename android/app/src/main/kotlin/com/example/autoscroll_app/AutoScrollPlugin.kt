package com.example.autoscroll_app

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.content.IntentFilter
import io.flutter.embedding.engine.plugins.FlutterPlugin
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel

class AutoScrollPlugin : FlutterPlugin, MethodChannel.MethodCallHandler {
    private var channel: MethodChannel? = null
    private lateinit var context: Context

    companion object {
        const val ACTION_APP_CHANGED = "com.example.autoscroll.APP_CHANGED"
        const val EXTRA_IS_TARGET_APP = "is_target_app"
    }

    private val appChangeReceiver = object : BroadcastReceiver() {
        override fun onReceive(context: Context?, intent: Intent?) {
            if (intent?.action == ACTION_APP_CHANGED) {
                val isTarget = intent.getBooleanExtra(EXTRA_IS_TARGET_APP, false)
                channel?.invokeMethod("onAppChanged", isTarget)
            }
        }
    }

    override fun onAttachedToEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        context = binding.applicationContext
        channel = MethodChannel(binding.binaryMessenger, "com.example.autoscroll/scroll")
        channel?.setMethodCallHandler(this)

        val filter = IntentFilter(ACTION_APP_CHANGED)
        if (android.os.Build.VERSION.SDK_INT >= android.os.Build.VERSION_CODES.TIRAMISU) {
            context.registerReceiver(appChangeReceiver, filter, Context.RECEIVER_NOT_EXPORTED)
        } else {
            context.registerReceiver(appChangeReceiver, filter)
        }
    }

    override fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
        when (call.method) {
            "scroll" -> {
                val intent = Intent(AutoScrollService.ACTION_SCROLL)
                intent.setPackage(context.packageName)
                context.sendBroadcast(intent)
                result.success(true)
            }
            "isServiceEnabled" -> {
                result.success(AutoScrollService.instance != null)
            }
            "openAccessibilitySettings" -> {
                val intent = Intent(android.provider.Settings.ACTION_ACCESSIBILITY_SETTINGS)
                intent.flags = Intent.FLAG_ACTIVITY_NEW_TASK
                context.startActivity(intent)
                result.success(true)
            }
            else -> {
                result.notImplemented()
            }
        }
    }

    override fun onDetachedFromEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        context.unregisterReceiver(appChangeReceiver)
        channel?.setMethodCallHandler(null)
        channel = null
    }
}
