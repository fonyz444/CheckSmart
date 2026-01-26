import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'core/constants.dart';
import 'features/dashboard/presentation/home_screen.dart';
import 'features/analytics/presentation/analytics_screen.dart';
import 'features/budget/presentation/budget_screen.dart';
import 'features/transactions/presentation/transactions_screen.dart';
import 'features/settings/presentation/settings_screen.dart';
import 'features/receipt_processing/presentation/receipt_scan_controller.dart';

/// Main app shell with bottom navigation
class MainShell extends ConsumerStatefulWidget {
  const MainShell({super.key});

  @override
  ConsumerState<MainShell> createState() => _MainShellState();
}

class _MainShellState extends ConsumerState<MainShell> {
  int _currentIndex = 0; // Start on Home

  final List<Widget> _screens = const [
    HomeScreen(),
    AnalyticsScreen(),
    TransactionsScreen(),
    SettingsScreen(),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F7),
      body: IndexedStack(index: _currentIndex, children: _screens),
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.05),
              blurRadius: 8,
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
                // Home button
                _NavButton(
                  icon: Icons.home_outlined,
                  activeIcon: Icons.home,
                  label: 'Главная',
                  isActive: _currentIndex == 0,
                  onTap: () => setState(() => _currentIndex = 0),
                ),

                // Analytics button
                _NavButton(
                  icon: Icons.pie_chart_outline,
                  activeIcon: Icons.pie_chart,
                  label: 'Аналитика',
                  isActive: _currentIndex == 1,
                  onTap: () => setState(() => _currentIndex = 1),
                ),

                // Transactions button
                _NavButton(
                  icon: Icons.receipt_long_outlined,
                  activeIcon: Icons.receipt_long,
                  label: 'Транзакции',
                  isActive: _currentIndex == 2,
                  onTap: () => setState(() => _currentIndex = 2),
                ),

                // Settings button
                _NavButton(
                  icon: Icons.settings_outlined,
                  activeIcon: Icons.settings,
                  label: 'Настройки',
                  isActive: _currentIndex == 3,
                  onTap: () => setState(() => _currentIndex = 3),
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
            color: isActive ? const Color(0xFF6C5CE7) : const Color(0xFF6B7280),
            size: 24,
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: TextStyle(
              color:
                  isActive ? const Color(0xFF6C5CE7) : const Color(0xFF6B7280),
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
                color: const Color(0xFFE5E7EB),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 24),

            if (scanState.isProcessing) ...[
              const CircularProgressIndicator(color: Color(0xFF6C5CE7)),
              const SizedBox(height: 16),
              Text(
                scanState.statusMessage ?? 'Обработка...',
                style: const TextStyle(color: Color(0xFF6B7280)),
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
                  color: Color(0xFF1A1A1A),
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
class _ResultView extends StatefulWidget {
  final dynamic result;
  final Function(ExpenseCategory) onCategorySelected;
  final VoidCallback onCancel;

  const _ResultView({
    required this.result,
    required this.onCategorySelected,
    required this.onCancel,
  });

  @override
  State<_ResultView> createState() => _ResultViewState();
}

class _ResultViewState extends State<_ResultView> {
  bool _showAllCategories = false;

  @override
  Widget build(BuildContext context) {
    final amount = widget.result.amount as double?;
    final date = widget.result.date as DateTime?;
    final merchant = widget.result.merchant as String?;
    final suggestedCategory =
        widget.result.suggestedCategory as ExpenseCategory?;
    final category = suggestedCategory ?? ExpenseCategory.other;

    return Column(
      children: [
        // Success icon
        Container(
          width: 64,
          height: 64,
          decoration: BoxDecoration(
            color: const Color(0xFF00D09C).withValues(alpha: 0.15),
            shape: BoxShape.circle,
          ),
          child: const Icon(Icons.check, color: Color(0xFF00D09C), size: 32),
        ),
        const SizedBox(height: 16),

        // Amount
        Text(
          '${amount?.toStringAsFixed(0) ?? '?'} ₸',
          style: const TextStyle(
            color: Color(0xFF1A1A1A),
            fontSize: 36,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 8),

        // Details
        if (merchant != null)
          Text(
            merchant,
            style: const TextStyle(color: Color(0xFF6B7280), fontSize: 16),
          ),
        if (date != null)
          Text(
            '${date.day}.${date.month}.${date.year}',
            style: const TextStyle(color: Color(0xFF9CA3AF), fontSize: 14),
          ),

        const SizedBox(height: 24),

        // Suggested category card
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: const Color(0xFF6C5CE7).withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: const Color(0xFF6C5CE7).withValues(alpha: 0.3),
            ),
          ),
          child: Column(
            children: [
              const Text(
                'Предложенная категория',
                style: TextStyle(color: Color(0xFF6B7280), fontSize: 12),
              ),
              const SizedBox(height: 8),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(category.emoji, style: const TextStyle(fontSize: 28)),
                  const SizedBox(width: 12),
                  Text(
                    category.displayName,
                    style: const TextStyle(
                      color: Color(0xFF1A1A1A),
                      fontSize: 20,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),

        const SizedBox(height: 16),

        // Confirm button
        SizedBox(
          width: double.infinity,
          child: ElevatedButton(
            onPressed: () => widget.onCategorySelected(category),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF6C5CE7),
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 16),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              elevation: 0,
            ),
            child: const Text(
              'Подтвердить',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
            ),
          ),
        ),

        const SizedBox(height: 12),

        // Change category toggle
        TextButton(
          onPressed: () {
            setState(() {
              _showAllCategories = !_showAllCategories;
            });
          },
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                _showAllCategories
                    ? 'Скрыть категории'
                    : 'Выбрать другую категорию',
                style: const TextStyle(color: Color(0xFF6B7280)),
              ),
              Icon(
                _showAllCategories ? Icons.expand_less : Icons.expand_more,
                color: const Color(0xFF6B7280),
                size: 20,
              ),
            ],
          ),
        ),

        // Category grid (collapsible)
        if (_showAllCategories) ...[
          const SizedBox(height: 8),
          Wrap(
            spacing: 12,
            runSpacing: 12,
            alignment: WrapAlignment.center,
            children:
                ExpenseCategory.values.map((cat) {
                  final isSelected = cat == category;
                  return _CategoryChip(
                    category: cat,
                    isSelected: isSelected,
                    onTap: () => widget.onCategorySelected(cat),
                  );
                }).toList(),
          ),
        ],

        const SizedBox(height: 16),

        // Cancel button
        TextButton(
          onPressed: widget.onCancel,
          child: const Text(
            'Отмена',
            style: TextStyle(color: Color(0xFF6B7280)),
          ),
        ),
      ],
    );
  }
}

class _CategoryChip extends StatelessWidget {
  final ExpenseCategory category;
  final VoidCallback onTap;
  final bool isSelected;

  const _CategoryChip({
    required this.category,
    required this.onTap,
    this.isSelected = false,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color:
          isSelected
              ? const Color(0xFF6C5CE7).withValues(alpha: 0.15)
              : const Color(0xFFF3F4F6),
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          decoration:
              isSelected
                  ? BoxDecoration(
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: const Color(0xFF6C5CE7),
                      width: 2,
                    ),
                  )
                  : null,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(category.emoji, style: const TextStyle(fontSize: 20)),
              const SizedBox(width: 8),
              Text(
                category.displayName,
                style: TextStyle(
                  color:
                      isSelected
                          ? const Color(0xFF6C5CE7)
                          : const Color(0xFF1A1A1A),
                  fontSize: 14,
                  fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                ),
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
      color: Colors.white,
      borderRadius: BorderRadius.circular(16),
      elevation: 0,
      shadowColor: Colors.black.withOpacity(0.05),
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
                  color: const Color(0xFF6C5CE7).withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, color: const Color(0xFF6C5CE7)),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        color: Color(0xFF1A1A1A),
                        fontSize: 16,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    Text(
                      subtitle,
                      style: const TextStyle(
                        color: Color(0xFF6B7280),
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right, color: Color(0xFFE5E7EB)),
            ],
          ),
        ),
      ),
    );
  }
}
