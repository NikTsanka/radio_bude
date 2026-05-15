import 'dart:convert';
import 'package:flutter/foundation.dart' show debugPrint;
import 'package:http/http.dart' as http;
import '../../core/constants.dart';
import 'station_model.dart';

/// Radio Browser API client
///
/// Documentation: https://de1.api.radio-browser.info/
/// 40,000+ რადიო სადგური მსოფლიოს ყველა კუთხიდან
class RadioBrowserService {
  /// რომელ mirror-ს ვცადეთ წინა request-ისთვის
  /// (cache მცირე ეფექტისთვის — fast retry)
  int _lastMirrorIndex = 0;

  /// HTTP client (reusable connections-ისთვის)
  final http.Client _client = http.Client();

  /// Top სადგურები (Click count-ით sorted)
  ///
  /// [limit] — რამდენი სადგური დააბრუნოს (default 50)
  /// [offset] — pagination-ისთვის (skip first N)
  Future<List<Station>> getTopStations({int limit = 50, int offset = 0}) async {
    return _request(
      '/json/stations/topclick',
      params: {
        'limit': limit.toString(),
        'offset': offset.toString(),
        'hidebroken': 'true', // გატეხილი სადგურები ფარდამიჩუმოდ გვერდი
      },
    );
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
    if (countryCode != null && countryCode.isNotEmpty) {
      params['countrycode'] = countryCode;
    }
    if (tag != null && tag.isNotEmpty) params['tag'] = tag;
    if (language != null && language.isNotEmpty) params['language'] = language;

    return _request('/json/stations/search', params: params);
  }

  /// კონკრეტული ქვეყნის სადგურები
  Future<List<Station>> getStationsByCountry(
    String countryCode, {
    int limit = 50,
  }) async {
    return searchStations(countryCode: countryCode, limit: limit);
  }

  /// ჟანრის სადგურები
  Future<List<Station>> getStationsByTag(String tag, {int limit = 50}) async {
    return searchStations(tag: tag, limit: limit);
  }

  /// ხელმისაწვდომი ქვეყნების სია (ფილტრის UI-სთვის)
  Future<List<CountryInfo>> getCountries() async {
    return _requestCountries('/json/countries');
  }

  /// ხელმისაწვდომი tag-ების სია (ფილტრის UI-სთვის)
  /// Top 30 ყველაზე პოპულარული tags
  Future<List<TagInfo>> getTopTags({int limit = 30}) async {
    return _requestTags(
      '/json/tags',
      params: {
        'order': 'stationcount',
        'reverse': 'true',
        'limit': limit.toString(),
      },
    );
  }

  /// სადგურის "click"-ის count გავუგზავნოთ Radio Browser-ს
  /// (იყენებენ statistics-ისთვის რომელი სადგურები პოპულარულია)
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

  /// Mirror fallback-ით HTTP request
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
          .where((station) => station.isPlayable) // ცარიერი URL-იანი ცარიერდება
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
          .where((t) => t.stationCount > 5) // ცარიერი tag-ები გადანდადებული
          .toList();
    });
  }

  /// Generic helper — სცადე ყველა mirror თანმიმდევრულად
  Future<T> _tryWithFallback<T>(
    Future<T> Function(String mirror) request,
  ) async {
    final mirrors = Constants.radioBrowserMirrors;
    Object? lastError;

    // ცარიერი mirror-დან ვცადოთ ჯერ
    for (int i = 0; i < mirrors.length; i++) {
      final mirrorIndex = (_lastMirrorIndex + i) % mirrors.length;
      final mirror = mirrors[mirrorIndex];

      try {
        final result = await request(mirror);
        _lastMirrorIndex = mirrorIndex; // ცარიერი mirror-ი ცარიერდება
        return result;
      } catch (e) {
        debugPrint('Mirror $mirror failed: $e');
        lastError = e;
        continue;
      }
    }

    throw Exception('All Radio Browser mirrors failed. Last error: $lastError');
  }

  /// Cleanup (აპლიკაციის გათიშვისას)
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
