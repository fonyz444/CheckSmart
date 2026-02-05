import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/constants.dart';
import '../../notifications/application/budget_alert_service.dart';
import '../data/transaction_repository.dart';
import '../domain/transaction_entity.dart';

/// Provider for TransactionService (wraps TransactionRepository with alerts)
final transactionServiceProvider = Provider<TransactionService>((ref) {
  return TransactionService(ref);
});

/// Service that wraps TransactionRepository and triggers budget alerts
class TransactionService {
  final Ref _ref;

  TransactionService(this._ref);

  /// Add a transaction and check for budget alerts
  Future<TransactionEntity> addTransaction({
    required double amount,
    required ExpenseCategory category,
    required DateTime date,
    required ReceiptSource source,
    String? merchant,
    String? receiptNumber,
    String? rawOcrText,
    String? note,
    String? customCategoryId,
  }) async {
    final repository = _ref.read(transactionRepositoryProvider);

    // Add the transaction
    final transaction = await repository.add(
      amount: amount,
      category: category,
      date: date,
      source: source,
      merchant: merchant,
      receiptNumber: receiptNumber,
      rawOcrText: rawOcrText,
      note: note,
      customCategoryId: customCategoryId,
    );

    // Check budget alerts (async, don't block the UI)
    _checkAlerts(transaction);

    return transaction;
  }

  /// Check alerts asynchronously
  Future<void> _checkAlerts(TransactionEntity transaction) async {
    try {
      final alertService = _ref.read(budgetAlertServiceProvider);
      await alertService.checkAlerts(transaction);
    } catch (e) {
      // Don't let alert failures affect the transaction
      // Could log this error in production
    }
  }

  /// Update a transaction (no alerts for updates)
  Future<void> updateTransaction(TransactionEntity transaction) async {
    final repository = _ref.read(transactionRepositoryProvider);
    await repository.update(transaction);
  }

  /// Delete a transaction
  Future<void> deleteTransaction(String id) async {
    final repository = _ref.read(transactionRepositoryProvider);
    await repository.delete(id);
  }
}
