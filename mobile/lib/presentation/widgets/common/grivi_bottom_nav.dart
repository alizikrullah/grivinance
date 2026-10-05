import 'package:flutter/material.dart';

import '../../../core/theme/app_theme.dart';
import 'grivi_motion.dart';

/// Empat tab + tombol tambah bulat di tengah.
class GriviBottomNav extends StatelessWidget {
  const GriviBottomNav({
    super.key,
    required this.index,
    required this.onChanged,
    required this.onAdd,
  });

  final int index;
  final ValueChanged<int> onChanged;
  final VoidCallback onAdd;

  static const _items = [
    (Icons.dashboard_outlined, Icons.dashboard, 'Beranda'),
    (Icons.receipt_long_outlined, Icons.receipt_long, 'Transaksi'),
    (Icons.pie_chart_outline, Icons.pie_chart, 'Grafik'),
    (Icons.person_outline, Icons.person, 'Akun'),
  ];

  @override
  Widget build(BuildContext context) {
    Widget item(int i) => Expanded(
      child: _NavItem(
        icon: _items[i].$1,
        activeIcon: _items[i].$2,
        label: _items[i].$3,
        selected: index == i,
        onTap: () => onChanged(i),
      ),
    );

    return Container(
      decoration: const BoxDecoration(
        color: AppColors.surface,
        border: Border(top: BorderSide(color: AppColors.surfaceVariant)),
      ),
      child: SafeArea(
        top: false,
        child: SizedBox(
          height: 66,
          child: Row(
            children: [
              item(0),
              item(1),
              Expanded(child: Center(child: _AddButton(onTap: onAdd))),
              item(2),
              item(3),
            ],
          ),
        ),
      ),
    );
  }
}

class _NavItem extends StatelessWidget {
  const _NavItem({
    required this.icon,
    required this.activeIcon,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final IconData icon;
  final IconData activeIcon;
  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final color = selected ? AppColors.primary : AppColors.textMuted;

    return GriviPressable(
      onTap: onTap,
      pressedScale: 0.9,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            curve: Curves.easeOut,
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
            decoration: BoxDecoration(
              color: selected ? AppColors.primary.withValues(alpha: 0.16) : Colors.transparent,
              borderRadius: BorderRadius.circular(20),
            ),
            child: Icon(selected ? activeIcon : icon, color: color, size: 23),
          ),
          const SizedBox(height: 3),
          Text(
            label,
            style: TextStyle(
              color: color,
              fontSize: 11,
              fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}

class _AddButton extends StatelessWidget {
  const _AddButton({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GriviPressable(
      onTap: onTap,
      pressedScale: 0.88,
      child: Container(
        height: 52,
        width: 52,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: const LinearGradient(
            colors: [AppColors.primary, AppColors.primaryDark],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          boxShadow: [
            BoxShadow(
              color: AppColors.primary.withValues(alpha: 0.35),
              blurRadius: 16,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: const Icon(Icons.add, color: AppColors.onPrimary, size: 28),
      ),
    );
  }
}
