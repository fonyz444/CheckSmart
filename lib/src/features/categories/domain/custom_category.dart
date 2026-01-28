import 'package:hive/hive.dart';
import 'package:uuid/uuid.dart';
import '../../../core/constants.dart';

part 'custom_category.g.dart';

/// Custom category created by user
@HiveType(typeId: HiveTypeIds.customCategory)
class CustomCategory extends HiveObject {
  @HiveField(0)
  final String id;

  @HiveField(1)
  final String name;

  @HiveField(2)
  final String emoji;

  @HiveField(3)
  final DateTime createdAt;

  @HiveField(4)
  final int color;

  CustomCategory({
    required this.id,
    required this.name,
    required this.emoji,
    required this.createdAt,
    required this.color,
  });

  /// Factory to create new custom category
  factory CustomCategory.create({
    required String name,
    required String emoji,
    required int color,
  }) {
    return CustomCategory(
      id: const Uuid().v4(),
      name: name,
      emoji: emoji,
      createdAt: DateTime.now(),
      color: color,
    );
  }

  /// Display name for UI
  String get displayName => name;
}
