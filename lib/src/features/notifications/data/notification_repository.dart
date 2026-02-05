import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:uuid/uuid.dart';

import '../../../core/constants.dart';
import '../domain/notification_settings.dart';

/// Provider for NotificationRepository
final notificationRepositoryProvider = Provider<NotificationRepository>((ref) {
  return NotificationRepository();
});

/// Provider for notification settings
final notificationSettingsProvider = Provider<NotificationSettings>((ref) {
  final repository = ref.watch(notificationRepositoryProvider);
  return repository.getSettings();
});

/// Repository for notification settings and history
class NotificationRepository {
  static const _uuid = Uuid();
  static const _settingsKey = 'notification_settings';

  Box? _settingsBox;
  Box? _historyBox;

  /// Get or open the settings box
  Future<Box> _getSettingsBox() async {
    if (_settingsBox == null || !_settingsBox!.isOpen) {
      _settingsBox = await Hive.openBox(HiveBoxes.settings);
    }
    return _settingsBox!;
  }

  /// Get or open the notification history box
  Future<Box> _getHistoryBox() async {
    if (_historyBox == null || !_historyBox!.isOpen) {
      _historyBox = await Hive.openBox(HiveBoxes.notificationHistory);
    }
    return _historyBox!;
  }

  /// Get notification settings (sync - uses already opened box)
  NotificationSettings getSettings() {
    try {
      final box = Hive.box(HiveBoxes.settings);
      final map = box.get(_settingsKey) as Map<dynamic, dynamic>?;
      if (map != null) {
        return NotificationSettings.fromMap(map);
      }
    } catch (_) {
      // Box not open yet, return defaults
    }
    return const NotificationSettings();
  }

  /// Save notification settings
  Future<void> saveSettings(NotificationSettings settings) async {
    final box = await _getSettingsBox();
    await box.put(_settingsKey, settings.toMap());
  }

  /// Check if a notification was already sent for this category/type in current period
  Future<bool> wasAlreadySent({
    required String categoryKey,
    required BudgetAlertType alertType,
    required DateTime periodStart,
  }) async {
    final box = await _getHistoryBox();
    final key = '${categoryKey}_${alertType.name}';
    final recordMap = box.get(key) as Map<dynamic, dynamic>?;

    if (recordMap == null) return false;

    final record = NotificationRecord.fromMap(recordMap);

    // Check if sent in the current budget period
    return record.periodStart.year == periodStart.year &&
        record.periodStart.month == periodStart.month &&
        record.periodStart.day == periodStart.day;
  }

  /// Record that a notification was sent
  Future<void> recordNotification({
    required String categoryKey,
    required BudgetAlertType alertType,
    required DateTime periodStart,
  }) async {
    final box = await _getHistoryBox();
    final key = '${categoryKey}_${alertType.name}';

    final record = NotificationRecord(
      id: _uuid.v4(),
      categoryKey: categoryKey,
      alertType: alertType,
      sentAt: DateTime.now(),
      periodStart: periodStart,
    );

    await box.put(key, record.toMap());
  }

  /// Get last forecast notification date (for weekly limit)
  Future<DateTime?> getLastForecastDate() async {
    final box = await _getHistoryBox();
    final timestamp = box.get('last_forecast_timestamp') as int?;
    if (timestamp == null) return null;
    return DateTime.fromMillisecondsSinceEpoch(timestamp);
  }

  /// Record forecast notification sent
  Future<void> recordForecastSent() async {
    final box = await _getHistoryBox();
    await box.put(
      'last_forecast_timestamp',
      DateTime.now().millisecondsSinceEpoch,
    );
  }

  /// Clear old notification history (older than 2 months)
  Future<void> cleanupOldRecords() async {
    final box = await _getHistoryBox();
    final twoMonthsAgo = DateTime.now().subtract(const Duration(days: 60));

    final keysToDelete = <String>[];
    for (final key in box.keys) {
      if (key is String && key != 'last_forecast_timestamp') {
        final recordMap = box.get(key) as Map<dynamic, dynamic>?;
        if (recordMap != null) {
          final record = NotificationRecord.fromMap(recordMap);
          if (record.sentAt.isBefore(twoMonthsAgo)) {
            keysToDelete.add(key);
          }
        }
      }
    }

    for (final key in keysToDelete) {
      await box.delete(key);
    }
  }
}
