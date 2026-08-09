package com.vocatree.vocatree

import android.appwidget.AppWidgetManager
import android.content.Context
import android.content.SharedPreferences
import android.widget.RemoteViews
import es.antonborri.home_widget.HomeWidgetProvider

/// VocaTree 홈 화면 위젯.
/// Flutter 앱이 `HomeWidget.saveWidgetData`로 저장한 스냅샷
/// (오늘 복습 대상 수 / 숙달 단어 수)을 읽어 렌더링한다.
class VocaTreeWidgetProvider : HomeWidgetProvider() {

    override fun onUpdate(
        context: Context,
        appWidgetManager: AppWidgetManager,
        appWidgetIds: IntArray,
        widgetData: SharedPreferences
    ) {
        val dueCount = widgetData.getInt("due_count", 0)
        val masteredCount = widgetData.getInt("mastered_count", 0)

        for (appWidgetId in appWidgetIds) {
            val views = RemoteViews(context.packageName, R.layout.vocatree_widget).apply {
                setTextViewText(R.id.widget_due_count, dueCount.toString())
                setTextViewText(R.id.widget_mastered_count, masteredCount.toString())
            }
            appWidgetManager.updateAppWidget(appWidgetId, views)
        }
    }
}
