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

  @override
  Widget build(BuildContext context) {
    final transactions = ref.watch(transactionsProvider);
    final filter = ref.watch(transactionFilterProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Transaksi'),
        actions: [
          IconButton(
            tooltip: 'Filter',
            icon: Badge(
              isLabelVisible: !filter.isEmpty,
              backgroundColor: AppColors.primary,
              child: const Icon(Icons.filter_list),
            ),
            onPressed: () => _openFilterSheet(context),
          ),
        ],
      ),
      body: Column(
        children: [
          if (!filter.isEmpty)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 0),
              child: Row(
                children: [
                  const Icon(Icons.filter_alt, size: 16, color: AppColors.primary),
                  const SizedBox(width: 6),
                  const Expanded(
                    child: Text(
                      'Filter aktif',
                      style: TextStyle(color: AppColors.primary, fontSize: 13),
                    ),
                  ),
                  TextButton(
                    onPressed: () => ref.read(transactionFilterProvider.notifier).state =
                        const TransactionFilter(),
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
                  ? 'Catat pemasukan atau pengeluaran pertama kamu'
                  : 'Tidak ada yang cocok dengan filter ini',
              builder: (data) => RefreshIndicator(
                color: AppColors.primary,
                backgroundColor: AppColors.surface,
                onRefresh: () => ref.read(transactionsProvider.notifier).refresh(),
                child: ListView.builder(
                  controller: _scrollController,
                  padding: const EdgeInsets.fromLTRB(12, 8, 12, 96),
                  itemCount: data.length + 1,
                  itemBuilder: (context, index) {
                    if (index == data.length) {
                      return ref.read(transactionsProvider.notifier).hasMore
                          ? const Padding(
                              padding: EdgeInsets.symmetric(vertical: 20),
                              child: Center(
                                child: CircularProgressIndicator(
                                  color: AppColors.primary,
                                ),
                              ),
                            )
                          : const SizedBox(height: 8);
                    }

                    final tx = data[index];
                    final showHeader =
                        index == 0 || !_sameDay(data[index - 1].date, tx.date);

                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (showHeader)
                          Padding(
                            padding: const EdgeInsets.fromLTRB(6, 14, 6, 4),
                            child: Text(
                              DateFormatter.full(tx.date),
                              style: const TextStyle(
                                color: AppColors.textMuted,
                                fontSize: 12.5,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        Container(
                          decoration: BoxDecoration(
                            color: AppColors.surface,
                            borderRadius: BorderRadius.circular(14),
                          ),
                          margin: const EdgeInsets.only(bottom: 8),
                          child: TransactionItem(
                            transaction: tx,
                            onTap: () => context.push(AppRoutes.transactionDetail(tx.id)),
                          ),
                        ),
                      ],
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

  static bool _sameDay(DateTime a, DateTime b) {
    final x = a.toLocal();
    final y = b.toLocal();
    return x.year == y.year && x.month == y.month && x.day == y.day;
  }

  void _openFilterSheet(BuildContext context) {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: AppColors.surface,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => const _FilterSheet(),
    );
  }
}

class _FilterSheet extends ConsumerWidget {
  const _FilterSheet();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final filter = ref.watch(transactionFilterProvider);
    final wallets = ref.watch(walletsProvider).value ?? const <WalletModel>[];
    final categories = ref.watch(categoriesProvider).value ?? const <CategoryModel>[];

    void update(TransactionFilter next) {
      ref.read(transactionFilterProvider.notifier).state = next;
    }

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Filter transaksi',
              style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 18),
            const _FilterLabel('Tipe'),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              children: [
                _Chip(
                  label: 'Semua',
                  selected: filter.type == null,
                  onTap: () => update(filter.copyWith(clearType: true)),
                ),
                for (final type in TxType.values)
                  _Chip(
                    label: type.label,
                    selected: filter.type == type,
                    onTap: () => update(filter.copyWith(type: type)),
                  ),
              ],
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
            const SizedBox(height: 18),
            const _FilterLabel('Kategori'),
            const SizedBox(height: 8),
            SizedBox(
              height: 132,
              child: SingleChildScrollView(
                child: Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    _Chip(
                      label: 'Semua',
                      selected: filter.categoryId == null,
                      onTap: () => update(filter.copyWith(clearCategory: true)),
                    ),
                    for (final category in categories)
                      _Chip(
                        label: category.name,
                        selected: filter.categoryId == category.id,
                        onTap: () => update(filter.copyWith(categoryId: category.id)),
                      ),
                  ],
                ),
              ),
            ),
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
                        builder: (context, child) =>
                            Theme(data: Theme.of(context), child: child!),
                      );
                      if (range != null) {
                        update(
                          filter.copyWith(startDate: range.start, endDate: range.end),
                        );
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
                  foregroundColor: const Color(0xFF04231A),
                  minimumSize: const Size.fromHeight(48),
                ),
                child: const Text('Terapkan'),
              ),
            ),
          ],
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
        color: selected ? const Color(0xFF04231A) : AppColors.textSecondary,
        fontSize: 13,
        fontWeight: FontWeight.w500,
      ),
      side: BorderSide.none,
    );
  }
}
