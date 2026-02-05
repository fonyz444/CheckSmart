import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../features/notifications/data/notification_repository.dart';
import '../../features/notifications/domain/notification_settings.dart';

/// Provider for NotificationService
final notificationServiceProvider = Provider<NotificationService>((ref) {
  final settings = ref.watch(notificationSettingsProvider);
  return NotificationService(settings);
});

/// Service for displaying local notifications
class NotificationService {
  static final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();

  final NotificationSettings _settings;

  NotificationService(this._settings);

  /// Notification channel IDs
  static const String _channelIdBudget = 'budget_alerts';
  static const String _channelIdLarge = 'large_purchase';

  /// Initialize the notification plugin
  static Future<void> initialize() async {
    const androidSettings = AndroidInitializationSettings(
      '@mipmap/ic_launcher',
    );
    const iosSettings = DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
    );

    const initSettings = InitializationSettings(
      android: androidSettings,
      iOS: iosSettings,
    );

    await _plugin.initialize(initSettings);

    // Create notification channels for Android
    final androidPlugin =
        _plugin
            .resolvePlatformSpecificImplementation<
              AndroidFlutterLocalNotificationsPlugin
            >();

    if (androidPlugin != null) {
      await androidPlugin.createNotificationChannel(
        const AndroidNotificationChannel(
          _channelIdBudget,
          'Budget Alerts',
          description: 'Notifications about budget limits and overspending',
          importance: Importance.high,
        ),
      );

      await androidPlugin.createNotificationChannel(
        const AndroidNotificationChannel(
          _channelIdLarge,
          'Large Purchases',
          description: 'Notifications about large transactions',
          importance: Importance.defaultImportance,
        ),
      );
    }
  }

  /// Request notification permission (Android 13+)
  static Future<bool> requestPermission() async {
    final androidPlugin =
        _plugin
            .resolvePlatformSpecificImplementation<
              AndroidFlutterLocalNotificationsPlugin
            >();

    if (androidPlugin != null) {
      final granted = await androidPlugin.requestNotificationsPermission();
      return granted ?? false;
    }

    return true;
  }

  /// Check if currently in quiet hours
  bool _isInQuietHours() {
    final now = TimeOfDay.now();
    final start = _settings.quietStart;
    final end = _settings.quietEnd;

    // Convert to minutes for easier comparison
    final nowMinutes = now.hour * 60 + now.minute;
    final startMinutes = start.hour * 60 + start.minute;
    final endMinutes = end.hour * 60 + end.minute;

    // Handle overnight quiet hours (e.g., 22:00 to 08:00)
    if (startMinutes > endMinutes) {
      return nowMinutes >= startMinutes || nowMinutes < endMinutes;
    }

    return nowMinutes >= startMinutes && nowMinutes < endMinutes;
  }

  /// Show a budget warning notification (95%)
  Future<void> showBudgetWarning({
    required String categoryName,
    required double percentUsed,
    required double remaining,
  }) async {
    if (!_settings.isEnabled) return;
    if (_isInQuietHours()) return; // Not critical, respect quiet hours

    await _plugin.show(
      categoryName.hashCode,
      '$categoryName: ${percentUsed.toStringAsFixed(0)}% лимита',
      'Осталось ₸${remaining.toStringAsFixed(0)}',
      const NotificationDetails(
        android: AndroidNotificationDetails(
          _channelIdBudget,
          'Budget Alerts',
          channelDescription: 'Budget limit warnings',
          importance: Importance.high,
          priority: Priority.high,
          icon: '@mipmap/ic_launcher',
        ),
        iOS: DarwinNotificationDetails(
          presentAlert: true,
          presentBadge: true,
          presentSound: true,
        ),
      ),
    );
  }

  /// Show a budget exceeded notification (100%+)
  Future<void> showBudgetExceeded({
    required String categoryName,
    required double overspend,
  }) async {
    if (!_settings.isEnabled) return;
    // Critical notification - DO NOT respect quiet hours (per user request)

    await _plugin.show(
      categoryName.hashCode + 1000,
      '$categoryName: лимит исчерпан',
      'Перерасход +₸${overspend.toStringAsFixed(0)}',
      const NotificationDetails(
        android: AndroidNotificationDetails(
          _channelIdBudget,
          'Budget Alerts',
          channelDescription: 'Budget limit exceeded',
          importance: Importance.max,
          priority: Priority.max,
          icon: '@mipmap/ic_launcher',
        ),
        iOS: DarwinNotificationDetails(
          presentAlert: true,
          presentBadge: true,
          presentSound: true,
        ),
      ),
    );
  }

  /// Show a large purchase notification
  Future<void> showLargePurchase({
    required double amount,
    String? merchant,
  }) async {
    if (!_settings.isEnabled) return;
    if (_isInQuietHours()) return;

    final title = 'Крупная покупка: ₸${amount.toStringAsFixed(0)}';
    final body =
        merchant != null
            ? '$merchant — учесть в бюджете?'
            : 'Учесть в бюджете?';

    await _plugin.show(
      DateTime.now().millisecondsSinceEpoch ~/ 1000,
      title,
      body,
      const NotificationDetails(
        android: AndroidNotificationDetails(
          _channelIdLarge,
          'Large Purchases',
          channelDescription: 'Large transaction alerts',
          importance: Importance.defaultImportance,
          priority: Priority.defaultPriority,
          icon: '@mipmap/ic_launcher',
        ),
        iOS: DarwinNotificationDetails(
          presentAlert: true,
          presentBadge: true,
          presentSound: true,
        ),
      ),
    );
  }

  /// Show a forecast overspend notification
  Future<void> showForecastOverspend({
    required double projectedOverspend,
  }) async {
    if (!_settings.isEnabled || !_settings.forecastEnabled) return;
    if (_isInQuietHours()) return;

    await _plugin.show(
      999999,
      'Прогноз перерасхода',
      'По текущему темпу к концу месяца будет +₸${projectedOverspend.toStringAsFixed(0)} перерасхода',
      const NotificationDetails(
        android: AndroidNotificationDetails(
          _channelIdBudget,
          'Budget Alerts',
          channelDescription: 'Forecast alerts',
          importance: Importance.high,
          priority: Priority.high,
          icon: '@mipmap/ic_launcher',
        ),
        iOS: DarwinNotificationDetails(
          presentAlert: true,
          presentBadge: true,
          presentSound: true,
        ),
      ),
    );
  }
}
