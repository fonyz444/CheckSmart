import 'dart:convert';
import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;
import 'package:connectivity_plus/connectivity_plus.dart';

import '../../transactions/domain/transaction_entity.dart';
import '../../categories/domain/custom_category.dart';

/// Provider for the AI Repository
final aiRepositoryProvider = Provider<AiRepository>((ref) {
  return AiRepository();
});

class AiRepository {
  // Constants
  static const _baseUrl = 'https://api.groq.com/openai/v1/chat/completions';
  static const _model = 'llama-3.3-70b-versatile';
  static const _cacheDuration = Duration(hours: 1);
  static const _requestTimeout = Duration(seconds: 30);
  static const _maxRetries = 3;

  // Secured API key from .env file
  static String get _apiKey => dotenv.env['GROQ_API_KEY'] ?? '';

  // Caching variables
  String? _cachedAnalysis;
  DateTime? _cacheTime;
  int? _cacheDataHash;

  /// Generates a robust hash to detect data changes
  int _generateDataHash(List<TransactionEntity> transactions) {
    if (transactions.isEmpty) return 0;

    return Object.hashAll(
      transactions.map(
        (t) => Object.hash(
          t.id,
          t.amount,
          t.category,
          t.date.millisecondsSinceEpoch,
        ),
      ),
    );
  }

  Future<String> getSpendingAnalysis(
    List<TransactionEntity> transactions, {
    double? monthlyIncome,
    Map<String, double>? budgetLimits,
    List<CustomCategory>? customCategories,
  }) async {
    // 1. Check API Configuration
    if (_apiKey.isEmpty) {
      return 'Ошибка конфигурации: API ключ не найден. Проверьте файл .env';
    }

    if (transactions.isEmpty) {
      return 'Нет данных о транзакциях для анализа.';
    }

    // 2. Check Internet Connectivity
    final connectivityResult = await Connectivity().checkConnectivity();
    if (connectivityResult.contains(ConnectivityResult.none)) {
      return 'Нет подключения к интернету. AI анализ недоступен в офлайн-режиме.';
    }

    // 2. Check Cache
    final currentHash = _generateDataHash(transactions);
    if (_cachedAnalysis != null &&
        _cacheTime != null &&
        _cacheDataHash == currentHash &&
        DateTime.now().difference(_cacheTime!) < _cacheDuration) {
      debugPrint('Returning cached AI analysis');
      return _cachedAnalysis!;
    }

    try {
      final prompt = _buildPrompt(
        transactions,
        monthlyIncome,
        budgetLimits,
        customCategories ?? [],
      );
      final analysis = await _fetchWithRetry(prompt);

      // Update cache
      _cachedAnalysis = analysis;
      _cacheTime = DateTime.now();
      _cacheDataHash = currentHash;

      return analysis;
    } catch (e, stackTrace) {
      debugPrint('AI Analysis Error: $e\n$stackTrace');

      if (e.toString().contains('SocketException') || e is SocketException) {
        return 'Ошибка сети. Проверьте интернет-соединение.';
      }
      if (e.toString().contains('TimeoutException') || e is TimeoutException) {
        return 'Превышено время ожидания. Попробуйте позже.';
      }
      return 'Не удалось получить анализ: ${e.toString().replaceAll('Exception:', '').trim()}';
    }
  }

  String _buildPrompt(
    List<TransactionEntity> transactions,
    double? monthlyIncome,
    Map<String, double>? budgetLimits,
    List<CustomCategory> customCategories,
  ) {
    final sb = StringBuffer();
    final now = DateTime.now();

    // Filter for current month
    final currentMonthData =
        transactions
            .where((t) => t.date.year == now.year && t.date.month == now.month)
            .toList();

    // Helper to avoid floating-point precision errors
    double roundMoney(double v) => (v * 100).round() / 100;

    double totalSpent = 0;
    final categoryTotals = <String, double>{};
    for (var t in currentMonthData) {
      totalSpent = roundMoney(totalSpent + t.amount);
      // Use custom category name if available, otherwise use standard category
      String catName;
      if (t.customCategoryId != null) {
        final customCat =
            customCategories
                .where((c) => c.id == t.customCategoryId)
                .firstOrNull;
        catName = customCat?.name ?? t.category.displayName;
      } else {
        catName = t.category.displayName;
      }
      categoryTotals[catName] = roundMoney(
        (categoryTotals[catName] ?? 0) + t.amount,
      );
    }

    sb.writeln('Task: Provide 3-4 personalized financial tips in Russian.');
    sb.writeln('Context: User is in Kazakhstan (Currency: Tenge ₸).');

    // 1. Financial Context
    sb.writeln('\n--- Current Month Data ---');
    sb.writeln('Total Spent: ${totalSpent.toStringAsFixed(0)} ₸');

    if (monthlyIncome != null && monthlyIncome > 0) {
      final spentPct = ((totalSpent / monthlyIncome) * 100).toStringAsFixed(1);
      sb.writeln('Monthly Income: ${monthlyIncome.toStringAsFixed(0)} ₸');
      sb.writeln('Spending Rate: $spentPct%');

      if (totalSpent > monthlyIncome) {
        sb.writeln('⚠️ ALERT: Spending exceeds income!');
      }
    }

    sb.writeln('Top Categories:');
    final sortedCats =
        categoryTotals.entries.toList()
          ..sort((a, b) => b.value.compareTo(a.value));

    for (var i = 0; i < (sortedCats.length > 5 ? 5 : sortedCats.length); i++) {
      final entry = sortedCats[i];
      sb.writeln('- ${entry.key}: ${entry.value.toStringAsFixed(0)} ₸');
    }

    // 2. Budget Comparison
    if (budgetLimits != null && budgetLimits.isNotEmpty) {
      sb.writeln('\n--- Budget Analysis ---');
      categoryTotals.forEach((cat, spent) {
        if (budgetLimits.containsKey(cat)) {
          final limit = budgetLimits[cat]!;
          if (limit > 0) {
            final pct = ((spent / limit) * 100).toStringAsFixed(0);
            sb.writeln('Category "$cat": $spent / $limit ₸ ($pct%)');
          }
        }
      });
    }

    // 3. Historical Comparison
    // Fix: Correctly calculate previous month
    final prevMonth = now.month == 1 ? 12 : now.month - 1;
    final prevYear = now.month == 1 ? now.year - 1 : now.year;

    final prevMonthData =
        transactions
            .where((t) => t.date.year == prevYear && t.date.month == prevMonth)
            .toList();

    if (prevMonthData.isNotEmpty) {
      final prevTotal = prevMonthData.fold<double>(
        0.0,
        (sum, t) => roundMoney(sum + t.amount),
      );
      if (prevTotal > 0) {
        final change = ((totalSpent - prevTotal) / prevTotal * 100);
        final sign = change >= 0 ? '+' : '';
        sb.writeln('\n--- Historical Context ---');
        sb.writeln(
          'Compared to last month: $sign${change.toStringAsFixed(1)}% (${prevTotal.toStringAsFixed(0)} ₸ -> ${totalSpent.toStringAsFixed(0)} ₸)',
        );
      }
    }

    sb.writeln('''
\nGuidelines:
1. Analyze the largest expenses and suggest specific ways to optimize them in Kazakhstan.
2. If spending > income, give urgent advice.
3. If specific categories are over budget, highlight them.
4. If spending increased significantly from last month, ask why/warn.
5. Use a friendly, encouraging professional tone.
6. Return response in Russian. Use numbered list.
7. RESPONSE LENGTH: Medium length. Provide 3-4 detailed but concise tips. Total approx 200-250 words. Avoid excessive pleasantries.
''');

    return sb.toString();
  }

  Future<String> _fetchWithRetry(String prompt) async {
    for (int i = 0; i < _maxRetries; i++) {
      try {
        final response = await http
            .post(
              Uri.parse(_baseUrl),
              headers: {
                'Content-Type': 'application/json',
                'Authorization': 'Bearer $_apiKey',
              },
              body: jsonEncode({
                'model': _model,
                'messages': [
                  {'role': 'user', 'content': prompt},
                ],
                'temperature': 0.7,
              }),
            )
            .timeout(_requestTimeout);

        if (response.statusCode == 200) {
          final data = jsonDecode(utf8.decode(response.bodyBytes));
          return data['choices'][0]['message']['content'] as String;
        }

        if (response.statusCode == 429) {
          // Rate limit - wait exponentially
          debugPrint('API Rate Limit. Waiting ${2 * (i + 1)}s...');
          await Future.delayed(Duration(seconds: 2 * (i + 1)));
          continue;
        }

        throw Exception('API error: ${response.statusCode} ${response.body}');
      } catch (e) {
        debugPrint('Attempt ${i + 1} failed: $e');
        if (i == _maxRetries - 1) rethrow; // Last attempt failed
        await Future.delayed(const Duration(seconds: 1));
      }
    }
    throw Exception('Max retries exceeded');
  }
}
