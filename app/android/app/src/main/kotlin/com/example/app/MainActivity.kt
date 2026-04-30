package com.example.app

import android.appwidget.AppWidgetManager
import android.content.Intent
import android.os.Bundle
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity: FlutterActivity() {
    private val channel = "widget_config"
    private var widgetId = AppWidgetManager.INVALID_APPWIDGET_ID

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        
        widgetId = intent.getIntExtra(
            AppWidgetManager.EXTRA_APPWIDGET_ID,
            AppWidgetManager.INVALID_APPWIDGET_ID
        )
        
        if (widgetId != AppWidgetManager.INVALID_APPWIDGET_ID) {
            val resultValue = Intent().putExtra(AppWidgetManager.EXTRA_APPWIDGET_ID, widgetId)
            setResult(RESULT_CANCELED, resultValue)
        }
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, channel).setMethodCallHandler { call, result ->
            when (call.method) {
                "getWidgetId" -> {
                    result.success(widgetId)
                }
                "finishWidgetConfig" -> {
                    if (widgetId != AppWidgetManager.INVALID_APPWIDGET_ID) {
                        val resultValue = Intent().putExtra(AppWidgetManager.EXTRA_APPWIDGET_ID, widgetId)
                        setResult(RESULT_OK, resultValue)
                        finish()
                    }
                    result.success(null)
                }
                else -> result.notImplemented()
            }
        }
    }
}