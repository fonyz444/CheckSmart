import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../receipt_processing/presentation/receipt_scan_controller.dart';
import '../data/transaction_repository.dart';
import '../domain/transaction_entity.dart';
import 'widgets/transaction_list_item.dart';

class TransactionsScreen extends ConsumerWidget {
  const TransactionsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final transactionsAsync = ref.watch(transactionsProvider);

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        centerTitle: true,
        surfaceTintColor: Colors.transparent,
        title: const Text(
          'Transactions',
          style: TextStyle(
            color: Color(0xFF1A1A1A),
            fontWeight: FontWeight.bold,
            fontSize: 17,
          ),
        ),
      ),
      body: transactionsAsync.when(
        data: (transactions) {
          if (transactions.isEmpty) {
            return const Center(
              child: Text(
                'No transactions yet',
                style: TextStyle(color: Color(0xFF9CA3AF), fontSize: 16),
              ),
            );
          }

          final groupedTransactions = _groupTransactionsByDate(transactions);

          return ListView.builder(
            padding: const EdgeInsets.only(bottom: 100),
            itemCount: groupedTransactions.length,
            itemBuilder: (context, index) {
              final group = groupedTransactions[index];
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(20, 24, 20, 8),
                    child: Text(
                      group.header,
                      style: const TextStyle(
                        color: Color(0xFF1A1A1A),
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  ...group.transactions.map((transaction) {
                    return TransactionListItem(
                      transaction: transaction,
                      onTap: () {
                        // TODO: Navigate to details
                      },
                    );
                  }),
                ],
              );
            },
          );
        },
        loading:
            () => const Center(
              child: CircularProgressIndicator(color: Color(0xFF6C5CE7)),
            ),
        error: (error, stack) => Center(child: Text('Error: $error')),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showScanOptions(context, ref),
        backgroundColor: const Color(0xFF1A1A1A),
        child: const Icon(Icons.add, color: Colors.white, size: 28),
      ),
    );
  }

  List<_DateGroup> _groupTransactionsByDate(
    List<TransactionEntity> transactions,
  ) {
    if (transactions.isEmpty) return [];

    final groups = <_DateGroup>[];
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final yesterday = today.subtract(const Duration(days: 1));

    // Sort transactions by date descending
    final sortedTransactions = List<TransactionEntity>.from(transactions)
      ..sort((a, b) => b.date.compareTo(a.date));

    DateTime? currentDate;
    List<TransactionEntity> currentList = [];

    for (final transaction in sortedTransactions) {
      final transactionDate = DateTime(
        transaction.date.year,
        transaction.date.month,
        transaction.date.day,
      );

      if (currentDate == null || transactionDate != currentDate) {
        if (currentDate != null) {
          groups.add(
            _DateGroup(
              _getDateHeader(currentDate, today, yesterday),
              currentList,
            ),
          );
        }
        currentDate = transactionDate;
        currentList = [transaction];
      } else {
        currentList.add(transaction);
      }
    }

    if (currentDate != null) {
      groups.add(
        _DateGroup(_getDateHeader(currentDate, today, yesterday), currentList),
      );
    }

    return groups;
  }

  String _getDateHeader(DateTime date, DateTime today, DateTime yesterday) {
    if (date == today) {
      return 'Today';
    } else if (date == yesterday) {
      return 'Yesterday';
    } else {
      return DateFormat('E, MMMM d').format(date);
    }
  }

  void _showScanOptions(BuildContext context, WidgetRef ref) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) => const _ScanOptionsSheet(),
    );
  }
}

class _DateGroup {
  final String header;
  final List<TransactionEntity> transactions;

  _DateGroup(this.header, this.transactions);
}

// TODO: Refactor this to be shared with HomeScreen to avoid duplication
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
                scanState.statusMessage ?? 'Processing...',
                style: const TextStyle(color: Color(0xFF6B7280)),
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
                child: const Text('Try Again'),
              ),
            ] else ...[
              const Text(
                'Add Receipt',
                style: TextStyle(
                  color: Color(0xFF1A1A1A),
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 24),
              _ScanOption(
                icon: Icons.camera_alt,
                title: 'Camera',
                subtitle: 'Take a photo of receipt',
                onTap: () async {
                  await controller.scanFromCamera();
                  if (context.mounted) Navigator.pop(context);
                },
              ),
              const SizedBox(height: 12),
              _ScanOption(
                icon: Icons.photo_library,
                title: 'Gallery',
                subtitle: 'Select from gallery',
                onTap: () async {
                  await controller.scanFromGallery();
                  if (context.mounted) Navigator.pop(context);
                },
              ),
            ],
            const SizedBox(height: 16),
          ],
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
                  color: const Color(0xFF6C5CE7).withOpacity(0.1),
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
