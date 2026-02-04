import 'package:equatable/equatable.dart';
import 'package:hive/hive.dart';

/// Note: Hive adapters are manually defined in main.dart
/// The @HiveType and @HiveField annotations are kept for documentation

/// Represents a source of income (e.g., Salary, Freelance payment)
@HiveType(typeId: 6)
class IncomeEntity extends Equatable {
  @HiveField(0)
  final String id;

  @HiveField(1)
  final double amount;

  @HiveField(2)
  final String source; // e.g., "Salary", "Freelance", "Gift"

  @HiveField(3)
  final DateTime date;

  @HiveField(4)
  final String? description;

  @HiveField(5)
  final DateTime createdAt;

  const IncomeEntity({
    required this.id,
    required this.amount,
    required this.source,
    required this.date,
    this.description,
    required this.createdAt,
  });

  IncomeEntity copyWith({
    String? id,
    double? amount,
    String? source,
    DateTime? date,
    String? description,
    DateTime? createdAt,
  }) {
    return IncomeEntity(
      id: id ?? this.id,
      amount: amount ?? this.amount,
      source: source ?? this.source,
      date: date ?? this.date,
      description: description ?? this.description,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  @override
  List<Object?> get props => [id, amount, source, date, description, createdAt];
}
