import 'package:flutter/material.dart';

/// Kotak icon berwarna yang dipakai di seluruh app.
///
/// Latarnya warna penuh, iconnya warna kontras — bukan icon berwarna di atas
/// latar warna yang sama dengan alpha rendah. Pola itu bikin semua kartu
/// kelihatan senada dan hambar.
///
/// Warna icon dipilih otomatis dari kecerahan latar: kuning dan hijau muda
/// dapat tinta gelap, biru dan ungu dapat putih.
class GriviIconBadge extends StatelessWidget {
  const GriviIconBadge({
    super.key,
    required this.icon,
    required this.color,
    this.size = 40,
    this.iconSize,
    this.radius = 12,
  });

  final IconData icon;
  final Color color;
  final double size;
  final double? iconSize;
  final double radius;

  static Color inkFor(Color background) {
    return ThemeData.estimateBrightnessForColor(background) == Brightness.dark
        ? Colors.white
        : const Color(0xFF0D0D0D);
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      height: size,
      width: size,
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(radius),
      ),
      child: Icon(icon, size: iconSize ?? size * 0.5, color: inkFor(color)),
    );
  }
}
