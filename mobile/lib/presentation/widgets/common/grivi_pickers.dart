import 'package:flutter/material.dart';

import '../../../core/constants/app_icons.dart';
import '../../../core/theme/app_theme.dart';
import 'grivi_icon_badge.dart';

/// Dipakai bareng form wallet dan form kategori.
class IconPickerField extends StatelessWidget {
  const IconPickerField({
    super.key,
    required this.selected,
    required this.onChanged,
    required this.color,
    required this.icons,
  });

  final String selected;
  final ValueChanged<String> onChanged;
  final Color color;

  /// Daftar icon yang boleh dipilih — beda antara wallet dan kategori.
  final List<String> icons;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const _PickerLabel('Icon'),
        const SizedBox(height: 10),
        SizedBox(
          height: 168,
          child: Container(
            decoration: BoxDecoration(
              color: AppColors.surfaceVariant,
              borderRadius: BorderRadius.circular(14),
            ),
            padding: const EdgeInsets.all(10),
            child: GridView.builder(
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 6,
                mainAxisSpacing: 8,
                crossAxisSpacing: 8,
              ),
              itemCount: icons.length,
              itemBuilder: (context, index) {
                final name = icons[index];
                final isSelected = name == selected;
                return InkWell(
                  onTap: () => onChanged(name),
                  borderRadius: BorderRadius.circular(10),
                  // Yang terpilih dirender persis seperti nanti tampil di kartu,
                  // jadi user lihat hasil jadinya sebelum menyimpan.
                  child: Container(
                    decoration: BoxDecoration(
                      color: isSelected ? color : AppColors.surface,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(
                      AppIcons.resolve(name),
                      size: 20,
                      color: isSelected
                          ? GriviIconBadge.inkFor(color)
                          : AppColors.textSecondary,
                    ),
                  ),
                );
              },
            ),
          ),
        ),
      ],
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
                    ? const Icon(Icons.check, size: 18, color: Colors.white)
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
