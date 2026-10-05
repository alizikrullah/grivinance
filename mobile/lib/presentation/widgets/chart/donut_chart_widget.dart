import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';

import '../../../core/constants/app_icons.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/currency_formatter.dart';
import '../../../data/models/summary_model.dart';
import '../common/grivi_icon_badge.dart';
import '../common/grivi_motion.dart';

/// Donut rincian per kategori + legend di bawahnya. Ketuk potongan donut atau
/// baris legend buat menyorot satu kategori; tengah donut ikut menampilkannya.
class DonutChartWidget extends StatefulWidget {
  const DonutChartWidget({super.key, required this.items, required this.emptyMessage});

  final List<CategoryBreakdown> items;

  /// Wajib diisi pemanggil: teksnya ikut tipe yang lagi dipilih, bukan selalu
  /// bicara soal pengeluaran.
  final String emptyMessage;

  @override
  State<DonutChartWidget> createState() => _DonutChartWidgetState();
}

class _DonutChartWidgetState extends State<DonutChartWidget> {
  int? _selected;

  @override
  void didUpdateWidget(DonutChartWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Data ganti (periode/tipe lain) = sorotan lama nggak berarti lagi.
    if (oldWidget.items != widget.items) _selected = null;
  }

  void _toggle(int index) => setState(() => _selected = _selected == index ? null : index);

  @override
  Widget build(BuildContext context) {
    final items = widget.items;
    final total = items.fold<double>(0, (sum, item) => sum + item.total);

    if (items.isEmpty || total <= 0) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 40),
        child: Center(
          child: Text(widget.emptyMessage, style: const TextStyle(color: AppColors.textMuted)),
        ),
      );
    }

    final focus = _selected == null ? null : items[_selected!];

    return Column(
      children: [
        SizedBox(
          height: 220,
          child: Stack(
            alignment: Alignment.center,
            children: [
              PieChart(
                PieChartData(
                  sectionsSpace: 2,
                  centerSpaceRadius: 64,
                  pieTouchData: PieTouchData(
                    touchCallback: (event, response) {
                      final index = response?.touchedSection?.touchedSectionIndex;
                      if (event is FlTapUpEvent && index != null && index >= 0) _toggle(index);
                    },
                  ),
                  sections: [
                    for (var i = 0; i < items.length; i++)
                      PieChartSectionData(
                        value: items[i].total,
                        color: hexToColor(items[i].color).withValues(
                          alpha: _selected == null || _selected == i ? 1 : 0.3,
                        ),
                        radius: _selected == i ? 38 : 30,
                        showTitle: false,
                      ),
                  ],
                ),
                duration: const Duration(milliseconds: 250),
              ),
              Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    focus?.name ?? 'Total',
                    style: const TextStyle(color: AppColors.textMuted, fontSize: 12),
                  ),
                  const SizedBox(height: 2),
                  AnimatedMoney(
                    value: focus?.total ?? total,
                    style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w700),
                  ),
                  if (focus != null)
                    Text(
                      '${(focus.total / total * 100).toStringAsFixed(1)}%',
                      style: TextStyle(color: hexToColor(focus.color), fontSize: 12),
                    ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 18),
        for (var i = 0; i < items.length; i++)
          _LegendRow(
            item: items[i],
            percent: items[i].total / total * 100,
            dimmed: _selected != null && _selected != i,
            onTap: () => _toggle(i),
          ),
      ],
    );
  }
}

class _LegendRow extends StatelessWidget {
  const _LegendRow({
    required this.item,
    required this.percent,
    required this.dimmed,
    required this.onTap,
  });

  final CategoryBreakdown item;
  final double percent;
  final bool dimmed;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GriviPressable(
      onTap: onTap,
      child: AnimatedOpacity(
        opacity: dimmed ? 0.4 : 1,
        duration: const Duration(milliseconds: 200),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 6),
          child: Row(
            children: [
              GriviIconBadge(
                name: item.icon,
                color: hexToColor(item.color),
                size: 30,
                radius: 9,
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
                style: const TextStyle(color: AppColors.textMuted, fontSize: 12.5),
              ),
              const SizedBox(width: 12),
              Text(
                CurrencyFormatter.format(item.total),
                style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13.5),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
