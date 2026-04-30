package com.example.app // TU PAQUETE

import android.appwidget.AppWidgetManager
import android.content.Context
import android.content.SharedPreferences
import android.net.Uri
import android.widget.RemoteViews
import es.antonborri.home_widget.HomeWidgetBackgroundIntent
import es.antonborri.home_widget.HomeWidgetProvider

class QuickActionsWidgetProvider : HomeWidgetProvider() {
    override fun onUpdate(
        context: Context,
        appWidgetManager: AppWidgetManager,
        appWidgetIds: IntArray,
        widgetData: SharedPreferences
    ) {
        for (appWidgetId in appWidgetIds) {
            val views = RemoteViews(context.packageName, R.layout.quick_actions_widget)
            
            // Leemos el título y la URI completa guardada desde Flutter
            val title = widgetData.getString("widget_${appWidgetId}_title", "Acción")
            val uriStr = widgetData.getString("widget_${appWidgetId}_uri", "babycare://action?category=nap")

            views.setTextViewText(R.id.btn_action, title)

            val uri = Uri.parse(uriStr)
            val intent = HomeWidgetBackgroundIntent.getBroadcast(context, uri)
            views.setOnClickPendingIntent(R.id.btn_action, intent)

            appWidgetManager.updateAppWidget(appWidgetId, views)
        }
    }
}