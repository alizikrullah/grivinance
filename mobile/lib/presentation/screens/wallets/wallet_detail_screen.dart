import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/constants/app_icons.dart';
import '../../../core/router/app_router.dart';
import '../../../core/theme/app_theme.dart';
import '../../../data/models/category_model.dart';
import '../../../data/models/transaction_model.dart';
import '../../../data/models/wallet_model.dart';
import '../../../providers/gamification_provider.dart';
import '../../../providers/transaction_provider.dart';
import '../../../providers/wallet_provider.dart';
import '../../widgets/common/grivi_async_view.dart';
import '../../widgets/common/grivi_card.dart';
import '../../widgets/common/grivi_icon_badge.dart';
import '../../widgets/common/grivi_motion.dart';
import '../../widgets/transaction/transaction_item.dart';

/// Ketuk wallet = lihat riwayatnya. Dulu langsung membuka form edit, padahal
/// yang biasanya dicari adalah "uangku ke mana aja dari sini".
class WalletDetailScreen extends ConsumerWidget {
  const WalletDetailScreen({super.key, required this.walletId});

  final String walletId;

  Future<void> _edit(BuildContext context) async {
    // Form edit mengembalikan true kalau wallet-nya dihapus; layar ini ikut tutup.
    final deleted = await context.push<bool>(AppRoutes.walletEdit(walletId));
    if (deleted == true && context.mounted) context.pop();
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final wallets = ref.watch(walletsProvider);
    final wallet = wallets.valueOrNull?.where((w) => w.id == walletId).firstOrNull;
    final history = ref.watch(walletTransactionsProvider(walletId));
    final hidden = ref.watch(hideBalanceProvider).valueOrNull ?? false;

    if (wallet == null) {
      return Scaffold(
        appBar: AppBar(),
        body: wallets.isLoading
            ? const Center(child: CircularProgressIndicator(color: AppColors.primary))
            : const GriviEmptyView(
                icon: Icons.account_balance_wallet_outlined,
                title: 'Wallet tidak ditemukan',
                message: 'Mungkin sudah dihapus.',
              ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(wallet.name),
        actions: [
          IconButton(
            tooltip: 'Edit',
            icon: const Icon(Icons.edit_outlined),
            onPressed: () => _edit(context),
          ),
        ],
      ),
      body: RefreshIndicator(
        color: AppColors.primary,
        backgroundColor: AppColors.surface,
        onRefresh: () async {
          ref.invalidate(walletsProvider);
          ref.invalidate(walletTransactionsProvider(walletId));
          await ref.read(walletTransactionsProvider(walletId).future);
        },
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
          children: [
            GriviFadeIn(child: _Header(wallet: wallet, hidden: hidden)),
            const SizedBox(height: 14),
            GriviFadeIn(
              index: 1,
              child: Row(
                children: [
                  _Action(
                    icon: Icons.add,
                    label: 'Catat',
                    onTap: () => context.push(AppRoutes.newTransaction(walletId: walletId)),
                  ),
                  const SizedBox(width: 10),
                  _Action(
                    icon: Icons.swap_horiz,
                    label: 'Transfer',
                    color: AppColors.transfer,
                    onTap: () => context.push(
                      AppRoutes.newTransaction(type: TxType.transfer, walletId: walletId),
                    ),
                  ),
                  const SizedBox(width: 10),
                  _Action(
                    icon: Icons.tune,
                    label: 'Atur',
                    color: AppColors.textSecondary,
                    onTap: () => _edit(context),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 22),
            const GriviSectionHeader(title: 'Riwayat'),
            GriviAsyncView<List<TransactionModel>>(
              value: history,
              onRetry: () => ref.invalidate(walletTransactionsProvider(walletId)),
              isEmpty: (data) => data.isEmpty,
              emptyIcon: Icons.receipt_long_outlined,
              emptyTitle: 'Belum ada transaksi',
              emptyMessage: 'Transaksi dan transfer wallet ini muncul di sini',
              builder: (data) => GriviCard(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Column(
                  children: [
                    for (var i = 0; i < data.length; i++)
                      GriviFadeIn(
                        index: i + 2,
                        child: TransactionItem(
                          transaction: data[i],
                          onTap: () => context.push(AppRoutes.transactionDetail(data[i].id)),
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Header extends StatelessWidget {
  const _Header({required this.wallet, required this.hidden});

  final WalletModel wallet;
  final bool hidden;

  @override
  Widget build(BuildContext context) {
    final color = hexToColor(wallet.color);

    return GriviCard(
      borderColor: color.withValues(alpha: 0.4),
      child: Row(
        children: [
          GriviIconBadge(name: wallet.icon, color: color, size: 56, radius: 16),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  wallet.type.label,
                  style: const TextStyle(color: AppColors.textMuted, fontSize: 12.5),
                ),
                AnimatedMoney(
                  value: wallet.balance,
                  hidden: hidden,
                  style: TextStyle(
                    fontSize: 26,
                    fontWeight: FontWeight.w800,
                    color: wallet.balance < 0 ? AppColors.expense : AppColors.textPrimary,
                  ),
                ),
                Text(
                  '${wallet.transactionCount} transaksi',
                  style: const TextStyle(color: AppColors.textSecondary, fontSize: 12.5),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _Action extends StatelessWidget {
  const _Action({
    required this.icon,
    required this.label,
    required this.onTap,
    this.color = AppColors.primary,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: GriviCard(
        onTap: onTap,
        padding: const EdgeInsets.symmetric(vertical: 14),
        child: Column(
          children: [
            Icon(icon, color: color),
            const SizedBox(height: 4),
            Text(label, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
          ],
        ),
      ),
    );
  }
}
