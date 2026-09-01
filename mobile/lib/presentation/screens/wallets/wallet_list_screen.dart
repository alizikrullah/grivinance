import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/router/app_router.dart';
import '../../../core/theme/app_theme.dart';
import '../../../data/models/wallet_model.dart';
import '../../../providers/wallet_provider.dart';
import '../../widgets/common/grivi_async_view.dart';
import '../../widgets/common/grivi_button.dart';
import '../../widgets/wallet/wallet_card.dart';

class WalletListScreen extends ConsumerWidget {
  const WalletListScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final wallets = ref.watch(walletsProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Wallet')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => context.push(AppRoutes.walletNew),
        backgroundColor: AppColors.primary,
        foregroundColor: const Color(0xFF04231A),
        icon: const Icon(Icons.add),
        label: const Text('Tambah'),
      ),
      body: GriviAsyncView<List<WalletModel>>(
        value: wallets,
        onRetry: () => ref.read(walletsProvider.notifier).refresh(),
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
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 96),
            itemCount: data.length,
            separatorBuilder: (_, _) => const SizedBox(height: 12),
            itemBuilder: (context, index) => WalletCard(
              wallet: data[index],
              onTap: () => context.push(AppRoutes.walletEdit(data[index].id)),
            ),
          ),
        ),
      ),
    );
  }
}
