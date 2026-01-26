import 'package:flutter/material.dart';

/// Transactions screen placeholder
class TransactionsScreen extends StatelessWidget {
  const TransactionsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F7),
      appBar: AppBar(
        backgroundColor: const Color(0xFFF5F5F7),
        title: const Text(
          'Транзакции',
          style: TextStyle(
            color: Color(0xFF1A1A1A),
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
      body: const Center(
        child: Text(
          'Скоро здесь появятся транзакции',
          style: TextStyle(color: Color(0xFF6B7280), fontSize: 16),
        ),
      ),
    );
  }
}
