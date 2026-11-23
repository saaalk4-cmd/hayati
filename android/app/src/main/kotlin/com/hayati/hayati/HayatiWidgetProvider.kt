package com.hayati.hayati

import android.appwidget.AppWidgetManager
import android.content.Context
import android.content.SharedPreferences
import android.os.SystemClock
import android.widget.RemoteViews
import es.antonborri.home_widget.HomeWidgetLaunchIntent
import es.antonborri.home_widget.HomeWidgetProvider
import java.text.SimpleDateFormat
import java.util.Date
import java.util.Locale

/**
 * ويدجت «حياتي»: الصلاة الجاية بعدّاد تنازلي + مهام وعادات النهارده.
 * التطبيق بيحفظ مواعيد صلوات النهارده وفجر بكرة، والويدجت بيختار الجاية بنفسه
 * كل ما يتحدث (كل 30 دقيقة أو لما التطبيق يحدّثه).
 */
class HayatiWidgetProvider : HomeWidgetProvider() {
    override fun onUpdate(
        context: Context,
        appWidgetManager: AppWidgetManager,
        appWidgetIds: IntArray,
        widgetData: SharedPreferences,
    ) {
        val names = (widgetData.getString("prayer_names", null) ?: "").split(",")
        val times = (widgetData.getString("prayer_times", null) ?: "")
            .split(",").mapNotNull { it.toLongOrNull() }
        val now = System.currentTimeMillis()
        val idx = times.indexOfFirst { it > now }

        for (id in appWidgetIds) {
            val views = RemoteViews(context.packageName, R.layout.hayati_widget)
            if (idx >= 0 && idx < names.size) {
                val at = times[idx]
                val fmt = SimpleDateFormat("h:mm a", Locale("ar"))
                val time = latin(fmt.format(Date(at)))
                views.setTextViewText(R.id.prayer_name, "${names[idx]} • $time")
                // عدّاد تنازلي حي لحد الصلاة
                views.setChronometer(
                    R.id.countdown,
                    SystemClock.elapsedRealtime() + (at - now),
                    null,
                    true,
                )
                views.setChronometerCountDown(R.id.countdown, true)
            } else {
                views.setTextViewText(R.id.prayer_name, "افتح التطبيق لتحديث المواقيت")
            }
            views.setTextViewText(
                R.id.tasks,
                widgetData.getString("tasks_line", null) ?: "مهام النهارده: —",
            )
            views.setTextViewText(
                R.id.habits,
                widgetData.getString("habits_line", null) ?: "",
            )
            views.setOnClickPendingIntent(
                R.id.widget_root,
                HomeWidgetLaunchIntent.getActivity(context, MainActivity::class.java),
            )
            appWidgetManager.updateAppWidget(id, views)
        }
    }

    private fun latin(s: String): String {
        val ar = "٠١٢٣٤٥٦٧٨٩"
        return s.map { c -> val i = ar.indexOf(c); if (i >= 0) ('0' + i) else c }
            .joinToString("")
    }
}
