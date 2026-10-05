import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/constants/app_icons.dart';
import '../../../core/router/app_router.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/currency_formatter.dart';
import '../../../core/utils/date_formatter.dart';
import '../../../data/models/transaction_model.dart';
import '../../../providers/transaction_provider.dart';
import '../../widgets/common/grivi_async_view.dart';
import '../../widgets/common/grivi_card.dart';
import '../../widgets/common/grivi_icon_badge.dart';
import '../../widgets/common/grivi_motion.dart';

class TransactionDetailScreen extends ConsumerWidget {
  const TransactionDetailScreen({super.key, required this.transactionId});

  final String transactionId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final detail = ref.watch(transactionDetailProvider(transactionId));
    final tx = detail.valueOrNull;
    // Biaya admin diatur lewat transfernya, jadi tombol edit/hapus disembunyikan.
    final editable = tx != null && !tx.isFee;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Detail transaksi'),
        actions: [
          if (editable) ...[
            IconButton(
              tooltip: 'Edit',
              icon: const Icon(Icons.edit_outlined),
              onPressed: () => context.push(AppRoutes.transactionEdit(transactionId)),
            ),
            IconButton(
              tooltip: 'Hapus',
              icon: const Icon(Icons.delete_outline, color: AppColors.expense),
              onPressed: () => _confirmDelete(context, ref, tx),
            ),
          ],
        ],
      ),
      body: GriviAsyncView<TransactionModel>(
        value: detail,
        onRetry: () => ref.invalidate(transactionDetailProvider(transactionId)),
        builder: (tx) => _DetailBody(tx: tx),
      ),
    );
  }

  Future<void> _confirmDelete(BuildContext context, WidgetRef ref, TransactionModel tx) async {
    final message = tx.isTransfer
        ? 'Saldo kedua wallet dikembalikan seperti sebelum transfer'
              '${tx.fee != null ? ', termasuk biaya adminnya' : ''}.'
        : 'Saldo wallet akan dikembalikan seperti sebelumnya.';

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(tx.isTransfer ? 'Hapus transfer?' : 'Hapus transaksi?'),
        content: Text(message),
        actions: [
          TextButton(onPressed: () => context.pop(false), child: const Text('Batal')),
          TextButton(
            onPressed: () => context.pop(true),
            style: TextButton.styleFrom(foregroundColor: AppColors.expense),
            child: const Text('Hapus'),
          ),
        ],
      ),
    );

    if (confirmed != true || !context.mounted) return;

    try {
      await ref.read(transactionsProvider.notifier).delete(transactionId);
      if (context.mounted) context.pop();
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e')));
      }
    }
  }
}

class _DetailBody extends StatelessWidget {
  const _DetailBody({required this.tx});

  final TransactionModel tx;

  @override
  Widget build(BuildContext context) {
    final String icon;
    final Color color;
    final String amount;
    final Color amountColor;

    if (tx.isTransfer) {
      icon = 'swap_horiz';
      color = AppColors.transfer;
      amount = CurrencyFormatter.format(tx.amount);
      amountColor = AppColors.transfer;
    } else {
      icon = tx.category?.icon ?? 'more_horiz';
      color = hexToColor(tx.category?.color ?? '#6B7280');
      amount = '${tx.isIncome ? '+' : '-'}${CurrencyFormatter.format(tx.amount)}';
      amountColor = tx.isIncome ? AppColors.income : AppColors.expense;
    }

    final rows = <(String, String)>[
      if (tx.isTransfer) ...[
        ('Dari', tx.wallet.name),
        ('Ke', tx.toWallet?.name ?? '-'),
        if (tx.fee != null) ('Biaya admin', CurrencyFormatter.format(tx.fee!)),
      ] else ...[
        ('Kategori', tx.category?.name ?? '-'),
        ('Wallet', tx.wallet.name),
      ],
      ('Tanggal', '${DateFormatter.full(tx.date)} · ${DateFormatter.time(tx.date)}'),
      if (tx.note?.isNotEmpty == true) ('Catatan', tx.note!),
    ];

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 24, 16, 32),
      children: [
        GriviFadeIn(
          child: Center(
            child: Column(
              children: [
                GriviIconBadge(name: icon, color: color, size: 72, radius: 22),
                const SizedBox(height: 16),
                Text(
                  amount,
                  style: TextStyle(
                    fontSize: 32,
                    fontWeight: FontWeight.w800,
                    color: amountColor,
                    letterSpacing: -0.8,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  tx.isFee ? 'Biaya admin transfer' : tx.type.label,
                  style: const TextStyle(color: AppColors.textSecondary),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 28),
        GriviFadeIn(
          index: 1,
          child: GriviCard(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Column(
              children: [
                for (var i = 0; i < rows.length; i++) ...[
                  if (i > 0) const Divider(height: 1),
                  _DetailRow(label: rows[i].$1, value: rows[i].$2),
                ],
              ],
            ),
          ),
        ),
        if (tx.isFee) ...[
          const SizedBox(height: 16),
          GriviFadeIn(
            index: 2,
            child: GriviCard(
              onTap: () => context.push(AppRoutes.transactionDetail(tx.feeForId!)),
              child: const Row(
                children: [
                  Icon(Icons.info_outline, color: AppColors.transfer, size: 20),
                  SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'Dicatat otomatis dari sebuah transfer. Ubah atau hapus lewat transfernya.',
                      style: TextStyle(color: AppColors.textSecondary, fontSize: 13),
                    ),
                  ),
                  Icon(Icons.chevron_right, color: AppColors.textMuted),
                ],
              ),
            ),
          ),
        ],
      ],
    );
  }
}

class _DetailRow extends StatelessWidget {
  const _DetailRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 14),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 96,
            child: Text(
              label,
              style: const TextStyle(color: AppColors.textMuted, fontSize: 13),
            ),
          ),
          Expanded(
            child: Text(
              value,
              textAlign: TextAlign.right,
              style: const TextStyle(fontWeight: FontWeight.w500),
            ),
          ),
        ],
      ),
    );
  }
}
