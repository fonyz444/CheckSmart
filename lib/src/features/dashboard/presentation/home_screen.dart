import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../core/constants.dart';
import '../../../core/app_theme.dart';
import '../../transactions/data/transaction_repository.dart';
import '../../receipt_processing/presentation/receipt_scan_controller.dart';
import '../../categories/data/custom_category_repository.dart';

/// Provider for category totals (weekly categories)
final weeklyCategoryTotalsProvider = Provider<Map<ExpenseCategory, double>>((
  ref,
) {
  final transactionsAsync = ref.watch(transactionsProvider);

  return transactionsAsync.when(
    data: (transactions) {
      final now = DateTime.now();
      // Start of current week (Monday)
      final weekDay = now.weekday;
      final startOfWeek = now.subtract(Duration(days: weekDay - 1));
      final startDate = DateTime(
        startOfWeek.year,
        startOfWeek.month,
        startOfWeek.day,
      );

      final totals = <ExpenseCategory, double>{};

      for (final t in transactions) {
        if (t.date.isAfter(startDate) || _isSameDay(t.date, startDate)) {
          totals[t.category] = (totals[t.category] ?? 0) + t.amount;
        }
      }

      return totals;
    },
    loading: () => <ExpenseCategory, double>{},
    error: (_, __) => <ExpenseCategory, double>{},
  );
});

/// Provider for category totals (monthly categories)
final monthlyCategoryTotalsProvider = Provider<Map<ExpenseCategory, double>>((
  ref,
) {
  final transactionsAsync = ref.watch(transactionsProvider);

  return transactionsAsync.when(
    data: (transactions) {
      final now = DateTime.now();
      final startOfMonth = DateTime(now.year, now.month, 1);

      final totals = <ExpenseCategory, double>{};

      for (final t in transactions) {
        if (t.date.isAfter(startOfMonth) || _isSameDay(t.date, startOfMonth)) {
          totals[t.category] = (totals[t.category] ?? 0) + t.amount;
        }
      }

      return totals;
    },
    loading: () => <ExpenseCategory, double>{},
    error: (_, __) => <ExpenseCategory, double>{},
  );
});

bool _isSameDay(DateTime a, DateTime b) {
  return a.year == b.year && a.month == b.month && a.day == b.day;
}

/// Provider for custom category totals (weekly)
final weeklyCustomCategoryTotalsProvider = Provider<Map<String, double>>((ref) {
  final transactionsAsync = ref.watch(transactionsProvider);

  return transactionsAsync.when(
    data: (transactions) {
      final now = DateTime.now();
      final weekDay = now.weekday;
      final startOfWeek = now.subtract(Duration(days: weekDay - 1));
      final startDate = DateTime(
        startOfWeek.year,
        startOfWeek.month,
        startOfWeek.day,
      );

      final totals = <String, double>{};

      for (final t in transactions) {
        if (t.customCategoryId != null &&
            (t.date.isAfter(startDate) || _isSameDay(t.date, startDate))) {
          totals[t.customCategoryId!] =
              (totals[t.customCategoryId!] ?? 0) + t.amount;
        }
      }

      return totals;
    },
    loading: () => <String, double>{},
    error: (_, __) => <String, double>{},
  );
});

/// Provider for custom category totals (monthly)
final monthlyCustomCategoryTotalsProvider = Provider<Map<String, double>>((
  ref,
) {
  final transactionsAsync = ref.watch(transactionsProvider);

  return transactionsAsync.when(
    data: (transactions) {
      final now = DateTime.now();
      final startOfMonth = DateTime(now.year, now.month, 1);

      final totals = <String, double>{};

      for (final t in transactions) {
        if (t.customCategoryId != null &&
            (t.date.isAfter(startOfMonth) ||
                _isSameDay(t.date, startOfMonth))) {
          totals[t.customCategoryId!] =
              (totals[t.customCategoryId!] ?? 0) + t.amount;
        }
      }

      return totals;
    },
    loading: () => <String, double>{},
    error: (_, __) => <String, double>{},
  );
});

/// Home screen with budget tracking and expense categories
class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  String _selectedPeriod = 'Jan 23 - Jan 29';

  @override
  Widget build(BuildContext context) {
    final weeklyCategoryTotals = ref.watch(weeklyCategoryTotalsProvider);
    final monthlyCategoryTotals = ref.watch(monthlyCategoryTotalsProvider);
    final weeklyCustomTotals = ref.watch(weeklyCustomCategoryTotalsProvider);
    final monthlyCustomTotals = ref.watch(monthlyCustomCategoryTotalsProvider);
    final customCategories = ref.watch(customCategoriesProvider);

    // Calculate totals (including custom categories)
    final totalMonthlySpent =
        monthlyCategoryTotals.values.fold<double>(
          0,
          (sum, amount) => sum + amount,
        ) +
        monthlyCustomTotals.values.fold<double>(
          0,
          (sum, amount) => sum + amount,
        );

    final totalWeeklySpent =
        weeklyCategoryTotals.values.fold<double>(
          0,
          (sum, amount) => sum + amount,
        ) +
        weeklyCustomTotals.values.fold<double>(
          0,
          (sum, amount) => sum + amount,
        );

    // Get sorted categories for display
    final monthlySorted =
        monthlyCategoryTotals.entries.toList()
          ..sort((a, b) => b.value.compareTo(a.value));
    final weeklySorted =
        weeklyCategoryTotals.entries.toList()
          ..sort((a, b) => b.value.compareTo(a.value));

    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: CustomScrollView(
          slivers: [
            // Header with AI assistant and period selector
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
                child: Row(
                  children: [
                    // AI Assistant Badge
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: const Color(0xFF6C5CE7),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Text(
                            'Aqsha AI',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 13,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(width: 6),
                          Icon(Icons.bolt, color: Colors.amber[300], size: 16),
                        ],
                      ),
                    ),
                    const Spacer(),
                    // Period Selector
                    InkWell(
                      onTap: _showPeriodSelector,
                      borderRadius: BorderRadius.circular(8),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 8,
                        ),
                        decoration: BoxDecoration(
                          border: Border.all(
                            color: const Color(0xFFE5E7EB),
                            width: 1,
                          ),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              _selectedPeriod,
                              style: const TextStyle(
                                color: Color(0xFF1A1A1A),
                                fontSize: 13,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                            const SizedBox(width: 4),
                            const Icon(
                              Icons.keyboard_arrow_down,
                              size: 18,
                              color: Color(0xFF6B7280),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),

            // Weekly Section
            if (weeklySorted.isNotEmpty || weeklyCustomTotals.isNotEmpty)
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'Weekly',
                                style: TextStyle(
                                  color: Color(0xFF9CA3AF),
                                  fontSize: 13,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                '${_getDaysLeftInWeek()} days left',
                                style: const TextStyle(
                                  color: Color(0xFF1A1A1A),
                                  fontSize: 15,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              const Text(
                                'TOTAL SPENT',
                                style: TextStyle(
                                  color: Color(0xFF9CA3AF),
                                  fontSize: 11,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                _formatAmount(totalWeeklySpent),
                                style: const TextStyle(
                                  color: Color(0xFF1A1A1A),
                                  fontSize: 15,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      // Weekly Categories
                      ...weeklySorted.map(
                        (entry) => Padding(
                          padding: const EdgeInsets.only(bottom: 8),
                          child: _TransactionCategoryRow(
                            icon: entry.key.emoji,
                            name: entry.key.displayName,
                            amount: entry.value,
                            color: _getCategoryColor(entry.key),
                          ),
                        ),
                      ),
                      // Weekly Custom Categories
                      ...weeklyCustomTotals.entries.map((entry) {
                        final customCat =
                            customCategories
                                .where((c) => c.id == entry.key)
                                .firstOrNull;
                        if (customCat == null) return const SizedBox.shrink();
                        return Padding(
                          padding: const EdgeInsets.only(bottom: 8),
                          child: _TransactionCategoryRow(
                            icon: customCat.emoji,
                            name: customCat.name,
                            amount: entry.value,
                            color: const Color(0xFF6C5CE7),
                          ),
                        );
                      }),
                      const SizedBox(height: 24),
                    ],
                  ),
                ),
              ),

            // Monthly Section
            if (monthlySorted.isNotEmpty || monthlyCustomTotals.isNotEmpty)
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'Monthly',
                                style: TextStyle(
                                  color: Color(0xFF9CA3AF),
                                  fontSize: 13,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                '${_getDaysLeftInMonth()} days left',
                                style: const TextStyle(
                                  color: Color(0xFF1A1A1A),
                                  fontSize: 15,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              const Text(
                                'TOTAL SPENT',
                                style: TextStyle(
                                  color: Color(0xFF9CA3AF),
                                  fontSize: 11,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                _formatAmount(totalMonthlySpent),
                                style: const TextStyle(
                                  color: Color(0xFF1A1A1A),
                                  fontSize: 15,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      // Monthly Categories
                      ...monthlySorted.map(
                        (entry) => Padding(
                          padding: const EdgeInsets.only(bottom: 8),
                          child: _TransactionCategoryRow(
                            icon: entry.key.emoji,
                            name: entry.key.displayName,
                            amount: entry.value,
                            color: _getCategoryColor(entry.key),
                          ),
                        ),
                      ),
                      // Monthly Custom Categories
                      ...monthlyCustomTotals.entries.map((entry) {
                        final customCat =
                            customCategories
                                .where((c) => c.id == entry.key)
                                .firstOrNull;
                        if (customCat == null) return const SizedBox.shrink();
                        return Padding(
                          padding: const EdgeInsets.only(bottom: 8),
                          child: _TransactionCategoryRow(
                            icon: customCat.emoji,
                            name: customCat.name,
                            amount: entry.value,
                            color: const Color(0xFF6C5CE7),
                          ),
                        );
                      }),
                      const SizedBox(height: 24),
                    ],
                  ),
                ),
              ),

            // Empty state if no transactions
            if (weeklySorted.isEmpty && monthlySorted.isEmpty)
              SliverFillRemaining(
                child: Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Container(
                        width: 80,
                        height: 80,
                        decoration: BoxDecoration(
                          color: const Color(0xFFF3F4F6),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: const Icon(
                          Icons.receipt_long_outlined,
                          size: 40,
                          color: Color(0xFF9CA3AF),
                        ),
                      ),
                      const SizedBox(height: 20),
                      const Text(
                        'Нет отсканированных чеков',
                        style: TextStyle(
                          color: Color(0xFF6B7280),
                          fontSize: 18,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      const SizedBox(height: 8),
                      const Text(
                        'Нажмите + чтобы отсканировать первый чек',
                        style: TextStyle(
                          color: Color(0xFF9CA3AF),
                          fontSize: 14,
                        ),
                      ),
                    ],
                  ),
                ),
              ),

            // Add new category button (only if there are transactions)
            if (monthlySorted.isNotEmpty)
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: TextButton(
                    onPressed: () {
                      // TODO: Implement add category
                    },
                    style: TextButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                    ),
                    child: const Text(
                      'Add new category',
                      style: TextStyle(
                        color: Color(0xFF9CA3AF),
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ),
              ),

            // Hidden categories link (only if there are transactions)
            if (monthlySorted.isNotEmpty)
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 20,
                    vertical: 8,
                  ),
                  child: InkWell(
                    onTap: () {
                      // TODO: Show hidden categories
                    },
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.visibility_off_outlined,
                          size: 16,
                          color: const Color(0xFF9CA3AF),
                        ),
                        const SizedBox(width: 6),
                        const Text(
                          'Hidden categories',
                          style: TextStyle(
                            color: Color(0xFF9CA3AF),
                            fontSize: 13,
                          ),
                        ),
                        const SizedBox(width: 4),
                        Icon(
                          Icons.chevron_right,
                          size: 16,
                          color: const Color(0xFF9CA3AF),
                        ),
                      ],
                    ),
                  ),
                ),
              ),

            // Bottom padding for nav bar
            const SliverToBoxAdapter(child: SizedBox(height: 100)),
          ],
        ),
      ),
      // FAB for adding receipts
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showScanOptions(context, ref),
        backgroundColor: const Color(0xFF1A1A1A),
        child: const Icon(Icons.add, color: Colors.white, size: 28),
      ),
    );
  }

  Color _getCategoryColor(ExpenseCategory category) {
    const colorMap = {
      ExpenseCategory.food: Color(0xFF3B82F6),
      ExpenseCategory.transport: Color(0xFF06B6D4),
      ExpenseCategory.utilities: Color(0xFFEC4899),
      ExpenseCategory.shopping: Color(0xFF8B5CF6),
      ExpenseCategory.entertainment: Color(0xFF10B981),
      ExpenseCategory.health: Color(0xFFEF4444),
      ExpenseCategory.education: Color(0xFFF59E0B),
      ExpenseCategory.transfer: Color(0xFFF97316),
      ExpenseCategory.other: Color(0xFF6B7280),
    };
    return colorMap[category] ?? const Color(0xFF6B7280);
  }

  String _formatAmount(double amount) {
    final currencyFormat = NumberFormat.currency(
      locale: 'ru_RU',
      symbol: '₸',
      decimalDigits: 0,
    );
    return currencyFormat.format(amount);
  }

  int _getDaysLeftInWeek() {
    final now = DateTime.now();
    final daysUntilSunday = 7 - now.weekday;
    return daysUntilSunday;
  }

  int _getDaysLeftInMonth() {
    final now = DateTime.now();
    final lastDayOfMonth = DateTime(now.year, now.month + 1, 0);
    return lastDayOfMonth.day - now.day;
  }

  void _showPeriodSelector() {
    final now = DateTime.now();
    final weekDay = now.weekday;
    final startOfWeek = now.subtract(Duration(days: weekDay - 1));
    final endOfWeek = startOfWeek.add(const Duration(days: 6));

    final dateFormat = DateFormat('MMM d', 'en');
    final currentWeek =
        '${dateFormat.format(startOfWeek)} - ${dateFormat.format(endOfWeek)}';

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder:
          (context) => Container(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text(
                  'Select Period',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 16),
                ListTile(
                  title: Text(currentWeek),
                  trailing:
                      _selectedPeriod == currentWeek
                          ? const Icon(Icons.check, color: Color(0xFF6C5CE7))
                          : null,
                  onTap: () {
                    setState(() => _selectedPeriod = currentWeek);
                    Navigator.pop(context);
                  },
                ),
              ],
            ),
          ),
    );
  }

  void _showScanOptions(BuildContext context, WidgetRef ref) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) => _ScanOptionsSheet(),
    );
  }
}

/// Transaction category row widget (displays amount spent only)
class _TransactionCategoryRow extends StatelessWidget {
  final String icon;
  final String name;
  final double amount;
  final Color color;

  const _TransactionCategoryRow({
    required this.icon,
    required this.name,
    required this.amount,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    final currencyFormat = NumberFormat.currency(
      locale: 'ru_RU',
      symbol: '₸',
      decimalDigits: 0,
    );

    return Row(
      children: [
        // Category Icon
        Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
          child: Center(
            child: Text(icon, style: const TextStyle(fontSize: 20)),
          ),
        ),
        const SizedBox(width: 12),
        // Category Name
        Expanded(
          child: Text(
            name,
            style: const TextStyle(
              color: Color(0xFF1A1A1A),
              fontSize: 15,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
        // Amount spent
        Text(
          currencyFormat.format(amount),
          style: const TextStyle(
            color: Color(0xFF1A1A1A),
            fontSize: 15,
            fontWeight: FontWeight.bold,
          ),
        ),
      ],
    );
  }
}

/// Scan options sheet
class _ScanOptionsSheet extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final scanState = ref.watch(receiptScanControllerProvider);
    final controller = ref.read(receiptScanControllerProvider.notifier);

    return Container(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.85,
      ),
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Handle bar
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: const Color(0xFFE5E7EB),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 24),

            if (scanState.isProcessing) ...[
              const CircularProgressIndicator(color: Color(0xFF6C5CE7)),
              const SizedBox(height: 16),
              Text(
                scanState.statusMessage ?? 'Обработка...',
                style: const TextStyle(color: Color(0xFF6B7280)),
              ),
            ] else if (scanState.result != null) ...[
              _ResultView(
                result: scanState.result!,
                onCategorySelected: (category) async {
                  final transaction = await controller.saveTransaction(
                    category: category,
                  );
                  if (context.mounted && transaction != null) {
                    Navigator.of(context).pop();
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(
                          'Сохранено: ${transaction.amount.toStringAsFixed(0)} ₸',
                        ),
                        backgroundColor: const Color(0xFF6C5CE7),
                      ),
                    );
                  }
                },
                onCustomCategorySelected: (
                  customCategoryId,
                  categoryName,
                ) async {
                  final transaction = await controller.saveTransaction(
                    category: ExpenseCategory.other,
                    customCategoryId: customCategoryId,
                  );
                  if (context.mounted && transaction != null) {
                    Navigator.of(context).pop();
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(
                          'Сохранено в "$categoryName": ${transaction.amount.toStringAsFixed(0)} ₸',
                        ),
                        backgroundColor: const Color(0xFF6C5CE7),
                      ),
                    );
                  }
                },
                onCancel: () => controller.clear(),
              ),
            ] else if (scanState.error != null) ...[
              Icon(Icons.error_outline, color: Colors.red[400], size: 48),
              const SizedBox(height: 16),
              Text(
                scanState.error!.message,
                style: TextStyle(color: Colors.red[400]),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),
              TextButton(
                onPressed: () => controller.clear(),
                child: const Text('Попробовать снова'),
              ),
            ] else ...[
              const Text(
                'Добавить чек',
                style: TextStyle(
                  color: Color(0xFF1A1A1A),
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 24),
              _ScanOption(
                icon: Icons.camera_alt,
                title: 'Камера',
                subtitle: 'Сфотографировать чек',
                onTap: () => controller.scanFromCamera(),
              ),
              const SizedBox(height: 12),
              _ScanOption(
                icon: Icons.photo_library,
                title: 'Галерея',
                subtitle: 'Выбрать фото',
                onTap: () => controller.scanFromGallery(),
              ),
              const SizedBox(height: 12),
              _ScanOption(
                icon: Icons.picture_as_pdf,
                title: 'PDF файл',
                subtitle: 'Kaspi / Halyk выписка',
                onTap: () => controller.scanFromPdf(),
              ),
            ],
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }
}

class _ResultView extends ConsumerStatefulWidget {
  final dynamic result;
  final Function(ExpenseCategory) onCategorySelected;
  final Function(String customCategoryId, String categoryName)
  onCustomCategorySelected;
  final VoidCallback onCancel;

  const _ResultView({
    required this.result,
    required this.onCategorySelected,
    required this.onCustomCategorySelected,
    required this.onCancel,
  });

  @override
  ConsumerState<_ResultView> createState() => _ResultViewState();
}

class _ResultViewState extends ConsumerState<_ResultView> {
  bool _showAllCategories = false;

  @override
  Widget build(BuildContext context) {
    final customCategories = ref.watch(customCategoriesProvider);
    final amount = widget.result.amount as double?;
    final date = widget.result.date as DateTime?;
    final merchant = widget.result.merchant as String?;
    final suggestedCategory =
        widget.result.suggestedCategory as ExpenseCategory?;
    final category = suggestedCategory ?? ExpenseCategory.other;

    return Column(
      children: [
        // Success icon
        Container(
          width: 64,
          height: 64,
          decoration: BoxDecoration(
            color: const Color(0xFF00D09C).withOpacity(0.15),
            shape: BoxShape.circle,
          ),
          child: const Icon(Icons.check, color: Color(0xFF00D09C), size: 32),
        ),
        const SizedBox(height: 16),

        // Amount
        Text(
          '${amount?.toStringAsFixed(0) ?? '?'} ₸',
          style: const TextStyle(
            color: Color(0xFF1A1A1A),
            fontSize: 36,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 8),

        // Date only (merchant hidden)
        if (date != null)
          Text(
            '${date.day}.${date.month}.${date.year}',
            style: const TextStyle(color: Color(0xFF9CA3AF), fontSize: 14),
          ),

        const SizedBox(height: 24),

        // Suggested category card
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: AppTheme.getCategoryColor(category).withOpacity(0.1),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: AppTheme.getCategoryColor(category).withOpacity(0.3),
            ),
          ),
          child: Column(
            children: [
              const Text(
                'Предложенная категория',
                style: TextStyle(color: Color(0xFF6B7280), fontSize: 12),
              ),
              const SizedBox(height: 8),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: AppTheme.getCategoryColor(category),
                      shape: BoxShape.circle,
                    ),
                    child: Center(
                      child: Text(
                        category.emoji,
                        style: const TextStyle(fontSize: 20),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Text(
                    category.displayName,
                    style: const TextStyle(
                      color: Color(0xFF1A1A1A),
                      fontSize: 20,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),

        const SizedBox(height: 16),

        // Confirm button
        SizedBox(
          width: double.infinity,
          child: ElevatedButton(
            onPressed: () => widget.onCategorySelected(category),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.getCategoryColor(category),
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 16),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              elevation: 0,
            ),
            child: const Text(
              'Подтвердить',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
            ),
          ),
        ),

        const SizedBox(height: 12),

        // Change category toggle
        TextButton(
          onPressed: () {
            setState(() {
              _showAllCategories = !_showAllCategories;
            });
          },
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                _showAllCategories
                    ? 'Скрыть категории'
                    : 'Выбрать другую категорию',
                style: const TextStyle(color: Color(0xFF6B7280)),
              ),
              Icon(
                _showAllCategories ? Icons.expand_less : Icons.expand_more,
                color: const Color(0xFF6B7280),
                size: 20,
              ),
            ],
          ),
        ),

        // Category grid (collapsible)
        if (_showAllCategories) ...[
          const SizedBox(height: 8),
          GridView.count(
            crossAxisCount: 2,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            mainAxisSpacing: 12,
            crossAxisSpacing: 12,
            childAspectRatio: 2.5,
            children: [
              // Built-in categories
              ...ExpenseCategory.values.map((cat) {
                final isSelected = cat == category;
                return _CategoryChipSelectable(
                  category: cat,
                  isSelected: isSelected,
                  onTap: () => widget.onCategorySelected(cat),
                );
              }),
              // Custom categories
              ...customCategories.map((custom) {
                return Material(
                  color: const Color(0xFFF3F4F6),
                  borderRadius: BorderRadius.circular(12),
                  child: InkWell(
                    onTap:
                        () => widget.onCustomCategorySelected(
                          custom.id,
                          custom.name,
                        ),
                    borderRadius: BorderRadius.circular(12),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 8,
                      ),
                      child: Row(
                        children: [
                          Text(
                            custom.emoji,
                            style: const TextStyle(fontSize: 20),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              custom.name,
                              style: const TextStyle(
                                color: Color(0xFF1A1A1A),
                                fontSize: 13,
                                fontWeight: FontWeight.w500,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              }),
              // Create new category button
              const _CreateCategoryButton(),
            ],
          ),
        ],

        const SizedBox(height: 16),

        // Cancel button
        TextButton(
          onPressed: widget.onCancel,
          child: const Text(
            'Отмена',
            style: TextStyle(color: Color(0xFF6B7280)),
          ),
        ),
      ],
    );
  }
}

class _CategoryChipSelectable extends StatelessWidget {
  final ExpenseCategory category;
  final VoidCallback onTap;
  final bool isSelected;

  const _CategoryChipSelectable({
    required this.category,
    required this.onTap,
    this.isSelected = false,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color:
          isSelected
              ? AppTheme.getCategoryColor(category).withOpacity(0.2)
              : AppTheme.getCategoryColor(category).withOpacity(0.1),
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          decoration:
              isSelected
                  ? BoxDecoration(
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: AppTheme.getCategoryColor(category),
                      width: 2,
                    ),
                  )
                  : null,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  color: AppTheme.getCategoryColor(category),
                  shape: BoxShape.circle,
                ),
                child: Center(
                  child: Text(
                    category.emoji,
                    style: const TextStyle(fontSize: 16),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Text(
                category.displayName,
                style: TextStyle(
                  color: const Color(0xFF1A1A1A),
                  fontSize: 14,
                  fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _CategoryChip extends StatelessWidget {
  final ExpenseCategory category;
  final VoidCallback onTap;

  const _CategoryChip({required this.category, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppTheme.getCategoryColor(category).withOpacity(0.1),
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  color: AppTheme.getCategoryColor(category),
                  shape: BoxShape.circle,
                ),
                child: Center(
                  child: Text(
                    category.emoji,
                    style: const TextStyle(fontSize: 16),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Text(
                category.displayName,
                style: const TextStyle(
                  color: Color(0xFF1A1A1A),
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Create category button widget
class _CreateCategoryButton extends ConsumerWidget {
  const _CreateCategoryButton();

  static const List<String> _availableEmojis = [
    '🍕',
    '🍔',
    '🍟',
    '🍿',
    '☕',
    '🍦',
    '🚗',
    '🚕',
    '🚙',
    '🚌',
    '✈️',
    '🚇',
    '🏠',
    '🏪',
    '🏥',
    '💊',
    '🎮',
    '🎵',
    '📚',
    '📝',
    '💼',
    '💰',
    '💳',
    '🎁',
    '👕',
    '👟',
    '💄',
    '🐕',
    '🌱',
    '⚽',
  ];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Material(
      color: const Color(0xFFF3F4F6),
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        onTap: () => _showCreateDialog(context, ref),
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 32,
                height: 32,
                decoration: const BoxDecoration(
                  color: Color(0xFF6C5CE7),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.add, color: Colors.white, size: 20),
              ),
              const SizedBox(width: 8),
              const Text(
                'Создать',
                style: TextStyle(
                  color: Color(0xFF1A1A1A),
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showCreateDialog(BuildContext context, WidgetRef ref) {
    String selectedEmoji = '📦';
    final nameController = TextEditingController();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder:
          (context) => StatefulBuilder(
            builder:
                (context, setState) => SingleChildScrollView(
                  padding: EdgeInsets.only(
                    left: 24,
                    right: 24,
                    top: 24,
                    bottom: MediaQuery.of(context).viewInsets.bottom + 24,
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Handle bar
                      Center(
                        child: Container(
                          width: 40,
                          height: 4,
                          decoration: BoxDecoration(
                            color: const Color(0xFFE5E7EB),
                            borderRadius: BorderRadius.circular(2),
                          ),
                        ),
                      ),
                      const SizedBox(height: 20),
                      // Title
                      const Text(
                        'Новая категория',
                        style: TextStyle(
                          color: Color(0xFF1A1A1A),
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 24),
                      // Selected emoji preview
                      Center(
                        child: Container(
                          width: 64,
                          height: 64,
                          decoration: BoxDecoration(
                            color: const Color(
                              0xFF6C5CE7,
                            ).withValues(alpha: 0.15),
                            shape: BoxShape.circle,
                          ),
                          child: Center(
                            child: Text(
                              selectedEmoji,
                              style: const TextStyle(fontSize: 32),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 20),
                      // Name input
                      TextField(
                        controller: nameController,
                        autofocus: true,
                        decoration: InputDecoration(
                          hintText: 'Название категории',
                          hintStyle: const TextStyle(color: Color(0xFF9CA3AF)),
                          filled: true,
                          fillColor: const Color(0xFFF9FAFB),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide.none,
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: const BorderSide(
                              color: Color(0xFF6C5CE7),
                              width: 2,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 20),
                      // Emoji label
                      const Text(
                        'Выберите иконку',
                        style: TextStyle(
                          color: Color(0xFF6B7280),
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      const SizedBox(height: 12),
                      // Emoji grid
                      GridView.builder(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        gridDelegate:
                            const SliverGridDelegateWithFixedCrossAxisCount(
                              crossAxisCount: 6,
                              mainAxisSpacing: 8,
                              crossAxisSpacing: 8,
                            ),
                        itemCount: _availableEmojis.length,
                        itemBuilder: (context, index) {
                          final emoji = _availableEmojis[index];
                          final isSelected = emoji == selectedEmoji;
                          return GestureDetector(
                            onTap: () => setState(() => selectedEmoji = emoji),
                            child: Container(
                              decoration: BoxDecoration(
                                color:
                                    isSelected
                                        ? const Color(
                                          0xFF6C5CE7,
                                        ).withValues(alpha: 0.15)
                                        : const Color(0xFFF9FAFB),
                                borderRadius: BorderRadius.circular(12),
                                border:
                                    isSelected
                                        ? Border.all(
                                          color: const Color(0xFF6C5CE7),
                                          width: 2,
                                        )
                                        : null,
                              ),
                              child: Center(
                                child: Text(
                                  emoji,
                                  style: const TextStyle(fontSize: 24),
                                ),
                              ),
                            ),
                          );
                        },
                      ),
                      const SizedBox(height: 24),
                      // Save button
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton(
                          onPressed: () async {
                            final name = nameController.text.trim();
                            if (name.isNotEmpty) {
                              await ref
                                  .read(customCategoriesProvider.notifier)
                                  .addCategory(name, selectedEmoji);
                              if (context.mounted) {
                                Navigator.pop(context);
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Text(
                                      'Категория "$name" создана',
                                      style: const TextStyle(
                                        color: Colors.white,
                                      ),
                                    ),
                                    backgroundColor: const Color(0xFF10B981),
                                    behavior: SnackBarBehavior.floating,
                                  ),
                                );
                              }
                            }
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF6C5CE7),
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          child: const Text(
                            'Сохранить',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
          ),
    );
  }
}

class _ScanOption extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  const _ScanOption({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: const Color(0xFFF9FAFB),
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: const Color(0xFF6C5CE7).withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, color: const Color(0xFF6C5CE7)),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        color: Color(0xFF1A1A1A),
                        fontSize: 16,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    Text(
                      subtitle,
                      style: const TextStyle(
                        color: Color(0xFF6B7280),
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right, color: Color(0xFFE5E7EB)),
            ],
          ),
        ),
      ),
    );
  }
}
