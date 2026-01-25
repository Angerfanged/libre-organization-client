import 'package:flutter/material.dart';
import 'package:dynamic_color/dynamic_color.dart';
import 'package:libre_organization_client/theme/dynamic_theme.dart';

import 'package:libre_organization_client/views/auth_gate.dart';
import 'package:libre_organization_client/views/home_page.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return DynamicColorBuilder(
      builder: (ColorScheme? lightDynamic, ColorScheme? darkDynamic) {
        ColorScheme lightColorScheme;
        ColorScheme darkColorScheme;

        if (lightDynamic != null && darkDynamic != null) {
          lightColorScheme = lightDynamic.harmonized();
          darkColorScheme = darkDynamic.harmonized();
        } else {
          lightColorScheme = DynamicTheme.fallbackLightColorScheme();
          darkColorScheme = DynamicTheme.fallbackDarkColorScheme();
        }

        return MaterialApp(
          theme: DynamicTheme.lightTheme(lightColorScheme),
          darkTheme: DynamicTheme.darkTheme(darkColorScheme),
          title: 'Libre Organization',
          home: const AuthGate(),
          routes: {
            '/auth': (context) => const AuthGate(),
            // Add your other routes here:
            '/home': (context) => const HomePage(),
            // '/settings': (context) => const SettingsPage(),
          },
        );
      },
    );
  }
}
