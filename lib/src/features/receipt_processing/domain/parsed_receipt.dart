import 'package:equatable/equatable.dart';
import '../../../core/constants.dart';

/// Represents the result of parsing a receipt (image or PDF)
/// This is an intermediate object before creating a full TransactionEntity
class ParsedReceipt extends Equatable {
  /// Extracted amount in Tenge (KZT)
  final double? amount;

  /// Extracted merchant name (e.g., "ИП ДАДИКБАЕВА")
  final String? merchant;

  /// Extracted transaction date
  final DateTime? date;

  /// Receipt/check number if found
  final String? receiptNumber;

  /// Detected source (Kaspi, Halyk, or generic camera)
  final ReceiptSource detectedSource;

  /// The raw OCR text for debugging and manual correction
  final String rawText;

  /// Confidence score (0.0 - 1.0) based on how many fields were extracted
  final double confidence;

  /// Auto-detected category based on receipt keywords
  final ExpenseCategory? suggestedCategory;

  const ParsedReceipt({
    this.amount,
    this.merchant,
    this.date,
    this.receiptNumber,
    required this.detectedSource,
    required this.rawText,
    required this.confidence,
    this.suggestedCategory,
  });

  /// Returns true if enough data was extracted to create a transaction
  bool get isValid => amount != null && amount! > 0;

  /// Returns true if this appears to be a Kaspi receipt
  bool get isKaspi =>
      detectedSource == ReceiptSource.pdfKaspi ||
      rawText.toLowerCase().contains('kaspi');

  /// Returns true if this appears to be a Halyk receipt
  bool get isHalyk =>
      detectedSource == ReceiptSource.pdfHalyk ||
      rawText.toLowerCase().contains('halyk');

  @override
  List<Object?> get props => [
    amount,
    merchant,
    date,
    receiptNumber,
    detectedSource,
    rawText,
    confidence,
    suggestedCategory,
  ];

  @override
  String toString() {
    return 'ParsedReceipt(amount: $amount ₸, merchant: $merchant, '
        'date: $date, source: ${detectedSource.displayName}, '
        'confidence: ${(confidence * 100).toStringAsFixed(0)}%)';
  }
}
