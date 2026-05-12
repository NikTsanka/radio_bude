import 'package:flutter/material.dart';
import 'core/theme/app_theme.dart';
import 'features/home/home_screen.dart';

class RadioBudeApp extends StatelessWidget {
  const RadioBudeApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Radio Bude',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light,
      darkTheme: AppTheme.dark,
      themeMode: ThemeMode.dark, // ჯერ მუქი, მერე system theme-ს დავხვეწავთ
      home: const HomeScreen(),
    );
  }
}
