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

    // Suggest category based on keywords
    final suggestedCategory = _suggestCategory(rawText);

    return ParsedReceipt(
      amount: amount,
      merchant: merchant,
      date: date,
      receiptNumber: receiptNumber,
      detectedSource: detectedSource,
      rawText: rawText,
      confidence: confidence,
      suggestedCategory: suggestedCategory,
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
    // Priority 0: Look for "ИТОГ" followed by amount (with or without =)
    // OCR variations: ИТОГО, ИТОГ, WTO, MTOT, MTOГ, ИТО, ИТОT
    // Handles: "ИТОГ =4200.00", "ИТОГО: 4200.00", "MTOT 4200.00"
    final itogoPattern = RegExp(
      r'(?:ИТОГ[ОO]?|[ИMW]TO[ГTT]?[OО]?|MTOT|MTOГ)[:\s]*[=I]?\s*(\d{1,3}(?:[\s,]?\d{3})*(?:[.,]\d{2})?)',
      caseSensitive: false,
    );
    var match = itogoPattern.firstMatch(text);
    if (match != null) {
      final cleaned = _cleanAmountString(match.group(1) ?? '');
      final amount = double.tryParse(cleaned);
      if (amount != null && amount > 0 && (amount < 2020 || amount > 2030)) {
        print('Found amount via ИТОГО pattern: $amount');
        return amount;
      }
    }

    // Priority 0.1: Look for "=415.00" or "I415.00" format (OCR often reads = as I)
    // Also look for amounts ending with .00 as they're likely totals
    // This is common in Magnum Cash&Carry and other Kazakh retail receipts
    final equalsAmountPattern = RegExp(
      r'[=I]\s*(\d{1,3}(?:[\s,]?\d{3})*(?:[.,]\d{2}))',
    );
    final equalsMatches = equalsAmountPattern.allMatches(text).toList();
    if (equalsMatches.isNotEmpty) {
      // Find the largest amount among all =XXX patterns (usually the total)
      double? maxAmount;
      for (final m in equalsMatches) {
        final cleaned = _cleanAmountString(m.group(1) ?? '');
        final amount = double.tryParse(cleaned);
        if (amount != null && amount > 0 && (amount < 2020 || amount > 2030)) {
          if (maxAmount == null || amount > maxAmount) {
            maxAmount = amount;
          }
        }
      }
      if (maxAmount != null && maxAmount >= 50) {
        print('Found amount via equals/I pattern: $maxAmount');
        return maxAmount;
      }
    }

    // Priority 0.5: Look for "КартаменТөлендi:QR:415.00" format (Magnum payment)
    final kartamenPattern = RegExp(
      r'(?:Картамен|KapTaMeH|[КK]арта)[^:]*:[^:]*:\s*(\d{1,3}(?:[\s,]?\d{3})*(?:[.,]\d{2})?)',
      caseSensitive: false,
    );
    match = kartamenPattern.firstMatch(text);
    if (match != null) {
      final cleaned = _cleanAmountString(match.group(1) ?? '');
      final amount = double.tryParse(cleaned);
      if (amount != null && amount > 0 && (amount < 2020 || amount > 2030)) {
        print('Found amount via card payment pattern: $amount');
        return amount;
      }
    }

    // Priority 0.6: Look for standalone "1,795 THr" or "1 795 тнг" format
    // This handles cases where OCR splits Сумма and amount on different lines
    final standaloneAmountTNGPattern = RegExp(
      r'(\d{1,3}(?:[,.\s]\d{3})+)\s*(?:тнг|THr|тг|ТНГ|ТГ|Thr)',
      caseSensitive: false,
    );
    match = standaloneAmountTNGPattern.firstMatch(text);
    if (match != null) {
      final cleaned = _cleanAmountString(match.group(1) ?? '');
      final amount = double.tryParse(cleaned);
      if (amount != null && amount >= 100 && (amount < 2020 || amount > 2030)) {
        print('Found amount via standalone THr pattern: $amount');
        return amount;
      }
    }

    // Priority 0.7: Look for "Сумма: 1,795 ТНГ" or "CyMma: 1,795 THr" format
    // This handles Kaspi/Детский мир receipts with comma as thousand separator
    // OCR variations: CyMma, CyMNa, CyMMa, CYMMA, Сумиа, Сумa
    final summaWithTNGPattern = RegExp(
      r'(?:Сумма|Сумa|Сумиa|CyM[MNmn]a|CYMMA)[:\s]+(\d{1,3}(?:[,.]\d{3})*(?:[.,]\d{2})?)\s*(?:тнг|THr|тг|ТНГ|ТГ|Thr)',
      caseSensitive: false,
    );
    match = summaWithTNGPattern.firstMatch(text);
    if (match != null) {
      final cleaned = _cleanAmountString(match.group(1) ?? '');
      final amount = double.tryParse(cleaned);
      if (amount != null && amount > 0 && (amount < 2020 || amount > 2030)) {
        print('Found amount via Сумма+ТНГ pattern: $amount');
        return amount;
      }
    }

    // Priority 1: Look for "265 ₸" or "265₸" pattern (amount with currency)
    // Match number followed by ₸ - must be at least 2 digits to avoid false positives
    final amountWithCurrency = RegExp(
      r'(\d{2,3}(?:\s?\d{3})*)\s*[₸Т](?:\s|$|[^a-zA-Zа-яА-Я])',
      caseSensitive: false,
    );
    match = amountWithCurrency.firstMatch(text);
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

    // Smart fallback: Find amounts ending with .00 (likely prices/totals)
    // EXCLUDE amounts preceded by "x " which are line item prices (e.g., "1,000 x 4900,00")
    // Pick the LAST valid amount as totals are usually at the bottom
    final decimalAmounts =
        RegExp(r'(\d{3,})[.,][0O]{2}').allMatches(text).toList();

    double? lastValidAmount;

    for (final m in decimalAmounts) {
      // Check if this amount is preceded by "x " (line item price)
      final precedingText =
          m.start >= 3 ? text.substring(m.start - 3, m.start) : '';
      final isLineItemPrice = RegExp(
        r'[xх×]\s*$',
        caseSensitive: false,
      ).hasMatch(precedingText);

      if (isLineItemPrice) {
        // Skip line item prices
        continue;
      }

      final cleaned = _cleanAmountString(m.group(1) ?? '');
      final amount = double.tryParse(cleaned);
      if (amount != null &&
          amount >= 100 &&
          amount <= 10000000 &&
          (amount < 2020 || amount > 2030)) {
        // Keep updating - the last one is usually the total
        lastValidAmount = amount;
      }
    }

    if (lastValidAmount != null) {
      print(
        'Found amount via decimal pattern (last non-item): $lastValidAmount',
      );
      return lastValidAmount;
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
  /// Handles both European (1.234,56) and Kazakh (1,234 or 1 234) formats
  String _cleanAmountString(String amount) {
    // First remove all spaces
    String cleaned = amount.replaceAll(RegExp(r'\s+'), '');

    // Check if comma is a thousand separator or decimal separator
    // Pattern: if we have X,XXX (comma followed by exactly 3 digits at end or before dot)
    // then comma is thousand separator
    if (RegExp(r'^\d{1,3}(,\d{3})+$').hasMatch(cleaned)) {
      // "1,795" or "12,345,678" - comma is thousand separator, no decimals
      cleaned = cleaned.replaceAll(',', '');
    } else if (RegExp(r'^\d{1,3}(,\d{3})+\.\d{2}$').hasMatch(cleaned)) {
      // "1,795.00" - comma is thousand separator, dot is decimal
      cleaned = cleaned.replaceAll(',', '');
    } else if (RegExp(r'^\d{1,3}(\.\d{3})+,\d{2}$').hasMatch(cleaned)) {
      // "1.795,00" - European format: dot is thousand, comma is decimal
      cleaned = cleaned.replaceAll('.', '').replaceAll(',', '.');
    } else {
      // Default: treat comma as decimal separator "1500,00" -> "1500.00"
      cleaned = cleaned.replaceAll(',', '.');
    }

    return cleaned;
  }

  /// Finds the index of ИТОГО-like keywords in text
  /// Returns -1 if not found
  int _findItogoKeywordIndex(String text) {
    final lowerText = text.toLowerCase();

    // Order by priority - more specific first
    final keywords = [
      'банковская карт', 'банковская кар', // Банковская карта (payment by card)
      'итого', 'итог', 'mtoro', 'mtor', 'wtoro', // ИТОГО variations
      'всего к оплате', 'к оплате',
      'всего',
    ];

    for (final keyword in keywords) {
      final index = lowerText.indexOf(keyword);
      if (index >= 0) {
        return index;
      }
    }

    return -1;
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

  /// Extracts the transaction date and time from receipt text
  DateTime? _extractDate(String text) {
    // Try DD.MM.YYYY HH:MM format first (Kaspi format with time)
    final dateTimePattern = RegExp(
      r'(\d{2})\.(\d{2})\.(\d{4})\s+(\d{1,2}):(\d{2})',
    );
    var match = dateTimePattern.firstMatch(text);
    if (match != null) {
      final day = int.tryParse(match.group(1) ?? '');
      final month = int.tryParse(match.group(2) ?? '');
      final year = int.tryParse(match.group(3) ?? '');
      final hour = int.tryParse(match.group(4) ?? '');
      final minute = int.tryParse(match.group(5) ?? '');

      if (day != null &&
          month != null &&
          year != null &&
          hour != null &&
          minute != null) {
        try {
          return DateTime(year, month, day, hour, minute);
        } catch (_) {
          // Invalid date components
        }
      }
    }

    // Try DD.MM.YYYY format (without time)
    match = DatePatterns.dotFormat.firstMatch(text);
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

  /// Suggests a category based on keywords in receipt text
  /// Returns null if no category could be determined
  ExpenseCategory _suggestCategory(String text) {
    final lowerText = text.toLowerCase();

    // Food/Grocery keywords (highest priority for supermarkets)
    // Include OCR variations: magnun, magпum, etc.
    final foodKeywords = [
      'magnum',
      'magnun',
      'magпum',
      'магнум',
      'cash&carry',
      'cashcarry',
      'small',
      'арзан',
      'metro',
      'метро',
      'продукты',
      'супермаркет',
      'supermarket',
      'grocery',
      'хлеб',
      'молоко',
      'мясо',
      'рыба',
      'овощи',
      'фрукты',
      'бакалея',
      'гастроном',
      'базар',
      'рынок',
      'green',
      'anvar',
      'ramstore',
      'рамстор',
      'interfood',
    ];
    for (final keyword in foodKeywords) {
      if (lowerText.contains(keyword)) {
        print('Suggested category: food (keyword: $keyword)');
        return ExpenseCategory.food;
      }
    }

    // Transport keywords
    final transportKeywords = [
      'бензин',
      'азс',
      'azs',
      'газпром',
      'petrol',
      'gasoline',
      'такси',
      'taxi',
      'яндекс',
      'yandex',
      'uber',
      'indriver',
      'bolt',
      'автобус',
      'bus',
      'метро',
      'subway',
      'sinooil',
      'qazaqoil',
      'helios',
      'гелиос',
      'km/l',
      'литр',
    ];
    for (final keyword in transportKeywords) {
      if (lowerText.contains(keyword)) {
        print('Suggested category: transport (keyword: $keyword)');
        return ExpenseCategory.transport;
      }
    }

    // Health/Pharmacy keywords
    final healthKeywords = [
      'аптека',
      'pharmacy',
      'pharma',
      'лекарств',
      'medicine',
      'doctor',
      'clinic',
      'клиника',
      'больница',
      'hospital',
      'стоматолог',
      'dentist',
      'dental',
      'медицин',
      'medical',
      'euroapteka',
      'sadyhan',
      'биосфера',
      'europharma',
    ];
    for (final keyword in healthKeywords) {
      if (lowerText.contains(keyword)) {
        print('Suggested category: health (keyword: $keyword)');
        return ExpenseCategory.health;
      }
    }

    // Entertainment keywords
    final entertainmentKeywords = [
      'кино',
      'cinema',
      'chaplin',
      'kinopark',
      'театр',
      'theater',
      'парк',
      'park',
      'аттракцион',
      'боулинг',
      'bowling',
      'бильярд',
      'караоке',
      'karaoke',
      'клуб',
      'club',
      'концерт',
      'concert',
      'игр',
      'game',
      'развлеч',
      'водный мир',
      'аквапарк',
    ];
    for (final keyword in entertainmentKeywords) {
      if (lowerText.contains(keyword)) {
        print('Suggested category: entertainment (keyword: $keyword)');
        return ExpenseCategory.entertainment;
      }
    }

    // Shopping keywords
    final shoppingKeywords = [
      'детский мир',
      'detskiy',
      'marwin',
      'zara',
      'hm',
      'h&m',
      'магазин',
      'shop',
      'store',
      'одежда',
      'clothes',
      'обувь',
      'shoes',
      'техника',
      'electronics',
      'sulpak',
      'сулпак',
      'mechta',
      'мечта',
      'technology',
      'алма',
      'cosmo',
    ];
    for (final keyword in shoppingKeywords) {
      if (lowerText.contains(keyword)) {
        print('Suggested category: shopping (keyword: $keyword)');
        return ExpenseCategory.shopping;
      }
    }

    // Utilities keywords
    final utilitiesKeywords = [
      'коммунал',
      'utility',
      'электр',
      'electric',
      'вода',
      'water',
      'газ',
      'gas',
      'отоплен',
      'heating',
      'qazaqgaz',
      'samruk',
      'казахтелеком',
      'kazakhtelecom',
      'billpay',
      'услуг',
    ];
    for (final keyword in utilitiesKeywords) {
      if (lowerText.contains(keyword)) {
        print('Suggested category: utilities (keyword: $keyword)');
        return ExpenseCategory.utilities;
      }
    }

    // Education keywords
    final educationKeywords = [
      'книга',
      'book',
      'учебник',
      'textbook',
      'курс',
      'course',
      'школа',
      'school',
      'университет',
      'university',
      'обучен',
      'training',
      'meloman',
      'меломан',
      'канцеляр',
      'stationery',
    ];
    for (final keyword in educationKeywords) {
      if (lowerText.contains(keyword)) {
        print('Suggested category: education (keyword: $keyword)');
        return ExpenseCategory.education;
      }
    }

    // Transfer keywords (NOTE: don't include kaspi/halyk - they appear on all receipts as payment method)
    final transferKeywords = [
      'перевод',
      'transfer',
      'пополнен',
      'deposit',
      'withdraw',
      'снятие',
      'зачисление',
      'получен перевод',
    ];
    for (final keyword in transferKeywords) {
      if (lowerText.contains(keyword)) {
        print('Suggested category: transfer (keyword: $keyword)');
        return ExpenseCategory.transfer;
      }
    }

    // Default to 'other' if no keywords matched
    print('Suggested category: other (no keywords matched)');
    return ExpenseCategory.other;
  }
}
