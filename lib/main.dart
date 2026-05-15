import 'dart:isolate';
import 'dart:ui';

import 'package:audio_service/audio_service.dart';
import 'package:flutter/material.dart';
import 'package:home_widget/home_widget.dart';

import 'app.dart';
import 'core/audio/audio_player_handler.dart';
import 'core/services/connectivity_service.dart';
import 'core/services/search_history_service.dart';
import 'core/theme/theme_service.dart';
import 'features/favorites/favorites_service.dart';
import 'features/world_radio/recently_played_service.dart';

late AudioPlayerHandler audioHandler;

@pragma('vm:entry-point')
Future<void> _widgetPlayPauseCallback(Uri? uri) async {
  IsolateNameServer.lookupPortByName('audio_control')?.send('play_pause');
}

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  final receivePort = ReceivePort();
  IsolateNameServer.registerPortWithName(receivePort.sendPort, 'audio_control');

  await HomeWidget.registerInteractivityCallback(_widgetPlayPauseCallback);

  audioHandler = await AudioService.init(
    builder: () => AudioPlayerHandler(),
    config: const AudioServiceConfig(
      androidNotificationChannelId: 'ge.canka.radio_bude.channel.audio',
      androidNotificationChannelName: 'Radio Hangi Playback',
      androidNotificationChannelDescription: 'Radio background playback',
      androidNotificationOngoing: true,
      androidNotificationIcon: 'mipmap/launcher_icon',
    ),
  );

  receivePort.listen((message) {
    if (message == 'play_pause') {
      if (audioHandler.playbackState.value.playing) {
        audioHandler.pause();
      } else {
        audioHandler.play();
      }
    }
  });

  await Future.wait([
    FavoritesService().load(),
    RecentlyPlayedService().load(),
    ThemeService().load(),
    SearchHistoryService().load(),
    ConnectivityService().init(),
  ]);

  runApp(const RadioBudeApp());
}
