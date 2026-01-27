import 'package:equatable/equatable.dart';
import '../../../core/constants.dart';

/// Represents a financial transaction in the app
///
/// Note: Hive adapters are manually defined in main.dart
/// The @HiveType and @HiveField annotations are kept for documentation
class TransactionEntity extends Equatable {
  final String id;
  final double amount;
  final String currency;
  final String? merchant;
  final ExpenseCategory category;
  final String? customCategoryId; // For custom user categories
  final DateTime date;
  final ReceiptSource source;
  final String? receiptNumber;
  final String? rawOcrText;
  final String? note;
  final DateTime createdAt;

  const TransactionEntity({
    required this.id,
    required this.amount,
    this.currency = kDefaultCurrency,
    this.merchant,
    required this.category,
    this.customCategoryId,
    required this.date,
    required this.source,
    this.receiptNumber,
    this.rawOcrText,
    this.note,
    required this.createdAt,
  });

  /// Creates a copy with optional field updates
  TransactionEntity copyWith({
    String? id,
    double? amount,
    String? currency,
    String? merchant,
    ExpenseCategory? category,
    String? customCategoryId,
    bool clearCustomCategoryId = false,
    DateTime? date,
    ReceiptSource? source,
    String? receiptNumber,
    String? rawOcrText,
    String? note,
    DateTime? createdAt,
  }) {
    return TransactionEntity(
      id: id ?? this.id,
      amount: amount ?? this.amount,
      currency: currency ?? this.currency,
      merchant: merchant ?? this.merchant,
      category: category ?? this.category,
      customCategoryId:
          clearCustomCategoryId
              ? null
              : (customCategoryId ?? this.customCategoryId),
      date: date ?? this.date,
      source: source ?? this.source,
      receiptNumber: receiptNumber ?? this.receiptNumber,
      rawOcrText: rawOcrText ?? this.rawOcrText,
      note: note ?? this.note,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  @override
  List<Object?> get props => [
    id,
    amount,
    currency,
    merchant,
    category,
    customCategoryId,
    date,
    source,
    receiptNumber,
    rawOcrText,
    note,
    createdAt,
  ];
}
