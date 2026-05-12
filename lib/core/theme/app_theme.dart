import 'package:flutter/material.dart';

class AppTheme {
  // Radio Bude-ის ბრენდინგისთვის — შენი ვებსაიტიდან მუქი ფერი
  static const _seedColor = Color(0xFFE91E63); // ვარდისფერი/მაგენტა accent

  static ThemeData get dark => ThemeData(
    colorScheme: ColorScheme.fromSeed(
      seedColor: _seedColor,
      brightness: Brightness.dark,
    ),
    useMaterial3: true,
    scaffoldBackgroundColor: const Color(0xFF0E0E0E),
    appBarTheme: const AppBarTheme(
      backgroundColor: Colors.transparent,
      elevation: 0,
    ),
  );

  static ThemeData get light => ThemeData(
    colorScheme: ColorScheme.fromSeed(seedColor: _seedColor),
    useMaterial3: true,
  );
}
