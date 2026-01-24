import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../core/constants.dart';
import '../../transactions/data/transaction_repository.dart';
import '../../transactions/domain/transaction_entity.dart';
import '../../receipt_processing/presentation/receipt_scan_controller.dart';

/// Main Dashboard screen for CheckSmart.kz
class DashboardScreen extends ConsumerWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final transactionsAsync = ref.watch(transactionsProvider);
    final monthlyTotal = ref.watch(monthlyTotalProvider);

    return Scaffold(
      backgroundColor: const Color(0xFF0D0D0D),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: const Text(
          'CheckSmart',
          style: TextStyle(
            color: Colors.white,
            fontSize: 24,
            fontWeight: FontWeight.bold,
          ),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.settings_outlined, color: Colors.white70),
            onPressed: () {
              // TODO: Navigate to settings
            },
          ),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(16),
              child: _MonthlyCard(monthlyTotal: monthlyTotal),
            ),

            // Transaction List
            Expanded(
              child: transactionsAsync.when(
                data: (transactions) {
                  if (transactions.isEmpty) {
                    return const _EmptyState();
                  }
                  return _TransactionList(transactions: transactions);
                },
                loading:
                    () => const Center(
                      child: CircularProgressIndicator(
                        color: Color(0xFF00D09C),
                      ),
                    ),
                error:
                    (e, _) => Center(
                      child: Text(
                        'Ошибка: $e',
                        style: const TextStyle(color: Colors.red),
                      ),
                    ),
              ),
            ),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showScanOptions(context, ref),
        backgroundColor: const Color(0xFF00D09C),
        icon: const Icon(Icons.document_scanner, color: Colors.black),
        label: const Text(
          'Сканировать',
          style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold),
        ),
      ),
    );
  }

  void _showScanOptions(BuildContext context, WidgetRef ref) {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF1A1A1A),
      isScrollControlled: true, // Allow full height
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder:
          (context) => DraggableScrollableSheet(
            initialChildSize: 0.5,
            minChildSize: 0.3,
            maxChildSize: 0.9,
            expand: false,
            builder: (context, scrollController) => const _ScanOptionsSheet(),
          ),
    );
  }
}

/// Monthly spending summary card
class _MonthlyCard extends StatelessWidget {
  final double monthlyTotal;

  const _MonthlyCard({required this.monthlyTotal});

  @override
  Widget build(BuildContext context) {
    final currencyFormat = NumberFormat.currency(
      locale: 'ru_RU',
      symbol: '₸',
      decimalDigits: 0,
    );

    final monthName = DateFormat.MMMM('ru').format(DateTime.now());

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF1E3A5F), Color(0xFF0F2027)],
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF00D09C).withValues(alpha: 0.2),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Расходы за $monthName',
            style: const TextStyle(color: Colors.white70, fontSize: 14),
          ),
          const SizedBox(height: 8),
          Text(
            currencyFormat.format(monthlyTotal),
            style: const TextStyle(
              color: Colors.white,
              fontSize: 36,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }
}

/// Empty state when no transactions exist
class _EmptyState extends StatelessWidget {
  const _EmptyState();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.receipt_long_outlined,
            size: 64,
            color: Colors.white.withValues(alpha: 0.3),
          ),
          const SizedBox(height: 16),
          Text(
            'Нет транзакций',
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.5),
              fontSize: 18,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Отсканируйте чек чтобы начать',
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.3),
              fontSize: 14,
            ),
          ),
        ],
      ),
    );
  }
}

/// Transaction list widget
class _TransactionList extends StatelessWidget {
  final List<TransactionEntity> transactions;

  const _TransactionList({required this.transactions});

  @override
  Widget build(BuildContext context) {
    final currencyFormat = NumberFormat.currency(
      locale: 'ru_RU',
      symbol: '₸',
      decimalDigits: 0,
    );
    final dateFormat = DateFormat('dd MMM', 'ru');

    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      itemCount: transactions.length,
      itemBuilder: (context, index) {
        final tx = transactions[index];
        return Container(
          margin: const EdgeInsets.only(bottom: 12),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: const Color(0xFF1A1A1A),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(
            children: [
              // Category icon
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: const Color(0xFF2A2A2A),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Center(
                  child: Text(
                    tx.category.emoji,
                    style: const TextStyle(fontSize: 24),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              // Details
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      tx.merchant ?? tx.category.displayName,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.w500,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${dateFormat.format(tx.date)} • ${tx.source.displayName}',
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.5),
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
              // Amount
              Text(
                '-${currencyFormat.format(tx.amount)}',
                style: const TextStyle(
                  color: Color(0xFFFF6B6B),
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
        );
      },
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

    return SingleChildScrollView(
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
            _ScanResultView(result: scanState.result!),
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
              onTap: () {
                controller.scanFromCamera();
              },
            ),
            const SizedBox(height: 12),

            // Gallery option
            _ScanOption(
              icon: Icons.photo_library,
              title: 'Галерея',
              subtitle: 'Выбрать фото',
              onTap: () {
                controller.scanFromGallery();
              },
            ),
            const SizedBox(height: 12),

            // PDF option
            _ScanOption(
              icon: Icons.picture_as_pdf,
              title: 'PDF файл',
              subtitle: 'Kaspi / Halyk выписка',
              onTap: () {
                controller.scanFromPdf();
              },
            ),
          ],

          const SizedBox(height: 16),
        ],
      ),
    );
  }
}

/// Individual scan option button
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
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: const Color(0xFF00D09C).withValues(alpha: 0.2),
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

/// Widget to display scan result
class _ScanResultView extends ConsumerStatefulWidget {
  final dynamic result;

  const _ScanResultView({required this.result});

  @override
  ConsumerState<_ScanResultView> createState() => _ScanResultViewState();
}

class _ScanResultViewState extends ConsumerState<_ScanResultView> {
  ExpenseCategory _selectedCategory = ExpenseCategory.shopping;

  @override
  Widget build(BuildContext context) {
    final result = widget.result;
    final currencyFormat = NumberFormat.currency(
      locale: 'ru_RU',
      symbol: '₸',
      decimalDigits: 0,
    );

    return Column(
      children: [
        Icon(Icons.check_circle, color: const Color(0xFF00D09C), size: 48),
        const SizedBox(height: 16),
        Text(
          result.amount != null
              ? currencyFormat.format(result.amount)
              : 'Сумма не распознана',
          style: const TextStyle(
            color: Colors.white,
            fontSize: 32,
            fontWeight: FontWeight.bold,
          ),
        ),
        if (result.merchant != null) ...[
          const SizedBox(height: 8),
          Text(
            result.merchant!,
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.7),
              fontSize: 16,
            ),
          ),
        ],
        const SizedBox(height: 24),

        // Category selector
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children:
              ExpenseCategory.values.map((cat) {
                final isSelected = cat == _selectedCategory;
                return FilterChip(
                  label: Text('${cat.emoji} ${cat.displayName}'),
                  selected: isSelected,
                  onSelected: (selected) {
                    setState(() => _selectedCategory = cat);
                  },
                  backgroundColor: const Color(0xFF2A2A2A),
                  selectedColor: const Color(0xFF00D09C).withValues(alpha: 0.3),
                  labelStyle: TextStyle(
                    color:
                        isSelected ? const Color(0xFF00D09C) : Colors.white70,
                  ),
                );
              }).toList(),
        ),

        const SizedBox(height: 24),

        // Save button
        SizedBox(
          width: double.infinity,
          child: ElevatedButton(
            onPressed:
                result.isValid
                    ? () async {
                      final controller = ref.read(
                        receiptScanControllerProvider.notifier,
                      );
                      await controller.saveTransaction(
                        category: _selectedCategory,
                      );
                      if (context.mounted) {
                        Navigator.pop(context);
                      }
                    }
                    : null,
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF00D09C),
              padding: const EdgeInsets.symmetric(vertical: 16),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            child: const Text(
              'Сохранить',
              style: TextStyle(
                color: Colors.black,
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ),
      ],
    );
  }
}
