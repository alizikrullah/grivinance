import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/models/wallet_model.dart';
import '../data/repositories/wallet_repository.dart';
import 'auth_provider.dart';

final walletRepositoryProvider = Provider<WalletRepository>((ref) {
  return WalletRepository(ref.watch(apiServiceProvider));
});

final walletsProvider = AsyncNotifierProvider<WalletsNotifier, List<WalletModel>>(
  WalletsNotifier.new,
);

class WalletsNotifier extends AsyncNotifier<List<WalletModel>> {
  WalletRepository get _repository => ref.read(walletRepositoryProvider);

  @override
  Future<List<WalletModel>> build() => _repository.list();

  Future<void> refresh() async {
    state = await AsyncValue.guard(_repository.list);
  }

  Future<void> create({
    required String name,
    required WalletType type,
    required String icon,
    required String color,
    required double balance,
  }) async {
    await _repository.create(
      name: name,
      type: type,
      icon: icon,
      color: color,
      balance: balance,
    );
    await refresh();
  }

  Future<void> edit({
    required String id,
    required String name,
    required WalletType type,
    required String icon,
    required String color,
    double? balance,
  }) async {
    await _repository.update(
      id: id,
      name: name,
      type: type,
      icon: icon,
      color: color,
      balance: balance,
    );
    await refresh();
  }

  Future<void> delete(String id) async {
    await _repository.delete(id);
    await refresh();
  }
}

/// Total saldo semua wallet, dipakai kartu utama dashboard.
final totalBalanceProvider = Provider<double>((ref) {
  final wallets = ref.watch(walletsProvider).value ?? const [];
  return wallets.fold<double>(0, (sum, w) => sum + w.balance);
});
