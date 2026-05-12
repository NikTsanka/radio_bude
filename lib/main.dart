import 'package:audio_service/audio_service.dart';
import 'package:flutter/material.dart';
import 'app.dart';
import 'core/audio/audio_player_handler.dart';

/// Global audio handler — აქედან წვდომა აქვს ნებისმიერ widget-ს
late AudioPlayerHandler audioHandler;

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  audioHandler = await AudioService.init(
    builder: () => AudioPlayerHandler(),
    config: const AudioServiceConfig(
      androidNotificationChannelId: 'ge.canka.radio_bude.channel.audio',
      androidNotificationChannelName: 'Radio Bude Playback',
      androidNotificationChannelDescription:
          'რადიოს უწყვეტი მუშაობა background-ში',
      androidNotificationOngoing: true,
      androidNotificationIcon: 'mipmap/ic_launcher',
    ),
  );

  runApp(const RadioBudeApp());
}
