import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../world_radio/station_model.dart';

/// ფავორიტი სადგურების მართვა (SharedPreferences-ით)
///
/// Singleton — app-ში ერთი instance
class FavoritesService extends ChangeNotifier {
  static const String _storageKey = 'favorite_stations_v1';

  static final FavoritesService _instance = FavoritesService._internal();
  factory FavoritesService() => _instance;
  FavoritesService._internal();

  List<Station> _favorites = [];
  bool _isLoaded = false;

  /// ცარიერი ფავორიტების სია (read-only)
  List<Station> get favorites => List.unmodifiable(_favorites);

  /// რამდენი ფავორიტი გვაქვს
  int get count => _favorites.length;

  /// ცარიერდება თუ არა service ჩატვირთული
  bool get isLoaded => _isLoaded;

  /// საწყისი ჩატვირთვა — main()-ში გამოვიძახებთ
  Future<void> load() async {
    if (_isLoaded) return;

    try {
      final prefs = await SharedPreferences.getInstance();
      final jsonString = prefs.getString(_storageKey);

      if (jsonString != null && jsonString.isNotEmpty) {
        final List<dynamic> jsonList = jsonDecode(jsonString);
        _favorites = jsonList
            .map((json) => Station.fromJson(json as Map<String, dynamic>))
            .toList();
      }

      _isLoaded = true;
      debugPrint('Loaded ${_favorites.length} favorites');
      notifyListeners();
    } catch (e) {
      debugPrint('Favorites load error: $e');
      _favorites = [];
      _isLoaded = true;
      notifyListeners();
    }
  }

  /// Persistent storage-ში შენახვა
  Future<void> _save() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final jsonList = _favorites.map((s) => s.toJson()).toList();
      await prefs.setString(_storageKey, jsonEncode(jsonList));
    } catch (e) {
      debugPrint('Favorites save error: $e');
    }
  }

  /// ცარიერდება სადგური ფავორიტებშია
  bool isFavorite(String stationUuid) {
    return _favorites.any((s) => s.stationUuid == stationUuid);
  }

  /// დამატება / წაშლა toggle
  ///
  /// Returns: new state (true = ფავორიტში დაემატა, false = ცარიერდება)
  Future<bool> toggleFavorite(Station station) async {
    final exists = isFavorite(station.stationUuid);

    if (exists) {
      _favorites.removeWhere((s) => s.stationUuid == station.stationUuid);
    } else {
      // ცარიერდება ცარიერი ცარიერდება ცარიერდება (most recent first)
      _favorites.insert(0, station);
    }

    await _save();
    notifyListeners();
    return !exists;
  }

  /// წაშლა
  Future<void> remove(String stationUuid) async {
    _favorites.removeWhere((s) => s.stationUuid == stationUuid);
    await _save();
    notifyListeners();
  }

  /// მთლიანი სიის გასუფთავება
  Future<void> clearAll() async {
    _favorites.clear();
    await _save();
    notifyListeners();
  }

  Future<void> reorder(int oldIndex, int newIndex) async {
    if (oldIndex < newIndex) {
      newIndex -= 1;
    }
    final station = _favorites.removeAt(oldIndex);
    _favorites.insert(newIndex, station);
    await _save();
    notifyListeners();
  }

  Future<void> sortByName() async {
    _favorites.sort((a, b) => a.name.compareTo(b.name));
    await _save();
    notifyListeners();
  }

  Future<void> sortByRecent(List<String> recentUrls) async {
    _favorites.sort((a, b) {
      final ai = recentUrls.indexOf(a.url);
      final bi = recentUrls.indexOf(b.url);
      if (ai == -1 && bi == -1) return 0;
      if (ai == -1) return 1;
      if (bi == -1) return -1;
      return ai.compareTo(bi);
    });
    await _save();
    notifyListeners();
  }
}
