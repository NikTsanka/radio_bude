package ge.canka.radio_bude

import android.appwidget.AppWidgetManager
import android.appwidget.AppWidgetProvider
import android.content.Context
import android.content.Intent
import android.app.PendingIntent
import android.widget.RemoteViews

class RadioWidgetProvider : AppWidgetProvider() {

    override fun onUpdate(
        context: Context,
        appWidgetManager: AppWidgetManager,
        appWidgetIds: IntArray,
    ) {
        for (id in appWidgetIds) {
            updateWidget(context, appWidgetManager, id)
        }
    }

    private fun updateWidget(
        context: Context,
        appWidgetManager: AppWidgetManager,
        appWidgetId: Int,
    ) {
        val prefs = context.getSharedPreferences("HomeWidgetPreferences", Context.MODE_PRIVATE)
        val stationName = prefs.getString("station_name", "Radio Hangi") ?: "Radio Hangi"
        val songTitle = prefs.getString("song_title", "Tap to open") ?: "Tap to open"
        val isPlaying = prefs.getBoolean("is_playing", false)

        val views = RemoteViews(context.packageName, R.layout.radio_widget)
        views.setTextViewText(R.id.widget_station_name, stationName)
        views.setTextViewText(R.id.widget_song_title, songTitle)
        views.setImageViewResource(
            R.id.widget_play_pause_icon,
            if (isPlaying) android.R.drawable.ic_media_pause
            else android.R.drawable.ic_media_play,
        )

        // Tap opens the app
        val launchIntent = context.packageManager.getLaunchIntentForPackage(context.packageName)
        val pendingIntent = PendingIntent.getActivity(
            context, 0, launchIntent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE,
        )
        views.setOnClickPendingIntent(R.id.widget_station_name, pendingIntent)
        views.setOnClickPendingIntent(R.id.widget_song_title, pendingIntent)
        views.setOnClickPendingIntent(R.id.widget_play_pause_icon, pendingIntent)

        appWidgetManager.updateAppWidget(appWidgetId, views)
    }
}
