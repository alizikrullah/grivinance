import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/router/app_router.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/date_formatter.dart';
import '../../../data/models/category_model.dart';
import '../../../data/models/transaction_model.dart';
import '../../../data/models/wallet_model.dart';
import '../../../providers/category_provider.dart';
import '../../../providers/transaction_provider.dart';
import '../../../providers/wallet_provider.dart';
import '../../widgets/common/grivi_async_view.dart';
import '../../widgets/common/grivi_icon_badge.dart';
import '../../widgets/common/grivi_motion.dart';
import '../../widgets/transaction/transaction_item.dart';

class TransactionListScreen extends ConsumerStatefulWidget {
  const TransactionListScreen({super.key});

  @override
  ConsumerState<TransactionListScreen> createState() => _TransactionListScreenState();
}

class _TransactionListScreenState extends ConsumerState<TransactionListScreen> {
  final _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
  }

  @override
  void dispose() {
    _scrollController.removeListener(_onScroll);
    _scrollController.dispose();
    super.dispose();
  }

  void _onScroll() {
    final position = _scrollController.position;
    if (position.pixels >= position.maxScrollExtent - 300) {
      ref.read(transactionsProvider.notifier).loadMore();
    }
  }

  void _setFilter(TransactionFilter filter) {
    ref.read(transactionFilterProvider.notifier).state = filter;
  }

  @override
  Widget build(BuildContext context) {
    final transactions = ref.watch(transactionsProvider);
    final filter = ref.watch(transactionFilterProvider);
    // Tipe punya chip sendiri di atas; badge filter cuma buat sisanya.
    final otherFilters = !filter.copyWith(clearType: true).isEmpty;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Transaksi'),
        actions: [
          IconButton(
            tooltip: 'Filter',
            icon: Badge(
              isLabelVisible: otherFilters,
              backgroundColor: AppColors.primary,
              child: const Icon(Icons.tune),
            ),
            onPressed: () => _openFilterSheet(context),
          ),
        ],
      ),
      body: Column(
        children: [
          SizedBox(
            height: 44,
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              children: [
                _TypeChip(
                  label: 'Semua',
                  selected: filter.type == null,
                  onTap: () => _setFilter(filter.copyWith(clearType: true)),
                ),
                for (final type in TxType.values)
                  _TypeChip(
                    label: type.label,
                    selected: filter.type == type,
                    color: _colorOf(type),
                    onTap: () => _setFilter(filter.copyWith(type: type, clearCategory: true)),
                  ),
              ],
            ),
          ),
          if (otherFilters)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 0),
              child: Row(
                children: [
                  const Icon(Icons.filter_alt, size: 16, color: AppColors.primary),
                  const SizedBox(width: 6),
                  const Expanded(
                    child: Text(
                      'Filter wallet/kategori/tanggal aktif',
                      style: TextStyle(color: AppColors.primary, fontSize: 13),
                    ),
                  ),
                  TextButton(
                    onPressed: () => _setFilter(TransactionFilter(type: filter.type)),
                    child: const Text('Reset'),
                  ),
                ],
              ),
            ),
          Expanded(
            child: GriviAsyncView<List<TransactionModel>>(
              value: transactions,
              onRetry: () => ref.read(transactionsProvider.notifier).refresh(),
              isEmpty: (data) => data.isEmpty,
              emptyIcon: Icons.receipt_long_outlined,
              emptyTitle: 'Tidak ada transaksi',
              emptyMessage: filter.isEmpty
                  ? 'Ketuk tombol + buat catat transaksi pertama kamu'
                  : 'Tidak ada yang cocok dengan filter ini',
              builder: (data) => RefreshIndicator(
                color: AppColors.primary,
                backgroundColor: AppColors.surface,
                onRefresh: () => ref.read(transactionsProvider.notifier).refresh(),
                child: ListView.builder(
                  controller: _scrollController,
                  padding: const EdgeInsets.fromLTRB(12, 4, 12, 28),
                  itemCount: data.length + 1,
                  itemBuilder: (context, index) {
                    if (index == data.length) {
                      return ref.read(transactionsProvider.notifier).hasMore
                          ? const Padding(
                              padding: EdgeInsets.symmetric(vertical: 20),
                              child: Center(
                                child: CircularProgressIndicator(color: AppColors.primary),
                              ),
                            )
                          : const SizedBox(height: 8);
                    }

                    final tx = data[index];
                    final showHeader =
                        index == 0 || !DateFormatter.sameDay(data[index - 1].date, tx.date);

                    return GriviFadeIn(
                      index: index,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          if (showHeader)
                            Padding(
                              padding: const EdgeInsets.fromLTRB(6, 14, 6, 6),
                              child: Text(
                                DateFormatter.dayHeader(tx.date),
                                style: const TextStyle(
                                  color: AppColors.textSecondary,
                                  fontSize: 13,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                          Container(
                            margin: const EdgeInsets.only(bottom: 8),
                            decoration: BoxDecoration(
                              color: AppColors.surface,
                              borderRadius: BorderRadius.circular(16),
                            ),
                            child: TransactionItem(
                              transaction: tx,
                              showTime: true,
                              onTap: () => context.push(AppRoutes.transactionDetail(tx.id)),
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  static Color _colorOf(TxType type) => switch (type) {
    TxType.income => AppColors.income,
    TxType.expense => AppColors.expense,
    TxType.transfer => AppColors.transfer,
  };

  void _openFilterSheet(BuildContext context) {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: AppColors.surface,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
      ),
      builder: (_) => const _FilterSheet(),
    );
  }
}

class _TypeChip extends StatelessWidget {
  const _TypeChip({
    required this.label,
    required this.selected,
    required this.onTap,
    this.color = AppColors.primary,
  });

  final String label;
  final bool selected;
  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(right: 8, top: 4, bottom: 6),
      child: GriviPressable(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          padding: const EdgeInsets.symmetric(horizontal: 14),
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: selected ? color : AppColors.surface,
            borderRadius: BorderRadius.circular(20),
          ),
          child: Text(
            label,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: selected ? GriviIconBadge.inkFor(color) : AppColors.textSecondary,
            ),
          ),
        ),
      ),
    );
  }
}

class _FilterSheet extends ConsumerWidget {
  const _FilterSheet();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final filter = ref.watch(transactionFilterProvider);
    final wallets = ref.watch(walletsProvider).valueOrNull ?? const <WalletModel>[];
    final categories = ref.watch(categoriesProvider).valueOrNull ?? const <CategoryModel>[];

    void update(TransactionFilter next) {
      ref.read(transactionFilterProvider.notifier).state = next;
    }

    // Kategori ikut tipe yang dipilih: dua "Lainnya" (pemasukan & pengeluaran)
    // nggak lagi muncul berdampingan tanpa bisa dibedakan, dan transfer
    // nggak punya kategori sama sekali.
    final categoryTypes = switch (filter.type) {
      null => TxType.categoryTypes,
      TxType.transfer => const <TxType>[],
      final type => [type],
    };

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Filter transaksi',
                style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 18),
              const _FilterLabel('Wallet'),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  _Chip(
                    label: 'Semua',
                    selected: filter.walletId == null,
                    onTap: () => update(filter.copyWith(clearWallet: true)),
                  ),
                  for (final wallet in wallets)
                    _Chip(
                      label: wallet.name,
                      selected: filter.walletId == wallet.id,
                      onTap: () => update(filter.copyWith(walletId: wallet.id)),
                    ),
                ],
              ),
              for (final type in categoryTypes) ...[
                const SizedBox(height: 18),
                _FilterLabel('Kategori ${type.label.toLowerCase()}'),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    if (type == categoryTypes.first)
                      _Chip(
                        label: 'Semua',
                        selected: filter.categoryId == null,
                        onTap: () => update(filter.copyWith(clearCategory: true)),
                      ),
                    for (final category in categories.where((c) => c.type == type))
                      _Chip(
                        label: category.name,
                        selected: filter.categoryId == category.id,
                        onTap: () => update(filter.copyWith(categoryId: category.id)),
                      ),
                  ],
                ),
              ],
              const SizedBox(height: 18),
              const _FilterLabel('Rentang tanggal'),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      icon: const Icon(Icons.date_range, size: 18),
                      label: Text(
                        filter.startDate == null
                            ? 'Semua tanggal'
                            : '${DateFormatter.short(filter.startDate!)} — '
                                  '${DateFormatter.short(filter.endDate ?? filter.startDate!)}',
                        overflow: TextOverflow.ellipsis,
                      ),
                      onPressed: () async {
                        final range = await showDateRangePicker(
                          context: context,
                          firstDate: DateTime(2020),
                          lastDate: DateTime(2100),
                        );
                        if (range != null) {
                          update(filter.copyWith(startDate: range.start, endDate: range.end));
                        }
                      },
                    ),
                  ),
                  if (filter.startDate != null)
                    IconButton(
                      icon: const Icon(Icons.close, size: 18),
                      onPressed: () => update(filter.copyWith(clearDates: true)),
                    ),
                ],
              ),
              const SizedBox(height: 22),
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: () => context.pop(),
                  style: FilledButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: AppColors.onPrimary,
                    minimumSize: const Size.fromHeight(48),
                  ),
                  child: const Text('Terapkan'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _FilterLabel extends StatelessWidget {
  const _FilterLabel(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: const TextStyle(
        color: AppColors.textSecondary,
        fontSize: 13,
        fontWeight: FontWeight.w500,
      ),
    );
  }
}

class _Chip extends StatelessWidget {
  const _Chip({required this.label, required this.selected, required this.onTap});

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return ChoiceChip(
      label: Text(label),
      selected: selected,
      onSelected: (_) => onTap(),
      showCheckmark: false,
      backgroundColor: AppColors.surfaceVariant,
      selectedColor: AppColors.primary,
      labelStyle: TextStyle(
        color: selected ? AppColors.onPrimary : AppColors.textSecondary,
        fontSize: 13,
        fontWeight: FontWeight.w500,
      ),
      side: BorderSide.none,
    );
  }
}
