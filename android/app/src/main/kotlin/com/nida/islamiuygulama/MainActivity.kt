package com.nida.islamiuygulama

import android.content.Intent
import android.os.Build
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import org.json.JSONObject

class MainActivity : FlutterActivity() {

    private val channelName = "com.nida.islamiuygulama/persistent_notification"

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, channelName).setMethodCallHandler { call, result ->
            when (call.method) {
                "start" -> {
                    @Suppress("UNCHECKED_CAST")
                    val data = call.arguments as? Map<String, Any?>
                    if (data != null) {
                        val json = JSONObject().apply {
                            data["location"]?.let { put("location", it.toString()) }
                            data["fajr"]?.let { put("fajr", it.toString()) }
                            data["dhuhr"]?.let { put("dhuhr", it.toString()) }
                            data["asr"]?.let { put("asr", it.toString()) }
                            data["maghrib"]?.let { put("maghrib", it.toString()) }
                            data["isha"]?.let { put("isha", it.toString()) }
                            data["appTitle"]?.let { put("appTitle", it.toString()) }
                        }.toString()
                        val intent = Intent(this, PrayerTimesForegroundService::class.java).apply {
                            putExtra(PrayerTimesForegroundService.EXTRA_DATA, json)
                        }
                        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                            startForegroundService(intent)
                        } else {
                            startService(intent)
                        }
                        result.success(true)
                    } else {
                        result.success(false)
                    }
                }
                "stop" -> {
                    val intent = Intent(this, PrayerTimesForegroundService::class.java).apply {
                        action = PrayerTimesForegroundService.ACTION_STOP
                    }
                    startService(intent)
                    result.success(true)
                }
                else -> result.notImplemented()
            }
        }
    }
}
