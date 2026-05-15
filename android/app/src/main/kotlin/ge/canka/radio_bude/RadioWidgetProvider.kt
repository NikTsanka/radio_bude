package ge.canka.radio_bude

import android.app.PendingIntent
import android.appwidget.AppWidgetManager
import android.appwidget.AppWidgetProvider
import android.content.ComponentName
import android.content.Context
import android.content.Intent
import android.view.KeyEvent
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

    override fun onReceive(context: Context, intent: Intent) {
        super.onReceive(context, intent)
        // Restore widget data after device reboot or app update
        if (intent.action == Intent.ACTION_BOOT_COMPLETED ||
            intent.action == Intent.ACTION_MY_PACKAGE_REPLACED
        ) {
            val manager = AppWidgetManager.getInstance(context)
            val ids = manager.getAppWidgetIds(
                ComponentName(context, RadioWidgetProvider::class.java),
            )
            onUpdate(context, manager, ids)
        }
    }

    private fun updateWidget(
        context: Context,
        appWidgetManager: AppWidgetManager,
        appWidgetId: Int,
    ) {
        val prefs = context.getSharedPreferences("HomeWidgetPreferences", Context.MODE_PRIVATE)
        val stationName = prefs.getString("station_name", "Radio Hangi") ?: "Radio Hangi"
        val songTitle   = prefs.getString("song_title", "Tap to open") ?: "Tap to open"
        val isPlaying   = prefs.getBoolean("is_playing", false)

        val views = RemoteViews(context.packageName, R.layout.radio_widget)
        views.setTextViewText(R.id.widget_station_name, stationName)
        views.setTextViewText(R.id.widget_song_title, songTitle)
        views.setImageViewResource(
            R.id.widget_play_pause_icon,
            if (isPlaying) R.drawable.ic_widget_pause else R.drawable.ic_widget_play,
        )

        // Tapping the widget body opens the app
        val openAppIntent = PendingIntent.getActivity(
            context, 0,
            context.packageManager.getLaunchIntentForPackage(context.packageName),
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE,
        )
        views.setOnClickPendingIntent(R.id.widget_root, openAppIntent)

        // Tapping the play/pause button sends a media key event to audio_service
        val keyEvent = KeyEvent(KeyEvent.ACTION_DOWN, KeyEvent.KEYCODE_MEDIA_PLAY_PAUSE)
        val mediaIntent = Intent(Intent.ACTION_MEDIA_BUTTON).apply {
            component = ComponentName(
                context,
                com.ryanheise.audioservice.MediaButtonReceiver::class.java,
            )
            putExtra(Intent.EXTRA_KEY_EVENT, keyEvent)
        }
        val playPauseIntent = PendingIntent.getBroadcast(
            context, 1, mediaIntent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE,
        )
        views.setOnClickPendingIntent(R.id.widget_play_btn, playPauseIntent)

        appWidgetManager.updateAppWidget(appWidgetId, views)
    }
}
