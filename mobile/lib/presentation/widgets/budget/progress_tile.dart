import 'package:flutter/material.dart';

import '../../../core/constants/app_icons.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/currency_formatter.dart';
import '../../../data/models/budget_model.dart';
import '../common/grivi_icon_badge.dart';
import '../common/grivi_motion.dart';

/// Baris kategori dengan bar progres — dipakai budget (terpakai vs budget)
/// dan "pengeluaran teratas" (porsi dari total) di Beranda.
class ProgressTile extends StatelessWidget {
  const ProgressTile({
    super.key,
    required this.name,
    required this.icon,
    required this.color,
    required this.ratio,
    required this.caption,
    required this.trailing,
    this.barColor,
    this.onTap,
  });

  /// Baris budget: warna bar ikut seberapa dekat ke batasnya.
  factory ProgressTile.budget(BudgetItem item, {VoidCallback? onTap}) {
    final over = item.ratio > 1;
    final barColor = over
        ? AppColors.expense
        : item.ratio >= 0.8
        ? AppColors.warning
        : hexToColor(item.color);

    return ProgressTile(
      name: item.name,
      icon: item.icon,
      color: hexToColor(item.color),
      ratio: item.ratio,
      barColor: barColor,
      caption: over
          ? 'Lewat ${CurrencyFormatter.format(-item.remaining)}'
          : 'Sisa ${CurrencyFormatter.format(item.remaining)}',
      trailing:
          '${CurrencyFormatter.compact(item.spent)} / ${CurrencyFormatter.compact(item.amount)}',
      onTap: onTap,
    );
  }

  final String name;
  final String icon;
  final Color color;
  final double ratio;
  final String caption;
  final String trailing;
  final Color? barColor;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return GriviPressable(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Row(
          children: [
            GriviIconBadge(name: icon, color: color, size: 38, radius: 11),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(fontWeight: FontWeight.w600),
                        ),
                      ),
                      Text(
                        '${(ratio * 100).round()}%',
                        style: TextStyle(
                          fontWeight: FontWeight.w700,
                          fontSize: 12.5,
                          color: barColor ?? color,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  GriviProgressBar(value: ratio, color: barColor ?? color, height: 7),
                  const SizedBox(height: 5),
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          caption,
                          style: const TextStyle(color: AppColors.textMuted, fontSize: 11.5),
                        ),
                      ),
                      Text(
                        trailing,
                        style: const TextStyle(color: AppColors.textSecondary, fontSize: 11.5),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
