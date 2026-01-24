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
      backgroundColor: const Color(0xFF121212),
      appBar: AppBar(
        backgroundColor: const Color(0xFF121212),
        title: const Text(
          'Бюджет',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        actions: [
          TextButton.icon(
            onPressed: () => setState(() => _isEditing = !_isEditing),
            icon: Icon(
              _isEditing ? Icons.check : Icons.edit,
              color: const Color(0xFF00D09C),
              size: 20,
            ),
            label: Text(
              _isEditing ? 'Готово' : 'Изменить',
              style: const TextStyle(color: Color(0xFF00D09C)),
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
    final repository = ref.watch(budgetLimitRepositoryProvider);

    return FutureBuilder<List<BudgetProgress>>(
      future: repository.getAllProgress(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(
            child: CircularProgressIndicator(color: Color(0xFF00D09C)),
          );
        }

        final progressList = snapshot.data ?? [];

        if (progressList.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.account_balance_wallet_outlined,
                  size: 64,
                  color: Colors.white.withValues(alpha: 0.3),
                ),
                const SizedBox(height: 16),
                Text(
                  'Нет установленных лимитов',
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.5),
                    fontSize: 16,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Нажмите "Изменить" чтобы добавить',
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.3),
                    fontSize: 14,
                  ),
                ),
              ],
            ),
          );
        }

        return ListView.separated(
          padding: const EdgeInsets.all(16),
          itemCount: progressList.length,
          separatorBuilder: (_, __) => const SizedBox(height: 12),
          itemBuilder: (context, index) {
            return BudgetProgressCard(progress: progressList[index]);
          },
        );
      },
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

  @override
  void initState() {
    super.initState();
    _initControllers();
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
                  backgroundColor: const Color(0xFF00D09C),
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
        color: const Color(0xFF1E1E1E),
        borderRadius: BorderRadius.circular(12),
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
                    color: Colors.white,
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
                        style: const TextStyle(color: Colors.white),
                        decoration: InputDecoration(
                          hintText: '0',
                          hintStyle: TextStyle(
                            color: Colors.white.withValues(alpha: 0.3),
                          ),
                          suffixText: '₸',
                          suffixStyle: const TextStyle(color: Colors.white70),
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
