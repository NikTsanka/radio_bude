import 'dart:convert';
import 'package:flutter/foundation.dart' show debugPrint;
import 'package:http/http.dart' as http;
import '../../core/constants.dart';
import 'station_model.dart';

class _CacheEntry<T> {
  final T data;
  final DateTime _fetchedAt;

  _CacheEntry(this.data) : _fetchedAt = DateTime.now();

  bool isValid(Duration ttl) => DateTime.now().difference(_fetchedAt) < ttl;
}

/// Radio Browser API client
///
/// Documentation: https://de1.api.radio-browser.info/
/// 40,000+ რადიო სადგური მსოფლიოს ყველა კუთხიდან
class RadioBrowserService {
  int _lastMirrorIndex = 0;
  final http.Client _client = http.Client();

  _CacheEntry<List<Station>>? _topStationsCache;
  _CacheEntry<List<TagInfo>>? _tagsCache;
  _CacheEntry<List<CountryInfo>>? _countriesCache;

  static const _topStationsTtl = Duration(minutes: 5);
  static const _tagsTtl = Duration(minutes: 30);
  static const _countriesTtl = Duration(minutes: 30);

  Future<List<Station>> getTopStations({int limit = 50, int offset = 0}) async {
    if (offset == 0 &&
        _topStationsCache != null &&
        _topStationsCache!.isValid(_topStationsTtl)) {
      return _topStationsCache!.data;
    }
    final result = await _request(
      '/json/stations/topclick',
      params: {
        'limit': limit.toString(),
        'offset': offset.toString(),
        'hidebroken': 'true',
      },
    );
    if (offset == 0) _topStationsCache = _CacheEntry(result);
    return result;
  }

  /// ძებნა სახელით / tag-ით / ქვეყნით
  ///
  /// ერთი ან რამდენიმე ფილტრი ერთად
  Future<List<Station>> searchStations({
    String? name,
    String? country,
    String? countryCode,
    String? tag,
    String? language,
    int limit = 50,
    int offset = 0,
  }) async {
    final params = <String, String>{
      'limit': limit.toString(),
      'offset': offset.toString(),
      'hidebroken': 'true',
      'order': 'clickcount', // ფარდამიჩუმოდ პოპულარობით ცარიერდება
      'reverse': 'true',
    };

    if (name != null && name.isNotEmpty) params['name'] = name;
    if (country != null && country.isNotEmpty) params['country'] = country;
    if (countryCode != null && countryCode.isNotEmpty) params['countrycode'] = countryCode;
    if (tag != null && tag.isNotEmpty) params['tag'] = tag;
    if (language != null && language.isNotEmpty) params['language'] = language;

    return _request('/json/stations/search', params: params);
  }

  Future<List<Station>> getStationsByCountry(
    String countryCode, {
    int limit = 50,
  }) async {
    return searchStations(countryCode: countryCode, limit: limit);
  }

  Future<List<Station>> getStationsByTag(String tag, {int limit = 50}) async {
    return searchStations(tag: tag, limit: limit);
  }

  Future<List<CountryInfo>> getCountries() async {
    if (_countriesCache != null && _countriesCache!.isValid(_countriesTtl)) {
      return _countriesCache!.data;
    }
    final result = await _requestCountries('/json/countries');
    _countriesCache = _CacheEntry(result);
    return result;
  }

  Future<List<TagInfo>> getTopTags({int limit = 30}) async {
    if (_tagsCache != null && _tagsCache!.isValid(_tagsTtl)) {
      return _tagsCache!.data;
    }
    final result = await _requestTags(
      '/json/tags',
      params: {
        'order': 'stationcount',
        'reverse': 'true',
        'limit': limit.toString(),
      },
    );
    _tagsCache = _CacheEntry(result);
    return result;
  }

  Future<bool> voteForStation(String stationUuid) async {
    if (stationUuid.isEmpty) return false;
    try {
      return await _tryWithFallback((mirror) async {
        final url = Uri.parse('$mirror/json/vote/$stationUuid');
        final response = await _client
            .get(url, headers: _headers)
            .timeout(const Duration(seconds: 5));
        if (response.statusCode != 200) return false;
        final json = jsonDecode(response.body) as Map<String, dynamic>;
        return json['ok'] == true;
      });
    } catch (e) {
      debugPrint('Vote failed: $e');
      return false;
    }
  }

  Future<void> registerClick(String stationUuid) async {
    if (stationUuid.isEmpty) return;

    try {
      // Fire-and-forget — შედეგი არ გვაინტერესებს
      _tryWithFallback((mirror) async {
        final url = Uri.parse('$mirror/json/url/$stationUuid');
        await _client
            .get(url, headers: _headers)
            .timeout(const Duration(seconds: 3));
      });
    } catch (e) {
      // ignore — არ არის კრიტიკული
    }
  }

  // ========== INTERNAL ==========

  Map<String, String> get _headers => {
    'User-Agent': Constants.userAgent,
    'Content-Type': 'application/json',
  };

  Future<List<Station>> _request(
    String path, {
    Map<String, String>? params,
  }) async {
    return _tryWithFallback((mirror) async {
      final uri = Uri.parse('$mirror$path').replace(queryParameters: params);

      final response = await _client
          .get(uri, headers: _headers)
          .timeout(const Duration(seconds: 10));

      if (response.statusCode != 200) {
        throw Exception('HTTP ${response.statusCode}');
      }

      final List<dynamic> jsonList = jsonDecode(response.body);
      return jsonList
          .map((json) => Station.fromJson(json as Map<String, dynamic>))
          .where((station) => station.isPlayable)
          .toList();
    });
  }

  Future<List<CountryInfo>> _requestCountries(String path) async {
    return _tryWithFallback((mirror) async {
      final uri = Uri.parse('$mirror$path');
      final response = await _client
          .get(uri, headers: _headers)
          .timeout(const Duration(seconds: 10));

      if (response.statusCode != 200) {
        throw Exception('HTTP ${response.statusCode}');
      }

      final List<dynamic> jsonList = jsonDecode(response.body);
      return jsonList
          .map((json) => CountryInfo.fromJson(json as Map<String, dynamic>))
          .where((c) => c.stationCount > 0)
          .toList()
        ..sort((a, b) => b.stationCount.compareTo(a.stationCount));
    });
  }

  Future<List<TagInfo>> _requestTags(
    String path, {
    Map<String, String>? params,
  }) async {
    return _tryWithFallback((mirror) async {
      final uri = Uri.parse('$mirror$path').replace(queryParameters: params);
      final response = await _client
          .get(uri, headers: _headers)
          .timeout(const Duration(seconds: 10));

      if (response.statusCode != 200) {
        throw Exception('HTTP ${response.statusCode}');
      }

      final List<dynamic> jsonList = jsonDecode(response.body);
      return jsonList
          .map((json) => TagInfo.fromJson(json as Map<String, dynamic>))
          .where((t) => t.stationCount > 5)
          .toList();
    });
  }

  Future<T> _tryWithFallback<T>(
    Future<T> Function(String mirror) request,
  ) async {
    final mirrors = Constants.radioBrowserMirrors;
    Object? lastError;

    for (int i = 0; i < mirrors.length; i++) {
      final mirrorIndex = (_lastMirrorIndex + i) % mirrors.length;
      final mirror = mirrors[mirrorIndex];

      try {
        final result = await request(mirror);
        _lastMirrorIndex = mirrorIndex;
        return result;
      } catch (e) {
        debugPrint('Mirror $mirror failed: $e');
        lastError = e;
        continue;
      }
    }

    throw Exception('All Radio Browser mirrors failed. Last error: $lastError');
  }

  void dispose() {
    _client.close();
  }
}

// ========== Helper Models ==========

/// ქვეყნის ინფო (ფილტრის UI-სთვის)
class CountryInfo {
  final String name;
  final String code;
  final int stationCount;

  CountryInfo({
    required this.name,
    required this.code,
    required this.stationCount,
  });

  factory CountryInfo.fromJson(Map<String, dynamic> json) {
    return CountryInfo(
      name: (json['name'] as String? ?? '').trim(),
      code: (json['iso_3166_1'] as String? ?? '').trim(),
      stationCount: (json['stationcount'] as num?)?.toInt() ?? 0,
    );
  }
}

/// Tag/Genre-ის ინფო
class TagInfo {
  final String name;
  final int stationCount;

  TagInfo({required this.name, required this.stationCount});

  factory TagInfo.fromJson(Map<String, dynamic> json) {
    return TagInfo(
      name: (json['name'] as String? ?? '').trim(),
      stationCount: (json['stationcount'] as num?)?.toInt() ?? 0,
    );
  }
}
