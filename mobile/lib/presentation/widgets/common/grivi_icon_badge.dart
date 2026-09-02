import 'package:flutter/material.dart';

import '../../../core/constants/app_icons.dart';

/// Kotak icon berwarna yang dipakai di seluruh app.
///
/// Dua mode, ditentukan dari isi `name`:
///
/// - **Material Icon** (`"restaurant"`) — latar warna penuh, icon warna kontras.
///   Bukan icon berwarna di atas latar warna sama dengan alpha rendah; pola itu
///   bikin semua kartu kelihatan senada dan hambar.
///
/// - **Logo** (`"logo:bca"`) — latar **putih**, logo apa adanya. Logo bank dan
///   e-wallet dirancang untuk latar terang; gopay misalnya wordmark-nya hitam
///   dan bakal hilang total kalau ditaruh di latar gelap atau di atas warna.
class GriviIconBadge extends StatelessWidget {
  /// Nama dari database — Material Icon atau logo.
  const GriviIconBadge({
    super.key,
    required this.name,
    required this.color,
    this.size = 40,
    this.radius = 12,
  }) : icon = null;

  /// Icon tetap yang di-hardcode di UI, bukan dari database.
  const GriviIconBadge.material(
    this.icon, {
    super.key,
    required this.color,
    this.size = 40,
    this.radius = 12,
  }) : name = null;

  final String? name;
  final IconData? icon;
  final Color color;
  final double size;
  final double radius;

  /// Putih atau hitam, mana yang kebaca di atas [background].
  static Color inkFor(Color background) {
    return ThemeData.estimateBrightnessForColor(background) == Brightness.dark
        ? Colors.white
        : const Color(0xFF0D0D0D);
  }

  @override
  Widget build(BuildContext context) {
    final isLogo = AppLogos.isLogo(name);

    return Container(
      height: size,
      width: size,
      padding: isLogo ? EdgeInsets.all(size * 0.14) : EdgeInsets.zero,
      decoration: BoxDecoration(
        color: isLogo ? Colors.white : color,
        borderRadius: BorderRadius.circular(radius),
      ),
      child: isLogo
          ? Image.asset(AppLogos.assetPath(name!), fit: BoxFit.contain)
          : Icon(icon ?? AppIcons.resolve(name), size: size * 0.5, color: inkFor(color)),
    );
  }
}
