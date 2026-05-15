import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'station_model.dart';

class RecentlyPlayedService extends ChangeNotifier {
  static const String _key = 'recently_played_v1';
  static const int _max = 10;

  static final RecentlyPlayedService _instance = RecentlyPlayedService._();
  factory RecentlyPlayedService() => _instance;
  RecentlyPlayedService._();

  List<Station> _recent = [];
  List<Station> get recent => List.unmodifiable(_recent);

  Future<void> load() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final s = prefs.getString(_key);
      if (s != null && s.isNotEmpty) {
        final list = jsonDecode(s) as List;
        _recent =
            list
                .map((j) => Station.fromJson(j as Map<String, dynamic>))
                .toList();
      }
      notifyListeners();
    } catch (_) {
      _recent = [];
    }
  }

  Future<void> add(Station station) async {
    _recent.removeWhere((s) => s.stationUuid == station.stationUuid);
    _recent.insert(0, station);
    if (_recent.length > _max) _recent = _recent.sublist(0, _max);
    notifyListeners();
    await _save();
  }

  Future<void> _save() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(
        _key,
        jsonEncode(_recent.map((s) => s.toJson()).toList()),
      );
    } catch (_) {}
  }
}
