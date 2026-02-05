import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/services/notification_service.dart';
import '../../budget/data/budget_limit_repository.dart';
import '../../budget/domain/budget_limit.dart';
import '../../categories/data/custom_category_repository.dart';
import '../../transactions/domain/transaction_entity.dart';
import '../data/notification_repository.dart';
import '../domain/notification_settings.dart';

/// Provider for BudgetAlertService
final budgetAlertServiceProvider = Provider<BudgetAlertService>((ref) {
  return BudgetAlertService(ref);
});

/// Service that checks transactions and triggers budget alerts
class BudgetAlertService {
  final Ref _ref;

  BudgetAlertService(this._ref);

  /// Check all alert conditions for a new transaction
  Future<void> checkAlerts(TransactionEntity transaction) async {
    final settings = _ref.read(notificationSettingsProvider);
    if (!settings.isEnabled) return;

    // Check budget limit alerts
    await _checkBudgetAlerts(transaction, settings);

    // Check large purchase
    await _checkLargePurchase(transaction, settings);

    // Check forecast (less frequently)
    await _checkForecast(settings);
  }

  /// Check budget limit thresholds
  Future<void> _checkBudgetAlerts(
    TransactionEntity transaction,
    NotificationSettings settings,
  ) async {
    final budgetRepo = _ref.read(budgetLimitRepositoryProvider);
    final notificationRepo = _ref.read(notificationRepositoryProvider);
    final notificationService = _ref.read(notificationServiceProvider);

    // Determine category key and get budget limit
    String categoryKey;
    String categoryName;
    BudgetLimit? limit;

    if (transaction.customCategoryId != null) {
      categoryKey = 'custom_${transaction.customCategoryId}';
      limit = budgetRepo.getByCustomCategory(transaction.customCategoryId!);

      // Get custom category name from state
      final customCategories = _ref.read(customCategoriesProvider);
      final customCategory =
          customCategories
              .where((c) => c.id == transaction.customCategoryId)
              .firstOrNull;
      categoryName = customCategory?.name ?? 'Другое';
    } else {
      categoryKey = transaction.category.name;
      limit = budgetRepo.getByCategory(transaction.category);
      categoryName = transaction.category.displayName;
    }

    if (limit == null || !limit.isActive) return;

    // Calculate current spending
    final spent = await budgetRepo.getSpentInPeriod(
      limit.category,
      limit.period,
      customCategoryId: limit.customCategoryId,
    );

    final percentUsed = limit.percentUsed(spent);
    final periodStart = _getPeriodStart(limit.period);

    // Check 100% threshold (exceeded) - CRITICAL
    if (percentUsed >= 100) {
      final alreadySent = await notificationRepo.wasAlreadySent(
        categoryKey: categoryKey,
        alertType: BudgetAlertType.exceeded,
        periodStart: periodStart,
      );

      if (!alreadySent) {
        final overspend = spent - limit.limitAmount;
        await notificationService.showBudgetExceeded(
          categoryName: categoryName,
          overspend: overspend,
        );
        await notificationRepo.recordNotification(
          categoryKey: categoryKey,
          alertType: BudgetAlertType.exceeded,
          periodStart: periodStart,
        );
      }
    }
    // Check warning threshold (95%)
    else if (percentUsed >= settings.warningThreshold * 100) {
      final alreadySent = await notificationRepo.wasAlreadySent(
        categoryKey: categoryKey,
        alertType: BudgetAlertType.warning,
        periodStart: periodStart,
      );

      if (!alreadySent) {
        await notificationService.showBudgetWarning(
          categoryName: categoryName,
          percentUsed: percentUsed,
          remaining: limit.remaining(spent),
        );
        await notificationRepo.recordNotification(
          categoryKey: categoryKey,
          alertType: BudgetAlertType.warning,
          periodStart: periodStart,
        );
      }
    }
  }

  /// Check if transaction is a large purchase
  Future<void> _checkLargePurchase(
    TransactionEntity transaction,
    NotificationSettings settings,
  ) async {
    if (transaction.amount >= settings.largePurchaseThreshold) {
      final notificationService = _ref.read(notificationServiceProvider);
      await notificationService.showLargePurchase(
        amount: transaction.amount,
        merchant: transaction.merchant,
      );
    }
  }

  /// Check forecast and send alert if needed (max once per week)
  Future<void> _checkForecast(NotificationSettings settings) async {
    if (!settings.forecastEnabled) return;

    final notificationRepo = _ref.read(notificationRepositoryProvider);
    final lastForecastDate = await notificationRepo.getLastForecastDate();

    // Only check once per week
    if (lastForecastDate != null) {
      final daysSince = DateTime.now().difference(lastForecastDate).inDays;
      if (daysSince < 7) return;
    }

    // Calculate projected monthly spending
    final budgetRepo = _ref.read(budgetLimitRepositoryProvider);
    final limits = budgetRepo.getAll();

    // Sum up all monthly budgets
    double totalBudget = 0;
    double totalSpent = 0;

    for (final limit in limits) {
      if (limit.period == BudgetPeriod.month) {
        totalBudget += limit.limitAmount;
        final spent = await budgetRepo.getSpentInPeriod(
          limit.category,
          limit.period,
          customCategoryId: limit.customCategoryId,
        );
        totalSpent += spent;
      }
    }

    if (totalBudget <= 0) return;

    // Calculate run rate forecast
    final now = DateTime.now();
    final endOfMonth = DateTime(now.year, now.month + 1, 0);
    final daysInMonth = endOfMonth.day;
    final daysPassed = now.day;

    if (daysPassed < 5) return; // Wait for enough data

    final dailyRate = totalSpent / daysPassed;
    final projectedMonthly = dailyRate * daysInMonth;
    final projectedOverspend = projectedMonthly - totalBudget;

    // Only alert if projected overspend is significant (>5%)
    if (projectedOverspend > totalBudget * 0.05) {
      final notificationService = _ref.read(notificationServiceProvider);
      await notificationService.showForecastOverspend(
        projectedOverspend: projectedOverspend,
      );
      await notificationRepo.recordForecastSent();
    }
  }

  /// Get the start date of the current budget period
  DateTime _getPeriodStart(BudgetPeriod period) {
    final now = DateTime.now();
    switch (period) {
      case BudgetPeriod.week:
        final daysToMonday = now.weekday - 1;
        return DateTime(now.year, now.month, now.day - daysToMonday);
      case BudgetPeriod.month:
        return DateTime(now.year, now.month, 1);
      case BudgetPeriod.year:
        return DateTime(now.year, 1, 1);
    }
  }
}
