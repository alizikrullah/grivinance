import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/router/app_router.dart';
import '../../../core/theme/app_theme.dart';
import '../../../data/models/wallet_model.dart';
import '../../../providers/gamification_provider.dart';
import '../../../providers/wallet_provider.dart';
import '../../widgets/common/grivi_async_view.dart';
import '../../widgets/common/grivi_button.dart';
import '../../widgets/common/grivi_motion.dart';
import '../../widgets/wallet/wallet_card.dart';

class WalletListScreen extends ConsumerWidget {
  const WalletListScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final wallets = ref.watch(walletsProvider);
    final total = ref.watch(totalBalanceProvider);
    final hidden = ref.watch(hideBalanceProvider).valueOrNull ?? false;

    return Scaffold(
      appBar: AppBar(title: const Text('Wallet')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => context.push(AppRoutes.walletNew),
        backgroundColor: AppColors.primary,
        foregroundColor: AppColors.onPrimary,
        icon: const Icon(Icons.add),
        label: const Text('Tambah'),
      ),
      body: GriviAsyncView<List<WalletModel>>(
        value: wallets,
        onRetry: () => ref.invalidate(walletsProvider),
        isEmpty: (data) => data.isEmpty,
        emptyIcon: Icons.account_balance_wallet_outlined,
        emptyTitle: 'Belum ada wallet',
        emptyMessage: 'Tambah dompet digital, rekening bank, atau uang tunai',
        emptyAction: SizedBox(
          width: 200,
          child: GriviButton(
            label: 'Tambah wallet',
            icon: Icons.add,
            onPressed: () => context.push(AppRoutes.walletNew),
          ),
        ),
        builder: (data) => RefreshIndicator(
          color: AppColors.primary,
          backgroundColor: AppColors.surface,
          onRefresh: () => ref.read(walletsProvider.notifier).refresh(),
          child: ListView.separated(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 96),
            itemCount: data.length + 1,
            separatorBuilder: (_, _) => const SizedBox(height: 12),
            itemBuilder: (context, index) {
              if (index == 0) {
                return Padding(
                  padding: const EdgeInsets.only(left: 4, bottom: 4),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Total ${data.length} wallet',
                        style: const TextStyle(color: AppColors.textMuted, fontSize: 13),
                      ),
                      AnimatedMoney(
                        value: total,
                        hidden: hidden,
                        style: const TextStyle(fontSize: 26, fontWeight: FontWeight.w800),
                      ),
                    ],
                  ),
                );
              }
              final wallet = data[index - 1];
              return GriviFadeIn(
                index: index,
                child: WalletCard(
                  wallet: wallet,
                  hidden: hidden,
                  onTap: () => context.push(AppRoutes.walletDetail(wallet.id)),
                ),
              );
            },
          ),
        ),
      ),
    );
  }
}
