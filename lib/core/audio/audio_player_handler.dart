import 'package:audio_service/audio_service.dart';
import 'package:just_audio/just_audio.dart';
import 'package:rxdart/rxdart.dart';
import '../constants.dart';

/// Radio Bude-ის audio handler.
/// AudioService-ი მართავს background playback-ს,
/// lock screen controls-ს, notification-ს, Bluetooth ღილაკებს.
class AudioPlayerHandler extends BaseAudioHandler with SeekHandler {
  final AudioPlayer _player = AudioPlayer();

  /// ICY metadata-დან მოპოვებული მიმდინარე სიმღერა
  /// (UI-ში StreamBuilder-ით უსმენთ)
  final BehaviorSubject<String?> currentSong = BehaviorSubject<String?>.seeded(
    null,
  );

  AudioPlayerHandler() {
    _init();
  }

  Future<void> _init() async {
    // ✓ Player-ის state ცვლილებები გადასცეთ AudioService-ს
    // (ეს უზრუნველყოფს, რომ lock screen-ის ღილაკები სწორ state-ში იყოს)
    _player.playbackEventStream.map(_transformEvent).pipe(playbackState);

    // ✓ ICY metadata stream — ეთერში სიმღერის სახელის წამოღება
    // Icecast-ი ყოველ რამდენიმე წამში გვაგზავნის "StreamTitle"-ს
    _player.icyMetadataStream.listen((icy) {
      final title = icy?.info?.title;
      if (title != null && title.isNotEmpty) {
        currentSong.add(title);

        // ✓ Lock screen / notification-ში სიმღერის სახელის განახლება
        final current = mediaItem.value;
        if (current != null) {
          mediaItem.add(
            current.copyWith(
              title: title,
              displaySubtitle: Constants.radioBudeName,
            ),
          );
        }
      }
    });

    // ✓ შეცდომების handling — თუ stream-ი დაიკარგა
    _player.playbackEventStream.listen(
      (event) {},
      onError: (Object e, StackTrace stackTrace) {
        print('Audio player error: $e');
      },
    );

    // ✓ Radio Bude-ის default ჩატვირთვა (აპლიკაცია გაშვებისთანავე ბრუნდება)
    await _loadRadioBude();
  }

  Future<void> _loadRadioBude() async {
    final item = MediaItem(
      id: Constants.radioBudeStreamUrl,
      album: Constants.radioBudeName,
      title: 'მზადდება...',
      artist: Constants.radioBudeAuthor,
      artUri: Uri.parse(Constants.radioBudeArtUrl),
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

  /// Radio Bude-ზე დაბრუნება
  Future<void> playRadioBude() async {
    await _loadRadioBude();
    await _player.play();
  }

  // === Audio Service-ის required overrides ===

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

  /// Player state-ის გადათარგმნა AudioService format-ში
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
