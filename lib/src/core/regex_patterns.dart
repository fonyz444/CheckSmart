/// Regex patterns for parsing Kazakhstan receipts (Kaspi, Halyk)
library;

/// Patterns for extracting total amount from receipts
/// Supports Russian (ИТОГО), Kazakh (БАРЛЫҒЫ), English (TOTAL), and direct ₸ amounts
abstract class AmountPatterns {
  /// Matches: "ИТОГО: 15 000,00" or "ИТОГО 15000.00"
  static final RegExp russianTotal = RegExp(
    r'ИТОГО[\s:]*([0-9\s]+[.,]?\d*)',
    caseSensitive: false,
  );

  /// Matches: "БАРЛЫҒЫ: 15000.00"
  static final RegExp kazakhTotal = RegExp(
    r'БАРЛЫҒЫ[\s:]*([0-9\s]+[.,]?\d*)',
    caseSensitive: false,
  );

  /// Matches: "TOTAL: 15,000.00"
  static final RegExp englishTotal = RegExp(
    r'TOTAL[\s:]*([0-9\s]+[.,]?\d*)',
    caseSensitive: false,
  );

  /// Matches: "Сумма: 15 000" or "Сумма 15000.00"
  static final RegExp sumPattern = RegExp(
    r'Сумма[\s:]*([0-9\s]+[.,]?\d*)',
    caseSensitive: false,
  );

  /// Matches direct amounts with ₸ symbol: "265 ₸" or "1 500 ₸"
  /// This is common in Kaspi "Покупки" receipts
  static final RegExp tengeAmount = RegExp(r'([0-9\s]+)\s*[₸T]');

  /// List of all amount patterns in priority order
  static List<RegExp> get all => [
    russianTotal,
    kazakhTotal,
    englishTotal,
    sumPattern,
    tengeAmount,
  ];
}

/// Patterns for identifying Kaspi Bank receipts
abstract class KaspiPatterns {
  /// Kaspi "Покупки" (purchases) receipt markers
  static final RegExp purchaseMarker = RegExp(
    r'Покупки|Kaspi\.kz|Kaspi Gold',
    caseSensitive: false,
  );

  /// Payment success indicator
  static final RegExp successMarker = RegExp(
    r'Платеж успешно совершен',
    caseSensitive: false,
  );

  /// Merchant pattern: "ИП ДАДИКБАЕВА" or "ТОО Магнум"
  static final RegExp merchant = RegExp(
    r'(?:ИП|ТОО|АО)\s+([А-ЯЁA-Z][А-ЯЁа-яёA-Za-z\s]+)',
    caseSensitive: false,
  );

  /// Receipt number: "№ чека QR13833905692"
  static final RegExp receiptNumber = RegExp(
    r'№\s*чека[\s:]*([A-Z0-9]+)',
    caseSensitive: false,
  );

  /// Date pattern: "Дата и время ... 12.01.2026 11:36"
  static final RegExp dateTime = RegExp(
    r'(\d{2}\.\d{2}\.\d{4})\s+(\d{2}:\d{2})',
  );
}

/// Patterns for identifying Halyk Bank receipts
abstract class HalykPatterns {
  /// Halyk Bank markers
  static final RegExp bankMarker = RegExp(
    r'Halyk\s*Bank|homebank',
    caseSensitive: false,
  );

  /// Payment success indicator
  static final RegExp successMarker = RegExp(
    r'Status:\s*Success|Успешно',
    caseSensitive: false,
  );

  /// Payment details marker
  static final RegExp detailsMarker = RegExp(
    r'Payment\s*details',
    caseSensitive: false,
  );
}

/// Date parsing patterns common to all receipts
abstract class DatePatterns {
  /// DD.MM.YYYY format (most common in KZ)
  static final RegExp dotFormat = RegExp(r'(\d{2})\.(\d{2})\.(\d{4})');

  /// YYYY-MM-DD format (ISO)
  static final RegExp isoFormat = RegExp(r'(\d{4})-(\d{2})-(\d{2})');

  /// DD/MM/YYYY format
  static final RegExp slashFormat = RegExp(r'(\d{2})/(\d{2})/(\d{4})');
}
