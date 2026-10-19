package com.example.aliskanlik_takipcisi

import android.appwidget.AppWidgetManager
import android.content.Context
import android.content.SharedPreferences
import android.widget.RemoteViews
import es.antonborri.home_widget.HomeWidgetProvider

class HabitWidgetProvider : HomeWidgetProvider() {
    override fun onUpdate(
        context: Context,
        appWidgetManager: AppWidgetManager,
        appWidgetIds: IntArray,
        widgetData: SharedPreferences,
    ) {
        val done = widgetData.getInt("done_count", 0)
        val total = widgetData.getInt("total_count", 0)
        val streak = widgetData.getInt("best_streak", 0)
        val nextIcon = widgetData.getString("next_icon", "🌱") ?: "🌱"
        val nextHabit = widgetData.getString("next_habit", "") ?: ""

        for (id in appWidgetIds) {
            val views = RemoteViews(context.packageName, R.layout.habit_widget).apply {
                setTextViewText(R.id.widget_progress, "$done / $total")
                setTextViewText(R.id.widget_streak, "🔥 Seri: $streak")
                setTextViewText(
                    R.id.widget_next,
                    if (nextHabit.isEmpty()) "Tümü tamam ✓" else "Sırada: $nextIcon $nextHabit",
                )
            }
            appWidgetManager.updateAppWidget(id, views)
        }
    }
}
