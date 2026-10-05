import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/constants/app_icons.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/currency_formatter.dart';
import '../../../core/utils/date_formatter.dart';
import '../../../data/models/budget_model.dart';
import '../../../data/models/category_model.dart';
import '../../../providers/budget_provider.dart';
import '../../../providers/category_provider.dart';
import '../../widgets/budget/progress_tile.dart';
import '../../widgets/common/grivi_async_view.dart';
import '../../widgets/common/grivi_button.dart';
import '../../widgets/common/grivi_card.dart';
import '../../widgets/common/grivi_error_banner.dart';
import '../../widgets/common/grivi_icon_badge.dart';
import '../../widgets/common/grivi_motion.dart';
import '../../widgets/common/grivi_month_picker.dart';
import '../../widgets/common/grivi_text_field.dart';

class BudgetScreen extends ConsumerWidget {
  const BudgetScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final month = ref.watch(budgetScreenMonthProvider);
    final budgets = ref.watch(budgetsProvider(month));

    void shift(int delta) {
      final next = DateTime(month.year, month.month + delta);
      ref.read(budgetScreenMonthProvider.notifier).state = (year: next.year, month: next.month);
    }

    void openEditor([BudgetItem? item]) => _openEditor(context, item, budgets.valueOrNull);

    return Scaffold(
      appBar: AppBar(title: const Text('Budget')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: openEditor,
        backgroundColor: AppColors.primary,
        foregroundColor: AppColors.onPrimary,
        icon: const Icon(Icons.add),
        label: const Text('Atur budget'),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 96),
        children: [
          Container(
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Row(
              children: [
                IconButton(icon: const Icon(Icons.chevron_left), onPressed: () => shift(-1)),
                Expanded(
                  child: GriviPressable(
                    onTap: () async {
                      final picked = await showGriviMonthPicker(
                        context,
                        initial: DateTime(month.year, month.month),
                      );
                      if (picked != null) {
                        ref.read(budgetScreenMonthProvider.notifier).state = (
                          year: picked.year,
                          month: picked.month,
                        );
                      }
                    },
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      child: Text(
                        DateFormatter.monthYear(DateTime(month.year, month.month)),
                        textAlign: TextAlign.center,
                        style: const TextStyle(fontWeight: FontWeight.w600),
                      ),
                    ),
                  ),
                ),
                IconButton(icon: const Icon(Icons.chevron_right), onPressed: () => shift(1)),
              ],
            ),
          ),
          const SizedBox(height: 16),
          GriviAsyncView<BudgetSummary>(
            value: budgets,
            onRetry: () => ref.invalidate(budgetsProvider(month)),
            isEmpty: (data) => data.isEmpty,
            emptyIcon: Icons.pie_chart_outline,
            emptyTitle: 'Belum ada budget',
            emptyMessage:
                'Atur batas pengeluaran per kategori. Sekali atur, berlaku tiap bulan '
                'sampai kamu ubah.',
            emptyAction: SizedBox(
              width: 200,
              child: GriviButton(label: 'Atur budget', icon: Icons.add, onPressed: openEditor),
            ),
            builder: (data) => Column(
              children: [
                GriviFadeIn(child: _SummaryCard(summary: data)),
                const SizedBox(height: 16),
                GriviFadeIn(
                  index: 1,
                  child: GriviCard(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                    child: Column(
                      children: [
                        for (final item in data.items)
                          ProgressTile.budget(item, onTap: () => openEditor(item)),
                      ],
                    ),
                  ),
                ),
                const Padding(
                  padding: EdgeInsets.only(top: 12),
                  child: Text(
                    'Budget berlaku tiap bulan; yang dihitung ulang tiap bulan cuma terpakainya.',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: AppColors.textMuted, fontSize: 12),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _openEditor(BuildContext context, BudgetItem? item, BudgetSummary? current) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
      ),
      builder: (sheet) => Padding(
        padding: EdgeInsets.only(bottom: MediaQuery.of(sheet).viewInsets.bottom),
        child: _BudgetEditor(
          item: item,
          taken: {for (final b in current?.items ?? const <BudgetItem>[]) b.categoryId},
        ),
      ),
    );
  }
}

class _SummaryCard extends StatelessWidget {
  const _SummaryCard({required this.summary});

  final BudgetSummary summary;

  @override
  Widget build(BuildContext context) {
    final ratio = summary.totalBudget == 0 ? 0.0 : summary.totalSpent / summary.totalBudget;
    final color = switch (summary.status) {
      BudgetStatus.safe => AppColors.primary,
      BudgetStatus.tight => AppColors.warning,
      BudgetStatus.over => AppColors.expense,
    };

    return GriviCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Expanded(
                child: Text('Sisa budget', style: TextStyle(color: AppColors.textMuted)),
              ),
              GriviChip(label: summary.status.label, color: color),
            ],
          ),
          const SizedBox(height: 4),
          AnimatedMoney(
            value: summary.remaining,
            style: TextStyle(fontSize: 28, fontWeight: FontWeight.w800, color: color),
          ),
          const SizedBox(height: 12),
          GriviProgressBar(value: ratio, color: color, height: 10),
          const SizedBox(height: 8),
          Text(
            'Terpakai ${CurrencyFormatter.format(summary.totalSpent)} '
            'dari ${CurrencyFormatter.format(summary.totalBudget)}',
            style: const TextStyle(color: AppColors.textSecondary, fontSize: 12.5),
          ),
        ],
      ),
    );
  }
}

/// Tambah budget (pilih kategori + nominal) atau ubah/hapus yang sudah ada.
class _BudgetEditor extends ConsumerStatefulWidget {
  const _BudgetEditor({required this.item, required this.taken});

  /// null = tambah baru.
  final BudgetItem? item;

  /// Kategori yang sudah punya budget — nggak ditawarkan lagi waktu tambah.
  final Set<String> taken;

  @override
  ConsumerState<_BudgetEditor> createState() => _BudgetEditorState();
}

class _BudgetEditorState extends ConsumerState<_BudgetEditor> {
  final _formKey = GlobalKey<FormState>();
  late final _amountController = TextEditingController(
    text: CurrencyFormatter.formatInput(widget.item?.amount ?? 0),
  );
  late String? _categoryId = widget.item?.categoryId;
  bool _loading = false;
  String? _error;

  bool get _isEdit => widget.item != null;

  @override
  void dispose() {
    _amountController.dispose();
    super.dispose();
  }

  Future<void> _run(Future<void> Function() action) async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      await action();
      if (mounted) Navigator.of(context).pop();
    } catch (e) {
      if (mounted) setState(() => _error = '$e');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _save() {
    if (!_formKey.currentState!.validate()) return;
    if (_categoryId == null) {
      setState(() => _error = 'Pilih kategorinya dulu');
      return;
    }
    _run(
      () => ref
          .read(budgetActionsProvider)
          .set(_categoryId!, CurrencyFormatter.parseInput(_amountController.text)),
    );
  }

  @override
  Widget build(BuildContext context) {
    final options = ref
        .watch(categoriesByTypeProvider(TxType.expense))
        .where((c) => !widget.taken.contains(c.id))
        .toList();

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 18, 20, 20),
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                _isEdit ? 'Budget ${widget.item!.name}' : 'Budget baru',
                style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 16),
              if (!_isEdit) ...[
                const Text(
                  'Kategori pengeluaran',
                  style: TextStyle(color: AppColors.textSecondary, fontSize: 13),
                ),
                const SizedBox(height: 8),
                ConstrainedBox(
                  constraints: const BoxConstraints(maxHeight: 180),
                  child: SingleChildScrollView(
                    child: Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        if (options.isEmpty)
                          const Text(
                            'Semua kategori pengeluaran sudah punya budget.',
                            style: TextStyle(color: AppColors.textMuted),
                          ),
                        for (final category in options)
                          GriviPressable(
                            onTap: () => setState(() => _categoryId = category.id),
                            child: AnimatedContainer(
                              duration: const Duration(milliseconds: 160),
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                              decoration: BoxDecoration(
                                color: AppColors.surfaceVariant,
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(
                                  color: _categoryId == category.id
                                      ? hexToColor(category.color)
                                      : Colors.transparent,
                                  width: 1.5,
                                ),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  GriviIconBadge(
                                    name: category.icon,
                                    color: hexToColor(category.color),
                                    size: 22,
                                    radius: 7,
                                  ),
                                  const SizedBox(width: 8),
                                  Text(category.name, style: const TextStyle(fontSize: 13)),
                                ],
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 16),
              ],
              GriviTextField(
                controller: _amountController,
                label: 'Budget per bulan',
                hint: '0',
                icon: Icons.payments_outlined,
                keyboardType: TextInputType.number,
                inputFormatters: [RupiahInputFormatter()],
                validator: (value) => CurrencyFormatter.parseInput(value ?? '') <= 0
                    ? 'Budget harus lebih dari 0'
                    : null,
              ),
              if (_error != null) ...[const SizedBox(height: 12), GriviErrorBanner(message: _error!)],
              const SizedBox(height: 18),
              GriviButton(label: 'Simpan', loading: _loading, onPressed: _save),
              if (_isEdit)
                TextButton(
                  onPressed: _loading
                      ? null
                      : () => _run(
                          () => ref.read(budgetActionsProvider).delete(widget.item!.categoryId),
                        ),
                  style: TextButton.styleFrom(foregroundColor: AppColors.expense),
                  child: const Text('Hapus budget ini'),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
