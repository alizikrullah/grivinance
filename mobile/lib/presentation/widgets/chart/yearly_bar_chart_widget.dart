import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/utils/date_formatter.dart';
import '../../../data/models/summary_model.dart';

/// Dua batang per bulan: hijau pemasukan, merah pengeluaran.
class YearlyBarChartWidget extends StatelessWidget {
  const YearlyBarChartWidget({super.key, required this.months});

  final List<MonthBucket> months;

  @override
  Widget build(BuildContext context) {
    final maxValue = months.fold<double>(
      0,
      (max, m) => [max, m.income, m.expense].reduce((a, b) => a > b ? a : b),
    );

    if (maxValue <= 0) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 40),
        child: Center(
          child: Text(
            'Belum ada transaksi di tahun ini',
            style: TextStyle(color: AppColors.textMuted),
          ),
        ),
      );
    }

    // Sedikit ruang di atas batang tertinggi supaya nggak mentok.
    final maxY = maxValue * 1.15;

    return Column(
      children: [
        SizedBox(
          height: 260,
          child: BarChart(
            BarChartData(
              maxY: maxY,
              alignment: BarChartAlignment.spaceAround,
              barTouchData: BarTouchData(
                touchTooltipData: BarTouchTooltipData(
                  getTooltipColor: (_) => AppColors.surfaceVariant,
                  getTooltipItem: (group, _, rod, _) => BarTooltipItem(
                    '${DateFormatter.monthNames[group.x]}\n'
                    '${_compact(rod.toY)}',
                    const TextStyle(color: AppColors.textPrimary, fontSize: 12),
                  ),
                ),
              ),
              gridData: FlGridData(
                show: true,
                drawVerticalLine: false,
                getDrawingHorizontalLine: (_) =>
                    const FlLine(color: AppColors.surfaceVariant, strokeWidth: 1),
              ),
              borderData: FlBorderData(show: false),
              titlesData: FlTitlesData(
                topTitles: const AxisTitles(),
                rightTitles: const AxisTitles(),
                leftTitles: AxisTitles(
                  sideTitles: SideTitles(
                    showTitles: true,
                    reservedSize: 46,
                    getTitlesWidget: (value, _) => Text(
                      _compact(value),
                      style: const TextStyle(color: AppColors.textMuted, fontSize: 10),
                    ),
                  ),
                ),
                bottomTitles: AxisTitles(
                  sideTitles: SideTitles(
                    showTitles: true,
                    reservedSize: 26,
                    getTitlesWidget: (value, _) {
                      final index = value.toInt();
                      if (index < 0 || index > 11) return const SizedBox.shrink();
                      return Padding(
                        padding: const EdgeInsets.only(top: 6),
                        child: Text(
                          DateFormatter.monthNames[index],
                          style: const TextStyle(
                            color: AppColors.textMuted,
                            fontSize: 10,
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ),
              barGroups: months.map((month) {
                return BarChartGroupData(
                  x: month.month - 1,
                  barsSpace: 3,
                  barRods: [
                    BarChartRodData(
                      toY: month.income,
                      color: AppColors.income,
                      width: 7,
                      borderRadius: const BorderRadius.vertical(top: Radius.circular(3)),
                    ),
                    BarChartRodData(
                      toY: month.expense,
                      color: AppColors.expense,
                      width: 7,
                      borderRadius: const BorderRadius.vertical(top: Radius.circular(3)),
                    ),
                  ],
                );
              }).toList(),
            ),
          ),
        ),
        const SizedBox(height: 14),
        const Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            _LegendDot(color: AppColors.income, label: 'Pemasukan'),
            SizedBox(width: 20),
            _LegendDot(color: AppColors.expense, label: 'Pengeluaran'),
          ],
        ),
      ],
    );
  }

  /// Sumbu Y pakai singkatan, kalau nggak angkanya kepanjangan dan kepotong.
  static String _compact(double value) {
    if (value >= 1000000000) return '${(value / 1000000000).toStringAsFixed(1)}M';
    if (value >= 1000000) return '${(value / 1000000).toStringAsFixed(1)}jt';
    if (value >= 1000) return '${(value / 1000).toStringAsFixed(0)}rb';
    return value.toStringAsFixed(0);
  }
}

class _LegendDot extends StatelessWidget {
  const _LegendDot({required this.color, required this.label});

  final Color color;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          height: 10,
          width: 10,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 6),
        Text(
          label,
          style: const TextStyle(color: AppColors.textSecondary, fontSize: 12.5),
        ),
      ],
    );
  }
}
