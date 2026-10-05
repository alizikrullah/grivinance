import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/models/gamification_model.dart';
import '../data/repositories/gamification_repository.dart';
import 'auth_provider.dart';

final gamificationRepositoryProvider = Provider<GamificationRepository>((ref) {
  return GamificationRepository(ref.watch(apiServiceProvider));
});

/// Streak, misi, XP, dan lencana. Tiap pengambilan ulang bisa membuka lencana
/// baru di server — `newlyUnlocked` di hasilnya jadi pemicu animasi di HomeShell.
final gamificationProvider =
    AsyncNotifierProvider<GamificationNotifier, GamificationState>(GamificationNotifier.new);

class GamificationNotifier extends AsyncNotifier<GamificationState> {
  GamificationRepository get _repository => ref.read(gamificationRepositoryProvider);

  @override
  Future<GamificationState> build() => whenSignedIn(ref, _repository.state);

  Future<void> claim(String missionKey) async {
    state = AsyncData(await _repository.claim(missionKey));
  }
}

/// Pilihan "sembunyikan saldo" di Beranda, diingat per HP.
final hideBalanceProvider = AsyncNotifierProvider<HideBalanceNotifier, bool>(
  HideBalanceNotifier.new,
);

class HideBalanceNotifier extends AsyncNotifier<bool> {
  @override
  Future<bool> build() => ref.read(storageServiceProvider).readHideBalance();

  Future<void> toggle() async {
    final next = !(state.valueOrNull ?? false);
    state = AsyncData(next);
    await ref.read(storageServiceProvider).saveHideBalance(next);
  }
}
