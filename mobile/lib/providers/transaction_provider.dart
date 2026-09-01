import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/models/category_model.dart';
import '../data/models/transaction_model.dart';
import '../data/repositories/transaction_repository.dart';
import 'auth_provider.dart';
import 'summary_provider.dart';
import 'wallet_provider.dart';

final transactionRepositoryProvider = Provider<TransactionRepository>((ref) {
  return TransactionRepository(ref.watch(apiServiceProvider));
});

/// Filter aktif di layar daftar transaksi.
final transactionFilterProvider = StateProvider<TransactionFilter>(
  (ref) => const TransactionFilter(),
);

/// Daftar transaksi dengan infinite scroll. Filter ikut di-watch, jadi ganti
/// filter otomatis muat ulang dari halaman 1.
final transactionsProvider =
    AsyncNotifierProvider<TransactionsNotifier, List<TransactionModel>>(
      TransactionsNotifier.new,
    );

class TransactionsNotifier extends AsyncNotifier<List<TransactionModel>> {
  static const int _pageSize = 20;

  int _page = 1;
  bool _hasMore = true;
  bool _loadingMore = false;

  bool get hasMore => _hasMore;

  TransactionRepository get _repository => ref.read(transactionRepositoryProvider);

  @override
  Future<List<TransactionModel>> build() async {
    final filter = ref.watch(transactionFilterProvider);
    _page = 1;
    final result = await _repository.list(page: 1, limit: _pageSize, filter: filter);
    _hasMore = result.hasMore;
    return result.items;
  }

  Future<void> loadMore() async {
    if (_loadingMore || !_hasMore) return;
    _loadingMore = true;

    try {
      final result = await _repository.list(
        page: _page + 1,
        limit: _pageSize,
        filter: ref.read(transactionFilterProvider),
      );
      _page += 1;
      _hasMore = result.hasMore;
      state = AsyncValue.data([...(state.value ?? []), ...result.items]);
    } finally {
      _loadingMore = false;
    }
  }

  Future<void> refresh() async {
    _page = 1;
    state = await AsyncValue.guard(() async {
      final result = await _repository.list(
        page: 1,
        limit: _pageSize,
        filter: ref.read(transactionFilterProvider),
      );
      _hasMore = result.hasMore;
      return result.items;
    });
  }

  Future<void> create({
    required String walletId,
    required String categoryId,
    required TxType type,
    required double amount,
    required DateTime date,
    String? note,
  }) async {
    await _repository.create(
      walletId: walletId,
      categoryId: categoryId,
      type: type,
      amount: amount,
      date: date,
      note: note,
    );
    await _afterWrite();
  }

  Future<void> edit({
    required String id,
    required String walletId,
    required String categoryId,
    required TxType type,
    required double amount,
    required DateTime date,
    String? note,
  }) async {
    await _repository.update(
      id: id,
      walletId: walletId,
      categoryId: categoryId,
      type: type,
      amount: amount,
      date: date,
      note: note,
    );
    await _afterWrite();
  }

  Future<void> delete(String id) async {
    await _repository.delete(id);
    await _afterWrite();
  }

  /// Tiap tulis transaksi, saldo wallet dan angka summary ikut berubah di server.
  /// Kalau nggak di-invalidate, dashboard nampilin saldo basi.
  Future<void> _afterWrite() async {
    await refresh();
    await ref.read(walletsProvider.notifier).refresh();
    ref.invalidate(dailySummaryProvider);
    ref.invalidate(monthlySummaryProvider);
    ref.invalidate(yearlySummaryProvider);
  }
}

/// 5 transaksi terakhir buat dashboard, lepas dari filter layar daftar.
final recentTransactionsProvider = FutureProvider<List<TransactionModel>>((ref) async {
  // Ikut berubah tiap daftar utama berubah, biar dashboard nggak ketinggalan.
  ref.watch(transactionsProvider);
  final page = await ref.watch(transactionRepositoryProvider).list(page: 1, limit: 5);
  return page.items;
});

final transactionDetailProvider = FutureProvider.family<TransactionModel, String>((
  ref,
  id,
) {
  return ref.watch(transactionRepositoryProvider).detail(id);
});
