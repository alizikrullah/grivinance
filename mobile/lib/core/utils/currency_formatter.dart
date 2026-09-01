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

  /// "150000.00" -> "Rp 150.000"
  static String format(double amount) => _rupiah.format(amount);

  /// Dipakai buat nominal yang sudah pasti positif/negatif dari saldo wallet.
  static String formatSigned(double amount) {
    final formatted = _rupiah.format(amount.abs());
    return amount < 0 ? '-$formatted' : formatted;
  }

  /// Input user "150.000" atau "150000" -> 150000.0
  static double parseInput(String raw) {
    final digits = raw.replaceAll(RegExp(r'[^0-9]'), '');
    return digits.isEmpty ? 0 : double.parse(digits);
  }
}
