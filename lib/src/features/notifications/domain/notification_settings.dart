import 'package:flutter/material.dart';

/// User preferences for budget notifications
class NotificationSettings {
  /// Enable/disable all budget notifications
  final bool isEnabled;

  /// Warning threshold (e.g., 0.95 = 95%)
  final double warningThreshold;

  /// Large purchase threshold in KZT (absolute value)
  final double largePurchaseThreshold;

  /// Enable forecast notifications
  final bool forecastEnabled;

  /// Quiet hours start time (notifications silenced)
  final TimeOfDay quietStart;

  /// Quiet hours end time
  final TimeOfDay quietEnd;

  const NotificationSettings({
    this.isEnabled = true,
    this.warningThreshold = 0.95,
    this.largePurchaseThreshold = 50000,
    this.forecastEnabled = true,
    this.quietStart = const TimeOfDay(hour: 22, minute: 0),
    this.quietEnd = const TimeOfDay(hour: 8, minute: 0),
  });

  NotificationSettings copyWith({
    bool? isEnabled,
    double? warningThreshold,
    double? largePurchaseThreshold,
    bool? forecastEnabled,
    TimeOfDay? quietStart,
    TimeOfDay? quietEnd,
  }) {
    return NotificationSettings(
      isEnabled: isEnabled ?? this.isEnabled,
      warningThreshold: warningThreshold ?? this.warningThreshold,
      largePurchaseThreshold:
          largePurchaseThreshold ?? this.largePurchaseThreshold,
      forecastEnabled: forecastEnabled ?? this.forecastEnabled,
      quietStart: quietStart ?? this.quietStart,
      quietEnd: quietEnd ?? this.quietEnd,
    );
  }

  /// Convert to Map for Hive storage
  Map<String, dynamic> toMap() {
    return {
      'isEnabled': isEnabled,
      'warningThreshold': warningThreshold,
      'largePurchaseThreshold': largePurchaseThreshold,
      'forecastEnabled': forecastEnabled,
      'quietStartHour': quietStart.hour,
      'quietStartMinute': quietStart.minute,
      'quietEndHour': quietEnd.hour,
      'quietEndMinute': quietEnd.minute,
    };
  }

  /// Create from Map (Hive storage)
  factory NotificationSettings.fromMap(Map<dynamic, dynamic> map) {
    return NotificationSettings(
      isEnabled: map['isEnabled'] as bool? ?? true,
      warningThreshold: (map['warningThreshold'] as num?)?.toDouble() ?? 0.95,
      largePurchaseThreshold:
          (map['largePurchaseThreshold'] as num?)?.toDouble() ?? 50000,
      forecastEnabled: map['forecastEnabled'] as bool? ?? true,
      quietStart: TimeOfDay(
        hour: map['quietStartHour'] as int? ?? 22,
        minute: map['quietStartMinute'] as int? ?? 0,
      ),
      quietEnd: TimeOfDay(
        hour: map['quietEndHour'] as int? ?? 8,
        minute: map['quietEndMinute'] as int? ?? 0,
      ),
    );
  }
}

/// Types of budget alerts
enum BudgetAlertType {
  warning, // 95% threshold
  exceeded, // 100% threshold
  largePurchase, // Large single purchase
  forecast, // Overspend forecast
}

/// Record of a sent notification for deduplication
class NotificationRecord {
  final String id;
  final String categoryKey; // "food", "custom_abc123", etc.
  final BudgetAlertType alertType;
  final DateTime sentAt;
  final DateTime periodStart; // Start of budget period when sent

  const NotificationRecord({
    required this.id,
    required this.categoryKey,
    required this.alertType,
    required this.sentAt,
    required this.periodStart,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'categoryKey': categoryKey,
      'alertType': alertType.index,
      'sentAt': sentAt.millisecondsSinceEpoch,
      'periodStart': periodStart.millisecondsSinceEpoch,
    };
  }

  factory NotificationRecord.fromMap(Map<dynamic, dynamic> map) {
    return NotificationRecord(
      id: map['id'] as String,
      categoryKey: map['categoryKey'] as String,
      alertType: BudgetAlertType.values[map['alertType'] as int],
      sentAt: DateTime.fromMillisecondsSinceEpoch(map['sentAt'] as int),
      periodStart: DateTime.fromMillisecondsSinceEpoch(
        map['periodStart'] as int,
      ),
    );
  }
}
