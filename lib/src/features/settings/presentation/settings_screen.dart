import 'package:flutter/material.dart';

/// Settings/Profile screen placeholder
class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      backgroundColor: Color(0xFF121212),
      body: SafeArea(
        child: Center(
          child: Text(
            'Настройки (скоро)',
            style: TextStyle(color: Colors.white54, fontSize: 16),
          ),
        ),
      ),
    );
  }
}
