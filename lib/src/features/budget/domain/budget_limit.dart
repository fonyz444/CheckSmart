import 'package:equatable/equatable.dart';
import 'package:hive/hive.dart';

import '../../../core/constants.dart';

part 'budget_limit.g.dart';

/// Period for budget limits
@HiveType(typeId: 2)
enum BudgetPeriod {
  @HiveField(0)
  week,
  @HiveField(1)
  month,
  @HiveField(2)
  year;

  String get displayName {
    switch (this) {
      case BudgetPeriod.week:
        return 'Неделя';
      case BudgetPeriod.month:
        return 'Месяц';
      case BudgetPeriod.year:
        return 'Год';
    }
  }

  String get shortName {
    switch (this) {
      case BudgetPeriod.week:
        return 'нед';
      case BudgetPeriod.month:
        return 'мес';
      case BudgetPeriod.year:
        return 'год';
    }
  }
}

/// Budget limit for a specific category
@HiveType(typeId: 3)
class BudgetLimit extends Equatable {
  @HiveField(0)
  final String id;

  @HiveField(1)
  final ExpenseCategory category;

  @HiveField(2)
  final double limitAmount;

  @HiveField(3)
  final BudgetPeriod period;

  @HiveField(4)
  final DateTime createdAt;

  @HiveField(5)
  final bool isActive;

  const BudgetLimit({
    required this.id,
    required this.category,
    required this.limitAmount,
    required this.period,
    required this.createdAt,
    this.isActive = true,
  });

  /// Calculate percentage of limit used
  double percentUsed(double spent) {
    if (limitAmount <= 0) return 0;
    return (spent / limitAmount * 100).clamp(0, 200);
  }

  /// Get status color based on percentage used
  /// Green: 0-60%, Yellow: 60-80%, Red: 80%+
  BudgetStatus getStatus(double spent) {
    final percent = percentUsed(spent);
    if (percent >= 100) return BudgetStatus.exceeded;
    if (percent >= 80) return BudgetStatus.warning;
    if (percent >= 60) return BudgetStatus.caution;
    return BudgetStatus.good;
  }

  /// Get remaining amount
  double remaining(double spent) {
    return (limitAmount - spent).clamp(0, double.infinity);
  }

  BudgetLimit copyWith({
    String? id,
    ExpenseCategory? category,
    double? limitAmount,
    BudgetPeriod? period,
    DateTime? createdAt,
    bool? isActive,
  }) {
    return BudgetLimit(
      id: id ?? this.id,
      category: category ?? this.category,
      limitAmount: limitAmount ?? this.limitAmount,
      period: period ?? this.period,
      createdAt: createdAt ?? this.createdAt,
      isActive: isActive ?? this.isActive,
    );
  }

  @override
  List<Object?> get props => [
    id,
    category,
    limitAmount,
    period,
    createdAt,
    isActive,
  ];
}

/// Budget status for visual indication
enum BudgetStatus {
  good, // 0-60% - Green
  caution, // 60-80% - Yellow
  warning, // 80-100% - Orange
  exceeded; // 100%+ - Red

  int get colorValue {
    switch (this) {
      case BudgetStatus.good:
        return 0xFF00D09C; // Green
      case BudgetStatus.caution:
        return 0xFFFFD93D; // Yellow
      case BudgetStatus.warning:
        return 0xFFFF9500; // Orange
      case BudgetStatus.exceeded:
        return 0xFFFF4757; // Red
    }
  }
}
