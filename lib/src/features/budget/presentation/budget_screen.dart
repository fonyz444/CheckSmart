import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/constants.dart';
import '../data/budget_limit_repository.dart';
import '../domain/budget_limit.dart';
import 'budget_progress_card.dart';

/// Screen for managing budget limits
class BudgetScreen extends ConsumerStatefulWidget {
  const BudgetScreen({super.key});

  @override
  ConsumerState<BudgetScreen> createState() => _BudgetScreenState();
}

class _BudgetScreenState extends ConsumerState<BudgetScreen> {
  bool _isEditing = false;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F7),
      appBar: AppBar(
        backgroundColor: const Color(0xFFF5F5F7),
        title: const Text(
          'Бюджет',
          style: TextStyle(
            color: Color(0xFF1A1A1A),
            fontWeight: FontWeight.bold,
          ),
        ),
        actions: [
          TextButton.icon(
            onPressed: () => setState(() => _isEditing = !_isEditing),
            icon: Icon(
              _isEditing ? Icons.check : Icons.edit,
              color: const Color(0xFF6C5CE7),
              size: 20,
            ),
            label: Text(
              _isEditing ? 'Готово' : 'Изменить',
              style: const TextStyle(color: Color(0xFF6C5CE7)),
            ),
          ),
        ],
      ),
      body:
          _isEditing
              ? _BudgetEditView(
                onDone: () => setState(() => _isEditing = false),
              )
              : _BudgetProgressView(),
    );
  }
}

/// View showing budget progress for all categories
class _BudgetProgressView extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final progressAsync = ref.watch(budgetProgressProvider);

    return progressAsync.when(
      loading:
          () => const Center(
            child: CircularProgressIndicator(color: Color(0xFF6C5CE7)),
          ),
      error:
          (error, stack) => Center(
            child: Text(
              'Ошибка: $error',
              style: const TextStyle(color: Colors.red),
            ),
          ),
      data: (progressList) {
        if (progressList.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.account_balance_wallet_outlined,
                  size: 64,
                  color: const Color(0xFF9CA3AF),
                ),
                const SizedBox(height: 16),
                const Text(
                  'Нет установленных лимитов',
                  style: TextStyle(color: Color(0xFF6B7280), fontSize: 16),
                ),
                const SizedBox(height: 8),
                const Text(
                  'Нажмите "Изменить" чтобы добавить',
                  style: TextStyle(color: Color(0xFF9CA3AF), fontSize: 14),
                ),
              ],
            ),
          );
        }

        // Calculate totals
        final totalBudgeted = progressList.fold<double>(
          0,
          (sum, p) => sum + p.limit.limitAmount,
        );
        final totalLeft = progressList.fold<double>(
          0,
          (sum, p) => sum + p.remaining,
        );

        // Get date range for weekly (current week)
        final now = DateTime.now();
        final weekStart = now.subtract(Duration(days: now.weekday - 1));
        final weekEnd = weekStart.add(const Duration(days: 6));
        final daysLeft = weekEnd.difference(now).inDays;

        return CustomScrollView(
          slivers: [
            // Weekly Budget Section
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Section header
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          'Weekly Budget',
                          style: TextStyle(
                            color: Color(0xFF1A1A1A),
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        Text(
                          '$daysLeft days left',
                          style: const TextStyle(
                            color: Color(0xFF6B7280),
                            fontSize: 14,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      '${_formatDate(weekStart)} - ${_formatDate(weekEnd)}',
                      style: const TextStyle(
                        color: Color(0xFF9CA3AF),
                        fontSize: 14,
                      ),
                    ),
                    const SizedBox(height: 16),
                    // Total budgeted and left
                    Row(
                      children: [
                        Expanded(
                          child: _SummaryCard(
                            label: 'Budgeted',
                            amount: totalBudgeted,
                            color: const Color(0xFF6B7280),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: _SummaryCard(
                            label: 'Left',
                            amount: totalLeft,
                            color:
                                totalLeft >= 0
                                    ? const Color(0xFF4CAF50)
                                    : Colors.red[600]!,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 20),
                  ],
                ),
              ),
            ),

            // Category list
            SliverPadding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              sliver: SliverList(
                delegate: SliverChildBuilderDelegate((context, index) {
                  return BudgetProgressCard(progress: progressList[index]);
                }, childCount: progressList.length),
              ),
            ),

            // Action buttons
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  children: [
                    // Add new category button
                    SizedBox(
                      width: double.infinity,
                      child: OutlinedButton.icon(
                        onPressed: () {
                          // Navigate to edit mode or show dialog
                        },
                        icon: const Icon(Icons.add, color: Color(0xFF6C5CE7)),
                        label: const Text(
                          'Add new category',
                          style: TextStyle(color: Color(0xFF6C5CE7)),
                        ),
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          side: const BorderSide(color: Color(0xFF6C5CE7)),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    // Hidden categories link
                    TextButton(
                      onPressed: () {
                        // Show hidden categories
                      },
                      child: const Text(
                        'Hidden categories',
                        style: TextStyle(
                          color: Color(0xFF9CA3AF),
                          fontSize: 14,
                        ),
                      ),
                    ),
                    const SizedBox(height: 100), // Bottom padding for nav
                  ],
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  String _formatDate(DateTime date) {
    const months = [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec',
    ];
    return '${months[date.month - 1]} ${date.day}';
  }
}

/// Summary card for budgeted/left totals
class _SummaryCard extends StatelessWidget {
  final String label;
  final double amount;
  final Color color;

  const _SummaryCard({
    required this.label,
    required this.amount,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: const TextStyle(color: Color(0xFF9CA3AF), fontSize: 14),
          ),
          const SizedBox(height: 8),
          Text(
            '${amount.toStringAsFixed(0)} ₸',
            style: TextStyle(
              color: color,
              fontSize: 24,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }
}

/// View for editing budget limits
class _BudgetEditView extends ConsumerStatefulWidget {
  final VoidCallback onDone;

  const _BudgetEditView({required this.onDone});

  @override
  ConsumerState<_BudgetEditView> createState() => _BudgetEditViewState();
}

class _BudgetEditViewState extends ConsumerState<_BudgetEditView> {
  final Map<ExpenseCategory, TextEditingController> _controllers = {};
  final Map<ExpenseCategory, BudgetPeriod> _periods = {};
  bool _initialized = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_initialized) {
      _initControllers();
      _initialized = true;
    }
  }

  void _initControllers() {
    final repository = ref.read(budgetLimitRepositoryProvider);

    for (final category in ExpenseCategory.values) {
      final existing = repository.getByCategory(category);
      _controllers[category] = TextEditingController(
        text: existing != null ? existing.limitAmount.toStringAsFixed(0) : '',
      );
      _periods[category] = existing?.period ?? BudgetPeriod.month;
    }
  }

  @override
  void dispose() {
    for (final controller in _controllers.values) {
      controller.dispose();
    }
    super.dispose();
  }

  Future<void> _saveAll() async {
    final repository = ref.read(budgetLimitRepositoryProvider);

    for (final category in ExpenseCategory.values) {
      final text =
          _controllers[category]?.text.replaceAll(RegExp(r'\s+'), '') ?? '';
      final amount = double.tryParse(text);
      final period = _periods[category] ?? BudgetPeriod.month;

      if (amount != null && amount > 0) {
        await repository.setLimit(
          category: category,
          amount: amount,
          period: period,
        );
      } else {
        // Remove limit if empty
        final existing = repository.getByCategory(category);
        if (existing != null) {
          await repository.delete(existing.id);
        }
      }
    }

    widget.onDone();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Expanded(
          child: ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: ExpenseCategory.values.length,
            itemBuilder: (context, index) {
              final category = ExpenseCategory.values[index];
              return _CategoryLimitTile(
                category: category,
                controller: _controllers[category]!,
                period: _periods[category] ?? BudgetPeriod.month,
                onPeriodChanged: (p) => setState(() => _periods[category] = p),
              );
            },
          ),
        ),
        // Save button
        SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _saveAll,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF6C5CE7),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: const Text(
                  'Сохранить бюджет',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _CategoryLimitTile extends StatelessWidget {
  final ExpenseCategory category;
  final TextEditingController controller;
  final BudgetPeriod period;
  final ValueChanged<BudgetPeriod> onPeriodChanged;

  const _CategoryLimitTile({
    required this.category,
    required this.controller,
    required this.period,
    required this.onPeriodChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.03),
            blurRadius: 4,
            offset: const Offset(0, 1),
          ),
        ],
      ),
      child: Row(
        children: [
          // Category icon
          Text(category.emoji, style: const TextStyle(fontSize: 28)),
          const SizedBox(width: 16),

          // Category name and input
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  category.displayName,
                  style: const TextStyle(
                    color: Color(0xFF1A1A1A),
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    // Amount input
                    Expanded(
                      child: TextField(
                        controller: controller,
                        keyboardType: TextInputType.number,
                        inputFormatters: [
                          FilteringTextInputFormatter.digitsOnly,
                        ],
                        style: const TextStyle(color: Color(0xFF1A1A1A)),
                        decoration: InputDecoration(
                          hintText: '0',
                          hintStyle: const TextStyle(color: Color(0xFF9CA3AF)),
                          suffixText: '₸',
                          suffixStyle: const TextStyle(
                            color: Color(0xFF6B7280),
                          ),
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 8,
                          ),
                          filled: true,
                          fillColor: const Color(0xFF2A2A2A),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                            borderSide: BorderSide.none,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    // Period selector
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8),
                      decoration: BoxDecoration(
                        color: const Color(0xFF2A2A2A),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: DropdownButton<BudgetPeriod>(
                        value: period,
                        dropdownColor: const Color(0xFF2A2A2A),
                        underline: const SizedBox(),
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 14,
                        ),
                        items:
                            BudgetPeriod.values.map((p) {
                              return DropdownMenuItem(
                                value: p,
                                child: Text('/${p.shortName}'),
                              );
                            }).toList(),
                        onChanged: (p) {
                          if (p != null) onPeriodChanged(p);
                        },
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
