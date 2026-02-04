import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:uuid/uuid.dart';

import '../../../core/constants.dart';
import '../domain/income_entity.dart';

/// Provider for IncomeRepository
final incomeRepositoryProvider = Provider<IncomeRepository>((ref) {
  return IncomeRepository();
});

/// Provider for all income entries
final incomeListProvider =
    StateNotifierProvider<IncomeListNotifier, List<IncomeEntity>>((ref) {
      return IncomeListNotifier();
    });

/// Provider for total income in current month
final monthlyIncomeProvider = Provider<double>((ref) {
  final incomeList = ref.watch(incomeListProvider);
  final now = DateTime.now();
  final startOfMonth = DateTime(now.year, now.month, 1);

  return incomeList
      .where(
        (i) => i.date.isAfter(startOfMonth) || _isSameDay(i.date, startOfMonth),
      )
      .fold(0.0, (sum, i) => sum + i.amount);
});

bool _isSameDay(DateTime a, DateTime b) {
  return a.year == b.year && a.month == b.month && a.day == b.day;
}

/// Repository for managing income with Hive storage
class IncomeRepository {
  final _uuid = const Uuid();

  Box<IncomeEntity> get _box => Hive.box<IncomeEntity>(HiveBoxes.income);

  /// Get all income entries
  List<IncomeEntity> getAll() {
    return _box.values.toList()..sort((a, b) => b.date.compareTo(a.date));
  }

  /// Add new income
  Future<IncomeEntity> add({
    required double amount,
    required String source,
    required DateTime date,
    String? description,
  }) async {
    final income = IncomeEntity(
      id: _uuid.v4(),
      amount: amount,
      source: source,
      date: date,
      description: description,
      createdAt: DateTime.now(),
    );
    await _box.put(income.id, income);
    return income;
  }

  /// Update income
  Future<IncomeEntity> update(IncomeEntity income) async {
    await _box.put(income.id, income);
    return income;
  }

  /// Delete income
  Future<void> delete(String id) async {
    await _box.delete(id);
  }

  /// Get total income for a period
  double getTotalForPeriod(DateTime start, DateTime end) {
    return _box.values
        .where(
          (i) =>
              i.date.isAfter(start) &&
              i.date.isBefore(end.add(const Duration(days: 1))),
        )
        .fold(0.0, (sum, i) => sum + i.amount);
  }
}

/// StateNotifier for income list
class IncomeListNotifier extends StateNotifier<List<IncomeEntity>> {
  Box<IncomeEntity>? _box;
  final _uuid = const Uuid();

  IncomeListNotifier() : super([]) {
    _init();
  }

  Future<void> _init() async {
    _box = Hive.box<IncomeEntity>(HiveBoxes.income);
    state = _box!.values.toList()..sort((a, b) => b.date.compareTo(a.date));
  }

  /// Add new income
  Future<void> add({
    required double amount,
    required String source,
    required DateTime date,
    String? description,
  }) async {
    final income = IncomeEntity(
      id: _uuid.v4(),
      amount: amount,
      source: source,
      date: date,
      description: description,
      createdAt: DateTime.now(),
    );
    await _box?.put(income.id, income);
    state = [...state, income]..sort((a, b) => b.date.compareTo(a.date));
  }

  /// Update income
  Future<void> update(IncomeEntity income) async {
    await _box?.put(income.id, income);
    state = state.map((i) => i.id == income.id ? income : i).toList();
  }

  /// Delete income
  Future<void> delete(String id) async {
    await _box?.delete(id);
    state = state.where((i) => i.id != id).toList();
  }

  /// Refresh from storage
  Future<void> refresh() async {
    if (_box != null) {
      state = _box!.values.toList()..sort((a, b) => b.date.compareTo(a.date));
    }
  }
}
