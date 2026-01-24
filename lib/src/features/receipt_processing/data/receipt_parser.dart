import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/constants.dart';
import '../../../core/regex_patterns.dart';
import '../domain/parsed_receipt.dart';

/// Provider for ReceiptParser
final receiptParserProvider = Provider<ReceiptParser>((ref) => ReceiptParser());

/// Parses raw OCR text into structured receipt data
///
/// **Parsing Strategy:**
/// 1. First detect the receipt source (Kaspi, Halyk, or generic)
/// 2. Apply source-specific patterns for better accuracy
/// 3. Fall back to generic patterns if specific ones fail
/// 4. Calculate confidence based on how many fields were extracted
class ReceiptParser {
  /// Parses raw OCR text and extracts structured data
  ///
  /// [rawText] - The raw text from Tesseract OCR
  /// [sourceHint] - Optional hint about the source (e.g., if file was named "kaspi.pdf")
  ParsedReceipt parse(String rawText, {ReceiptSource? sourceHint}) {
    if (rawText.trim().isEmpty) {
      return ParsedReceipt(
        rawText: rawText,
        detectedSource: sourceHint ?? ReceiptSource.camera,
        confidence: 0.0,
      );
    }

    // Detect source
    final detectedSource = _detectSource(rawText, sourceHint);

    // Extract fields
    final amount = _extractAmount(rawText);
    final merchant = _extractMerchant(rawText);
    final date = _extractDate(rawText);
    final receiptNumber = _extractReceiptNumber(rawText);

    // Calculate confidence (0.0 - 1.0)
    final confidence = _calculateConfidence(
      amount: amount,
      merchant: merchant,
      date: date,
      receiptNumber: receiptNumber,
    );

    return ParsedReceipt(
      amount: amount,
      merchant: merchant,
      date: date,
      receiptNumber: receiptNumber,
      detectedSource: detectedSource,
      rawText: rawText,
      confidence: confidence,
    );
  }

  /// Detects the receipt source based on text markers
  ReceiptSource _detectSource(String text, ReceiptSource? hint) {
    if (hint != null && hint != ReceiptSource.camera) {
      return hint; // Trust explicit hint
    }

    final lowerText = text.toLowerCase();

    // Check for Kaspi markers
    if (KaspiPatterns.purchaseMarker.hasMatch(text) ||
        lowerText.contains('kaspi')) {
      return ReceiptSource.pdfKaspi;
    }

    // Check for Halyk markers
    if (HalykPatterns.bankMarker.hasMatch(text) ||
        lowerText.contains('halyk') ||
        lowerText.contains('homebank')) {
      return ReceiptSource.pdfHalyk;
    }

    return ReceiptSource.camera; // Default to camera/generic
  }

  /// Extracts the transaction amount from receipt text
  double? _extractAmount(String text) {
    // Priority 1: Look for "265 T" or "265₸" pattern (amount with currency)
    // Match number followed by ₸ or standalone T (not in middle of word)
    final amountWithCurrency = RegExp(
      r'(\d{1,3}(?:\s?\d{3})*)\s*[₸ТT](?:\s|$|[^a-zA-Zа-яА-Я])',
      caseSensitive: false,
    );
    var match = amountWithCurrency.firstMatch(text);
    if (match != null) {
      final cleaned = _cleanAmountString(match.group(1) ?? '');
      final amount = double.tryParse(cleaned);
      // Filter out year-like numbers (2020-2030)
      if (amount != null && amount > 0 && (amount < 2020 || amount > 2030)) {
        print('Found amount with currency symbol: $amount');
        return amount;
      }
    }

    // Priority 2: "Платеж успешно совершен" followed by amount
    final successPattern = RegExp(
      r'успешно\s+совершен[^\d]*(\d{1,3}(?:\s?\d{3})*)',
      caseSensitive: false,
    );
    match = successPattern.firstMatch(text);
    if (match != null) {
      final cleaned = _cleanAmountString(match.group(1) ?? '');
      final amount = double.tryParse(cleaned);
      if (amount != null && amount > 0) {
        print('Found amount after success message: $amount');
        return amount;
      }
    }

    // Priority 3: Look for "Итого", "Сумма", "Оплачено" followed by amount
    final totalPattern = RegExp(
      r'(?:итого|сумма|всего|оплачено)[^\d]*(\d{1,3}(?:[\s,]\d{3})*(?:[.,]\d{2})?)',
      caseSensitive: false,
    );
    match = totalPattern.firstMatch(text);
    if (match != null) {
      final cleaned = _cleanAmountString(match.group(1) ?? '');
      final amount = double.tryParse(cleaned);
      if (amount != null && amount > 0) {
        print('Found amount after total keyword: $amount');
        return amount;
      }
    }

    // Try standard patterns from regex_patterns.dart
    for (final pattern in AmountPatterns.all) {
      match = pattern.firstMatch(text);
      if (match != null && match.groupCount >= 1) {
        final amountStr = match.group(1);
        if (amountStr != null) {
          final cleaned = _cleanAmountString(amountStr);
          final amount = double.tryParse(cleaned);
          // Filter out year-like numbers
          if (amount != null &&
              amount > 0 &&
              (amount < 2020 || amount > 2030)) {
            print('Found amount via standard pattern: $amount');
            return amount;
          }
        }
      }
    }

    // Last resort: Find standalone numbers (not years, not too small)
    final allNumbers = RegExp(r'\b(\d{2,}(?:\s\d{3})*)\b').allMatches(text);
    for (final numMatch in allNumbers) {
      final cleaned = _cleanAmountString(numMatch.group(1) ?? '');
      final amount = double.tryParse(cleaned);
      // Reasonable range: 50 - 10,000,000 AND not a year
      if (amount != null &&
          amount >= 50 &&
          amount <= 10000000 &&
          (amount < 2020 || amount > 2030)) {
        print('Found amount via fallback: $amount');
        return amount;
      }
    }

    return null;
  }

  /// Cleans an amount string by removing spaces and normalizing separators
  String _cleanAmountString(String amount) {
    return amount
        .replaceAll(RegExp(r'\s+'), '') // Remove spaces: "1 500" -> "1500"
        .replaceAll(',', '.'); // Normalize decimal: "1500,00" -> "1500.00"
  }

  /// Extracts the merchant name from receipt text
  String? _extractMerchant(String text) {
    // Pattern 1: Cyrillic "ИП ДАДИКБАЕВА", "ТОО МАГНУМ"
    final cyrillicPattern = RegExp(
      r'(?:ИП|ТОО|АО|ЗАО)\s+[А-ЯЁA-Z][А-ЯЁа-яёA-Za-z\s]+',
      caseSensitive: false,
    );
    var match = cyrillicPattern.firstMatch(text);
    if (match != null) {
      return match.group(0)?.trim();
    }

    // Pattern 2: Latin transliteration of Cyrillic prefixes
    // OCR often reads: ИП -> Mn, MN, IP | ТОО -> TOO | АО -> AO
    final latinPattern = RegExp(
      r'(?:Mn|MN|IP|Inn|TOO|AO|3AO)\s+[A-ZА-ЯЁ][A-Za-zА-Яа-яЁё\s]+',
      caseSensitive: false,
    );
    match = latinPattern.firstMatch(text);
    if (match != null) {
      String merchant = match.group(0)?.trim() ?? '';
      // Convert Latin-transliterated prefix to proper Cyrillic
      merchant = merchant
          .replaceAll(RegExp(r'^Mn\s+', caseSensitive: false), 'ИП ')
          .replaceAll(RegExp(r'^MN\s+', caseSensitive: false), 'ИП ')
          .replaceAll(RegExp(r'^IP\s+', caseSensitive: false), 'ИП ')
          .replaceAll(RegExp(r'^Inn\s+', caseSensitive: false), 'ИП ')
          .replaceAll(RegExp(r'^TOO\s+', caseSensitive: false), 'ТОО ')
          .replaceAll(RegExp(r'^AO\s+', caseSensitive: false), 'АО ')
          .replaceAll(RegExp(r'^3AO\s+', caseSensitive: false), 'ЗАО ');
      return merchant;
    }

    // Pattern 3: Any capitalized name after common merchant labels
    final labelPattern = RegExp(
      r'(?:продавец|магазин|компания)[:\s]+([A-ZА-ЯЁ][A-Za-zА-Яа-яЁё\s]+)',
      caseSensitive: false,
    );
    match = labelPattern.firstMatch(text);
    if (match != null && match.groupCount >= 1) {
      return match.group(1)?.trim();
    }

    return null;
  }

  /// Extracts the transaction date from receipt text
  DateTime? _extractDate(String text) {
    // Try DD.MM.YYYY format first (most common in KZ)
    var match = DatePatterns.dotFormat.firstMatch(text);
    if (match != null) {
      final day = int.tryParse(match.group(1) ?? '');
      final month = int.tryParse(match.group(2) ?? '');
      final year = int.tryParse(match.group(3) ?? '');

      if (day != null && month != null && year != null) {
        try {
          return DateTime(year, month, day);
        } catch (_) {
          // Invalid date components
        }
      }
    }

    // Try YYYY-MM-DD format
    match = DatePatterns.isoFormat.firstMatch(text);
    if (match != null) {
      final year = int.tryParse(match.group(1) ?? '');
      final month = int.tryParse(match.group(2) ?? '');
      final day = int.tryParse(match.group(3) ?? '');

      if (day != null && month != null && year != null) {
        try {
          return DateTime(year, month, day);
        } catch (_) {
          // Invalid date components
        }
      }
    }

    return null;
  }

  /// Extracts the receipt number from text
  String? _extractReceiptNumber(String text) {
    final match = KaspiPatterns.receiptNumber.firstMatch(text);
    if (match != null && match.groupCount >= 1) {
      return match.group(1);
    }

    // Generic receipt number pattern
    final genericPattern = RegExp(r'(?:№|#|Receipt)\s*:?\s*([A-Z0-9]{6,})');
    final genericMatch = genericPattern.firstMatch(text);
    if (genericMatch != null && genericMatch.groupCount >= 1) {
      return genericMatch.group(1);
    }

    return null;
  }

  /// Calculates confidence score based on extracted fields
  double _calculateConfidence({
    double? amount,
    String? merchant,
    DateTime? date,
    String? receiptNumber,
  }) {
    double score = 0.0;

    // Amount is worth 40% (most important)
    if (amount != null && amount > 0) score += 0.4;

    // Merchant is worth 25%
    if (merchant != null && merchant.isNotEmpty) score += 0.25;

    // Date is worth 25%
    if (date != null) score += 0.25;

    // Receipt number is worth 10%
    if (receiptNumber != null && receiptNumber.isNotEmpty) score += 0.1;

    return score;
  }
}
