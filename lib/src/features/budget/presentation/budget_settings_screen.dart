import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../core/constants.dart';
import '../../categories/data/custom_category_repository.dart';
import '../../income/data/income_repository.dart';
import '../../income/domain/income_entity.dart';
import '../data/budget_limit_repository.dart';
import '../domain/budget_limit.dart';

/// Budget & Income Settings Screen with tabs
class BudgetSettingsScreen extends ConsumerStatefulWidget {
  const BudgetSettingsScreen({super.key});

  @override
  ConsumerState<BudgetSettingsScreen> createState() =>
      _BudgetSettingsScreenState();
}

class _BudgetSettingsScreenState extends ConsumerState<BudgetSettingsScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F7),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        title: const Text(
          'Budget & Income',
          style: TextStyle(
            color: Color(0xFF1A1A1A),
            fontWeight: FontWeight.bold,
          ),
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Color(0xFF1A1A1A)),
          onPressed: () => Navigator.of(context).pop(),
        ),
        bottom: TabBar(
          controller: _tabController,
          labelColor: const Color(0xFF6C5CE7),
          unselectedLabelColor: const Color(0xFF9CA3AF),
          indicatorColor: const Color(0xFF6C5CE7),
          tabs: const [Tab(text: 'Income'), Tab(text: 'Limits')],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: const [_IncomeTab(), _LimitsTab()],
      ),
    );
  }
}

/// Income Tab - List and manage income sources
class _IncomeTab extends ConsumerWidget {
  const _IncomeTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final incomeList = ref.watch(incomeListProvider);
    final monthlyTotal = ref.watch(monthlyIncomeProvider);
    final currencyFormat = NumberFormat.currency(
      locale: 'en_US',
      symbol: '₸',
      decimalDigits: 0,
    );

    return Column(
      children: [
        // Monthly Total Card
        Container(
          margin: const EdgeInsets.all(20),
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [Color(0xFF6C5CE7), Color(0xFF8B7CF7)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(20),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Monthly Income',
                style: TextStyle(color: Colors.white70, fontSize: 14),
              ),
              const SizedBox(height: 8),
              Text(
                currencyFormat.format(monthlyTotal),
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 32,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
        ),

        // Income List
        Expanded(
          child:
              incomeList.isEmpty
                  ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.account_balance_wallet_outlined,
                          size: 64,
                          color: Colors.grey[300],
                        ),
                        const SizedBox(height: 16),
                        Text(
                          'No income added yet',
                          style: TextStyle(
                            color: Colors.grey[500],
                            fontSize: 16,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Tap + to add your income',
                          style: TextStyle(
                            color: Colors.grey[400],
                            fontSize: 14,
                          ),
                        ),
                      ],
                    ),
                  )
                  : ListView.builder(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    itemCount: incomeList.length,
                    itemBuilder: (context, index) {
                      final income = incomeList[index];
                      return _IncomeListItem(income: income);
                    },
                  ),
        ),

        // Add Income FAB
        Padding(
          padding: const EdgeInsets.all(20),
          child: SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: () => _showAddIncomeDialog(context, ref),
              icon: const Icon(Icons.add),
              label: const Text('Add Income'),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF6C5CE7),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  void _showAddIncomeDialog(BuildContext context, WidgetRef ref) {
    final amountController = TextEditingController();
    final sourceController = TextEditingController();
    DateTime selectedDate = DateTime.now();

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
                (context, setState) => Padding(
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
                      const Text(
                        'Add Income',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF1A1A1A),
                        ),
                      ),
                      const SizedBox(height: 24),
                      TextField(
                        controller: sourceController,
                        decoration: InputDecoration(
                          labelText: 'Source (e.g., Salary)',
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),
                      TextField(
                        controller: amountController,
                        keyboardType: TextInputType.number,
                        decoration: InputDecoration(
                          labelText: 'Amount (₸)',
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),
                      ListTile(
                        contentPadding: EdgeInsets.zero,
                        title: const Text('Date'),
                        subtitle: Text(
                          DateFormat('dd MMMM yyyy').format(selectedDate),
                        ),
                        trailing: const Icon(Icons.calendar_today),
                        onTap: () async {
                          final date = await showDatePicker(
                            context: context,
                            initialDate: selectedDate,
                            firstDate: DateTime(2020),
                            lastDate: DateTime.now(),
                          );
                          if (date != null) {
                            setState(() => selectedDate = date);
                          }
                        },
                      ),
                      const SizedBox(height: 24),
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton(
                          onPressed: () {
                            final amount = double.tryParse(
                              amountController.text,
                            );
                            final source = sourceController.text.trim();
                            if (amount != null &&
                                amount > 0 &&
                                source.isNotEmpty) {
                              ref
                                  .read(incomeListProvider.notifier)
                                  .add(
                                    amount: amount,
                                    source: source,
                                    date: selectedDate,
                                  );
                              Navigator.of(context).pop();
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
                          child: const Text('Save'),
                        ),
                      ),
                    ],
                  ),
                ),
          ),
    );
  }
}

class _IncomeListItem extends ConsumerWidget {
  final IncomeEntity income;

  const _IncomeListItem({required this.income});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final currencyFormat = NumberFormat.currency(
      locale: 'en_US',
      symbol: '₸',
      decimalDigits: 0,
    );

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: const Color(0xFF00D09C).withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(Icons.arrow_downward, color: Color(0xFF00D09C)),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  income.source,
                  style: const TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 16,
                    color: Color(0xFF1A1A1A),
                  ),
                ),
                Text(
                  DateFormat('dd MMM yyyy').format(income.date),
                  style: TextStyle(color: Colors.grey[500], fontSize: 12),
                ),
              ],
            ),
          ),
          Text(
            '+${currencyFormat.format(income.amount)}',
            style: const TextStyle(
              color: Color(0xFF00D09C),
              fontWeight: FontWeight.bold,
              fontSize: 16,
            ),
          ),
          IconButton(
            icon: Icon(Icons.delete_outline, color: Colors.grey[400]),
            onPressed: () {
              ref.read(incomeListProvider.notifier).delete(income.id);
            },
          ),
        ],
      ),
    );
  }
}

/// Limits Tab - Set budget limits for categories
class _LimitsTab extends ConsumerWidget {
  const _LimitsTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final budgetProgressAsync = ref.watch(budgetProgressProvider);
    final customCategories = ref.watch(customCategoriesProvider);

    return budgetProgressAsync.when(
      data: (progressList) {
        return ListView(
          padding: const EdgeInsets.all(20),
          children: [
            // Section: Standard Categories
            const Text(
              'Standard Categories',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: Color(0xFF1A1A1A),
              ),
            ),
            const SizedBox(height: 12),
            ...ExpenseCategory.values.map((category) {
              final progress =
                  progressList
                      .where(
                        (p) =>
                            p.limit.category == category &&
                            p.limit.customCategoryId == null,
                      )
                      .firstOrNull;
              return _CategoryLimitItem(
                emoji: category.emoji,
                name: category.displayName,
                progress: progress,
                onTap:
                    () => _showSetLimitDialog(
                      context,
                      ref,
                      category: category,
                      currentLimit: progress?.limit,
                    ),
              );
            }),

            // Section: Custom Categories
            if (customCategories.isNotEmpty) ...[
              const SizedBox(height: 24),
              const Text(
                'Custom Categories',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF1A1A1A),
                ),
              ),
              const SizedBox(height: 12),
              ...customCategories.map((customCat) {
                final progress =
                    progressList
                        .where((p) => p.limit.customCategoryId == customCat.id)
                        .firstOrNull;
                return _CategoryLimitItem(
                  emoji: customCat.emoji,
                  name: customCat.name,
                  progress: progress,
                  onTap:
                      () => _showSetLimitDialog(
                        context,
                        ref,
                        customCategoryId: customCat.id,
                        customCategoryName: customCat.name,
                        currentLimit: progress?.limit,
                      ),
                );
              }),
            ],
          ],
        );
      },
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, s) => Center(child: Text('Error: $e')),
    );
  }

  void _showSetLimitDialog(
    BuildContext context,
    WidgetRef ref, {
    ExpenseCategory? category,
    String? customCategoryId,
    String? customCategoryName,
    BudgetLimit? currentLimit,
  }) {
    final amountController = TextEditingController(
      text: currentLimit?.limitAmount.toStringAsFixed(0) ?? '',
    );
    BudgetPeriod selectedPeriod = currentLimit?.period ?? BudgetPeriod.month;

    final title = category?.displayName ?? customCategoryName ?? 'Category';

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
                (context, setState) => Padding(
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
                      Text(
                        'Set Limit for $title',
                        style: const TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF1A1A1A),
                        ),
                      ),
                      const SizedBox(height: 24),
                      TextField(
                        controller: amountController,
                        keyboardType: TextInputType.number,
                        decoration: InputDecoration(
                          labelText: 'Limit Amount (₸)',
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),
                      const Text('Period'),
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 8,
                        children:
                            BudgetPeriod.values.map((period) {
                              final isSelected = period == selectedPeriod;
                              return ChoiceChip(
                                label: Text(period.displayName),
                                selected: isSelected,
                                selectedColor: const Color(
                                  0xFF6C5CE7,
                                ).withOpacity(0.2),
                                onSelected: (selected) {
                                  if (selected) {
                                    setState(() => selectedPeriod = period);
                                  }
                                },
                              );
                            }).toList(),
                      ),
                      const SizedBox(height: 24),
                      Row(
                        children: [
                          if (currentLimit != null)
                            Expanded(
                              child: OutlinedButton(
                                onPressed: () {
                                  ref
                                      .read(budgetLimitRepositoryProvider)
                                      .delete(currentLimit.id);
                                  ref.invalidate(budgetProgressProvider);
                                  Navigator.of(context).pop();
                                },
                                style: OutlinedButton.styleFrom(
                                  foregroundColor: Colors.red,
                                  side: const BorderSide(color: Colors.red),
                                  padding: const EdgeInsets.symmetric(
                                    vertical: 16,
                                  ),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                ),
                                child: const Text('Remove'),
                              ),
                            ),
                          if (currentLimit != null) const SizedBox(width: 12),
                          Expanded(
                            child: ElevatedButton(
                              onPressed: () async {
                                final amount = double.tryParse(
                                  amountController.text,
                                );
                                if (amount != null && amount > 0) {
                                  final repo = ref.read(
                                    budgetLimitRepositoryProvider,
                                  );
                                  if (customCategoryId != null) {
                                    await repo.setCustomCategoryLimit(
                                      customCategoryId: customCategoryId,
                                      amount: amount,
                                      period: selectedPeriod,
                                    );
                                  } else if (category != null) {
                                    await repo.setLimit(
                                      category: category,
                                      amount: amount,
                                      period: selectedPeriod,
                                    );
                                  }
                                  ref.invalidate(budgetProgressProvider);
                                  if (context.mounted)
                                    Navigator.of(context).pop();
                                }
                              },
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFF6C5CE7),
                                foregroundColor: Colors.white,
                                padding: const EdgeInsets.symmetric(
                                  vertical: 16,
                                ),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                              ),
                              child: const Text('Save'),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
          ),
    );
  }
}

class _CategoryLimitItem extends StatelessWidget {
  final String emoji;
  final String name;
  final BudgetProgress? progress;
  final VoidCallback onTap;

  const _CategoryLimitItem({
    required this.emoji,
    required this.name,
    this.progress,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final currencyFormat = NumberFormat.currency(
      locale: 'en_US',
      symbol: '₸',
      decimalDigits: 0,
    );

    final hasLimit = progress != null;
    final spent = progress?.spent ?? 0;
    final limit = progress?.limit.limitAmount ?? 0;
    final percent = hasLimit ? (spent / limit * 100).clamp(0, 100) : 0.0;
    final statusColor =
        hasLimit ? Color(progress!.status.colorValue) : Colors.grey;

    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          children: [
            Row(
              children: [
                Text(emoji, style: const TextStyle(fontSize: 24)),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    name,
                    style: const TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 16,
                      color: Color(0xFF1A1A1A),
                    ),
                  ),
                ),
                if (hasLimit)
                  Text(
                    '${currencyFormat.format(spent)} / ${currencyFormat.format(limit)}',
                    style: TextStyle(
                      color: statusColor,
                      fontWeight: FontWeight.w600,
                      fontSize: 14,
                    ),
                  )
                else
                  Text(
                    'No limit',
                    style: TextStyle(color: Colors.grey[400], fontSize: 14),
                  ),
                const SizedBox(width: 8),
                Icon(Icons.chevron_right, color: Colors.grey[400]),
              ],
            ),
            if (hasLimit) ...[
              const SizedBox(height: 12),
              ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: LinearProgressIndicator(
                  value: percent / 100,
                  backgroundColor: Colors.grey[200],
                  valueColor: AlwaysStoppedAnimation<Color>(statusColor),
                  minHeight: 6,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
