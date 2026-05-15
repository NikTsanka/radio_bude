import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

class SearchHistoryService extends ChangeNotifier {
  static const String _key = 'search_history_v1';
  static const int _max = 5;

  static final SearchHistoryService _instance = SearchHistoryService._();
  factory SearchHistoryService() => _instance;
  SearchHistoryService._();

  List<String> _history = [];
  List<String> get history => List.unmodifiable(_history);

  Future<void> load() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      _history = prefs.getStringList(_key) ?? [];
      notifyListeners();
    } catch (_) {}
  }

  Future<void> add(String query) async {
    final q = query.trim();
    if (q.isEmpty) return;
    _history.remove(q);
    _history.insert(0, q);
    if (_history.length > _max) _history = _history.sublist(0, _max);
    notifyListeners();
    await _save();
  }

  Future<void> remove(String query) async {
    _history.remove(query);
    notifyListeners();
    await _save();
  }

  Future<void> _save() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setStringList(_key, _history);
    } catch (_) {}
  }
}
