import 'package:flutter/material.dart';

import '../../../core/constants/app_icons.dart';
import '../../../core/theme/app_theme.dart';
import '../../../data/models/wallet_model.dart';
import '../common/grivi_icon_badge.dart';
import '../common/grivi_motion.dart';

class WalletCard extends StatelessWidget {
  const WalletCard({
    super.key,
    required this.wallet,
    this.onTap,
    this.width,
    this.hidden = false,
  });

  final WalletModel wallet;
  final VoidCallback? onTap;
  final double? width;

  /// Mode "sembunyikan saldo" dari Beranda.
  final bool hidden;

  @override
  Widget build(BuildContext context) {
    final color = hexToColor(wallet.color);

    return GriviPressable(
      onTap: onTap,
      child: Container(
        width: width,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: color.withValues(alpha: 0.32)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                GriviIconBadge(name: wallet.icon, color: color, size: 38, radius: 11),
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
            AnimatedMoney(
              value: wallet.balance,
              hidden: hidden,
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
