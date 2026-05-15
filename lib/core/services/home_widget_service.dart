import 'package:home_widget/home_widget.dart';

class HomeWidgetService {
  static const String _androidName = 'RadioWidgetProvider';

  static Future<void> update({
    required String stationName,
    required String songTitle,
    required bool isPlaying,
    String? coverArtUrl,
  }) async {
    try {
      await Future.wait([
        HomeWidget.saveWidgetData<String>('station_name', stationName),
        HomeWidget.saveWidgetData<String>('song_title', songTitle),
        HomeWidget.saveWidgetData<bool>('is_playing', isPlaying),
        // null removes the key so the widget falls back to launcher icon
        HomeWidget.saveWidgetData<String?>('cover_art_url', coverArtUrl),
      ]);
      await HomeWidget.updateWidget(androidName: _androidName);
    } catch (_) {}
  }
}
