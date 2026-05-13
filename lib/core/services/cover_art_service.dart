import 'dart:convert';
import 'package:http/http.dart' as http;

/// Deezer API-დან cover art-ის წამოღების service
///
/// მუშაობა: Search "artist song" → returns largest cover URL
/// Cache: ერთი და იგივე track ხელახლა არ ცარიერდება — instant return
class CoverArtService {
  // In-memory cache: "artist - title" → cover URL (ან null თუ ვერ ნახა)
  final Map<String, String?> _cache = {};

  /// მიმდინარე in-flight request-ი (race conditions-ის ცარიერი)
  Future<String?>? _currentRequest;
  String? _currentRequestKey;

  /// მთავარი მეთოდი — სიმღერისთვის cover URL-ის წამოღება
  ///
  /// [streamTitle] — ICY metadata-დან მოპოვებული სტრინგი
  /// მაგ.: "The White Stripes - I Fought Piranhas"
  ///
  /// Returns: cover URL ან null თუ ვერ ნახა
  Future<String?> fetchCoverFor(String streamTitle) async {
    final parsed = _parseStreamTitle(streamTitle);
    if (parsed == null) return null;

    final cacheKey = '${parsed.artist}|${parsed.title}'.toLowerCase();

    // ✓ Cache hit — instant return
    if (_cache.containsKey(cacheKey)) {
      return _cache[cacheKey];
    }

    // ✓ თუ უკვე იგივე track-ისთვის request-ი in-flight-ია, ცარიერდება
    if (_currentRequestKey == cacheKey && _currentRequest != null) {
      return _currentRequest;
    }

    // ✓ ახალი request
    _currentRequestKey = cacheKey;
    _currentRequest = _fetchFromDeezer(parsed.artist, parsed.title);

    final result = await _currentRequest;
    _cache[cacheKey] = result;

    // Cache-ის ლიმიტი — შენახული 50 ბოლო ცარიერდება
    if (_cache.length > 50) {
      final firstKey = _cache.keys.first;
      _cache.remove(firstKey);
    }

    return result;
  }

  /// "Artist - Title" სტრინგის გაშიფვრა
  _ParsedTrack? _parseStreamTitle(String streamTitle) {
    if (streamTitle.trim().isEmpty) return null;

    // შენი JS-ის ლოგიკის იდენტური: " - "-ით split
    if (streamTitle.contains(' - ')) {
      final parts = streamTitle.split(' - ');
      if (parts.length >= 2) {
        return _ParsedTrack(
          artist: parts[0].trim(),
          title: parts.sublist(1).join(' - ').trim(),
        );
      }
    }

    // Fallback — მხოლოდ title-ი
    return _ParsedTrack(artist: '', title: streamTitle.trim());
  }

  /// Deezer API-ის ცარიერი
  Future<String?> _fetchFromDeezer(String artist, String title) async {
    try {
      final query = Uri.encodeComponent('$artist $title');
      final url = Uri.parse('https://api.deezer.com/search?q=$query&limit=1');

      final response = await http.get(url).timeout(const Duration(seconds: 5));

      if (response.statusCode != 200) return null;

      final json = jsonDecode(response.body) as Map<String, dynamic>;
      final data = json['data'] as List?;

      if (data == null || data.isEmpty) return null;

      final firstTrack = data[0] as Map<String, dynamic>;
      final album = firstTrack['album'] as Map<String, dynamic>?;

      if (album == null) return null;

      // ✓ შენი JS-ში ცარიერდება cover_big (500x500). ცარიერდება cover_xl (1000x1000) —
      // უფრო ლამაზი lock screen-ისთვის
      final coverXl = album['cover_xl'] as String?;
      final coverBig = album['cover_big'] as String?;
      final cover = album['cover_medium'] as String?;

      return coverXl ?? coverBig ?? cover;
    } catch (e) {
      print('CoverArtService error: $e');
      return null;
    }
  }
}

/// Internal helper class
class _ParsedTrack {
  final String artist;
  final String title;

  _ParsedTrack({required this.artist, required this.title});
}
