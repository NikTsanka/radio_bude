import 'dart:async';
import 'dart:math' as math;
import 'package:audio_service/audio_service.dart';
import 'package:flutter/foundation.dart' show debugPrint;
import 'package:just_audio/just_audio.dart';
import 'package:rxdart/rxdart.dart';
import '../constants.dart';
import '../services/cover_art_service.dart';
import '../services/home_widget_service.dart';

class AudioPlayerHandler extends BaseAudioHandler with SeekHandler {
  final AudioPlayer _player = AudioPlayer();
  final CoverArtService _coverService = CoverArtService();

  final BehaviorSubject<String?> currentSong =
      BehaviorSubject<String?>.seeded(null);
  final BehaviorSubject<double> volume = BehaviorSubject<double>.seeded(1.0);
  final BehaviorSubject<DateTime?> sleepTimerEnd =
      BehaviorSubject<DateTime?>.seeded(null);

  late final Stream<String?> currentlyPlayingUrl = mediaItem
      .map((item) => item?.id)
      .distinct();

  String? _currentStreamUrl;
  bool _intentionalStop = false;
  Timer? _sleepTimer;
  Timer? _reconnectTimer;
  int _reconnectAttempts = 0;
  static const int _maxReconnectAttempts = 5;

  AudioPlayerHandler() {
    _init();
  }

  Future<void> _init() async {
    _player.playbackEventStream.map(_transformEvent).pipe(playbackState);

    _player.icyMetadataStream.listen((icy) async {
      final title = icy?.info?.title;
      if (title != null && title.isNotEmpty) {
        currentSong.add(title);

        final current = mediaItem.value;
        if (current != null) {
          mediaItem.add(
            current.copyWith(
              title: title,
              displaySubtitle: Constants.radioBudeName,
            ),
          );
        }

        _updateCoverArt(title);
        unawaited(_updateHomeWidget());
      }
    });

    _player.playbackEventStream.listen(
      (_) {},
      onError: (Object e, StackTrace _) {
        debugPrint('Audio error: $e');
        if (!_intentionalStop && _currentStreamUrl != null) {
          _scheduleReconnect();
        }
      },
    );

    await _loadRadioBude();
  }

  void _scheduleReconnect() {
    if (_reconnectAttempts >= _maxReconnectAttempts) {
      debugPrint('Max reconnect attempts reached — giving up.');
      return;
    }
    _reconnectAttempts++;
    _reconnectTimer?.cancel();
    final backoffSeconds = (3 * (1 << (_reconnectAttempts - 1))).clamp(3, 60);
    final jitterMs = math.Random().nextInt(1500);
    final delay = Duration(seconds: backoffSeconds, milliseconds: jitterMs);
    debugPrint('Reconnect attempt $_reconnectAttempts in ${delay.inSeconds}s...');
    _reconnectTimer = Timer(delay, () async {
      if (_intentionalStop || _currentStreamUrl == null) return;
      try {
        await _player.setUrl(_currentStreamUrl!);
        await _player.play();
        _reconnectAttempts = 0;
        debugPrint('Reconnected successfully.');
      } catch (e) {
        debugPrint('Reconnect attempt $_reconnectAttempts failed: $e');
        _scheduleReconnect();
      }
    });
  }

  Future<void> _updateHomeWidget({bool? isPlaying}) async {
    final item = mediaItem.value;
    await HomeWidgetService.update(
      stationName: item?.album ?? Constants.radioBudeName,
      songTitle: currentSong.value ?? item?.title ?? '',
      isPlaying: isPlaying ?? _player.playing,
    );
  }

  Future<void> _updateCoverArt(String streamTitle) async {
    final coverUrl = await _coverService.fetchCoverFor(streamTitle);
    if (coverUrl == null) return; // keep existing art; don't fall back to asset URI
    final current = mediaItem.value;
    if (current != null && current.title == streamTitle) {
      mediaItem.add(current.copyWith(artUri: Uri.parse(coverUrl)));
    }
  }

  Future<void> _loadRadioBude() async {
    _currentStreamUrl = Constants.radioBudeStreamUrl;
    final item = MediaItem(
      id: Constants.radioBudeStreamUrl,
      album: Constants.radioBudeName,
      title: 'Loading...',
    );
    mediaItem.add(item);
    try {
      await _player.setUrl(Constants.radioBudeStreamUrl);
    } catch (e) {
      debugPrint('Error loading Radio Bude: $e');
    }
  }

  Future<void> playStation({
    required String url,
    required String name,
    String? country,
    String? favicon,
  }) async {
    _intentionalStop = false;
    _reconnectTimer?.cancel();
    _reconnectAttempts = 0;
    _currentStreamUrl = url;

    final item = MediaItem(
      id: url,
      album: name,
      title: name,
      artist: country ?? '',
      artUri:
          favicon != null && favicon.isNotEmpty ? Uri.parse(favicon) : null,
    );
    mediaItem.add(item);
    currentSong.add(null);

    try {
      await _player.setUrl(url);
      await _player.play();
      unawaited(_updateHomeWidget(isPlaying: true));
    } catch (e) {
      debugPrint('Error playing station: $e');
    }
  }

  Future<void> playRadioBude() async {
    _intentionalStop = false;
    _reconnectTimer?.cancel();
    _reconnectAttempts = 0;
    await _loadRadioBude();
    await _player.play();
  }

  Future<void> setVolume(double vol) async {
    await _player.setVolume(vol);
    volume.add(vol);
  }

  void setSleepTimer(Duration duration) {
    _sleepTimer?.cancel();
    final end = DateTime.now().add(duration);
    sleepTimerEnd.add(end);
    _sleepTimer = Timer(duration, () async {
      await pause();
      sleepTimerEnd.add(null);
    });
  }

  void cancelSleepTimer() {
    _sleepTimer?.cancel();
    _sleepTimer = null;
    sleepTimerEnd.add(null);
  }

  @override
  Future<void> play() async {
    _intentionalStop = false;
    await _player.play();
    unawaited(_updateHomeWidget(isPlaying: true));
  }

  @override
  Future<void> pause() async {
    await _player.pause();
    unawaited(_updateHomeWidget(isPlaying: false));
  }

  @override
  Future<void> stop() async {
    _intentionalStop = true;
    _reconnectTimer?.cancel();
    _sleepTimer?.cancel();
    sleepTimerEnd.add(null);
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
