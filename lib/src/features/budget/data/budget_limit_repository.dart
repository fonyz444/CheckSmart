import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:uuid/uuid.dart';

import '../../../core/constants.dart';
import '../../transactions/data/transaction_repository.dart';
import '../domain/budget_limit.dart';

/// Provider for BudgetLimitRepository
final budgetLimitRepositoryProvider = Provider<BudgetLimitRepository>((ref) {
  return BudgetLimitRepository(ref);
});

/// Provider for all budget limits
final budgetLimitsProvider = StreamProvider<List<BudgetLimit>>((ref) {
  return ref.watch(budgetLimitRepositoryProvider).watchAll();
});

/// Provider for budget progress (spent amount) for a specific category
final categorySpentProvider = FutureProvider.family<double, ExpenseCategory>((
  ref,
  category,
) async {
  final transactionRepo = ref.watch(transactionRepositoryProvider);
  return await transactionRepo.getTotalByCategory(category);
});

/// Reactive provider for all budget progress - updates when transactions change
final budgetProgressProvider = FutureProvider<List<BudgetProgress>>((
  ref,
) async {
  // Watch transactions to trigger rebuild when they change
  ref.watch(transactionsProvider);

  final repository = ref.watch(budgetLimitRepositoryProvider);
  return repository.getAllProgress();
});

/// Repository for managing budget limits with Hive storage
class BudgetLimitRepository {
  static const String _boxName = 'budget_limits';
  final Ref _ref;
  final _uuid = const Uuid();

  BudgetLimitRepository(this._ref);

  /// Get the Hive box
  Box<BudgetLimit> get _box => Hive.box<BudgetLimit>(_boxName);

  /// Initialize Hive box (call during app startup)
  static Future<void> initialize() async {
    if (!Hive.isAdapterRegistered(4)) {
      Hive.registerAdapter(BudgetPeriodAdapter());
    }
    if (!Hive.isAdapterRegistered(5)) {
      Hive.registerAdapter(BudgetLimitAdapter());
    }
    await Hive.openBox<BudgetLimit>(_boxName);
  }

  /// Watch all budget limits as a stream
  Stream<List<BudgetLimit>> watchAll() {
    return _box.watch().map((_) => getAll()).asBroadcastStream()
      ..listen((_) {}); // Keep stream active
    // Return initial value immediately
  }

  /// Get all budget limits
  List<BudgetLimit> getAll() {
    return _box.values.where((limit) => limit.isActive).toList();
  }

  /// Get budget limit for a specific category
  BudgetLimit? getByCategory(ExpenseCategory category) {
    try {
      return _box.values.firstWhere(
        (limit) => limit.category == category && limit.isActive,
      );
    } catch (_) {
      return null;
    }
  }

  /// Create or update budget limit for a category
  Future<BudgetLimit> setLimit({
    required ExpenseCategory category,
    required double amount,
    required BudgetPeriod period,
  }) async {
    // Check if limit already exists for this category
    final existing = getByCategory(category);

    if (existing != null) {
      // Update existing
      final updated = existing.copyWith(limitAmount: amount, period: period);
      await _box.put(existing.id, updated);
      return updated;
    } else {
      // Create new
      final limit = BudgetLimit(
        id: _uuid.v4(),
        category: category,
        limitAmount: amount,
        period: period,
        createdAt: DateTime.now(),
      );
      await _box.put(limit.id, limit);
      return limit;
    }
  }

  /// Delete budget limit
  Future<void> delete(String id) async {
    await _box.delete(id);
  }

  /// Disable budget limit (soft delete)
  Future<void> disable(String id) async {
    final limit = _box.get(id);
    if (limit != null) {
      await _box.put(id, limit.copyWith(isActive: false));
    }
  }

  /// Get spending for a category within the budget period
  Future<double> getSpentInPeriod(
    ExpenseCategory category,
    BudgetPeriod period,
  ) async {
    final transactionRepo = _ref.read(transactionRepositoryProvider);
    final now = DateTime.now();

    DateTime startDate;
    switch (period) {
      case BudgetPeriod.week:
        // Start of current week (Monday)
        startDate = now.subtract(Duration(days: now.weekday - 1));
        startDate = DateTime(startDate.year, startDate.month, startDate.day);
        break;
      case BudgetPeriod.month:
        // Start of current month
        startDate = DateTime(now.year, now.month, 1);
        break;
      case BudgetPeriod.year:
        // Start of current year
        startDate = DateTime(now.year, 1, 1);
        break;
    }

    return await transactionRepo.getTotalByCategory(
      category,
      startDate: startDate,
      endDate: now,
    );
  }

  /// Get all budget progress data
  Future<List<BudgetProgress>> getAllProgress() async {
    final limits = getAll();
    final progressList = <BudgetProgress>[];

    for (final limit in limits) {
      final spent = await getSpentInPeriod(limit.category, limit.period);
      progressList.add(BudgetProgress(limit: limit, spent: spent));
    }

    return progressList;
  }
}

/// Budget progress data combining limit and actual spending
class BudgetProgress {
  final BudgetLimit limit;
  final double spent;

  const BudgetProgress({required this.limit, required this.spent});

  double get percentUsed => limit.percentUsed(spent);
  double get remaining => limit.remaining(spent);
  BudgetStatus get status => limit.getStatus(spent);
}
