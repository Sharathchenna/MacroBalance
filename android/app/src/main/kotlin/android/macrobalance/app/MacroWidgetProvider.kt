package android.macrobalance.app

import android.app.PendingIntent
import android.appwidget.AppWidgetManager
import android.content.Context
import android.content.Intent
import android.content.SharedPreferences
import android.os.Build
import android.os.Bundle
import android.util.SizeF
import android.widget.RemoteViews
import es.antonborri.home_widget.HomeWidgetProvider
import org.json.JSONArray
import org.json.JSONObject
import java.text.NumberFormat
import java.util.Calendar
import kotlin.math.roundToInt

/**
 * The Android home-screen widget. Reads what WidgetService saves for the iOS
 * widget (macro_data, daily_meals JSON) and shows today's calories and macros;
 * tall enough, it also lists recent meals. Data from an earlier day reads as
 * nothing eaten yet. Tapping opens the app.
 */
class MacroWidgetProvider : HomeWidgetProvider() {

    override fun onUpdate(
        context: Context,
        appWidgetManager: AppWidgetManager,
        appWidgetIds: IntArray,
        widgetData: SharedPreferences,
    ) {
        appWidgetIds.forEach { id -> appWidgetManager.updateAppWidget(id, views(context, widgetData)) }
    }

    override fun onAppWidgetOptionsChanged(
        context: Context,
        appWidgetManager: AppWidgetManager,
        appWidgetId: Int,
        newOptions: Bundle,
    ) {
        super.onAppWidgetOptionsChanged(context, appWidgetManager, appWidgetId, newOptions)
        // Below Android 12 the layout is picked by size here, not by the system.
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.S) {
            val data = context.getSharedPreferences("HomeWidgetPreferences", Context.MODE_PRIVATE)
            val tall = newOptions.getInt(AppWidgetManager.OPTION_APPWIDGET_MIN_HEIGHT) >= LARGE_MIN_HEIGHT_DP
            appWidgetManager.updateAppWidget(appWidgetId, layout(context, data, large = tall))
        }
    }

    private fun views(context: Context, data: SharedPreferences): RemoteViews =
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
            RemoteViews(
                mapOf(
                    SizeF(110f, 110f) to layout(context, data, large = false),
                    SizeF(180f, LARGE_MIN_HEIGHT_DP.toFloat()) to layout(context, data, large = true),
                )
            )
        } else {
            layout(context, data, large = false)
        }

    private fun layout(context: Context, data: SharedPreferences, large: Boolean): RemoteViews {
        val views = RemoteViews(
            context.packageName,
            if (large) R.layout.macro_widget_large else R.layout.macro_widget_small,
        )
        val macros = data.getString("macro_data", null)?.let { runCatching { JSONObject(it) }.getOrNull() }
        val today = macros != null && isToday(macros.optLong("timestamp"))
        fun eaten(key: String) = if (today) macros!!.optDouble(key, 0.0) else 0.0
        fun goal(key: String) = macros?.optDouble(key, 0.0) ?: 0.0

        val number = NumberFormat.getIntegerInstance()
        views.setTextViewText(R.id.calories, number.format(eaten("calories").roundToInt()))
        views.setTextViewText(
            R.id.calories_goal,
            if (goal("caloriesGoal") > 0) "/ ${number.format(goal("caloriesGoal").roundToInt())} cal" else "cal",
        )
        views.setProgressBar(R.id.calories_bar, 100, percent(eaten("calories"), goal("caloriesGoal")), false)
        listOf(
            Triple("protein", R.id.protein_bar, R.id.protein_value),
            Triple("carbs", R.id.carbs_bar, R.id.carbs_value),
            Triple("fat", R.id.fat_bar, R.id.fat_value),
        ).forEach { (key, bar, value) ->
            val g = goal("${key}Goal")
            views.setProgressBar(bar, 100, percent(eaten(key), g), false)
            views.setTextViewText(
                value,
                if (g > 0) "${eaten(key).roundToInt()}/${g.roundToInt()}g" else "${eaten(key).roundToInt()}g",
            )
        }

        if (large) views.setTextViewText(R.id.meals, recentMeals(data, number))

        val open = Intent(context, MainActivity::class.java).apply {
            flags = Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TOP
        }
        views.setOnClickPendingIntent(
            R.id.widget_root,
            PendingIntent.getActivity(context, 0, open, PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE),
        )
        return views
    }

    private fun recentMeals(data: SharedPreferences, number: NumberFormat): String {
        val meals = data.getString("daily_meals", null)?.let { runCatching { JSONArray(it) }.getOrNull() }
            ?: return "Nothing logged yet today"
        val lines = (0 until meals.length())
            .mapNotNull { meals.optJSONObject(it) }
            .filter { isToday(it.optLong("timestamp")) }
            .take(4)
            .map { "${it.optString("name")} · ${number.format(it.optDouble("calories", 0.0).roundToInt())} cal" }
        return lines.joinToString("\n").ifEmpty { "Nothing logged yet today" }
    }

    private fun percent(value: Double, goal: Double) =
        if (goal <= 0) 0 else (value / goal * 100).roundToInt().coerceIn(0, 100)

    private fun isToday(millis: Long): Boolean {
        if (millis <= 0) return false
        val then = Calendar.getInstance().apply { timeInMillis = millis }
        val now = Calendar.getInstance()
        return then.get(Calendar.YEAR) == now.get(Calendar.YEAR) &&
            then.get(Calendar.DAY_OF_YEAR) == now.get(Calendar.DAY_OF_YEAR)
    }

    private companion object {
        /** From this height the widget has room for recent meals. */
        const val LARGE_MIN_HEIGHT_DP = 250
    }
}
