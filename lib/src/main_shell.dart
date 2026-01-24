import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'core/constants.dart';
import 'features/dashboard/presentation/home_screen.dart';
import 'features/analytics/presentation/analytics_screen.dart';
import 'features/budget/presentation/budget_screen.dart';
import 'features/receipt_processing/presentation/receipt_scan_controller.dart';

/// Main app shell with bottom navigation
class MainShell extends ConsumerStatefulWidget {
  const MainShell({super.key});

  @override
  ConsumerState<MainShell> createState() => _MainShellState();
}

class _MainShellState extends ConsumerState<MainShell> {
  int _currentIndex = 1; // Start on Home (center)

  final List<Widget> _screens = const [
    AnalyticsScreen(),
    HomeScreen(),
    BudgetScreen(),
  ];

  void _showScanOptions() {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF1E1E1E),
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) => const _ScanOptionsSheet(),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF121212),
      body: IndexedStack(index: _currentIndex, children: _screens),
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          color: const Color(0xFF1E1E1E),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.3),
              blurRadius: 10,
              offset: const Offset(0, -2),
            ),
          ],
        ),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                // Analytics button
                _NavButton(
                  icon: Icons.pie_chart_outline,
                  activeIcon: Icons.pie_chart,
                  label: 'Аналитика',
                  isActive: _currentIndex == 0,
                  onTap: () => setState(() => _currentIndex = 0),
                ),

                // Home button
                _NavButton(
                  icon: Icons.home_outlined,
                  activeIcon: Icons.home,
                  label: 'Главная',
                  isActive: _currentIndex == 1,
                  onTap: () => setState(() => _currentIndex = 1),
                ),

                // Center Add button (prominent)
                GestureDetector(
                  onTap: _showScanOptions,
                  child: Container(
                    width: 52,
                    height: 52,
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [Color(0xFF6C5CE7), Color(0xFF00D09C)],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: [
                        BoxShadow(
                          color: const Color(0xFF6C5CE7).withValues(alpha: 0.4),
                          blurRadius: 12,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: const Icon(Icons.add, color: Colors.white, size: 26),
                  ),
                ),

                // Budget button
                _NavButton(
                  icon: Icons.account_balance_wallet_outlined,
                  activeIcon: Icons.account_balance_wallet,
                  label: 'Бюджет',
                  isActive: _currentIndex == 2,
                  onTap: () => setState(() => _currentIndex = 2),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _NavButton extends StatelessWidget {
  final IconData icon;
  final IconData activeIcon;
  final String label;
  final bool isActive;
  final VoidCallback onTap;

  const _NavButton({
    required this.icon,
    required this.activeIcon,
    required this.label,
    required this.isActive,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            isActive ? activeIcon : icon,
            color: isActive ? const Color(0xFF00D09C) : Colors.white54,
            size: 24,
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: TextStyle(
              color: isActive ? const Color(0xFF00D09C) : Colors.white54,
              fontSize: 12,
              fontWeight: isActive ? FontWeight.w600 : FontWeight.normal,
            ),
          ),
        ],
      ),
    );
  }
}

/// Bottom sheet with scan options
class _ScanOptionsSheet extends ConsumerWidget {
  const _ScanOptionsSheet();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final scanState = ref.watch(receiptScanControllerProvider);
    final controller = ref.read(receiptScanControllerProvider.notifier);

    return Container(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.85,
      ),
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Handle bar
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.white24,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 24),

            if (scanState.isProcessing) ...[
              const CircularProgressIndicator(color: Color(0xFF00D09C)),
              const SizedBox(height: 16),
              Text(
                scanState.statusMessage ?? 'Обработка...',
                style: const TextStyle(color: Colors.white70),
              ),
            ] else if (scanState.result != null) ...[
              // SUCCESS! Show parsed result
              _ResultView(
                result: scanState.result!,
                onCategorySelected: (category) async {
                  final transaction = await controller.saveTransaction(
                    category: category,
                  );
                  if (context.mounted && transaction != null) {
                    Navigator.of(context).pop();
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(
                          'Сохранено: ${transaction.amount.toStringAsFixed(0)} ₸',
                        ),
                        backgroundColor: const Color(0xFF00D09C),
                      ),
                    );
                  }
                },
                onCancel: () {
                  controller.clear();
                },
              ),
            ] else if (scanState.error != null) ...[
              Icon(Icons.error_outline, color: Colors.red[400], size: 48),
              const SizedBox(height: 16),
              Text(
                scanState.error!.message,
                style: TextStyle(color: Colors.red[400]),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),
              TextButton(
                onPressed: () => controller.clear(),
                child: const Text('Попробовать снова'),
              ),
            ] else ...[
              const Text(
                'Добавить чек',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 24),

              // Camera option
              _ScanOption(
                icon: Icons.camera_alt,
                title: 'Камера',
                subtitle: 'Сфотографировать чек',
                onTap: () => controller.scanFromCamera(),
              ),
              const SizedBox(height: 12),

              // Gallery option
              _ScanOption(
                icon: Icons.photo_library,
                title: 'Галерея',
                subtitle: 'Выбрать фото',
                onTap: () => controller.scanFromGallery(),
              ),
              const SizedBox(height: 12),

              // PDF option
              _ScanOption(
                icon: Icons.picture_as_pdf,
                title: 'PDF файл',
                subtitle: 'Kaspi / Halyk выписка',
                onTap: () => controller.scanFromPdf(),
              ),
            ],

            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }
}

/// Shows parsed receipt result and category selection
class _ResultView extends StatelessWidget {
  final dynamic result;
  final Function(ExpenseCategory) onCategorySelected;
  final VoidCallback onCancel;

  const _ResultView({
    required this.result,
    required this.onCategorySelected,
    required this.onCancel,
  });

  @override
  Widget build(BuildContext context) {
    final amount = result.amount as double?;
    final date = result.date as DateTime?;
    final merchant = result.merchant as String?;

    return Column(
      children: [
        // Success icon
        Container(
          width: 64,
          height: 64,
          decoration: BoxDecoration(
            color: const Color(0xFF00D09C).withValues(alpha: 0.2),
            shape: BoxShape.circle,
          ),
          child: const Icon(Icons.check, color: Color(0xFF00D09C), size: 32),
        ),
        const SizedBox(height: 16),

        // Amount
        Text(
          '${amount?.toStringAsFixed(0) ?? '?'} ₸',
          style: const TextStyle(
            color: Colors.white,
            fontSize: 36,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 8),

        // Details
        if (merchant != null)
          Text(
            merchant,
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.7),
              fontSize: 16,
            ),
          ),
        if (date != null)
          Text(
            '${date.day}.${date.month}.${date.year}',
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.5),
              fontSize: 14,
            ),
          ),

        const SizedBox(height: 24),

        // Category selection header
        const Text(
          'Выберите категорию',
          style: TextStyle(
            color: Colors.white,
            fontSize: 16,
            fontWeight: FontWeight.w500,
          ),
        ),
        const SizedBox(height: 16),

        // Category grid
        Wrap(
          spacing: 12,
          runSpacing: 12,
          alignment: WrapAlignment.center,
          children:
              ExpenseCategory.values.map((category) {
                return _CategoryChip(
                  category: category,
                  onTap: () => onCategorySelected(category),
                );
              }).toList(),
        ),

        const SizedBox(height: 24),

        // Cancel button
        TextButton(
          onPressed: onCancel,
          child: Text(
            'Отмена',
            style: TextStyle(color: Colors.white.withValues(alpha: 0.5)),
          ),
        ),
      ],
    );
  }
}

class _CategoryChip extends StatelessWidget {
  final ExpenseCategory category;
  final VoidCallback onTap;

  const _CategoryChip({required this.category, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: const Color(0xFF2A2A2A),
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(category.emoji, style: const TextStyle(fontSize: 20)),
              const SizedBox(width: 8),
              Text(
                category.displayName,
                style: const TextStyle(color: Colors.white, fontSize: 14),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ScanOption extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  const _ScanOption({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: const Color(0xFF2A2A2A),
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      const Color(0xFF6C5CE7).withValues(alpha: 0.3),
                      const Color(0xFF00D09C).withValues(alpha: 0.3),
                    ],
                  ),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, color: const Color(0xFF00D09C)),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    Text(
                      subtitle,
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.5),
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
              Icon(
                Icons.chevron_right,
                color: Colors.white.withValues(alpha: 0.3),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
