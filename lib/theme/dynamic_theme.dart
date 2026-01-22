import 'package:flutter/material.dart';

class DynamicTheme {
  static ThemeData lightTheme(ColorScheme colorScheme) {
    return ThemeData(
      brightness: Brightness.light,
      colorScheme: colorScheme,
      fontFamily: 'Roboto',
      scaffoldBackgroundColor: Colors.white,
      useMaterial3: true,
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ButtonStyle(
          backgroundColor: MaterialStateProperty.all(colorScheme.primary),
        ),
      ),
    );
  }

  static ThemeData darkTheme(ColorScheme colorScheme) {
    return ThemeData(
      brightness: Brightness.dark,
      colorScheme: colorScheme,
      fontFamily: 'Roboto',
      scaffoldBackgroundColor: Colors.black,
      useMaterial3: true,
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ButtonStyle(
          backgroundColor: MaterialStateProperty.all(colorScheme.primary),
        ),
      ),
    );
  }

  static ColorScheme fallbackLightColorScheme() {
    return ColorScheme.fromSeed(seedColor: Color(0xFFFAFAFA));
  }

  static ColorScheme fallbackDarkColorScheme() {
    return ColorScheme.fromSeed(
      seedColor: Color(0xFF202020),
      brightness: Brightness.dark,
    );
  }
}
