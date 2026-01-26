import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive_flutter/hive_flutter.dart';
import '../../../core/constants.dart';
import '../domain/custom_category.dart';

/// Provider for custom categories repository
final customCategoriesProvider =
    StateNotifierProvider<CustomCategoriesNotifier, List<CustomCategory>>((
      ref,
    ) {
      return CustomCategoriesNotifier();
    });

/// Notifier for managing custom categories
class CustomCategoriesNotifier extends StateNotifier<List<CustomCategory>> {
  Box<CustomCategory>? _box;

  CustomCategoriesNotifier() : super([]) {
    _init();
  }

  Future<void> _init() async {
    _box = await Hive.openBox<CustomCategory>(HiveBoxes.customCategories);
    state = _box!.values.toList();
  }

  /// Add a new custom category
  Future<void> addCategory(String name, String emoji) async {
    final category = CustomCategory.create(name: name, emoji: emoji);
    await _box?.add(category);
    state = [...state, category];
  }

  /// Delete a custom category
  Future<void> deleteCategory(String id) async {
    final index = state.indexWhere((c) => c.id == id);
    if (index != -1) {
      await _box?.deleteAt(index);
      state = state.where((c) => c.id != id).toList();
    }
  }

  /// Refresh categories from storage
  Future<void> refresh() async {
    if (_box != null) {
      state = _box!.values.toList();
    }
  }
}
