import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/models/transaction_model.dart';
import '../data/repositories/transaction_repository.dart';
import '../data/services/export_service.dart';
import 'auth_provider.dart';
import 'data_refresh.dart';

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

  /// Naik tiap build ulang (ganti filter, invalidate). Halaman yang selesai
  /// dimuat untuk generasi lama dibuang, supaya hasil filter lama nggak
  /// nyampur ke daftar baru.
  int _generation = 0;

  bool get hasMore => _hasMore;

  TransactionRepository get _repository => ref.read(transactionRepositoryProvider);

  @override
  Future<List<TransactionModel>> build() {
    final filter = ref.watch(transactionFilterProvider);
    _generation++;
    _page = 1;
    _loadingMore = false;
    return whenSignedIn(ref, () async {
      final result = await _repository.list(page: 1, limit: _pageSize, filter: filter);
      _hasMore = result.hasMore;
      return result.items;
    });
  }

  Future<void> loadMore() async {
    if (_loadingMore || !_hasMore || !state.hasValue) return;
    _loadingMore = true;
    final generation = _generation;

    try {
      final result = await _repository.list(
        page: _page + 1,
        limit: _pageSize,
        filter: ref.read(transactionFilterProvider),
      );
      if (generation != _generation) return;
      _page += 1;
      _hasMore = result.hasMore;
      state = AsyncValue.data([...(state.valueOrNull ?? []), ...result.items]);
    } finally {
      if (generation == _generation) _loadingMore = false;
    }
  }

  Future<void> refresh() async {
    ref.invalidateSelf();
    await future;
  }

  Future<void> create(TransactionInput input) async {
    await _repository.create(input);
    invalidateMoneyData(ref.invalidate);
  }

  Future<void> edit(String id, TransactionInput input) async {
    await _repository.update(id, input);
    invalidateMoneyData(ref.invalidate);
  }

  Future<void> delete(String id) async {
    await _repository.delete(id);
    invalidateMoneyData(ref.invalidate);
  }
}

/// 5 transaksi terakhir buat dashboard, lepas dari filter layar daftar.
/// Disegarkan lewat invalidateMoneyData — dulu dia nge-watch daftar utama,
/// jadi tiap halaman infinite scroll ikut memicu request ulang.
final recentTransactionsProvider = FutureProvider<List<TransactionModel>>((ref) {
  return whenSignedIn(ref, () async {
    final page = await ref.read(transactionRepositoryProvider).list(page: 1, limit: 5);
    return page.items;
  });
});

final transactionDetailProvider = FutureProvider.family<TransactionModel, String>((
  ref,
  id,
) {
  return whenSignedIn(ref, () => ref.read(transactionRepositoryProvider).detail(id));
});

/// Riwayat satu wallet di layar detail wallet, termasuk transfer yang masuk.
// ponytail: 50 terbaru tanpa infinite scroll; daftar lengkapnya lewat filter
// wallet di tab Transaksi.
final walletTransactionsProvider = FutureProvider.family<List<TransactionModel>, String>((
  ref,
  walletId,
) {
  return whenSignedIn(ref, () async {
    final page = await ref
        .read(transactionRepositoryProvider)
        .list(limit: 50, filter: TransactionFilter(walletId: walletId));
    return page.items;
  });
});

final exportServiceProvider = Provider<ExportService>((ref) {
  return ExportService(ref.watch(transactionRepositoryProvider));
});
