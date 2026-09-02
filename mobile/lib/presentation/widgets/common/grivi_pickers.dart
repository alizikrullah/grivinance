import 'package:flutter/material.dart';

import '../../../core/constants/app_icons.dart';
import '../../../core/theme/app_theme.dart';
import 'grivi_icon_badge.dart';

/// Satu kelompok pilihan dalam picker, misal "Bank" atau "E-Wallet".
class IconGroup {
  const IconGroup(this.label, this.names);

  final String label;
  final List<String> names;
}

/// Dipakai form wallet dan form kategori, isinya beda lewat [groups].
class IconPickerField extends StatelessWidget {
  const IconPickerField({
    super.key,
    required this.selected,
    required this.onChanged,
    required this.color,
    required this.groups,
  });

  final String selected;
  final ValueChanged<String> onChanged;
  final Color color;
  final List<IconGroup> groups;

  @override
  Widget build(BuildContext context) {
    final showLabels = groups.length > 1;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const _PickerLabel('Icon'),
        const SizedBox(height: 10),
        Container(
          height: 226,
          width: double.infinity,
          decoration: BoxDecoration(
            color: AppColors.surfaceVariant,
            borderRadius: BorderRadius.circular(14),
          ),
          padding: const EdgeInsets.all(12),
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                for (final group in groups) ...[
                  if (showLabels) ...[
                    Text(
                      group.label,
                      style: const TextStyle(
                        color: AppColors.textMuted,
                        fontSize: 11.5,
                        fontWeight: FontWeight.w600,
                        letterSpacing: 0.3,
                      ),
                    ),
                    const SizedBox(height: 8),
                  ],
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: group.names
                        .map(
                          (name) => _Tile(
                            name: name,
                            color: color,
                            selected: name == selected,
                            onTap: () => onChanged(name),
                          ),
                        )
                        .toList(),
                  ),
                  if (group != groups.last) const SizedBox(height: 16),
                ],
              ],
            ),
          ),
        ),
      ],
    );
  }
}

/// Tiap pilihan dirender persis seperti nanti tampil di kartu, jadi user lihat
/// hasil jadinya sebelum menyimpan. Yang terpilih ditandai cincin, bukan
/// diredupkan — meredupkan bikin logo kelihatan rusak.
class _Tile extends StatelessWidget {
  const _Tile({
    required this.name,
    required this.color,
    required this.selected,
    required this.onTap,
  });

  final String name;
  final Color color;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(13),
      child: Container(
        padding: const EdgeInsets.all(3),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(13),
          border: Border.all(
            color: selected ? AppColors.textPrimary : Colors.transparent,
            width: 2,
          ),
        ),
        child: GriviIconBadge(name: name, color: color, size: 36, radius: 10),
      ),
    );
  }
}

class ColorPickerField extends StatelessWidget {
  const ColorPickerField({super.key, required this.selected, required this.onChanged});

  final String selected;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const _PickerLabel('Warna'),
        const SizedBox(height: 10),
        Wrap(
          spacing: 10,
          runSpacing: 10,
          children: pickableColors.map((hex) {
            final isSelected = hex == selected;
            return InkWell(
              onTap: () => onChanged(hex),
              borderRadius: BorderRadius.circular(20),
              child: Container(
                height: 38,
                width: 38,
                decoration: BoxDecoration(
                  color: hexToColor(hex),
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: isSelected ? AppColors.textPrimary : Colors.transparent,
                    width: 2.5,
                  ),
                ),
                child: isSelected
                    ? Icon(
                        Icons.check,
                        size: 18,
                        color: GriviIconBadge.inkFor(hexToColor(hex)),
                      )
                    : null,
              ),
            );
          }).toList(),
        ),
      ],
    );
  }
}

class _PickerLabel extends StatelessWidget {
  const _PickerLabel(this.text);

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
