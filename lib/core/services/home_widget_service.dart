import 'package:home_widget/home_widget.dart';

class HomeWidgetService {
  static const String _androidName = 'RadioWidgetProvider';

  static Future<void> update({
    required String stationName,
    required String songTitle,
    required bool isPlaying,
  }) async {
    try {
      await Future.wait([
        HomeWidget.saveWidgetData<String>('station_name', stationName),
        HomeWidget.saveWidgetData<String>('song_title', songTitle),
        HomeWidget.saveWidgetData<bool>('is_playing', isPlaying),
      ]);
      await HomeWidget.updateWidget(androidName: _androidName);
    } catch (_) {}
  }
}
