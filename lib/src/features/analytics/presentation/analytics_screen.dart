import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../core/app_theme.dart';
import '../../../core/constants.dart';
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
                      'Reports',
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
                            _MonthlyExpensesPieChart(
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
            'Press "Analyze" to get personalized expense insights from CheckSmart.',
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

class _MonthlyExpensesPieChart extends ConsumerStatefulWidget {
  final List<TransactionEntity> transactions;

  const _MonthlyExpensesPieChart({required this.transactions});

  @override
  ConsumerState<_MonthlyExpensesPieChart> createState() =>
      _MonthlyExpensesPieChartState();
}

class _MonthlyExpensesPieChartState
    extends ConsumerState<_MonthlyExpensesPieChart> {
  int _touchedIndex = -1;

  @override
  Widget build(BuildContext context) {
    final customCategories = ref.watch(customCategoriesProvider);
    final now = DateTime.now();

    // 1. Filter transactions for current month
    final currentMonthTransactions =
        widget.transactions.where((t) {
          return t.date.year == now.year && t.date.month == now.month;
        }).toList();

    // 2. Group by Category
    final categoryTotals = <String, double>{};
    final categoryInfo = <String, Map<String, dynamic>>{};

    for (var t in currentMonthTransactions) {
      String key;
      String name;
      String emoji;
      Color color;

      if (t.customCategoryId != null) {
        key = t.customCategoryId!;
        final customCat =
            customCategories.where((c) => c.id == key).firstOrNull;
        name = customCat?.name ?? 'Custom';
        emoji = customCat?.emoji ?? '📁';
        color = Color(customCat?.color ?? 0xFF6C5CE7); // Custom category color
      } else {
        key = t.category.name;
        name = t.category.displayName;
        emoji = t.category.emoji;
        color = AppTheme.getCategoryColor(t.category);
      }

      categoryTotals[key] = (categoryTotals[key] ?? 0) + t.amount;
      categoryInfo[key] = {'name': name, 'emoji': emoji, 'color': color};
    }

    final totalSpent = categoryTotals.values.fold(0.0, (sum, val) => sum + val);

    // Prepare sections
    final sortedKeys =
        categoryTotals.keys.toList()
          ..sort((a, b) => categoryTotals[b]!.compareTo(categoryTotals[a]!));

    // Colors for chart (if multiple custom categories, maybe vary basic color?)
    // For now using defined colors.

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
            'Monthly Expenses',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Color(0xFF1A1A1A),
            ),
          ),
          const SizedBox(height: 32),
          SizedBox(
            height: 250,
            child: Stack(
              children: [
                PieChart(
                  PieChartData(
                    pieTouchData: PieTouchData(
                      touchCallback: (FlTouchEvent event, pieTouchResponse) {
                        setState(() {
                          if (!event.isInterestedForInteractions ||
                              pieTouchResponse == null ||
                              pieTouchResponse.touchedSection == null) {
                            _touchedIndex = -1;
                            return;
                          }
                          _touchedIndex =
                              pieTouchResponse
                                  .touchedSection!
                                  .touchedSectionIndex;
                        });
                      },
                    ),
                    borderData: FlBorderData(show: false),
                    sectionsSpace: 2, // Gap between sections
                    centerSpaceRadius: 80, // Donut hole size
                    sections: _showingSections(
                      sortedKeys,
                      categoryTotals,
                      categoryInfo,
                      totalSpent,
                    ),
                  ),
                ),
                // Center info
                Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (_touchedIndex != -1 &&
                          _touchedIndex < sortedKeys.length) ...[
                        Text(
                          categoryInfo[sortedKeys[_touchedIndex]]!['emoji'],
                          style: const TextStyle(fontSize: 28),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          categoryInfo[sortedKeys[_touchedIndex]]!['name'],
                          style: const TextStyle(
                            fontSize: 14,
                            color: Color(0xFF6B7280),
                            fontWeight: FontWeight.w500,
                          ),
                          textAlign: TextAlign.center,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '${categoryTotals[sortedKeys[_touchedIndex]]!.toStringAsFixed(0)} ₸',
                          style: const TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF1A1A1A),
                          ),
                        ),
                      ] else ...[
                        const Icon(
                          Icons.account_balance_wallet_outlined,
                          size: 32,
                          color: Color(0xFF9CA3AF),
                        ),
                        const SizedBox(height: 8),
                        const Text(
                          'Total',
                          style: TextStyle(
                            fontSize: 14,
                            color: Color(0xFF6B7280),
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '${totalSpent.toStringAsFixed(0)} ₸',
                          style: const TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF1A1A1A),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          // Optional: Legend or List below if needed, but per request pie chart logic is main
        ],
      ),
    );
  }

  List<PieChartSectionData> _showingSections(
    List<String> sortedKeys,
    Map<String, double> categoryTotals,
    Map<String, Map<String, dynamic>> categoryInfo,
    double totalSpent,
  ) {
    return List.generate(sortedKeys.length, (i) {
      final isTouched = i == _touchedIndex;
      final key = sortedKeys[i];
      final amount = categoryTotals[key]!;
      final info = categoryInfo[key]!;

      // Calculate percentage for sizing if needed, currently fixed radius
      final radius = isTouched ? 30.0 : 25.0; // Slightly larger on touch

      return PieChartSectionData(
        color: info['color'],
        value: amount,
        title: '', // No title on chart itself (clean look)
        radius: radius,
        titleStyle: const TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.bold,
          color: Colors.white,
        ),
        badgeWidget: isTouched ? _Badge(info['emoji']) : null,
        badgePositionPercentageOffset: 1.3,
      );
    });
  }
}

class _Badge extends StatelessWidget {
  final String emoji;
  const _Badge(this.emoji);

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 28,
      height: 28,
      decoration: BoxDecoration(
        color: Colors.white,
        shape: BoxShape.circle,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 4,
            offset: const Offset(0, 2),
            spreadRadius: 1,
          ),
        ],
      ),
      child: Center(child: Text(emoji, style: const TextStyle(fontSize: 14))),
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
            'This Month vs Last Month',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Color(0xFF1A1A1A),
            ),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              _LegendItem(color: const Color(0xFF6C5CE7), label: 'This Month'),
              const SizedBox(width: 16),
              _LegendItem(
                color: Colors.grey[300]!,
                label: 'Last Month',
                textColor: Colors.grey[500],
              ),
            ],
          ),
          const SizedBox(height: 24),
          AspectRatio(
            aspectRatio: 1.5,
            child: LineChart(
              LineChartData(
                lineTouchData: LineTouchData(
                  touchTooltipData: LineTouchTooltipData(
                    getTooltipItems: (touchedSpots) {
                      // Sort spots so "This Month" (index 1) is usually first or consistent
                      touchedSpots.sort(
                        (a, b) => b.barIndex.compareTo(a.barIndex),
                      );

                      return touchedSpots.map((spot) {
                        final isThisMonth = spot.barIndex == 1;
                        final label = isThisMonth ? 'Current: ' : 'Previous: ';
                        final value = NumberFormat.currency(
                          symbol: '₸',
                          decimalDigits: 0,
                          locale: 'en_US',
                        ).format(spot.y);

                        return LineTooltipItem(
                          // Rich text for the tooltip
                          '',
                          const TextStyle(),
                          children: [
                            TextSpan(
                              text: '$label\n',
                              style: TextStyle(
                                color: Colors.grey[400],
                                fontSize: 10,
                                fontWeight: FontWeight.normal,
                              ),
                            ),
                            TextSpan(
                              text: value,
                              style: TextStyle(
                                color:
                                    isThisMonth
                                        ? Colors.white
                                        : Colors.grey[300],
                                fontSize: 14,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                          textAlign: TextAlign.left,
                        );
                      }).toList();
                    },
                    fitInsideHorizontally: true,
                    fitInsideVertically: true,
                  ),
                  getTouchedSpotIndicator: (
                    LineChartBarData barData,
                    List<int> spotIndexes,
                  ) {
                    return spotIndexes.map((spotIndex) {
                      return TouchedSpotIndicatorData(
                        FlLine(
                          color: const Color(0xFF6C5CE7).withOpacity(0.5),
                          strokeWidth: 2,
                          dashArray: [5, 5],
                        ),
                        FlDotData(
                          getDotPainter: (spot, percent, barData, index) {
                            return FlDotCirclePainter(
                              radius: 6,
                              color: Colors.white,
                              strokeWidth: 3,
                              strokeColor: const Color(0xFF6C5CE7),
                            );
                          },
                        ),
                      );
                    }).toList();
                  },
                ),
                gridData: FlGridData(
                  show: true,
                  drawVerticalLine: false,
                  getDrawingHorizontalLine: (value) {
                    return FlLine(
                      color: Colors.grey[200],
                      strokeWidth: 1,
                      dashArray: [5, 5],
                    );
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
                    curveSmoothness: 0.35,
                    color: Colors.grey[200],
                    barWidth: 2,
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
                    curveSmoothness: 0.35,
                    color: const Color(0xFF6C5CE7),
                    barWidth: 4,
                    isStrokeCapRound: true,
                    dotData: const FlDotData(show: false),
                    belowBarData: BarAreaData(
                      show: true,
                      gradient: LinearGradient(
                        colors: [
                          const Color(0xFF6C5CE7).withOpacity(0.3),
                          const Color(0xFF6C5CE7).withOpacity(0.0),
                        ],
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                      ),
                    ),
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
  final Color? textColor;

  const _LegendItem({required this.color, required this.label, this.textColor});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 12,
          height:
              12, // Changed to square/circle for cleaner look or keep line? Kept line logic but maybe cleaner dot?
          // The old one was a line. Let's make it a circle for standard legend or keep line.
          // The request was for "Pie Chart style". Usually dots.
          // But I'll stick to minimizing changes to _LegendItem unless broken.
          // Wait, the previous code was generating a line.
          // Let's just remove isDashed logic.
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(2),
          ),
        ),
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
