import 'package:flutter/services.dart';
import 'package:intl/intl.dart';

/// Uang datang dari API sebagai string ("150000.00"), bukan number.
/// Semua konversi ke tampilan lewat sini.
class CurrencyFormatter {
  CurrencyFormatter._();

  static final NumberFormat _rupiah = NumberFormat.currency(
    locale: 'id_ID',
    symbol: 'Rp ',
    decimalDigits: 0,
  );

  static final NumberFormat _plain = NumberFormat.decimalPattern('id_ID');

  /// "150000.00" -> "Rp 150.000"
  static String format(double amount) => _rupiah.format(amount);

  /// Dipakai buat nominal yang sudah pasti positif/negatif dari saldo wallet.
  static String formatSigned(double amount) {
    final formatted = _rupiah.format(amount.abs());
    return amount < 0 ? '-$formatted' : formatted;
  }

  /// "+Rp 150.000" / "-Rp 150.000" — arus masuk/keluar.
  static String formatDelta(double amount) {
    final formatted = _rupiah.format(amount.abs());
    return amount < 0 ? '-$formatted' : '+$formatted';
  }

  /// Ringkas buat ruang sempit: 1.250.000 -> "1,3 jt", 25.000 -> "25 rb".
  static String compact(double value) {
    final abs = value.abs();
    final sign = value < 0 ? '-' : '';
    String fixed(double v, int digits) =>
        v.toStringAsFixed(digits).replaceAll('.', ',').replaceAll(RegExp(r',0$'), '');
    if (abs >= 1e12) return '$sign${fixed(abs / 1e12, 1)} T';
    if (abs >= 1e9) return '$sign${fixed(abs / 1e9, 1)} M';
    if (abs >= 1e6) return '$sign${fixed(abs / 1e6, 1)} jt';
    if (abs >= 1e3) return '$sign${fixed(abs / 1e3, 0)} rb';
    return '$sign${abs.toStringAsFixed(0)}';
  }

  /// Isi awal field nominal: 150000.0 -> "150.000".
  static String formatInput(double amount) =>
      amount == 0 ? '' : _plain.format(amount.round());

  /// Input user "150.000" atau "150000" -> 150000.0
  static double parseInput(String raw) {
    final digits = raw.replaceAll(RegExp(r'[^0-9]'), '');
    return digits.isEmpty ? 0 : double.parse(digits);
  }
}

/// Field nominal menampilkan pemisah ribuan selagi diketik: "1000000" -> "1.000.000".
class RupiahInputFormatter extends TextInputFormatter {
  static final NumberFormat _plain = NumberFormat.decimalPattern('id_ID');

  /// Batas digit supaya nominal tetap di bawah batas backend (999 miliar).
  static const int _maxDigits = 12;

  @override
  TextEditingValue formatEditUpdate(TextEditingValue oldValue, TextEditingValue newValue) {
    var digits = newValue.text.replaceAll(RegExp(r'[^0-9]'), '');
    if (digits.length > _maxDigits) return oldValue;
    digits = digits.replaceFirst(RegExp(r'^0+(?=\d)'), '');
    if (digits.isEmpty) return const TextEditingValue();

    final text = _plain.format(int.parse(digits));
    return TextEditingValue(
      text: text,
      selection: TextSelection.collapsed(offset: text.length),
    );
  }
}
