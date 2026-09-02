import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/models/category_model.dart';
import '../data/models/summary_model.dart';
import '../data/repositories/summary_repository.dart';
import 'auth_provider.dart';

final summaryRepositoryProvider = Provider<SummaryRepository>((ref) {
  return SummaryRepository(ref.watch(apiServiceProvider));
});

/// Tanggal/bulan/tahun yang lagi dipilih di layar chart.
final selectedDateProvider = StateProvider<DateTime>((ref) => DateTime.now());
final selectedMonthProvider = StateProvider<DateTime>((ref) => DateTime.now());
final selectedYearProvider = StateProvider<int>((ref) => DateTime.now().year);

/// Tipe yang lagi ditampilkan donut. Sengaja dipakai bareng tab Harian dan
/// Bulanan — kalau state-nya lokal per tab, pindah tab terasa seperti ke-reset.
final summaryTypeProvider = StateProvider<TxType>((ref) => TxType.expense);

final dailySummaryProvider = FutureProvider<PeriodSummary>((ref) {
  final date = ref.watch(selectedDateProvider);
  return ref.watch(summaryRepositoryProvider).daily(date);
});

final monthlySummaryProvider = FutureProvider<PeriodSummary>((ref) {
  final month = ref.watch(selectedMonthProvider);
  return ref.watch(summaryRepositoryProvider).monthly(month.year, month.month);
});

final yearlySummaryProvider = FutureProvider<YearlySummary>((ref) {
  final year = ref.watch(selectedYearProvider);
  return ref.watch(summaryRepositoryProvider).yearly(year);
});
