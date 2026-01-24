import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../core/constants.dart';
import '../../transactions/data/transaction_repository.dart';
import '../../transactions/domain/transaction_entity.dart';

/// Analytics screen with spending breakdown
class AnalyticsScreen extends ConsumerWidget {
  const AnalyticsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final transactionsAsync = ref.watch(transactionsProvider);
    final monthlyTotal = ref.watch(monthlyTotalProvider);

    return SafeArea(
      child: CustomScrollView(
        slivers: [
          // Header
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'Мой Баланс',
                        style: TextStyle(color: Colors.white70, fontSize: 16),
                      ),
                      IconButton(
                        icon: const Icon(Icons.close, color: Colors.white54),
                        onPressed: () {},
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),

                  // Large balance
                  FittedBox(
                    fit: BoxFit.scaleDown,
                    alignment: Alignment.centerLeft,
                    child: Text(
                      NumberFormat.currency(
                        locale: 'ru',
                        symbol: '₸',
                        decimalDigits: 0,
                      ).format(monthlyTotal),
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 42,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),

                  const SizedBox(height: 12),

                  // Percentage change badge
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: const Color(0xFF00D09C).withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.trending_down,
                          color: Color(0xFF00D09C),
                          size: 16,
                        ),
                        SizedBox(width: 4),
                        Text(
                          'Бюджет',
                          style: TextStyle(
                            color: Color(0xFF00D09C),
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 32),

                  // Spending this month section
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Расходы ${DateFormat.MMMM('ru').format(DateTime.now())}',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 18,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      Text(
                        NumberFormat.currency(
                          locale: 'ru',
                          symbol: '₸',
                          decimalDigits: 0,
                        ).format(monthlyTotal),
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.6),
                          fontSize: 14,
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 12),

                  // Progress bar
                  _SpendingProgressBar(spent: monthlyTotal),

                  const SizedBox(height: 32),

                  // Category breakdown header
                  const Text(
                    'По категориям',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
          ),

          // Category breakdown list
          transactionsAsync.when(
            data: (transactions) {
              final categoryTotals = <ExpenseCategory, double>{};
              for (final t in transactions) {
                categoryTotals[t.category] =
                    (categoryTotals[t.category] ?? 0) + t.amount;
              }

              final sorted =
                  categoryTotals.entries.toList()
                    ..sort((a, b) => b.value.compareTo(a.value));

              if (sorted.isEmpty) {
                return const SliverToBoxAdapter(
                  child: Padding(
                    padding: EdgeInsets.all(40),
                    child: Center(
                      child: Text(
                        'Нет данных для аналитики',
                        style: TextStyle(color: Colors.white54),
                      ),
                    ),
                  ),
                );
              }

              return SliverList(
                delegate: SliverChildBuilderDelegate((context, index) {
                  final entry = sorted[index];
                  final total = categoryTotals.values.fold<double>(
                    0,
                    (a, b) => a + b,
                  );
                  final percentage =
                      total > 0 ? (entry.value / total * 100) : 0;

                  return _CategoryAnalyticsTile(
                    category: entry.key,
                    amount: entry.value,
                    percentage: percentage.toDouble(),
                    colorIndex: index,
                  );
                }, childCount: sorted.length),
              );
            },
            loading:
                () => const SliverFillRemaining(
                  child: Center(
                    child: CircularProgressIndicator(color: Color(0xFF00D09C)),
                  ),
                ),
            error:
                (e, _) => SliverToBoxAdapter(
                  child: Text(
                    'Error: $e',
                    style: const TextStyle(color: Colors.red),
                  ),
                ),
          ),

          // Bottom padding
          const SliverToBoxAdapter(child: SizedBox(height: 100)),
        ],
      ),
    );
  }
}

class _SpendingProgressBar extends StatelessWidget {
  final double spent;

  const _SpendingProgressBar({required this.spent});

  @override
  Widget build(BuildContext context) {
    // For demo, assume a budget of 500,000 tenge
    const budget = 500000.0;
    final progress = (spent / budget).clamp(0.0, 1.0);

    return Column(
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: LinearProgressIndicator(
            value: progress,
            backgroundColor: const Color(0xFF2A2A2A),
            valueColor: const AlwaysStoppedAnimation<Color>(Color(0xFF00D09C)),
            minHeight: 8,
          ),
        ),
      ],
    );
  }
}

class _CategoryAnalyticsTile extends StatelessWidget {
  final ExpenseCategory category;
  final double amount;
  final double percentage;
  final int colorIndex;

  const _CategoryAnalyticsTile({
    required this.category,
    required this.amount,
    required this.percentage,
    required this.colorIndex,
  });

  Color get _color {
    const colors = [
      Color(0xFF6C5CE7),
      Color(0xFF00D09C),
      Color(0xFF00B4D8),
      Color(0xFFFF6B6B),
      Color(0xFFFFA94D),
      Color(0xFFE056FD),
    ];
    return colors[colorIndex % colors.length];
  }

  @override
  Widget build(BuildContext context) {
    final currencyFormat = NumberFormat.currency(
      locale: 'ru',
      symbol: '₸',
      decimalDigits: 0,
    );

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 6),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF1E1E1E),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          // Category icon with colored background
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: _color.withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Center(
              child: Text(category.emoji, style: const TextStyle(fontSize: 22)),
            ),
          ),
          const SizedBox(width: 14),
          // Name and percentage
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  category.displayName,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 15,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 6),
                // Mini progress bar
                ClipRRect(
                  borderRadius: BorderRadius.circular(2),
                  child: LinearProgressIndicator(
                    value: percentage / 100,
                    backgroundColor: const Color(0xFF2A2A2A),
                    valueColor: AlwaysStoppedAnimation<Color>(_color),
                    minHeight: 4,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          // Amount and percentage
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                currencyFormat.format(amount),
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
              Text(
                '${percentage.toStringAsFixed(0)}%',
                style: TextStyle(
                  color: _color,
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
