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
import '../domain/ai_analysis_result.dart';

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
  AiAnalysisResult? _cachedAnalysis;
  DateTime? _cacheTime;
  int? _cacheDataHash;

  /// Generates a robust hash based on the data that goes into the prompt.
  int _generateDataHash({
    required List<TransactionEntity> monthTx,
    double? monthlyIncome,
    Map<String, double>? budgetLimits,
    List<CustomCategory>? customCategories,
  }) {
    return Object.hash(
      monthlyIncome ?? 0,
      Object.hashAll(
        budgetLimits?.entries.map((e) => Object.hash(e.key, e.value)) ??
            const [],
      ),
      Object.hashAll(
        customCategories?.map((c) => Object.hash(c.id, c.name)) ?? const [],
      ),
      Object.hashAll(
        monthTx.map(
          (t) => Object.hash(
            t.id,
            t.amount,
            t.category,
            t.customCategoryId,
            t.date.millisecondsSinceEpoch,
          ),
        ),
      ),
    );
  }

  Future<AiAnalysisResult> getSpendingAnalysis(
    List<TransactionEntity> transactions, {
    double? monthlyIncome,
    Map<String, double>? budgetLimits,
    List<CustomCategory>? customCategories,
  }) async {
    // 1. Check API Configuration
    if (_apiKey.isEmpty) {
      return AiAnalysisResult(
        insights: [],
        summary: 'Ошибка конфигурации: API ключ не найден. Проверьте файл .env',
        generatedAt: DateTime.now(),
      );
    }

    final now = DateTime.now();
    final currentMonthData =
        transactions
            .where((t) => t.date.year == now.year && t.date.month == now.month)
            .toList();

    if (currentMonthData.isEmpty) {
      return AiAnalysisResult(
        insights: [],
        summary: 'Нет данных о транзакциях за текущий месяц.',
        generatedAt: DateTime.now(),
      );
    }

    // 2. Check Internet Connectivity (UX hint, not a guarantee)
    final connectivityResult = await Connectivity().checkConnectivity();
    if (connectivityResult.contains(ConnectivityResult.none)) {
      // Return cached data if available, otherwise show offline message
      if (_cachedAnalysis != null) {
        return _cachedAnalysis!;
      }
      return AiAnalysisResult(
        insights: [],
        summary:
            'Нет подключения к интернету. AI анализ недоступен в офлайн-режиме.',
        generatedAt: DateTime.now(),
      );
    }

    // 3. Check Cache
    final currentHash = _generateDataHash(
      monthTx: currentMonthData,
      monthlyIncome: monthlyIncome,
      budgetLimits: budgetLimits,
      customCategories: customCategories,
    );
    if (_cachedAnalysis != null &&
        _cacheTime != null &&
        _cacheDataHash == currentHash &&
        DateTime.now().difference(_cacheTime!) < _cacheDuration) {
      debugPrint('Returning cached AI analysis');
      return _cachedAnalysis!;
    }

    try {
      final prompts = _buildPrompts(
        now: now,
        currentMonthData: currentMonthData,
        allTransactions: transactions,
        monthlyIncome: monthlyIncome,
        budgetLimits: budgetLimits,
        customCategories: customCategories ?? [],
      );
      final analysis = await _fetchWithRetry(prompts.$1, prompts.$2);

      // Update cache
      _cachedAnalysis = analysis;
      _cacheTime = DateTime.now();
      _cacheDataHash = currentHash;

      return analysis;
    } catch (e, stackTrace) {
      debugPrint('AI Analysis Error: $e\n$stackTrace');

      if (e.toString().contains('SocketException') || e is SocketException) {
        return AiAnalysisResult(
          insights: [],
          summary: 'Ошибка сети. Проверьте интернет-соединение.',
          generatedAt: DateTime.now(),
        );
      }
      if (e.toString().contains('TimeoutException') || e is TimeoutException) {
        return AiAnalysisResult(
          insights: [],
          summary: 'Превышено время ожидания. Попробуйте позже.',
          generatedAt: DateTime.now(),
        );
      }
      return AiAnalysisResult(
        insights: [],
        summary:
            'Не удалось получить анализ: ${e.toString().replaceAll('Exception:', '').trim()}',
        generatedAt: DateTime.now(),
      );
    }
  }

  /// Builds the system and user prompts.
  /// Returns a record (systemPrompt, userPrompt).
  (String, String) _buildPrompts({
    required DateTime now,
    required List<TransactionEntity> currentMonthData,
    required List<TransactionEntity> allTransactions,
    double? monthlyIncome,
    Map<String, double>? budgetLimits,
    required List<CustomCategory> customCategories,
  }) {
    // --- System Prompt ---
    const systemPrompt = '''
You are a personal finance analyst.
The user is from Kazakhstan, currency is ₸ (tenge).

Your goal: provide 3-4 specific, measurable insights that can be acted upon within 7 days.

Strict rules:
- Do not make up facts. Use only the data provided.
- No generic phrases like "try to save" without a specific action.
- Each insight must contain numbers (₸, %, or days).
- If data is insufficient, honestly say "not enough data" and suggest what to add (e.g., limits/income).
- Write in English, be concise and to the point.

Return the response strictly in JSON (no Markdown, no comments) in this format:
{
  "insights": [
    {
      "title": "brief 3-7 words",
      "type": "tempo|overspend|budget|trend|category|income",
      "observed": "what you noticed (1 sentence with numbers)",
      "why": "why it matters (1 short sentence)",
      "action7d": "what to do in 7 days (1 specific action)",
      "impact": "expected effect (₸/%), or 'cannot estimate from data'"
    }
  ],
  "summary": "1 sentence: overall conclusion/warning"
}
''';

    // --- User Prompt (Data) ---
    final sb = StringBuffer();

    // Helper to avoid floating-point precision errors
    double roundMoney(double v) => (v * 100).round() / 100;

    double totalSpent = 0;
    final categoryTotals = <String, double>{};
    for (var t in currentMonthData) {
      totalSpent = roundMoney(totalSpent + t.amount);
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

    // Time calculations
    final daysInMonth = DateTime(now.year, now.month + 1, 0).day;
    final daysPassed = now.day;
    final daysLeft = daysInMonth - daysPassed;
    final avgDailySpend = daysPassed > 0 ? totalSpent / daysPassed : 0.0;
    final projectedTotal = roundMoney(avgDailySpend * daysInMonth);

    sb.writeln('Analysis Data (current month only):');
    sb.writeln('');
    sb.writeln(
      'Current Date: ${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}',
    );
    sb.writeln('Days Passed in Month: $daysPassed');
    sb.writeln('Days Left in Month: $daysLeft');
    sb.writeln('');
    sb.writeln('Summary:');
    sb.writeln('- TotalSpent: ${totalSpent.toStringAsFixed(0)} ₸');
    sb.writeln(
      '- AverageDailySpend: ${avgDailySpend.toStringAsFixed(0)} ₸/day',
    );
    sb.writeln(
      '- ProjectedTotalAtEndOfMonth: ${projectedTotal.toStringAsFixed(0)} ₸',
    );

    if (monthlyIncome != null && monthlyIncome > 0) {
      final spentPct = ((totalSpent / monthlyIncome) * 100);
      final incomeAlert = totalSpent > monthlyIncome;
      sb.writeln('');
      sb.writeln('Income:');
      sb.writeln('- MonthlyIncome: ${monthlyIncome.toStringAsFixed(0)} ₸');
      sb.writeln('- SpentPctOfIncome: ${spentPct.toStringAsFixed(1)}%');
      sb.writeln('- IncomeAlert: $incomeAlert');
      if (incomeAlert) {
        sb.writeln('⚠️ WARNING: Spending exceeds income!');
      }
    } else {
      sb.writeln('');
      sb.writeln('Income: Not specified');
    }

    sb.writeln('');
    sb.writeln('Categories (top 5):');
    final sortedCats =
        categoryTotals.entries.toList()
          ..sort((a, b) => b.value.compareTo(a.value));
    for (var i = 0; i < (sortedCats.length > 5 ? 5 : sortedCats.length); i++) {
      final entry = sortedCats[i];
      sb.writeln('- ${entry.key}: ${entry.value.toStringAsFixed(0)} ₸');
    }

    // Budget Comparison
    if (budgetLimits != null && budgetLimits.isNotEmpty) {
      sb.writeln('');
      sb.writeln('BudgetLimits:');
      categoryTotals.forEach((cat, spent) {
        if (budgetLimits.containsKey(cat)) {
          final limit = budgetLimits[cat]!;
          if (limit > 0) {
            final pct = ((spent / limit) * 100);
            sb.writeln(
              '- $cat: spent ${spent.toStringAsFixed(0)} ₸ / limit ${limit.toStringAsFixed(0)} ₸ / pct ${pct.toStringAsFixed(0)}%',
            );
          }
        }
      });
    } else {
      sb.writeln('');
      sb.writeln('BudgetLimits: Not set');
    }

    // Historical Comparison
    final prevMonth = now.month == 1 ? 12 : now.month - 1;
    final prevYear = now.month == 1 ? now.year - 1 : now.year;
    final prevMonthData =
        allTransactions
            .where((t) => t.date.year == prevYear && t.date.month == prevMonth)
            .toList();

    if (prevMonthData.isNotEmpty) {
      final prevTotal = prevMonthData.fold<double>(
        0.0,
        (sum, t) => roundMoney(sum + t.amount),
      );
      if (prevTotal > 0) {
        final change = ((totalSpent - prevTotal) / prevTotal * 100);
        sb.writeln('');
        sb.writeln('History:');
        sb.writeln('- LastMonthTotal: ${prevTotal.toStringAsFixed(0)} ₸');
        sb.writeln('- ChangeVsLastMonthPct: ${change.toStringAsFixed(1)}%');
      }
    } else {
      sb.writeln('');
      sb.writeln('History: No data for previous month');
    }

    sb.writeln('''

Task:
Generate 3-4 insights.
Priorities (in this order):
1) Urgent: if TotalSpent > MonthlyIncome or IncomeAlert=true.
2) Budgets: if pct >= 80% for any category — must have separate insight.
3) Spending pace: assess if current AverageDailySpend will lead to overspending by end of month (considering remaining days and income/budget if available).
4) Trend: if ChangeVsLastMonthPct absolute value > 15%, create insight and carefully ask "why".
5) Savings: suggest 1 practical step for KZ (limit delivery/taxi/coffee/subscriptions) — but only tied to top categories.

Important:
- If no income and no limits — create insight "add income/limits for precise control" and 2-3 insights on categories/pace.
''');

    return (systemPrompt, sb.toString());
  }

  Future<AiAnalysisResult> _fetchWithRetry(
    String systemPrompt,
    String userPrompt,
  ) async {
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
                  {'role': 'system', 'content': systemPrompt},
                  {'role': 'user', 'content': userPrompt},
                ],
                'temperature': 0.5,
                'max_completion_tokens': 600,
                'response_format': {'type': 'json_object'},
                'seed': 42,
              }),
            )
            .timeout(_requestTimeout);

        if (response.statusCode == 200) {
          final data = jsonDecode(utf8.decode(response.bodyBytes));
          final content = data['choices'][0]['message']['content'] as String;

          // Log raw response for debugging
          debugPrint('=== Groq AI Raw Response ===');
          debugPrint(content);
          debugPrint('============================');

          try {
            final jsonContent = jsonDecode(content) as Map<String, dynamic>;
            final result = AiAnalysisResult.fromJson(jsonContent);
            if (result.isValid) {
              return result;
            }
            // Invalid structure, throw to retry or return error
            throw Exception('Invalid AI response structure');
          } catch (parseError) {
            debugPrint('JSON Parse Error: $parseError');
            // If parsing fails on last attempt, return a fallback result
            if (i == _maxRetries - 1) {
              return AiAnalysisResult(
                insights: [],
                summary: 'Не удалось разобрать ответ AI. Попробуйте ещё раз.',
                generatedAt: DateTime.now(),
              );
            }
            // Otherwise, retry
            continue;
          }
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
