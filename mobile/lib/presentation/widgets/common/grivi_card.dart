import 'package:flutter/material.dart';

import '../../../core/theme/app_theme.dart';
import 'grivi_motion.dart';

/// Kotak permukaan standar. Kalau [onTap] diisi, otomatis bisa ditekan.
class GriviCard extends StatelessWidget {
  const GriviCard({
    super.key,
    required this.child,
    this.onTap,
    this.padding = const EdgeInsets.all(16),
    this.color = AppColors.surface,
    this.borderColor,
    this.radius = 18,
  });

  final Widget child;
  final VoidCallback? onTap;
  final EdgeInsetsGeometry padding;
  final Color color;
  final Color? borderColor;
  final double radius;

  @override
  Widget build(BuildContext context) {
    final card = Container(
      width: double.infinity,
      padding: padding,
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(radius),
        border: borderColor == null ? null : Border.all(color: borderColor!, width: 1.2),
      ),
      child: child,
    );
    return onTap == null ? card : GriviPressable(onTap: onTap, child: card);
  }
}

/// Judul section + aksi kecil di kanan ("Kelola", "Semua").
class GriviSectionHeader extends StatelessWidget {
  const GriviSectionHeader({super.key, required this.title, this.actionLabel, this.onAction});

  final String title;
  final String? actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        children: [
          Expanded(
            child: Text(
              title,
              style: const TextStyle(fontSize: 16.5, fontWeight: FontWeight.w700),
            ),
          ),
          if (actionLabel != null)
            GriviPressable(
              onTap: onAction,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      actionLabel!,
                      style: const TextStyle(
                        color: AppColors.primary,
                        fontWeight: FontWeight.w600,
                        fontSize: 13.5,
                      ),
                    ),
                    const Icon(Icons.chevron_right, size: 18, color: AppColors.primary),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}

/// Pil kecil berisi teks (dan ikon). Latar tipis dari warna yang sama —
/// ini label, bukan kotak ikon, jadi aturan kontras GriviIconBadge nggak berlaku.
class GriviChip extends StatelessWidget {
  const GriviChip({
    super.key,
    required this.label,
    this.icon,
    this.color = AppColors.textSecondary,
    this.background,
    this.onTap,
  });

  final String label;
  final IconData? icon;
  final Color color;
  final Color? background;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    // Text.rich, bukan Row + Flexible: chip ini sering ditaruh langsung di
    // Row yang lebarnya tak terbatas, dan Flexible di sana melempar error
    // layout. Teks menyesuaikan diri di dua kondisi itu.
    final chip = Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: background ?? color.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text.rich(
        TextSpan(
          children: [
            if (icon != null)
              WidgetSpan(
                alignment: PlaceholderAlignment.middle,
                child: Padding(
                  padding: const EdgeInsets.only(right: 5),
                  child: Icon(icon, size: 14, color: color),
                ),
              ),
            TextSpan(text: label),
          ],
        ),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(color: color, fontSize: 12, fontWeight: FontWeight.w600),
      ),
    );
    return onTap == null ? chip : GriviPressable(onTap: onTap, child: chip);
  }
}
