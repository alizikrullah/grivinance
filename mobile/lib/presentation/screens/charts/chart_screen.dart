import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/utils/currency_formatter.dart';
import '../../../core/utils/date_formatter.dart';
import '../../../data/models/category_model.dart';
import '../../../data/models/summary_model.dart';
import '../../../providers/summary_provider.dart';
import '../../widgets/chart/donut_chart_widget.dart';
import '../../widgets/chart/yearly_bar_chart_widget.dart';
import '../../widgets/common/grivi_async_view.dart';

class ChartScreen extends StatelessWidget {
  const ChartScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 3,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Grafik'),
          bottom: const TabBar(
            indicatorColor: AppColors.primary,
            labelColor: AppColors.primary,
            unselectedLabelColor: AppColors.textMuted,
            tabs: [
              Tab(text: 'Harian'),
              Tab(text: 'Bulanan'),
              Tab(text: 'Tahunan'),
            ],
          ),
        ),
        body: const TabBarView(children: [_DailyTab(), _MonthlyTab(), _YearlyTab()]),
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
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 96),
      children: [
        _PeriodPicker(
          label: DateFormatter.full(date),
          onTap: () async {
            final picked = await showDatePicker(
              context: context,
              initialDate: date,
              firstDate: DateTime(2020),
              lastDate: DateTime(2100),
            );
            if (picked != null) {
              ref.read(selectedDateProvider.notifier).state = picked;
            }
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

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 96),
      children: [
        _PeriodPicker(
          label: DateFormatter.monthYear(month),
          onTap: () async {
            final picked = await showDatePicker(
              context: context,
              initialDate: month,
              firstDate: DateTime(2020),
              lastDate: DateTime(2100),
              initialDatePickerMode: DatePickerMode.year,
              helpText: 'Pilih bulan',
            );
            if (picked != null) {
              ref.read(selectedMonthProvider.notifier).state = picked;
            }
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
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 96),
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            IconButton(
              icon: const Icon(Icons.chevron_left),
              onPressed: () => ref.read(selectedYearProvider.notifier).state = year - 1,
            ),
            SizedBox(
              width: 90,
              child: Text(
                '$year',
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w700),
              ),
            ),
            IconButton(
              icon: const Icon(Icons.chevron_right),
              onPressed: () => ref.read(selectedYearProvider.notifier).state = year + 1,
            ),
          ],
        ),
        const SizedBox(height: 8),
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

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: selected ? color : Colors.transparent, width: 1.5),
        ),
        child: Opacity(
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
              Text(
                CurrencyFormatter.format(amount),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700, color: color),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _PeriodPicker extends StatelessWidget {
  const _PeriodPicker({required this.label, required this.onTap});

  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: AppColors.surfaceVariant,
          borderRadius: BorderRadius.circular(14),
        ),
        child: Row(
          children: [
            const Icon(Icons.event, size: 19, color: AppColors.textMuted),
            const SizedBox(width: 12),
            Expanded(
              child: Text(label, style: const TextStyle(fontWeight: FontWeight.w500)),
            ),
            const Icon(Icons.expand_more, color: AppColors.textMuted),
          ],
        ),
      ),
    );
  }
}
