/// Radio Browser API-ის სადგურის model
///
/// Reference: https://api.radio-browser.info/
class Station {
  /// უნიკალური ID (UUID)
  final String stationUuid;

  /// სადგურის სახელი
  final String name;

  /// რეალური stream URL (გადანდადებული, თუ ცხელია)
  /// ეს არის ის URL რომელიც playback-ისთვის გვჭირდება
  final String url;

  /// ლოგოს URL (შეიძლება იყოს ცარიელი)
  final String favicon;

  /// ქვეყანა (მაგ: "Georgia", "United Kingdom")
  final String country;

  /// ქვეყნის ISO კოდი (მაგ: "GE", "GB")
  final String countryCode;

  /// ენა (მაგ: "english", "russian")
  final String language;

  /// ჟანრის tags (მაგ: ["rock", "alternative", "indie"])
  final List<String> tags;

  /// ბიტრეიტი kbps-ში (0 თუ უცნობია)
  final int bitrate;

  /// კოდეკი (mp3, aac, ogg)
  final String codec;

  /// ხმოვანების რაოდენობა — ხარისხის მაჩვენებელი
  final int votes;

  /// clicktrack — რამდენ ადამიანმა მოუსმინა ბოლო 24 საათში
  final int clickCount;

  Station({
    required this.stationUuid,
    required this.name,
    required this.url,
    required this.favicon,
    required this.country,
    required this.countryCode,
    required this.language,
    required this.tags,
    required this.bitrate,
    required this.codec,
    required this.votes,
    required this.clickCount,
  });

  /// JSON-დან Station-ის შექმნა
  factory Station.fromJson(Map<String, dynamic> json) {
    // tags-ი არის comma-separated string Radio Browser-ში
    final tagsString = json['tags'] as String? ?? '';
    final tags = tagsString.isEmpty
        ? <String>[]
        : tagsString
              .split(',')
              .map((t) => t.trim())
              .where((t) => t.isNotEmpty)
              .toList();

    return Station(
      stationUuid: json['stationuuid'] as String? ?? '',
      name: (json['name'] as String? ?? 'Unknown').trim(),
      // url_resolved უპირატესია — ეს არის final stream URL (after redirects)
      url: (json['url_resolved'] as String? ?? json['url'] as String? ?? '')
          .trim(),
      favicon: (json['favicon'] as String? ?? '').trim(),
      country: (json['country'] as String? ?? '').trim(),
      countryCode: (json['countrycode'] as String? ?? '').trim(),
      language: (json['language'] as String? ?? '').trim(),
      tags: tags,
      bitrate: (json['bitrate'] as num?)?.toInt() ?? 0,
      codec: (json['codec'] as String? ?? '').toLowerCase(),
      votes: (json['votes'] as num?)?.toInt() ?? 0,
      clickCount: (json['clickcount'] as num?)?.toInt() ?? 0,
    );
  }

  /// JSON-ად კონვერტაცია (ფავორიტებში შესანახად)
  Map<String, dynamic> toJson() {
    return {
      'stationuuid': stationUuid,
      'name': name,
      'url_resolved': url,
      'favicon': favicon,
      'country': country,
      'countrycode': countryCode,
      'language': language,
      'tags': tags.join(','),
      'bitrate': bitrate,
      'codec': codec,
      'votes': votes,
      'clickcount': clickCount,
    };
  }

  /// მოკლე აღწერა UI-სთვის (მაგ: "Georgia · 128 kbps · MP3")
  String get description {
    final parts = <String>[];
    if (country.isNotEmpty) parts.add(country);
    if (bitrate > 0) parts.add('$bitrate kbps');
    if (codec.isNotEmpty) parts.add(codec.toUpperCase());
    return parts.join(' · ');
  }

  /// თამაშის შესაძლებლობა
  bool get isPlayable => url.isNotEmpty;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Station && stationUuid == other.stationUuid;

  @override
  int get hashCode => stationUuid.hashCode;

  @override
  String toString() => 'Station($name, $country, $bitrate kbps)';
}
