import 'package:flutter/material.dart';

/// Uygulama temasi — acik ve koyu ThemeData tek yerden. Renk semasi tek bir
/// tohum renkten (Material 3) turer; koyu mod ayni tohumdan Brightness.dark
/// ile uretilir, boylece marka rengi iki modda tutarli kalir.
const Color _seedColor = Color(0xFF1565C0);

ThemeData buildLightTheme() => ThemeData(
      useMaterial3: true,
      colorScheme: ColorScheme.fromSeed(seedColor: _seedColor),
    );

ThemeData buildDarkTheme() => ThemeData(
      useMaterial3: true,
      colorScheme: ColorScheme.fromSeed(
        seedColor: _seedColor,
        brightness: Brightness.dark,
      ),
    );
