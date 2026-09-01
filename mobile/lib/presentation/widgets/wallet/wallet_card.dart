import 'package:flutter/material.dart';

import '../../../core/constants/app_icons.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/currency_formatter.dart';
import '../../../data/models/wallet_model.dart';
import '../common/grivi_icon_badge.dart';

class WalletCard extends StatelessWidget {
  const WalletCard({super.key, required this.wallet, this.onTap, this.width});

  final WalletModel wallet;
  final VoidCallback? onTap;
  final double? width;

  @override
  Widget build(BuildContext context) {
    final color = hexToColor(wallet.color);

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        width: width,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: color.withValues(alpha: 0.28)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                GriviIconBadge(
                  icon: AppIcons.resolve(wallet.icon),
                  color: color,
                  size: 38,
                  radius: 11,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        wallet.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontWeight: FontWeight.w600),
                      ),
                      Text(
                        wallet.type.label,
                        style: const TextStyle(color: AppColors.textMuted, fontSize: 12),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            Text(
              CurrencyFormatter.formatSigned(wallet.balance),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w700,
                color: wallet.balance < 0 ? AppColors.expense : AppColors.textPrimary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
