import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/utils/date_formatter.dart';
import '../../../data/models/category_model.dart';
import '../../../data/models/summary_model.dart';
import '../../../providers/summary_provider.dart';
import '../../widgets/chart/donut_chart_widget.dart';
import '../../widgets/chart/yearly_bar_chart_widget.dart';
import '../../widgets/common/grivi_async_view.dart';
import '../../widgets/common/grivi_motion.dart';
import '../../widgets/common/grivi_month_picker.dart';

/// Tab-nya dikendalikan [chartTabProvider], supaya kartu Pemasukan/Pengeluaran
/// di Beranda bisa langsung membuka tab Bulanan.
class ChartScreen extends ConsumerStatefulWidget {
  const ChartScreen({super.key});

  @override
  ConsumerState<ChartScreen> createState() => _ChartScreenState();
}

class _ChartScreenState extends ConsumerState<ChartScreen> with SingleTickerProviderStateMixin {
  late final TabController _tabs = TabController(
    length: 3,
    vsync: this,
    initialIndex: ref.read(chartTabProvider),
  )..addListener(() => ref.read(chartTabProvider.notifier).state = _tabs.index);

  @override
  void dispose() {
    _tabs.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    ref.listen<int>(chartTabProvider, (_, next) {
      if (_tabs.index != next) _tabs.animateTo(next);
    });

    return Scaffold(
      appBar: AppBar(
        title: const Text('Grafik'),
        bottom: TabBar(
          controller: _tabs,
          indicatorColor: AppColors.primary,
          labelColor: AppColors.primary,
          unselectedLabelColor: AppColors.textMuted,
          tabs: const [
            Tab(text: 'Harian'),
            Tab(text: 'Bulanan'),
            Tab(text: 'Tahunan'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabs,
        children: const [_DailyTab(), _MonthlyTab(), _YearlyTab()],
      ),
    );
  }
}

class _DailyTab extends ConsumerWidget {
  const _DailyTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final date = ref.watch(selectedDateProvider);
    final summary = ref.watch(dailySummaryProvider);

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 28),
      children: [
        _PeriodPicker(
          label: DateFormatter.full(date),
          onPrevious: () => ref.read(selectedDateProvider.notifier).state = date.subtract(
            const Duration(days: 1),
          ),
          onNext: () =>
              ref.read(selectedDateProvider.notifier).state = date.add(const Duration(days: 1)),
          onTap: () async {
            final picked = await showDatePicker(
              context: context,
              initialDate: date,
              firstDate: DateTime(2020),
              lastDate: DateTime(2100),
            );
            if (picked != null) ref.read(selectedDateProvider.notifier).state = picked;
          },
        ),
        const SizedBox(height: 16),
        GriviAsyncView<PeriodSummary>(
          value: summary,
          onRetry: () => ref.invalidate(dailySummaryProvider),
          builder: (data) => _SummaryBody(summary: data),
        ),
      ],
    );
  }
}

class _MonthlyTab extends ConsumerWidget {
  const _MonthlyTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final month = ref.watch(selectedMonthProvider);
    final summary = ref.watch(monthlySummaryProvider);

    void shift(int delta) => ref.read(selectedMonthProvider.notifier).state = DateTime(
      month.year,
      month.month + delta,
    );

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 28),
      children: [
        _PeriodPicker(
          label: DateFormatter.monthYear(month),
          onPrevious: () => shift(-1),
          onNext: () => shift(1),
          onTap: () async {
            final picked = await showGriviMonthPicker(context, initial: month);
            if (picked != null) ref.read(selectedMonthProvider.notifier).state = picked;
          },
        ),
        const SizedBox(height: 16),
        GriviAsyncView<PeriodSummary>(
          value: summary,
          onRetry: () => ref.invalidate(monthlySummaryProvider),
          builder: (data) => _SummaryBody(summary: data),
        ),
      ],
    );
  }
}

class _YearlyTab extends ConsumerWidget {
  const _YearlyTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final year = ref.watch(selectedYearProvider);
    final summary = ref.watch(yearlySummaryProvider);

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 28),
      children: [
        _PeriodPicker(
          label: '$year',
          onPrevious: () => ref.read(selectedYearProvider.notifier).state = year - 1,
          onNext: () => ref.read(selectedYearProvider.notifier).state = year + 1,
        ),
        const SizedBox(height: 16),
        GriviAsyncView<YearlySummary>(
          value: summary,
          onRetry: () => ref.invalidate(yearlySummaryProvider),
          builder: (data) => Column(
            children: [
              _TotalsRow(
                income: data.totalIncome,
                expense: data.totalExpense,
                selectable: false,
              ),
              const SizedBox(height: 22),
              YearlyBarChartWidget(months: data.months),
            ],
          ),
        ),
      ],
    );
  }
}

class _SummaryBody extends ConsumerWidget {
  const _SummaryBody({required this.summary});

  final PeriodSummary summary;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final type = ref.watch(summaryTypeProvider);
    final isExpense = type == TxType.expense;

    return Column(
      children: [
        _TotalsRow(income: summary.totalIncome, expense: summary.totalExpense),
        const SizedBox(height: 22),
        Align(
          alignment: Alignment.centerLeft,
          child: Text(
            '${type.label} per kategori',
            style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
          ),
        ),
        const SizedBox(height: 10),
        DonutChartWidget(
          items: isExpense ? summary.expenses : summary.incomes,
          emptyMessage: 'Belum ada ${type.label.toLowerCase()} di periode ini',
        ),
      ],
    );
  }
}

/// Dua kartu ini merangkap tombol pilih tipe untuk donut di bawahnya.
/// Di tab Tahunan tidak ada donut, jadi [selectable] dimatikan supaya kartunya
/// tidak terlihat bisa diklik padahal tidak melakukan apa-apa.
class _TotalsRow extends ConsumerWidget {
  const _TotalsRow({required this.income, required this.expense, this.selectable = true});

  final double income;
  final double expense;
  final bool selectable;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final active = ref.watch(summaryTypeProvider);

    void select(TxType type) => ref.read(summaryTypeProvider.notifier).state = type;

    return Row(
      children: [
        Expanded(
          child: _TotalCard(
            label: 'Pemasukan',
            amount: income,
            color: AppColors.income,
            icon: Icons.south_west,
            selected: selectable && active == TxType.income,
            onTap: selectable ? () => select(TxType.income) : null,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _TotalCard(
            label: 'Pengeluaran',
            amount: expense,
            color: AppColors.expense,
            icon: Icons.north_east,
            selected: selectable && active == TxType.expense,
            onTap: selectable ? () => select(TxType.expense) : null,
          ),
        ),
      ],
    );
  }
}

class _TotalCard extends StatelessWidget {
  const _TotalCard({
    required this.label,
    required this.amount,
    required this.color,
    required this.icon,
    this.selected = false,
    this.onTap,
  });

  final String label;
  final double amount;
  final Color color;
  final IconData icon;
  final bool selected;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    // Yang tidak terpilih diredupkan supaya jelas mana yang lagi ditampilkan
    // donut. Tanpa beda tampilan, kartunya tidak terbaca sebagai tombol.
    final dim = onTap != null && !selected;

    return GriviPressable(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: selected ? color : Colors.transparent, width: 1.5),
        ),
        child: AnimatedOpacity(
          duration: const Duration(milliseconds: 180),
          opacity: dim ? 0.5 : 1,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(icon, size: 15, color: color),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      label,
                      style: const TextStyle(color: AppColors.textMuted, fontSize: 12.5),
                    ),
                  ),
                  if (selected) Icon(Icons.pie_chart, size: 13, color: color),
                ],
              ),
              const SizedBox(height: 8),
              AnimatedMoney(
                value: amount,
                style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700, color: color),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Label periode dengan panah mundur/maju; ketuk labelnya buat memilih langsung.
class _PeriodPicker extends StatelessWidget {
  const _PeriodPicker({
    required this.label,
    required this.onPrevious,
    required this.onNext,
    this.onTap,
  });

  final String label;
  final VoidCallback onPrevious;
  final VoidCallback onNext;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          IconButton(icon: const Icon(Icons.chevron_left), onPressed: onPrevious),
          Expanded(
            child: GriviPressable(
              onTap: onTap,
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 12),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    if (onTap != null) ...[
                      const Icon(Icons.event, size: 17, color: AppColors.textMuted),
                      const SizedBox(width: 8),
                    ],
                    Text(label, style: const TextStyle(fontWeight: FontWeight.w600)),
                  ],
                ),
              ),
            ),
          ),
          IconButton(icon: const Icon(Icons.chevron_right), onPressed: onNext),
        ],
      ),
    );
  }
}
