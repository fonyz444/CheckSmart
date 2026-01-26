import 'dart:convert';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;

import '../../transactions/domain/transaction_entity.dart';

/// Provider for the AI Repository
final aiRepositoryProvider = Provider<AiRepository>((ref) {
  return AiRepository();
});

class AiRepository {
  // Secured API key from .env file
  static String get _apiKey => dotenv.env['GROQ_API_KEY'] ?? '';
  static const _baseUrl = 'https://api.groq.com/openai/v1/chat/completions';
  static const _model = 'llama-3.3-70b-versatile';

  Future<String> getSpendingAnalysis(
    List<TransactionEntity> transactions,
  ) async {
    if (transactions.isEmpty) {
      return 'Нет данных о транзакциях для анализа.';
    }

    try {
      final sb = StringBuffer();
      sb.writeln(
        'Analyze these financial transactions for a user in Kazakhstan (currency Tenge ₸).',
      );
      sb.writeln(
        'Provide 3 short, actionable, and personalized tips to save money or manage budget better.',
      );
      sb.writeln('Keep the tone friendly and professional. Answer in Russian.');
      sb.writeln('Data:');

      final now = DateTime.now();
      final currentMonth =
          transactions
              .where(
                (t) => t.date.year == now.year && t.date.month == now.month,
              )
              .toList();

      double totalSpent = 0;
      final categoryTotals = <String, double>{};

      for (var t in currentMonth) {
        totalSpent += t.amount;
        final catName = t.category.displayName;
        categoryTotals[catName] = (categoryTotals[catName] ?? 0) + t.amount;
      }

      sb.writeln('Total spent this month: ${totalSpent.toStringAsFixed(0)} ₸');
      sb.writeln('Breakdown by category:');
      categoryTotals.forEach((key, value) {
        sb.writeln('- $key: ${value.toStringAsFixed(0)} ₸');
      });

      final response = await http.post(
        Uri.parse(_baseUrl),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $_apiKey',
        },
        body: jsonEncode({
          'model': _model,
          'messages': [
            {'role': 'user', 'content': sb.toString()},
          ],
          'temperature': 0.7,
        }),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(utf8.decode(response.bodyBytes));
        return data['choices'][0]['message']['content'] as String;
      } else {
        return 'Ошибка Groq API: ${response.statusCode} - ${response.body}';
      }
    } catch (e) {
      return 'Ошибка сети: $e';
    }
  }
}
