import 'package:audio_service/audio_service.dart';
import 'package:flutter/material.dart';
import 'app.dart';
import 'core/audio/audio_player_handler.dart';
import 'core/theme/theme_service.dart';
import 'features/favorites/favorites_service.dart';
import 'features/world_radio/recently_played_service.dart';

late AudioPlayerHandler audioHandler;

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

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

  await Future.wait([
    FavoritesService().load(),
    RecentlyPlayedService().load(),
    ThemeService().load(),
  ]);

  runApp(const RadioBudeApp());
}
