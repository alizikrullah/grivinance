import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/router/app_router.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/currency_formatter.dart';
import '../../../data/models/wallet_model.dart';
import '../../../providers/auth_provider.dart';
import '../../../providers/transaction_provider.dart';
import '../../../providers/wallet_provider.dart';
import '../../widgets/common/grivi_async_view.dart';
import '../../widgets/transaction/transaction_item.dart';
import '../../widgets/wallet/wallet_card.dart';

class DashboardScreen extends ConsumerWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(authProvider).value;
    final wallets = ref.watch(walletsProvider);
    final recent = ref.watch(recentTransactionsProvider);

    return Scaffold(
      body: SafeArea(
        child: RefreshIndicator(
          color: AppColors.primary,
          backgroundColor: AppColors.surface,
          onRefresh: () async {
            await ref.read(walletsProvider.notifier).refresh();
            ref.invalidate(recentTransactionsProvider);
          },
          child: ListView(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 96),
            children: [
              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Halo,',
                          style: TextStyle(color: AppColors.textSecondary),
                        ),
                        Text(
                          user?.name ?? '-',
                          style: const TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 18),
              const _TotalBalanceCard(),
              const SizedBox(height: 22),
              _SectionHeader(
                title: 'Wallet',
                actionLabel: 'Kelola',
                onAction: () => context.push(AppRoutes.wallets),
              ),
              const SizedBox(height: 10),
              // Tinggi tetap cuma membungkus daftar kartunya. Kalau ikut
              // membungkus GriviAsyncView, state kosong dan error yang jauh
              // lebih tinggi bakal meluber dan menimpa section di bawahnya.
              GriviAsyncView<List<WalletModel>>(
                value: wallets,
                onRetry: () => ref.read(walletsProvider.notifier).refresh(),
                isEmpty: (data) => data.isEmpty,
                emptyIcon: Icons.account_balance_wallet_outlined,
                emptyTitle: 'Belum ada wallet',
                emptyMessage: 'Tambah wallet dulu sebelum mencatat transaksi',
                builder: (data) => SizedBox(
                  height: 132,
                  child: ListView.separated(
                    scrollDirection: Axis.horizontal,
                    itemCount: data.length,
                    separatorBuilder: (_, _) => const SizedBox(width: 12),
                    itemBuilder: (context, index) => WalletCard(
                      wallet: data[index],
                      width: 190,
                      onTap: () => context.push(AppRoutes.walletEdit(data[index].id)),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 22),
              _SectionHeader(
                title: 'Transaksi terakhir',
                actionLabel: 'Semua',
                // Pindah tab, bukan push — biar nggak ada dua daftar transaksi
                // yang hidup barengan dengan state berbeda.
                onAction: () => ref.read(homeTabProvider.notifier).state = 1,
              ),
              const SizedBox(height: 6),
              GriviAsyncView(
                value: recent,
                onRetry: () => ref.invalidate(recentTransactionsProvider),
                isEmpty: (data) => data.isEmpty,
                emptyIcon: Icons.receipt_long_outlined,
                emptyTitle: 'Belum ada transaksi',
                emptyMessage: 'Catat pemasukan atau pengeluaran pertama kamu',
                builder: (data) => Container(
                  decoration: BoxDecoration(
                    color: AppColors.surface,
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Column(
                    children: [
                      for (final tx in data)
                        TransactionItem(
                          transaction: tx,
                          onTap: () => context.push(AppRoutes.transactionDetail(tx.id)),
                        ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _TotalBalanceCard extends ConsumerWidget {
  const _TotalBalanceCard();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final total = ref.watch(totalBalanceProvider);
    final loading = ref.watch(walletsProvider).isLoading;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [AppColors.primary, AppColors.primaryDark],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Total saldo',
            style: TextStyle(color: Color(0xCC04231A), fontSize: 13),
          ),
          const SizedBox(height: 8),
          Text(
            loading ? '—' : CurrencyFormatter.formatSigned(total),
            style: const TextStyle(
              color: Color(0xFF04231A),
              fontSize: 30,
              fontWeight: FontWeight.w800,
              letterSpacing: -0.8,
            ),
          ),
        ],
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({
    required this.title,
    required this.actionLabel,
    required this.onAction,
  });

  final String title;
  final String actionLabel;
  final VoidCallback onAction;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(title, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
        TextButton(onPressed: onAction, child: Text(actionLabel)),
      ],
    );
  }
}
