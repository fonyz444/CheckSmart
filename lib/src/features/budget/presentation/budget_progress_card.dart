import 'package:flutter/material.dart';

import '../../../core/app_theme.dart';
import '../data/budget_limit_repository.dart';

/// Budget progress card matching EXACT reference design
/// Layout: [Colored Circle Icon] [Category Name] ........... [Left Amount]
///                               [Budgeted: X ₸]
class BudgetProgressCard extends StatelessWidget {
  final BudgetProgress progress;
  final VoidCallback? onTap;

  const BudgetProgressCard({super.key, required this.progress, this.onTap});

  @override
  Widget build(BuildContext context) {
    final limit = progress.limit;
    final remaining = progress.remaining;
    final categoryColor = AppTheme.getCategoryColor(limit.category);

    // Determine if over budget
    final isOverBudget = remaining < 0;
    final leftColor = isOverBudget ? Colors.red[600]! : const Color(0xFF4CAF50);

    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(16),
        margin: const EdgeInsets.only(bottom: 12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.04),
              blurRadius: 6,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          children: [
            // Circular colored icon with emoji
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: categoryColor,
                shape: BoxShape.circle,
              ),
              child: Center(
                child: Text(
                  limit.category.emoji,
                  style: const TextStyle(fontSize: 24),
                ),
              ),
            ),
            const SizedBox(width: 16),
            // Category name and budgeted amount
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    limit.category.displayName,
                    style: const TextStyle(
                      color: Color(0xFF1A1A1A),
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Budgeted: ${limit.limitAmount.toStringAsFixed(0)} ₸',
                    style: const TextStyle(
                      color: Color(0xFF9CA3AF),
                      fontSize: 14,
                    ),
                  ),
                ],
              ),
            ),
            // Left amount on the right
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  'Left',
                  style: TextStyle(
                    color: leftColor,
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '${remaining.abs().toStringAsFixed(0)} ₸',
                  style: TextStyle(
                    color: leftColor,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
