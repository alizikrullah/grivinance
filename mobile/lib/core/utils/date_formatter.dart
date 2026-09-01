import 'package:intl/intl.dart';

/// API kirim tanggal UTC. User lihatnya dalam WIB.
class DateFormatter {
  DateFormatter._();

  static final DateFormat _full = DateFormat('d MMMM yyyy', 'id_ID');
  static final DateFormat _short = DateFormat('d MMM yyyy', 'id_ID');
  static final DateFormat _monthYear = DateFormat('MMMM yyyy', 'id_ID');
  static final DateFormat _time = DateFormat('HH:mm', 'id_ID');
  static final DateFormat _isoDate = DateFormat('yyyy-MM-dd');

  static const List<String> monthNames = [
    'Jan', 'Feb', 'Mar', 'Apr', 'Mei', 'Jun',
    'Jul', 'Agu', 'Sep', 'Okt', 'Nov', 'Des',
  ];

  /// "1 September 2026"
  static String full(DateTime date) => _full.format(date.toLocal());

  /// "1 Sep 2026"
  static String short(DateTime date) => _short.format(date.toLocal());

  /// "September 2026"
  static String monthYear(DateTime date) => _monthYear.format(date.toLocal());

  /// "14:30"
  static String time(DateTime date) => _time.format(date.toLocal());

  /// Format yang dimau query param API: "2026-09-01"
  static String isoDate(DateTime date) => _isoDate.format(date.toLocal());
}
