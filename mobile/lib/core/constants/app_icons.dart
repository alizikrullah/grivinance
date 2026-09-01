import 'package:flutter/material.dart';

/// Backend simpan icon sebagai String. Ini jembatan ke IconData Material.
/// Kalau nama icon dari server nggak ada di sini, jatuh ke fallback, bukan crash.
class AppIcons {
  AppIcons._();

  static const IconData fallback = Icons.more_horiz;

  static const Map<String, IconData> _map = {
    // preset kategori pengeluaran
    'restaurant': Icons.restaurant,
    'directions_car': Icons.directions_car,
    'shopping_bag': Icons.shopping_bag,
    'bolt': Icons.bolt,
    'water_drop': Icons.water_drop,
    'wifi': Icons.wifi,
    'local_hospital': Icons.local_hospital,
    'movie': Icons.movie,
    'school': Icons.school,
    'credit_card': Icons.credit_card,
    'more_horiz': Icons.more_horiz,

    // preset kategori pemasukan
    'work': Icons.work,
    'laptop': Icons.laptop,
    'trending_up': Icons.trending_up,
    'card_giftcard': Icons.card_giftcard,

    // pilihan tambahan buat kategori & wallet custom
    'account_balance': Icons.account_balance,
    'account_balance_wallet': Icons.account_balance_wallet,
    'payments': Icons.payments,
    'savings': Icons.savings,
    'wallet': Icons.wallet,
    'phone_android': Icons.phone_android,
    'coffee': Icons.coffee,
    'fastfood': Icons.fastfood,
    'local_grocery_store': Icons.local_grocery_store,
    'local_gas_station': Icons.local_gas_station,
    'flight': Icons.flight,
    'hotel': Icons.hotel,
    'fitness_center': Icons.fitness_center,
    'pets': Icons.pets,
    'child_care': Icons.child_care,
    'home': Icons.home,
    'build': Icons.build,
    'checkroom': Icons.checkroom,
    'sports_esports': Icons.sports_esports,
    'music_note': Icons.music_note,
    'book': Icons.book,
    'redeem': Icons.redeem,
    'volunteer_activism': Icons.volunteer_activism,
    'attach_money': Icons.attach_money,
    'currency_exchange': Icons.currency_exchange,
    'store': Icons.store,
  };

  static IconData resolve(String? name) => _map[name] ?? fallback;

  /// Picker wallet cuma nawarin icon yang masuk akal buat dompet dan rekening.
  /// Sebelumnya satu daftar dipakai bersama, jadi buat milih icon "Tunai" user
  /// harus scroll lewat garpu-sendok, mobil, dan wifi dulu.
  static const List<String> forWallet = [
    'account_balance_wallet',
    'account_balance',
    'wallet',
    'payments',
    'credit_card',
    'savings',
    'attach_money',
    'currency_exchange',
    'phone_android',
    'store',
    'redeem',
    'more_horiz',
  ];

  /// Sisanya buat kategori — semua icon kecuali yang khusus wallet.
  static List<String> get forCategory => _map.keys
      .where((name) => !forWallet.contains(name) || name == 'more_horiz')
      .toList();
}

/// Warna dari API datang sebagai "#RRGGBB".
Color hexToColor(String hex) {
  final cleaned = hex.replaceAll('#', '').trim();
  if (cleaned.length != 6) return const Color(0xFF6B7280);
  return Color(int.parse('FF$cleaned', radix: 16));
}

String colorToHex(Color color) {
  final value =
      ((color.a * 255).round() << 24) |
      ((color.r * 255).round() << 16) |
      ((color.g * 255).round() << 8) |
      (color.b * 255).round();
  return '#${(value & 0xFFFFFF).toRadixString(16).padLeft(6, '0').toUpperCase()}';
}

/// Palet siap pakai buat color picker.
const List<String> pickableColors = [
  '#10B981',
  '#3B82F6',
  '#A855F7',
  '#F97316',
  '#EF4444',
  '#EAB308',
  '#06B6D4',
  '#EC4899',
  '#8B5CF6',
  '#14B8A6',
  '#F43F5E',
  '#22C55E',
  '#6366F1',
  '#F59E0B',
  '#6B7280',
  '#84CC16',
];
