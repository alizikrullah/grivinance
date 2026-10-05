import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'budget_provider.dart';
import 'category_provider.dart';
import 'gamification_provider.dart';
import 'summary_provider.dart';
import 'transaction_provider.dart';
import 'wallet_provider.dart';

/// Satu jalur penyegaran setelah apa pun yang menyentuh uang ditulis.
///
/// Tulis transaksi mengubah saldo, summary, budget, dan misi. Hapus wallet
/// ikut menghapus transaksinya di server. Ganti nama wallet/kategori mengubah
/// label di daftar transaksi. Sebelumnya tiap notifier menyegarkan sebagian
/// saja, jadi layar lain nampilin data basi (BUG-6, BUG-9) — sekarang semuanya
/// lewat sini.
///
/// Terima `ref.invalidate` dan bukan `Ref`, supaya bisa dipanggil dari
/// notifier (Ref) maupun dari layar (WidgetRef, misal tarik-untuk-refresh).
void invalidateMoneyData(void Function(ProviderOrFamily provider) invalidate) {
  invalidate(walletsProvider);
  invalidate(categoriesProvider);
  invalidate(transactionsProvider);
  invalidate(recentTransactionsProvider);
  invalidate(transactionDetailProvider);
  invalidate(walletTransactionsProvider);
  invalidate(dailySummaryProvider);
  invalidate(monthlySummaryProvider);
  invalidate(yearlySummaryProvider);
  invalidate(thisMonthSummaryProvider);
  invalidate(budgetsProvider);
  invalidate(gamificationProvider);
}
