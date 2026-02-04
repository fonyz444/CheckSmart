/// Core constants for the CheckSmart.kz application
library;

/// Default currency for Kazakhstan
const String kDefaultCurrency = 'KZT';
const String kCurrencySymbol = '₸';

/// Hive box names for local storage
abstract class HiveBoxes {
  static const String transactions = 'transactions_box';
  static const String settings = 'settings_box';
  static const String customCategories = 'custom_categories_box';
  static const String income = 'income_box';
}

/// Hive type IDs for type adapters
abstract class HiveTypeIds {
  static const int transaction = 0;
  static const int receiptSource = 1;
  static const int category = 2;
  static const int customCategory = 3;
  static const int income = 6;
}

/// Default expense categories for Kazakhstan market
enum ExpenseCategory {
  food('Food', '🍔'),
  transport('Transport', '🚗'),
  utilities('Utilities', '💡'),
  shopping('Shopping', '🛒'),
  entertainment('Entertainment', '🎬'),
  health('Health', '💊'),
  education('Education', '📚'),
  taxes('Taxes', '🏛️'),
  transfer('Transfer', '💸'),
  other('Other', '📦');

  final String displayName;
  final String emoji;

  const ExpenseCategory(this.displayName, this.emoji);
}

/// Source of the receipt/transaction
enum ReceiptSource {
  camera('Camera'),
  pdfKaspi('Kaspi PDF'),
  pdfHalyk('Halyk PDF'),
  manual('Manual');

  final String displayName;

  const ReceiptSource(this.displayName);
}
