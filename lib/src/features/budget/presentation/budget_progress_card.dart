import 'package:flutter/material.dart';

import '../data/budget_limit_repository.dart';

/// Compact progress card showing budget status for a category
class BudgetProgressCard extends StatelessWidget {
  final BudgetProgress progress;
  final VoidCallback? onTap;

  const BudgetProgressCard({super.key, required this.progress, this.onTap});

  @override
  Widget build(BuildContext context) {
    final limit = progress.limit;
    final spent = progress.spent;
    final percentUsed = progress.percentUsed / 100; // 0.0 - 1.0+
    final status = progress.status;

    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: const Color(0xFF1E1E1E),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: Color(status.colorValue).withValues(alpha: 0.3),
            width: 1,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Category header
            Row(
              children: [
                Text(
                  limit.category.emoji,
                  style: const TextStyle(fontSize: 24),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        limit.category.displayName,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      Text(
                        '${limit.limitAmount.toStringAsFixed(0)} ₸/${limit.period.shortName}',
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.5),
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
                // Percentage badge
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: Color(status.colorValue).withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    '${progress.percentUsed.toStringAsFixed(0)}%',
                    style: TextStyle(
                      color: Color(status.colorValue),
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),

            const SizedBox(height: 16),

            // Progress bar
            ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(
                value: percentUsed.clamp(0.0, 1.0),
                minHeight: 8,
                backgroundColor: Colors.white.withValues(alpha: 0.1),
                valueColor: AlwaysStoppedAnimation<Color>(
                  Color(status.colorValue),
                ),
              ),
            ),

            const SizedBox(height: 12),

            // Spent / Remaining info
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Потрачено: ${spent.toStringAsFixed(0)} ₸',
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.7),
                    fontSize: 13,
                  ),
                ),
                Text(
                  'Остаток: ${progress.remaining.toStringAsFixed(0)} ₸',
                  style: TextStyle(
                    color:
                        progress.remaining > 0
                            ? const Color(0xFF00D09C)
                            : Colors.red[400],
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
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

/// Mini version for home screen
class BudgetProgressMini extends StatelessWidget {
  final BudgetProgress progress;

  const BudgetProgressMini({super.key, required this.progress});

  @override
  Widget build(BuildContext context) {
    final limit = progress.limit;
    final status = progress.status;
    final percentUsed = progress.percentUsed / 100;

    return Container(
      width: 100,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFF1E1E1E),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        children: [
          Text(limit.category.emoji, style: const TextStyle(fontSize: 24)),
          const SizedBox(height: 8),
          Text(
            limit.category.displayName,
            style: const TextStyle(color: Colors.white, fontSize: 12),
            textAlign: TextAlign.center,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 8),
          // Circular progress
          SizedBox(
            width: 40,
            height: 40,
            child: Stack(
              alignment: Alignment.center,
              children: [
                CircularProgressIndicator(
                  value: percentUsed.clamp(0.0, 1.0),
                  strokeWidth: 4,
                  backgroundColor: Colors.white.withValues(alpha: 0.1),
                  valueColor: AlwaysStoppedAnimation<Color>(
                    Color(status.colorValue),
                  ),
                ),
                Text(
                  '${progress.percentUsed.toStringAsFixed(0)}%',
                  style: TextStyle(
                    color: Color(status.colorValue),
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
