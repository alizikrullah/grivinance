import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/router/app_router.dart';
import '../../../core/theme/app_theme.dart';
import '../../../providers/auth_provider.dart';
import '../../../providers/gamification_provider.dart';
import '../../../providers/transaction_provider.dart';
import '../../widgets/common/grivi_avatar.dart';
import '../../widgets/common/grivi_card.dart';
import '../../widgets/common/grivi_icon_badge.dart';
import '../../widgets/common/grivi_motion.dart';
import '../../widgets/gamification/gamification_widgets.dart';

class AccountScreen extends ConsumerStatefulWidget {
  const AccountScreen({super.key});

  @override
  ConsumerState<AccountScreen> createState() => _AccountScreenState();
}

class _AccountScreenState extends ConsumerState<AccountScreen> {
  bool _exporting = false;

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(authProvider).valueOrNull;
    final game = ref.watch(gamificationProvider).valueOrNull;

    final tiles = <Widget>[
      _MenuTile(
        icon: Icons.manage_accounts_outlined,
        title: 'Edit profil',
        subtitle: 'Foto, nama, nomor HP, email, password',
        onTap: () => context.push(AppRoutes.profile),
      ),
      _MenuTile(
        icon: Icons.account_balance_wallet_outlined,
        title: 'Wallet',
        subtitle: 'Kelola dompet, rekening, dan tunai',
        onTap: () => context.push(AppRoutes.wallets),
      ),
      _MenuTile(
        icon: Icons.category_outlined,
        title: 'Kategori',
        subtitle: 'Kategori bawaan dan buatan sendiri',
        onTap: () => context.push(AppRoutes.categories),
      ),
      _MenuTile(
        icon: Icons.pie_chart_outline,
        title: 'Budget',
        subtitle: 'Batas pengeluaran per kategori tiap bulan',
        onTap: () => context.push(AppRoutes.budgets),
      ),
      _MenuTile(
        icon: Icons.emoji_events_outlined,
        title: 'Lencana',
        subtitle: game == null
            ? 'Pencapaian kamu'
            : '${game.unlockedCount} dari ${game.achievements.length} terbuka',
        color: AppColors.warning,
        onTap: () => context.push(AppRoutes.achievements),
      ),
      _MenuTile(
        icon: Icons.file_download_outlined,
        title: _exporting ? 'Menyiapkan file...' : 'Export ke Excel',
        subtitle: 'Pilih rentang tanggal, hasilnya file .xlsx',
        onTap: _exporting ? null : _export,
      ),
    ];

    return Scaffold(
      appBar: AppBar(title: const Text('Akun')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 28),
        children: [
          GriviFadeIn(
            child: GriviCard(
              onTap: () => context.push(AppRoutes.profile),
              child: Column(
                children: [
                  Row(
                    children: [
                      const GriviAvatar(size: 58),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              user?.name ?? '-',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w700),
                            ),
                            Text(
                              user?.email ?? '',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(color: AppColors.textSecondary, fontSize: 13),
                            ),
                          ],
                        ),
                      ),
                      const Icon(Icons.edit_outlined, size: 19, color: AppColors.textMuted),
                    ],
                  ),
                  if (game != null) ...[
                    const SizedBox(height: 16),
                    LevelProgress(state: game),
                  ],
                ],
              ),
            ),
          ),
          const SizedBox(height: 18),
          for (var i = 0; i < tiles.length; i++)
            Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: GriviFadeIn(index: i + 1, child: tiles[i]),
            ),
          const SizedBox(height: 12),
          GriviFadeIn(
            index: tiles.length + 1,
            child: _MenuTile(
              icon: Icons.logout,
              title: 'Keluar',
              danger: true,
              onTap: () => _confirmLogout(context),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _export() async {
    final range = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2020),
      lastDate: DateTime(2100),
      helpText: 'Pilih rentang transaksi',
      saveText: 'Export',
    );
    if (range == null || !mounted) return;

    setState(() => _exporting = true);
    final messenger = ScaffoldMessenger.of(context);

    try {
      final service = ref.read(exportServiceProvider);
      final transactions = await service.fetchRange(start: range.start, end: range.end);

      if (transactions.isEmpty) {
        messenger.showSnackBar(
          const SnackBar(content: Text('Tidak ada transaksi di rentang itu')),
        );
        return;
      }

      final path = await service.buildWorkbook(
        transactions: transactions,
        start: range.start,
        end: range.end,
      );
      await service.share(path, start: range.start, end: range.end);
    } catch (e) {
      messenger.showSnackBar(SnackBar(content: Text('Gagal export: $e')));
    } finally {
      if (mounted) setState(() => _exporting = false);
    }
  }

  Future<void> _confirmLogout(BuildContext context) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Keluar dari akun?'),
        content: const Text('Kamu perlu login lagi untuk mengakses data.'),
        actions: [
          TextButton(onPressed: () => context.pop(false), child: const Text('Batal')),
          TextButton(
            onPressed: () => context.pop(true),
            style: TextButton.styleFrom(foregroundColor: AppColors.expense),
            child: const Text('Keluar'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      await ref.read(authProvider.notifier).logout();
    }
  }
}

class _MenuTile extends StatelessWidget {
  const _MenuTile({
    required this.icon,
    required this.title,
    required this.onTap,
    this.subtitle,
    this.color = AppColors.primary,
    this.danger = false,
  });

  final IconData icon;
  final String title;
  final String? subtitle;
  final VoidCallback? onTap;
  final Color color;
  final bool danger;

  @override
  Widget build(BuildContext context) {
    final tint = danger ? AppColors.expense : color;

    return GriviCard(
      onTap: onTap,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
      radius: 16,
      child: Row(
        children: [
          GriviIconBadge.material(icon, color: tint),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    color: danger ? AppColors.expense : AppColors.textPrimary,
                  ),
                ),
                if (subtitle != null)
                  Text(
                    subtitle!,
                    style: const TextStyle(color: AppColors.textMuted, fontSize: 12.5),
                  ),
              ],
            ),
          ),
          if (!danger) const Icon(Icons.chevron_right, color: AppColors.textMuted),
        ],
      ),
    );
  }
}
