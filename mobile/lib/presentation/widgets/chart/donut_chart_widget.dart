import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';

import '../../../core/constants/app_icons.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/currency_formatter.dart';
import '../../../data/models/summary_model.dart';

/// Donut pengeluaran per kategori + legend di bawahnya.
class DonutChartWidget extends StatelessWidget {
  const DonutChartWidget({super.key, required this.items});

  final List<CategoryBreakdown> items;

  @override
  Widget build(BuildContext context) {
    final total = items.fold<double>(0, (sum, item) => sum + item.total);

    if (items.isEmpty || total <= 0) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 40),
        child: Center(
          child: Text(
            'Belum ada pengeluaran di periode ini',
            style: TextStyle(color: AppColors.textMuted),
          ),
        ),
      );
    }

    return Column(
      children: [
        SizedBox(
          height: 210,
          child: Stack(
            alignment: Alignment.center,
            children: [
              PieChart(
                PieChartData(
                  sectionsSpace: 2,
                  centerSpaceRadius: 62,
                  sections: items.map((item) {
                    return PieChartSectionData(
                      value: item.total,
                      color: hexToColor(item.color),
                      radius: 30,
                      showTitle: false,
                    );
                  }).toList(),
                ),
              ),
              Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text(
                    'Total',
                    style: TextStyle(color: AppColors.textMuted, fontSize: 12),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    CurrencyFormatter.format(total),
                    style: const TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 18),
        ...items.map((item) {
          final percent = total == 0 ? 0.0 : item.total / total * 100;
          return Padding(
            padding: const EdgeInsets.symmetric(vertical: 6),
            child: Row(
              children: [
                Container(
                  height: 30,
                  width: 30,
                  decoration: BoxDecoration(
                    color: hexToColor(item.color).withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(9),
                  ),
                  child: Icon(
                    AppIcons.resolve(item.icon),
                    size: 15,
                    color: hexToColor(item.color),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    item.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontSize: 14),
                  ),
                ),
                Text(
                  '${percent.toStringAsFixed(1)}%',
                  style: const TextStyle(
                    color: AppColors.textMuted,
                    fontSize: 12.5,
                  ),
                ),
                const SizedBox(width: 12),
                Text(
                  CurrencyFormatter.format(item.total),
                  style: const TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 13.5,
                  ),
                ),
              ],
            ),
          );
        }),
      ],
    );
  }
}
