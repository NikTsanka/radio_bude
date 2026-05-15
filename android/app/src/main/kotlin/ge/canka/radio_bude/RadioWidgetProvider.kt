package ge.canka.radio_bude

import android.app.PendingIntent
import android.appwidget.AppWidgetManager
import android.appwidget.AppWidgetProvider
import android.content.ComponentName
import android.content.Context
import android.content.Intent
import android.graphics.Bitmap
import android.graphics.BitmapFactory
import android.net.Uri
import android.widget.RemoteViews
import es.antonborri.home_widget.HomeWidgetBackgroundIntent
import java.net.HttpURLConnection
import java.net.URL

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
        val coverArtUrl = prefs.getString("cover_art_url", null)

        val openIntent = PendingIntent.getActivity(
            context, 0,
            context.packageManager.getLaunchIntentForPackage(context.packageName),
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE,
        )
        val playIntent = HomeWidgetBackgroundIntent.getBroadcast(
            context,
            Uri.parse("radiobude://play_pause"),
        )

        fun buildViews(art: Bitmap?): RemoteViews {
            val v = RemoteViews(context.packageName, R.layout.radio_widget)
            v.setTextViewText(R.id.widget_station_name, stationName)
            v.setTextViewText(R.id.widget_song_title, songTitle)
            v.setImageViewResource(
                R.id.widget_play_pause_icon,
                if (isPlaying) R.drawable.ic_widget_pause else R.drawable.ic_widget_play,
            )
            if (art != null) {
                v.setImageViewBitmap(R.id.widget_art, art)
            } else {
                v.setImageViewResource(R.id.widget_art, R.mipmap.launcher_icon)
            }
            v.setOnClickPendingIntent(R.id.widget_root, openIntent)
            v.setOnClickPendingIntent(R.id.widget_play_btn, playIntent)
            return v
        }

        // Render immediately with launcher icon, then update art in background
        appWidgetManager.updateAppWidget(appWidgetId, buildViews(null))

        if (coverArtUrl != null) {
            Thread {
                val bitmap = downloadBitmap(coverArtUrl)
                appWidgetManager.updateAppWidget(appWidgetId, buildViews(bitmap))
            }.start()
        }
    }

    private fun downloadBitmap(url: String): Bitmap? = try {
        val conn = URL(url).openConnection() as HttpURLConnection
        conn.connectTimeout = 5_000
        conn.readTimeout = 5_000
        conn.connect()
        BitmapFactory.decodeStream(conn.inputStream)
    } catch (_: Exception) {
        null
    }
}
