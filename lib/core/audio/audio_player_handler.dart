import 'package:audio_service/audio_service.dart';
import 'package:just_audio/just_audio.dart';
import 'package:rxdart/rxdart.dart';
import '../constants.dart';
import '../services/cover_art_service.dart';

/// Radio Bude-ის audio handler.
/// AudioService-ი ფარდამიჩუმოდ უმართავს background playback-ს,
/// lock screen controls-ს, notification-ს, Bluetooth ღილაკებს.
class AudioPlayerHandler extends BaseAudioHandler with SeekHandler {
  final AudioPlayer _player = AudioPlayer();
  final CoverArtService _coverService = CoverArtService();

  /// ICY metadata-დან მოპოვებული მიმდინარე სიმღერა
  final BehaviorSubject<String?> currentSong = BehaviorSubject<String?>.seeded(
    null,
  );

  static const String _defaultCover = Constants.radioBudeArtUrl;

  AudioPlayerHandler() {
    _init();
  }

  Future<void> _init() async {
    _player.playbackEventStream.map(_transformEvent).pipe(playbackState);

    // ✓ ICY metadata listener — ეთერში სიმღერის ცვლა + cover fetch
    _player.icyMetadataStream.listen((icy) async {
      final title = icy?.info?.title;
      if (title != null && title.isNotEmpty) {
        currentSong.add(title);

        // ✓ მყისიერად UI განვაახლოთ ცარიერი სიმღერით (cover ჯერ default)
        final current = mediaItem.value;
        if (current != null) {
          mediaItem.add(
            current.copyWith(
              title: title,
              displaySubtitle: Constants.radioBudeName,
            ),
          );
        }

        // ✓ Deezer-დან cover-ის ცარიერდება ფონზე — UI არ ცარიერდება
        _updateCoverArt(title);
      }
    });

    _player.playbackEventStream.listen(
      (event) {},
      onError: (Object e, StackTrace stackTrace) {
        print('Audio player error: $e');
      },
    );

    await _loadRadioBude();
  }

  /// Deezer-დან cover-ის წამოღება და MediaItem-ის ცარიერი
  Future<void> _updateCoverArt(String streamTitle) async {
    final coverUrl = await _coverService.fetchCoverFor(streamTitle);

    // ✓ მნიშვნელოვანი: ცარიერდება მაშინაც კი როცა cover null-ია — default-ით
    final finalCoverUrl = coverUrl ?? _defaultCover;

    final current = mediaItem.value;
    if (current != null && current.title == streamTitle) {
      // ✓ მხოლოდ თუ ჯერ კიდევ იგივე სიმღერა იკრავება (ცარიერი race condition)
      mediaItem.add(current.copyWith(artUri: Uri.parse(finalCoverUrl)));
    }
  }

  Future<void> _loadRadioBude() async {
    final item = MediaItem(
      id: Constants.radioBudeStreamUrl,
      album: Constants.radioBudeName,
      title: 'Loading...',
      artUri: Uri.parse(_defaultCover),
    );

    mediaItem.add(item);

    try {
      await _player.setUrl(Constants.radioBudeStreamUrl);
    } catch (e) {
      print('Error loading Radio Bude: $e');
    }
  }

  /// მსოფლიო რადიოს გაშვება (Phase 4-ში გამოვიყენებთ)
  Future<void> playStation({
    required String url,
    required String name,
    String? country,
    String? favicon,
  }) async {
    final item = MediaItem(
      id: url,
      album: name,
      title: name,
      artist: country ?? '',
      artUri: favicon != null && favicon.isNotEmpty ? Uri.parse(favicon) : null,
    );

    mediaItem.add(item);
    currentSong.add(null);

    try {
      await _player.setUrl(url);
      await _player.play();
    } catch (e) {
      print('Error playing station: $e');
    }
  }

  Future<void> playRadioBude() async {
    await _loadRadioBude();
    await _player.play();
  }

  // === Audio Service overrides ===

  @override
  Future<void> play() => _player.play();

  @override
  Future<void> pause() => _player.pause();

  @override
  Future<void> stop() async {
    await _player.stop();
    await super.stop();
  }

  @override
  Future<void> seek(Duration position) => _player.seek(position);

  PlaybackState _transformEvent(PlaybackEvent event) {
    return PlaybackState(
      controls: [MediaControl.pause, MediaControl.play, MediaControl.stop],
      systemActions: const {MediaAction.seek},
      androidCompactActionIndices: const [0, 1, 2],
      processingState: const {
        ProcessingState.idle: AudioProcessingState.idle,
        ProcessingState.loading: AudioProcessingState.loading,
        ProcessingState.buffering: AudioProcessingState.buffering,
        ProcessingState.ready: AudioProcessingState.ready,
        ProcessingState.completed: AudioProcessingState.completed,
      }[_player.processingState]!,
      playing: _player.playing,
      updatePosition: _player.position,
      bufferedPosition: _player.bufferedPosition,
      speed: _player.speed,
      queueIndex: event.currentIndex,
    );
  }
}
