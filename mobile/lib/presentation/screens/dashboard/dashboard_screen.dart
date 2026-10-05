import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/constants/app_icons.dart';
import '../../../core/router/app_router.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/currency_formatter.dart';
import '../../../core/utils/date_formatter.dart';
import '../../../data/models/budget_model.dart';
import '../../../data/models/category_model.dart';
import '../../../data/models/gamification_model.dart';
import '../../../data/models/summary_model.dart';
import '../../../data/models/user_model.dart';
import '../../../data/models/wallet_model.dart';
import '../../../providers/auth_provider.dart';
import '../../../providers/budget_provider.dart';
import '../../../providers/data_refresh.dart';
import '../../../providers/gamification_provider.dart';
import '../../../providers/summary_provider.dart';
import '../../../providers/transaction_provider.dart';
import '../../../providers/wallet_provider.dart';
import '../../widgets/budget/progress_tile.dart';
import '../../widgets/common/grivi_async_view.dart';
import '../../widgets/common/grivi_avatar.dart';
import '../../widgets/common/grivi_card.dart';
import '../../widgets/common/grivi_icon_badge.dart';
import '../../widgets/common/grivi_motion.dart';
import '../../widgets/gamification/gamification_widgets.dart';
import '../../widgets/transaction/transaction_item.dart';
import '../../widgets/wallet/wallet_card.dart';

class DashboardScreen extends ConsumerWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(authProvider).valueOrNull;
    final game = ref.watch(gamificationProvider).valueOrNull;
    final month = ref.watch(thisMonthSummaryProvider).valueOrNull;
    final budgets = ref.watch(budgetsProvider(currentBudgetMonth())).valueOrNull;
    final hidden = ref.watch(hideBalanceProvider).valueOrNull ?? false;

    final sections = <Widget>[
      _Header(user: user, game: game),
      _BalanceCard(game: game, month: month, budgets: budgets, hidden: hidden),
      _StatTiles(month: month, budgets: budgets, hidden: hidden),
      if (game != null && game.missions.isNotEmpty) MissionCard(state: game),
      _WalletSection(hidden: hidden),
      if (_SpendingSection.hasContent(month, budgets))
        _SpendingSection(month: month!, budgets: budgets),
      const _RecentSection(),
    ];

    return Scaffold(
      body: SafeArea(
        child: RefreshIndicator(
          color: AppColors.primary,
          backgroundColor: AppColors.surface,
          onRefresh: () async {
            invalidateMoneyData(ref.invalidate);
            await ref.read(walletsProvider.future);
          },
          child: ListView.separated(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 28),
            itemCount: sections.length,
            separatorBuilder: (_, i) => SizedBox(height: i == 0 ? 18 : 20),
            itemBuilder: (_, i) => GriviFadeIn(index: i, child: sections[i]),
          ),
        ),
      ),
    );
  }
}

class _Header extends ConsumerWidget {
  const _Header({required this.user, required this.game});

  final UserModel? user;
  final GamificationState? game;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final birthday = user?.isBirthday(DateTime.now()) ?? false;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            GriviAvatar(
              size: 48,
              onTap: () => ref.read(homeTabProvider.notifier).state = 3,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    DateFormatter.greeting(),
                    style: const TextStyle(color: AppColors.textSecondary, fontSize: 13),
                  ),
                  Text(
                    'Hai, ${user?.greetingName ?? ''}! 👋',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontSize: 21, fontWeight: FontWeight.w800),
                  ),
                ],
              ),
            ),
            if (game != null) StreakChip(state: game!),
          ],
        ),
        if (birthday) ...[
          const SizedBox(height: 12),
          const GriviChip(
            icon: Icons.cake_outlined,
            label: 'Selamat ulang tahun! Semoga dompetnya makin tebal 🎉',
            color: AppColors.warning,
          ),
        ],
      ],
    );
  }
}

class _BalanceCard extends ConsumerWidget {
  const _BalanceCard({
    required this.game,
    required this.month,
    required this.budgets,
    required this.hidden,
  });

  final GamificationState? game;
  final PeriodSummary? month;
  final BudgetSummary? budgets;
  final bool hidden;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final total = ref.watch(totalBalanceProvider);
    final loaded = ref.watch(walletsProvider).hasValue;
    final ink = AppColors.onPrimary;
    final net = month == null ? null : month!.totalIncome - month!.totalExpense;

    return Container(
      padding: const EdgeInsets.fromLTRB(20, 16, 16, 18),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [AppColors.primary, AppColors.primaryDark],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: AppColors.primary.withValues(alpha: 0.25),
            blurRadius: 24,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text('Total saldo', style: TextStyle(color: ink.withValues(alpha: 0.8))),
              GriviPressable(
                onTap: () => ref.read(hideBalanceProvider.notifier).toggle(),
                child: Padding(
                  padding: const EdgeInsets.all(6),
                  child: Icon(
                    hidden ? Icons.visibility_off_outlined : Icons.visibility_outlined,
                    size: 18,
                    color: ink.withValues(alpha: 0.8),
                  ),
                ),
              ),
              const Spacer(),
              if (game != null)
                Flexible(
                  child: LevelChip(
                    state: game!,
                    onDark: true,
                    onTap: () => context.push(AppRoutes.achievements),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 4),
          loaded
              ? AnimatedMoney(
                  value: total,
                  hidden: hidden,
                  style: TextStyle(
                    color: ink,
                    fontSize: 32,
                    fontWeight: FontWeight.w800,
                    letterSpacing: -0.8,
                  ),
                )
              : Text('—', style: TextStyle(color: ink, fontSize: 32)),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              if (net != null)
                GriviChip(
                  icon: net >= 0 ? Icons.trending_up : Icons.trending_down,
                  label: hidden
                      ? 'Bulan ini'
                      : '${net >= 0 ? '+' : '-'}Rp ${CurrencyFormatter.compact(net.abs())} bulan ini',
                  color: ink,
                  background: ink.withValues(alpha: 0.12),
                ),
              if (budgets != null && !budgets!.isEmpty)
                GriviChip(
                  icon: budgets!.status == BudgetStatus.safe
                      ? Icons.verified_outlined
                      : Icons.warning_amber_rounded,
                  label: budgets!.status.label,
                  color: ink,
                  background: ink.withValues(alpha: 0.12),
                  onTap: () => context.push(AppRoutes.budgets),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

/// Pemasukan, pengeluaran, dan sisa budget bulan ini. Dua yang pertama
/// langsung membuka tab Bulanan di Grafik dengan donut tipe itu.
class _StatTiles extends ConsumerWidget {
  const _StatTiles({required this.month, required this.budgets, required this.hidden});

  final PeriodSummary? month;
  final BudgetSummary? budgets;
  final bool hidden;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    void openChart(TxType type) {
      ref.read(summaryTypeProvider.notifier).state = type;
      ref.read(selectedMonthProvider.notifier).state = DateTime.now();
      ref.read(chartTabProvider.notifier).state = 1;
      ref.read(homeTabProvider.notifier).state = 2;
    }

    final hasBudget = budgets != null && !budgets!.isEmpty;
    final budgetColor = !hasBudget
        ? AppColors.textSecondary
        : switch (budgets!.status) {
            BudgetStatus.safe => AppColors.primary,
            BudgetStatus.tight => AppColors.warning,
            BudgetStatus.over => AppColors.expense,
          };

    return Row(
      children: [
        Expanded(
          child: _StatTile(
            icon: Icons.south_west,
            label: 'Pemasukan',
            color: AppColors.income,
            value: month?.totalIncome,
            hidden: hidden,
            onTap: () => openChart(TxType.income),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: _StatTile(
            icon: Icons.north_east,
            label: 'Pengeluaran',
            color: AppColors.expense,
            value: month?.totalExpense,
            hidden: hidden,
            onTap: () => openChart(TxType.expense),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: _StatTile(
            icon: Icons.pie_chart_outline,
            label: hasBudget ? 'Sisa budget' : 'Budget',
            color: budgetColor,
            value: hasBudget ? budgets!.remaining : null,
            placeholder: 'Atur',
            hidden: hidden,
            onTap: () => context.push(AppRoutes.budgets),
          ),
        ),
      ],
    );
  }
}

class _StatTile extends StatelessWidget {
  const _StatTile({
    required this.icon,
    required this.label,
    required this.color,
    required this.value,
    required this.hidden,
    required this.onTap,
    this.placeholder = '—',
  });

  final IconData icon;
  final String label;
  final Color color;
  final double? value;
  final bool hidden;
  final VoidCallback onTap;
  final String placeholder;

  @override
  Widget build(BuildContext context) {
    return GriviCard(
      onTap: onTap,
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          GriviIconBadge.material(icon, color: color, size: 30, radius: 10),
          const SizedBox(height: 10),
          Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(color: AppColors.textMuted, fontSize: 12),
          ),
          const SizedBox(height: 2),
          value == null
              ? Text(
                  placeholder,
                  style: TextStyle(color: color, fontWeight: FontWeight.w700, fontSize: 15),
                )
              : AnimatedMoney(
                  value: value!,
                  compact: true,
                  hidden: hidden,
                  style: TextStyle(color: color, fontWeight: FontWeight.w700, fontSize: 15),
                ),
        ],
      ),
    );
  }
}

class _WalletSection extends ConsumerWidget {
  const _WalletSection({required this.hidden});

  final bool hidden;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final wallets = ref.watch(walletsProvider);

    return Column(
      children: [
        GriviSectionHeader(
          title: 'Wallet',
          actionLabel: 'Kelola',
          onAction: () => context.push(AppRoutes.wallets),
        ),
        // Tinggi tetap cuma membungkus daftar kartunya. Kalau ikut membungkus
        // GriviAsyncView, state kosong dan error yang jauh lebih tinggi bakal
        // meluber dan menimpa section di bawahnya (BUG-1).
        GriviAsyncView<List<WalletModel>>(
          value: wallets,
          onRetry: () => ref.invalidate(walletsProvider),
          isEmpty: (data) => data.isEmpty,
          emptyIcon: Icons.account_balance_wallet_outlined,
          emptyTitle: 'Belum ada wallet',
          emptyMessage: 'Tambah wallet dulu sebelum mencatat transaksi',
          builder: (data) => SizedBox(
            height: 128,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: data.length + 1,
              separatorBuilder: (_, _) => const SizedBox(width: 12),
              itemBuilder: (context, index) {
                if (index == data.length) {
                  return _AddWalletCard(onTap: () => context.push(AppRoutes.walletNew));
                }
                return WalletCard(
                  wallet: data[index],
                  width: 180,
                  hidden: hidden,
                  onTap: () => context.push(AppRoutes.walletDetail(data[index].id)),
                );
              },
            ),
          ),
        ),
      ],
    );
  }
}

class _AddWalletCard extends StatelessWidget {
  const _AddWalletCard({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GriviPressable(
      onTap: onTap,
      child: Container(
        width: 96,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: AppColors.surfaceVariant, width: 1.5),
        ),
        child: const Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.add_circle_outline, color: AppColors.primary),
            SizedBox(height: 6),
            Text('Tambah', style: TextStyle(color: AppColors.textSecondary, fontSize: 12.5)),
          ],
        ),
      ),
    );
  }
}

/// Budget bulan ini kalau ada; kalau belum, pengeluaran terbesar bulan ini.
class _SpendingSection extends ConsumerWidget {
  const _SpendingSection({required this.month, required this.budgets});

  final PeriodSummary month;
  final BudgetSummary? budgets;

  static bool hasContent(PeriodSummary? month, BudgetSummary? budgets) =>
      (budgets != null && !budgets.isEmpty) || (month?.expenses.isNotEmpty ?? false);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final useBudget = budgets != null && !budgets!.isEmpty;

    final List<Widget> rows;
    if (useBudget) {
      final items = [...budgets!.items]..sort((a, b) => b.ratio.compareTo(a.ratio));
      rows = [
        for (final item in items.take(3))
          ProgressTile.budget(item, onTap: () => context.push(AppRoutes.budgets)),
      ];
    } else {
      final total = month.totalExpense;
      rows = [
        for (final item in month.expenses.take(3))
          ProgressTile(
            name: item.name,
            icon: item.icon,
            color: hexToColor(item.color),
            ratio: total == 0 ? 0 : item.total / total,
            caption: 'dari pengeluaran bulan ini',
            trailing: 'Rp ${CurrencyFormatter.compact(item.total)}',
          ),
      ];
    }

    return Column(
      children: [
        GriviSectionHeader(
          title: useBudget ? 'Budget bulan ini' : 'Pengeluaran teratas',
          actionLabel: useBudget ? 'Atur' : 'Budget',
          onAction: () => context.push(AppRoutes.budgets),
        ),
        GriviCard(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
          child: Column(children: rows),
        ),
      ],
    );
  }
}

class _RecentSection extends ConsumerWidget {
  const _RecentSection();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final recent = ref.watch(recentTransactionsProvider);

    return Column(
      children: [
        GriviSectionHeader(
          title: 'Transaksi terakhir',
          actionLabel: 'Semua',
          // Pindah tab, bukan push — biar nggak ada dua daftar transaksi
          // yang hidup barengan dengan state berbeda.
          onAction: () => ref.read(homeTabProvider.notifier).state = 1,
        ),
        GriviAsyncView(
          value: recent,
          onRetry: () => ref.invalidate(recentTransactionsProvider),
          isEmpty: (data) => data.isEmpty,
          emptyIcon: Icons.receipt_long_outlined,
          emptyTitle: 'Belum ada transaksi',
          emptyMessage: 'Ketuk tombol + buat catat pemasukan atau pengeluaran pertama',
          builder: (data) => GriviCard(
            padding: const EdgeInsets.symmetric(vertical: 4),
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
    );
  }
}
