import 'package:hive_flutter/hive_flutter.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import '../../../core/constants.dart';
import '../domain/transaction_entity.dart';

/// Provider for TransactionRepository
final transactionRepositoryProvider = Provider<TransactionRepository>((ref) {
  return TransactionRepository();
});

/// Provider for watching all transactions (reactive)
final transactionsProvider = StreamProvider<List<TransactionEntity>>((ref) {
  final repository = ref.watch(transactionRepositoryProvider);
  return repository.watchAll();
});

/// Provider for this month's total spending (reactive - updates when transactions change)
final monthlyTotalProvider = Provider<double>((ref) {
  final transactionsAsync = ref.watch(transactionsProvider);

  return transactionsAsync.when(
    data: (transactions) {
      final now = DateTime.now();
      final startOfMonth = DateTime(now.year, now.month, 1);

      double total = 0.0;
      for (final t in transactions) {
        if (t.date.isAfter(startOfMonth) ||
            (t.date.year == startOfMonth.year &&
                t.date.month == startOfMonth.month &&
                t.date.day >= startOfMonth.day)) {
          total += t.amount;
        }
      }
      return total;
    },
    loading: () => 0.0,
    error: (_, __) => 0.0,
  );
});

/// Repository for transaction CRUD operations using Hive
class TransactionRepository {
  static const _uuid = Uuid();

  Box<TransactionEntity>? _box;

  /// Gets or opens the Hive box
  Future<Box<TransactionEntity>> _getBox() async {
    if (_box == null || !_box!.isOpen) {
      _box = await Hive.openBox<TransactionEntity>(HiveBoxes.transactions);
    }
    return _box!;
  }

  /// Saves a new transaction
  Future<TransactionEntity> add({
    required double amount,
    required ExpenseCategory category,
    required DateTime date,
    required ReceiptSource source,
    String? merchant,
    String? receiptNumber,
    String? rawOcrText,
    String? note,
  }) async {
    final box = await _getBox();

    final transaction = TransactionEntity(
      id: _uuid.v4(),
      amount: amount,
      category: category,
      date: date,
      source: source,
      merchant: merchant,
      receiptNumber: receiptNumber,
      rawOcrText: rawOcrText,
      note: note,
      createdAt: DateTime.now(),
    );

    await box.put(transaction.id, transaction);
    return transaction;
  }

  /// Updates an existing transaction
  Future<void> update(TransactionEntity transaction) async {
    final box = await _getBox();
    await box.put(transaction.id, transaction);
  }

  /// Deletes a transaction by ID
  Future<void> delete(String id) async {
    final box = await _getBox();
    await box.delete(id);
  }

  /// Gets a transaction by ID
  Future<TransactionEntity?> getById(String id) async {
    final box = await _getBox();
    return box.get(id);
  }

  /// Gets all transactions sorted by date (newest first)
  Future<List<TransactionEntity>> getAll() async {
    final box = await _getBox();
    final transactions = box.values.toList();
    transactions.sort((a, b) => b.date.compareTo(a.date));
    return transactions;
  }

  /// Watches all transactions reactively
  Stream<List<TransactionEntity>> watchAll() async* {
    final box = await _getBox();

    // Emit current state first
    yield box.values.toList()..sort((a, b) => b.date.compareTo(a.date));

    // Then watch for changes
    await for (final _ in box.watch()) {
      yield box.values.toList()..sort((a, b) => b.date.compareTo(a.date));
    }
  }

  /// Gets total spending for the current month
  Future<double> getMonthlyTotal() async {
    final box = await _getBox();
    final now = DateTime.now();
    final startOfMonth = DateTime(now.year, now.month, 1);

    final monthlyTransactions = box.values.where(
      (t) => t.date.isAfter(startOfMonth) || t.date == startOfMonth,
    );

    double total = 0.0;
    for (final t in monthlyTransactions) {
      total += t.amount;
    }
    return total;
  }

  /// Gets spending by category for current month
  Future<Map<ExpenseCategory, double>> getMonthlyCategoryTotals() async {
    final box = await _getBox();
    final now = DateTime.now();
    final startOfMonth = DateTime(now.year, now.month, 1);

    final monthlyTransactions = box.values.where(
      (t) => t.date.isAfter(startOfMonth) || t.date == startOfMonth,
    );

    final totals = <ExpenseCategory, double>{};
    for (final category in ExpenseCategory.values) {
      totals[category] = 0.0;
    }

    for (final transaction in monthlyTransactions) {
      totals[transaction.category] =
          (totals[transaction.category] ?? 0) + transaction.amount;
    }

    return totals;
  }

  /// Gets total spending for a specific category within a date range
  double getTotalByCategory(
    ExpenseCategory category, {
    DateTime? startDate,
    DateTime? endDate,
  }) {
    if (_box == null || !_box!.isOpen) {
      return 0.0;
    }

    final now = DateTime.now();
    final start = startDate ?? DateTime(now.year, now.month, 1);
    final end = endDate ?? now;

    double total = 0.0;
    for (final t in _box!.values) {
      if (t.category == category) {
        final date = t.date;
        if ((date.isAfter(start) || _isSameDay(date, start)) &&
            (date.isBefore(end) || _isSameDay(date, end))) {
          total += t.amount;
        }
      }
    }
    return total;
  }

  bool _isSameDay(DateTime a, DateTime b) {
    return a.year == b.year && a.month == b.month && a.day == b.day;
  }
}
