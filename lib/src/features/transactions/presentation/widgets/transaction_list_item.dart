import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../../core/app_theme.dart';
import '../../../categories/data/custom_category_repository.dart';
import '../../domain/transaction_entity.dart';

class TransactionListItem extends ConsumerWidget {
  final TransactionEntity transaction;
  final VoidCallback? onTap;

  const TransactionListItem({super.key, required this.transaction, this.onTap});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final currencyFormat = NumberFormat.currency(
      locale: 'ru_RU',
      symbol: '₸',
      decimalDigits: 0,
    );

    // Check if this is a custom category
    final customCategories = ref.watch(customCategoriesProvider);
    final customCategory =
        transaction.customCategoryId != null
            ? customCategories
                .where((c) => c.id == transaction.customCategoryId)
                .firstOrNull
            : null;

    // Use custom category data if available, otherwise use standard category
    final displayName =
        customCategory?.name ?? transaction.category.displayName;
    final emoji = customCategory?.emoji ?? transaction.category.emoji;
    final color =
        customCategory != null
            ? const Color(0xFF6C5CE7)
            : AppTheme.getCategoryColor(transaction.category);

    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
        child: Row(
          children: [
            // Category Icon
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(color: color, shape: BoxShape.circle),
              alignment: Alignment.center,
              child: Text(emoji, style: const TextStyle(fontSize: 24)),
            ),
            const SizedBox(width: 16),

            // Details
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    displayName,
                    style: const TextStyle(
                      color: Color(0xFF1A1A1A),
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),

            // Amount
            Text(
              currencyFormat.format(transaction.amount),
              style: const TextStyle(
                color: Color(0xFF9CA3AF),
                fontSize: 16,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
