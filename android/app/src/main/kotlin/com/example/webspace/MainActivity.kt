package com.example.webspace

import android.app.ActivityManager
import android.content.Context
import android.content.pm.ActivityInfo
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, ORIENTATION_CHANNEL)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    // Flutter maps landscapeLeft+landscapeRight to USER_LANDSCAPE, which
                    // honours the system rotation lock. SENSOR_LANDSCAPE always follows the
                    // sensor, so landscape flips 180° like YouTube even when rotation is locked.
                    "setSensorLandscape" -> {
                        try {
                            requestedOrientation = ActivityInfo.SCREEN_ORIENTATION_SENSOR_LANDSCAPE
                            result.success(null)
                        } catch (e: IllegalStateException) {
                            // Some API 26 activity setups reject fixed orientations; report it
                            // to Dart (which logs it) instead of crashing the app.
                            result.error("ORIENTATION_FAILED", e.message, null)
                        }
                    }
                    else -> result.notImplemented()
                }
            }
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, DEVICE_CHANNEL)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    // Lets Dart pick a lighter visual profile on low-end devices
                    // such as ARMv7 set-top boxes.
                    "getMemoryInfo" -> {
                        val activityManager =
                            getSystemService(Context.ACTIVITY_SERVICE) as? ActivityManager
                        if (activityManager == null) {
                            result.error("UNAVAILABLE", "ActivityManager unavailable", null)
                        } else {
                            val memoryInfo = ActivityManager.MemoryInfo()
                            activityManager.getMemoryInfo(memoryInfo)
                            result.success(
                                mapOf(
                                    "isLowRamDevice" to activityManager.isLowRamDevice,
                                    "totalMemBytes" to memoryInfo.totalMem,
                                ),
                            )
                        }
                    }
                    else -> result.notImplemented()
                }
            }
    }

    private companion object {
        const val ORIENTATION_CHANNEL = "com.example.webspace/orientation"
        const val DEVICE_CHANNEL = "com.example.webspace/device"
    }
}
