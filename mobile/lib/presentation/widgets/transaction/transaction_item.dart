import 'package:flutter/material.dart';

import '../../../core/constants/app_icons.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/currency_formatter.dart';
import '../../../core/utils/date_formatter.dart';
import '../../../data/models/transaction_model.dart';
import '../common/grivi_icon_badge.dart';
import '../common/grivi_motion.dart';

class TransactionItem extends StatelessWidget {
  const TransactionItem({
    super.key,
    required this.transaction,
    this.onTap,
    this.showTime = false,
  });

  final TransactionModel transaction;
  final VoidCallback? onTap;

  /// Di daftar yang dikelompokkan per hari, tanggal udah ada di judul grup —
  /// cukup jamnya.
  final bool showTime;

  @override
  Widget build(BuildContext context) {
    final tx = transaction;

    final String icon;
    final Color color;
    final String subtitle;
    final String amount;
    final Color amountColor;

    if (tx.isTransfer) {
      icon = 'swap_horiz';
      color = AppColors.transfer;
      subtitle = '${tx.wallet.name} → ${tx.toWallet?.name ?? '-'}';
      amount = CurrencyFormatter.format(tx.amount);
      amountColor = AppColors.transfer;
    } else {
      icon = tx.category?.icon ?? 'more_horiz';
      color = hexToColor(tx.category?.color ?? '#6B7280');
      subtitle = tx.note?.isNotEmpty == true ? '${tx.wallet.name} · ${tx.note}' : tx.wallet.name;
      amount = '${tx.isIncome ? '+' : '-'}${CurrencyFormatter.format(tx.amount)}';
      amountColor = tx.isIncome ? AppColors.income : AppColors.expense;
    }

    return GriviPressable(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
        child: Row(
          children: [
            GriviIconBadge(name: icon, color: color, size: 42),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    tx.isFee ? 'Biaya admin transfer' : tx.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 15),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(color: AppColors.textMuted, fontSize: 12.5),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 10),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  amount,
                  style: TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 14.5,
                    color: amountColor,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  showTime ? DateFormatter.time(tx.date) : DateFormatter.short(tx.date),
                  style: const TextStyle(color: AppColors.textMuted, fontSize: 11.5),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
