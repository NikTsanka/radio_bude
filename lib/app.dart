import 'package:flutter/material.dart';
import 'core/theme/app_theme.dart';
import 'core/theme/theme_service.dart';
import 'features/home/home_screen.dart';

class RadioBudeApp extends StatelessWidget {
  const RadioBudeApp({super.key});

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: ThemeService(),
      builder: (context, _) => MaterialApp(
            title: 'Radio Hangi',
            debugShowCheckedModeBanner: false,
            theme: AppTheme.light,
            darkTheme: AppTheme.dark,
            themeMode: ThemeService().mode,
            home: const HomeScreen(),
          ),
    );
  }
}
