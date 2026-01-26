import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'core/app_theme.dart';
import 'main_shell.dart';

/// Root application widget for CheckSmart.kz
class CheckSmartApp extends StatelessWidget {
  const CheckSmartApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'CheckSmart.kz',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme,
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
