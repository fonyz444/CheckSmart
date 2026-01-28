import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../transactions/data/transaction_repository.dart';
import '../../transactions/domain/transaction_entity.dart';
import '../data/ai_repository.dart';
import '../../budget/data/budget_limit_repository.dart';
import '../../budget/domain/budget_limit.dart';
import '../../categories/data/custom_category_repository.dart';

/// Analytics screen matching the "Reports" design
class AnalyticsScreen extends ConsumerWidget {
  const AnalyticsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final transactionsAsync = ref.watch(transactionsProvider);

    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F7), // Light grey background
      body: SafeArea(
        child: CustomScrollView(
          slivers: [
            // Header
            const SliverToBoxAdapter(
              child: Padding(
                padding: EdgeInsets.fromLTRB(24, 24, 24, 16),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Отчеты',
                      style: TextStyle(
                        fontFamily: 'Inter',
                        fontSize: 28,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF1A1A1A),
                      ),
                    ),
                  ],
                ),
              ),
            ),

            // Content
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Column(
                  children: [
                    // AI Analyzer Card
                    transactionsAsync.when(
                      data:
                          (transactions) =>
                              _AqshaAIAnalyzerCard(transactions: transactions),
                      loading: () => const SizedBox(), // Wait for data
                      error: (_, __) => const SizedBox(),
                    ),
                    const SizedBox(height: 16),

                    // Charts
                    transactionsAsync.when(
                      data: (transactions) {
                        return Column(
                          children: [
                            _MonthlySpendVsBudgetChart(
                              transactions: transactions,
                            ),
                            const SizedBox(height: 16),
                            _MonthComparisonChart(transactions: transactions),
                            const SizedBox(height: 100), // Bottom padding
                          ],
                        );
                      },
                      loading:
                          () =>
                              const Center(child: CircularProgressIndicator()),
                      error:
                          (e, s) => Text(
                            'Error: $e',
                            style: const TextStyle(color: Colors.red),
                          ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _AqshaAIAnalyzerCard extends ConsumerStatefulWidget {
  final List<TransactionEntity> transactions;
  const _AqshaAIAnalyzerCard({required this.transactions});

  @override
  ConsumerState<_AqshaAIAnalyzerCard> createState() =>
      _AqshaAIAnalyzerCardState();
}

class _AqshaAIAnalyzerCardState extends ConsumerState<_AqshaAIAnalyzerCard> {
  bool _isLoading = false;

  Future<void> _analyze() async {
    setState(() => _isLoading = true);

    try {
      final repository = ref.read(aiRepositoryProvider);

      // Fetch active monthly budgets
      final budgetRepo = ref.read(budgetLimitRepositoryProvider);
      final budgets =
          budgetRepo
              .getAll()
              .where((l) => l.period == BudgetPeriod.month)
              .toList();

      final budgetMap = {
        for (var b in budgets) b.category.displayName: b.limitAmount,
      };

      // Fetch custom categories
      final customCategories = ref.read(customCategoriesProvider);

      final result = await repository.getSpendingAnalysis(
        widget.transactions,
        budgetLimits: budgetMap,
        customCategories: customCategories,
      );

      if (mounted) {
        _showResult(result);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error: $e')));
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  void _showResult(String result) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder:
          (context) => DraggableScrollableSheet(
            initialChildSize: 0.6,
            maxChildSize: 0.9,
            minChildSize: 0.4,
            expand: false,
            builder:
                (context, scrollController) => SingleChildScrollView(
                  controller: scrollController,
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Center(
                        child: Container(
                          width: 40,
                          height: 4,
                          decoration: BoxDecoration(
                            color: Colors.grey[300],
                            borderRadius: BorderRadius.circular(2),
                          ),
                        ),
                      ),
                      const SizedBox(height: 24),
                      Row(
                        children: [
                          const Icon(
                            Icons.auto_awesome,
                            color: Color(0xFF6C5CE7),
                          ),
                          const SizedBox(width: 8),
                          const Text(
                            'Aqsha AI Insights',
                            style: TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      Text(
                        result,
                        style: const TextStyle(
                          fontSize: 16,
                          height: 1.5,
                          color: Color(0xFF2C2C2C),
                        ),
                      ),
                      const SizedBox(height: 40),
                    ],
                  ),
                ),
          ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF6C5CE7).withOpacity(0.05),
            blurRadius: 20,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: const Color(0xFF6C5CE7).withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(
                  Icons.auto_awesome,
                  color: Color(0xFF6C5CE7),
                  size: 24,
                ),
              ),
              const SizedBox(width: 12),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Aqsha AI Analyzer',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF1A1A1A),
                    ),
                  ),
                  Text(
                    'SMART INSIGHTS',
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w600,
                      color: Colors.grey[400],
                      letterSpacing: 1.2,
                    ),
                  ),
                ],
              ),
              const Spacer(),
              GestureDetector(
                onTap: _isLoading ? null : _analyze,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 8,
                  ),
                  decoration: BoxDecoration(
                    color: const Color(0xFF6C5CE7).withOpacity(0.1),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child:
                      _isLoading
                          ? const SizedBox(
                            width: 12,
                            height: 12,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Color(0xFF6C5CE7),
                            ),
                          )
                          : const Text(
                            'Analyze',
                            style: TextStyle(
                              color: Color(0xFF6C5CE7),
                              fontWeight: FontWeight.w600,
                              fontSize: 12,
                            ),
                          ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Text(
            'Нажмите "Analyze" для получения персонализированных советов по расходам от Aqsha AI.',
            style: TextStyle(
              fontSize: 14,
              color: Colors.grey[600],
              fontStyle: FontStyle.italic,
              height: 1.4,
            ),
          ),
        ],
      ),
    );
  }
}

class _MonthlySpendVsBudgetChart extends StatelessWidget {
  final List<TransactionEntity> transactions;

  const _MonthlySpendVsBudgetChart({required this.transactions});

  @override
  Widget build(BuildContext context) {
    // Process data for the chart
    // For demo purposes, we'll create cumulative spending points for the current month
    final now = DateTime.now();
    final currentMonthTransactions =
        transactions.where((t) {
          return t.date.year == now.year && t.date.month == now.month;
        }).toList();

    // Sort by date
    currentMonthTransactions.sort((a, b) => a.date.compareTo(b.date));

    // Generate spots
    List<FlSpot> spots = [];

    // Group by day to make it smoother or just add points
    // Map<Day, Total>
    final dayTotals = <int, double>{};
    for (var t in currentMonthTransactions) {
      dayTotals[t.date.day] = (dayTotals[t.date.day] ?? 0) + t.amount;
    }

    // Cumulative
    double cumulativeVal = 0;
    // We want points from day 1 to today
    for (int i = 1; i <= now.day; i++) {
      if (dayTotals.containsKey(i)) {
        cumulativeVal += dayTotals[i]!;
      }
      // Only add spot if we have data or it's a significant point.
      spots.add(FlSpot(i.toDouble(), cumulativeVal));
    }

    if (spots.isEmpty) {
      spots.add(const FlSpot(0, 0));
    }

    // Budget line (Mock: 500,000 budget)
    final budget = 500000.0;

    // Spots for budget line
    // If spots is empty, budgetSpots also needs to be safe.
    final budgetSpots = [const FlSpot(1, 0), FlSpot(30, budget)];

    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Расходы vs Бюджет',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Color(0xFF1A1A1A),
            ),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              _LegendItem(color: const Color(0xFF00D09C), label: 'Расходы'),
              const SizedBox(width: 16),
              _LegendItem(
                color: const Color(0xFF6C5CE7),
                label: 'Бюджет (${NumberFormat.compact().format(budget)})',
                isDashed: true,
              ),
            ],
          ),
          const SizedBox(height: 24),
          AspectRatio(
            aspectRatio: 1.5,
            child: LineChart(
              LineChartData(
                gridData: FlGridData(
                  show: true,
                  drawVerticalLine: false,
                  horizontalInterval: budget / 4,
                  getDrawingHorizontalLine: (value) {
                    return FlLine(color: Colors.grey[100], strokeWidth: 1);
                  },
                ),
                titlesData: FlTitlesData(
                  show: true,
                  rightTitles: const AxisTitles(
                    sideTitles: SideTitles(showTitles: false),
                  ),
                  topTitles: const AxisTitles(
                    sideTitles: SideTitles(showTitles: false),
                  ),
                  bottomTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      reservedSize: 30,
                      interval: 7, // Show every week
                      getTitlesWidget: (value, meta) {
                        if (value < 1 || value > 31) {
                          return const SizedBox.shrink();
                        }
                        return Text(
                          '${value.toInt()} авг', // TODO: Dynamic month
                          style: TextStyle(
                            color: Colors.grey[400],
                            fontSize: 12,
                          ),
                        );
                      },
                    ),
                  ),
                  leftTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      reservedSize: 40,
                      getTitlesWidget: (value, meta) {
                        return Text(
                          NumberFormat.compact().format(value),
                          style: TextStyle(
                            color: Colors.grey[400],
                            fontSize: 12,
                          ),
                        );
                      },
                    ),
                  ),
                ),
                borderData: FlBorderData(show: false),
                minX: 1,
                maxX: 30, // Approx month end
                minY: 0,
                // Add some headroom
                maxY:
                    (spots.isNotEmpty ? spots.last.y : 0) > budget
                        ? (spots.last.y * 1.2)
                        : budget * 1.1,
                lineBarsData: [
                  // Budget Line (Dotted)
                  LineChartBarData(
                    spots: budgetSpots,
                    isCurved: false,
                    color: const Color(0xFF6C5CE7),
                    barWidth: 2,
                    isStrokeCapRound: true,
                    dotData: const FlDotData(show: false),
                    dashArray: [5, 5],
                  ),
                  // Spent Line
                  LineChartBarData(
                    spots: spots,
                    isCurved: true,
                    color: const Color(0xFF00D09C),
                    barWidth: 3,
                    isStrokeCapRound: true,
                    dotData: FlDotData(
                      show: true,
                      getDotPainter: (spot, percent, barData, index) {
                        // Only show dot on the last point
                        if (index == spots.length - 1) {
                          return FlDotCirclePainter(
                            radius: 4,
                            color: Colors.white,
                            strokeWidth: 3,
                            strokeColor: const Color(0xFF00D09C),
                          );
                        }
                        return FlDotCirclePainter(
                          radius: 0,
                          color: Colors.transparent,
                        );
                      },
                    ),
                    belowBarData: BarAreaData(show: false),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _MonthComparisonChart extends StatelessWidget {
  final List<TransactionEntity> transactions;

  const _MonthComparisonChart({required this.transactions});

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    // Current Month Data
    final currentMonthSpots = _getMonthlyCumulative(transactions, now);

    // Last Month Data
    final lastMonthDate = DateTime(now.year, now.month - 1, 1);
    final lastMonthSpots = _getMonthlyCumulative(transactions, lastMonthDate);

    // Max Y for scale
    double maxY = 0;
    if (currentMonthSpots.isNotEmpty) maxY = currentMonthSpots.last.y;
    if (lastMonthSpots.isNotEmpty && lastMonthSpots.last.y > maxY) {
      maxY = lastMonthSpots.last.y;
    }
    if (maxY == 0) maxY = 10000;

    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Этот месяц vs Прошлый',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Color(0xFF1A1A1A),
            ),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              _LegendItem(color: const Color(0xFF6C5CE7), label: 'Этот месяц'),
              const SizedBox(width: 16),
              _LegendItem(
                color: Colors.grey[300]!,
                label: 'Прошлый',
                textColor: Colors.grey[500],
              ),
            ],
          ),
          const SizedBox(height: 24),
          AspectRatio(
            aspectRatio: 1.5,
            child: LineChart(
              LineChartData(
                gridData: FlGridData(
                  show: true,
                  drawVerticalLine: false,
                  getDrawingHorizontalLine: (value) {
                    return FlLine(color: Colors.grey[100], strokeWidth: 1);
                  },
                ),
                titlesData: FlTitlesData(
                  show: true,
                  rightTitles: const AxisTitles(
                    sideTitles: SideTitles(showTitles: false),
                  ),
                  topTitles: const AxisTitles(
                    sideTitles: SideTitles(showTitles: false),
                  ),
                  bottomTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      reservedSize: 30,
                      interval: 7,
                      getTitlesWidget: (value, meta) {
                        if (value < 1 || value > 31) {
                          return const SizedBox.shrink();
                        }
                        return Text(
                          '${value.toInt()}',
                          style: TextStyle(
                            color: Colors.grey[400],
                            fontSize: 12,
                          ),
                        );
                      },
                    ),
                  ),
                  leftTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      reservedSize: 40,
                      getTitlesWidget: (value, meta) {
                        return Text(
                          NumberFormat.compact().format(value),
                          style: TextStyle(
                            color: Colors.grey[400],
                            fontSize: 12,
                          ),
                        );
                      },
                    ),
                  ),
                ),
                borderData: FlBorderData(show: false),
                minX: 1,
                maxX: 30,
                minY: 0,
                maxY: maxY * 1.1,
                lineBarsData: [
                  // Last Month
                  LineChartBarData(
                    spots:
                        lastMonthSpots.isEmpty
                            ? [const FlSpot(0, 0)]
                            : lastMonthSpots,
                    isCurved: true,
                    color: Colors.grey[300],
                    barWidth: 3,
                    isStrokeCapRound: true,
                    dotData: const FlDotData(show: false),
                  ),
                  // This Month
                  LineChartBarData(
                    spots:
                        currentMonthSpots.isEmpty
                            ? [const FlSpot(0, 0)]
                            : currentMonthSpots,
                    isCurved: true,
                    color: const Color(0xFF6C5CE7),
                    barWidth: 3,
                    isStrokeCapRound: true,
                    dotData: const FlDotData(show: false),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  List<FlSpot> _getMonthlyCumulative(
    List<TransactionEntity> allTransactions,
    DateTime date,
  ) {
    final transactionsInMonth =
        allTransactions.where((t) {
          return t.date.year == date.year && t.date.month == date.month;
        }).toList();

    transactionsInMonth.sort((a, b) => a.date.compareTo(b.date));

    List<FlSpot> spots = [];
    double cumulative = 0;
    final dayTotals = <int, double>{};

    for (var t in transactionsInMonth) {
      dayTotals[t.date.day] = (dayTotals[t.date.day] ?? 0) + t.amount;
    }

    // We only go up to today if it's current month, else end of month
    final isCurrentMonth =
        date.year == DateTime.now().year && date.month == DateTime.now().month;
    final endDay = isCurrentMonth ? DateTime.now().day : 31;

    for (int i = 1; i <= endDay; i++) {
      if (dayTotals.containsKey(i)) {
        cumulative += dayTotals[i]!;
      }
      spots.add(FlSpot(i.toDouble(), cumulative));
    }

    if (spots.isEmpty) spots.add(const FlSpot(1, 0));

    return spots;
  }
}

class _LegendItem extends StatelessWidget {
  final Color color;
  final String label;
  final bool isDashed;
  final Color? textColor;

  const _LegendItem({
    required this.color,
    required this.label,
    this.isDashed = false,
    this.textColor,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 12,
          height: 2,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(1),
          ),
        ),
        if (isDashed) ...[
          const SizedBox(width: 2),
          Container(
            width: 12,
            height: 2,
            decoration: BoxDecoration(
              color: color,
              borderRadius: BorderRadius.circular(1),
            ),
          ),
        ],
        const SizedBox(width: 8),
        Text(
          label,
          style: TextStyle(
            color: textColor ?? const Color(0xFF1A1A1A),
            fontSize: 12,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }
}
