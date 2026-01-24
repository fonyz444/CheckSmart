import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'main_shell.dart';

/// Root application widget for CheckSmart.kz
class CheckSmartApp extends StatelessWidget {
  const CheckSmartApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'CheckSmart.kz',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        brightness: Brightness.dark,
        colorScheme: const ColorScheme.dark(
          primary: Color(0xFF00D09C),
          secondary: Color(0xFF6C5CE7),
          surface: Color(0xFF1E1E1E),
          error: Color(0xFFFF6B6B),
        ),
        scaffoldBackgroundColor: const Color(0xFF121212),
        appBarTheme: const AppBarTheme(
          backgroundColor: Colors.transparent,
          elevation: 0,
        ),
        fontFamily: 'Roboto',
      ),
      home: const MainShell(),
    );
  }
}

/// Wraps the app with Riverpod provider scope
class CheckSmartAppWrapper extends StatelessWidget {
  const CheckSmartAppWrapper({super.key});

  @override
  Widget build(BuildContext context) {
    return const ProviderScope(child: CheckSmartApp());
  }
}
