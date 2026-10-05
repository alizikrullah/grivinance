import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/models/user_model.dart';
import '../data/repositories/auth_repository.dart';
import '../data/services/api_service.dart';
import '../data/services/storage_service.dart';

final storageServiceProvider = Provider<StorageService>((ref) => StorageService());

final apiServiceProvider = Provider<ApiService>((ref) {
  final storage = ref.watch(storageServiceProvider);
  return ApiService(
    storage,
    onSessionExpired: () => ref.read(authProvider.notifier).forceLogout(),
  );
});

final authRepositoryProvider = Provider<AuthRepository>((ref) {
  return AuthRepository(ref.watch(apiServiceProvider), ref.watch(storageServiceProvider));
});

/// null = belum login. Router baca ini buat nentuin redirect.
///
/// Status error cuma muncul waktu cold start dan server nggak kejangkau —
/// token tetap disimpan dan splash nampilin tombol coba lagi (BUG-4).
final authProvider = AsyncNotifierProvider<AuthNotifier, UserModel?>(AuthNotifier.new);

/// Pesan buat layar login kalau user dikeluarkan paksa karena sesinya habis.
final sessionNoticeProvider = StateProvider<String?>((ref) => null);

class AuthNotifier extends AsyncNotifier<UserModel?> {
  AuthRepository get _repository => ref.read(authRepositoryProvider);

  @override
  Future<UserModel?> build() async {
    // Cold start: token ada di secure storage nggak berarti masih valid,
    // jadi wajib dicek ke /me dulu sebelum masuk dashboard.
    final token = await ref.read(storageServiceProvider).readAccessToken();
    if (token == null) return null;

    try {
      return await _repository.me();
    } on ApiException catch (e) {
      // Cuma penolakan dari server yang berarti sesinya habis. Sinyal putus
      // atau server lagi redeploy dilempar ulang: token disimpan, splash
      // nampilin "coba lagi", bukan menendang user ke layar login.
      if (e.statusCode == 401) {
        await ref.read(storageServiceProvider).clear();
        return null;
      }
      rethrow;
    }
  }

  /// Dipakai tombol "Coba lagi" di splash waktu server nggak kejangkau.
  void retry() => ref.invalidateSelf();

  // login/register sengaja nggak mengeset AsyncLoading: router menganggap
  // loading = "masih cek sesi" dan melempar ke splash, yang membuang form
  // login beserta pesan errornya (BUG-5). Layar login punya spinner sendiri.
  Future<void> login({required String email, required String password}) async {
    final result = await _repository.login(email: email, password: password);
    ref.read(sessionNoticeProvider.notifier).state = null;
    state = AsyncData(result.user);
  }

  Future<void> register({
    required String name,
    required String email,
    required String password,
  }) async {
    final result = await _repository.register(name: name, email: email, password: password);
    ref.read(sessionNoticeProvider.notifier).state = null;
    state = AsyncData(result.user);
  }

  Future<void> logout() async {
    await _repository.logout();
    state = const AsyncData(null);
  }

  /// Dipanggil interceptor waktu server menolak refresh token.
  void forceLogout() {
    if (state.valueOrNull == null) return;
    ref.read(sessionNoticeProvider.notifier).state = 'Sesi kamu berakhir, silakan masuk lagi';
    state = const AsyncData(null);
  }

  Future<void> updateProfile({
    required String name,
    String? nickname,
    String? phone,
    DateTime? birthDate,
  }) async {
    final user = await _repository.updateProfile(
      name: name,
      nickname: nickname,
      phone: phone,
      birthDate: birthDate,
    );
    state = AsyncData(user);
  }

  Future<void> changeEmail({required String email, required String currentPassword}) async {
    state = AsyncData(
      await _repository.changeEmail(email: email, currentPassword: currentPassword),
    );
  }

  Future<void> changePassword({
    required String currentPassword,
    required String newPassword,
  }) => _repository.changePassword(currentPassword: currentPassword, newPassword: newPassword);

  Future<void> uploadAvatar(Uint8List bytes, String mimeType) async {
    await _repository.uploadAvatar(bytes, mimeType);
    state = AsyncData(await _repository.me());
  }

  Future<void> deleteAvatar() async {
    await _repository.deleteAvatar();
    state = AsyncData(await _repository.me());
  }
}

/// Id user yang sedang login. Semua provider data `watch` ini lewat
/// [whenSignedIn], jadi ganti akun = semua data dibangun ulang (BUG-8).
final currentUserIdProvider = Provider<String?>((ref) {
  return ref.watch(authProvider.select((auth) => auth.valueOrNull?.id));
});

/// Muat data milik user yang sedang login.
///
/// Saat belum/tidak login, fetch ditahan (future yang nggak pernah selesai):
/// request tanpa token cuma bakal kena 401 dan memicu pesan "sesi berakhir"
/// palsu. Begitu ada user, provider dibangun ulang dan fetch jalan.
Future<T> whenSignedIn<T>(Ref ref, Future<T> Function() load) {
  final userId = ref.watch(currentUserIdProvider);
  if (userId == null) return Completer<T>().future;
  return load();
}

/// Foto profil. Kuncinya ikut `avatarUpdatedAt`, jadi ganti foto langsung
/// memuat ulang tanpa cache basi.
final avatarProvider = FutureProvider<Uint8List?>((ref) async {
  final key = ref.watch(
    authProvider.select((auth) => (auth.valueOrNull?.id, auth.valueOrNull?.avatarUpdatedAt)),
  );
  if (key.$1 == null || key.$2 == null) return null;
  return ref.read(authRepositoryProvider).avatar();
});

/// Dipakai go_router buat refresh redirect tiap status auth berubah.
class AuthRouterNotifier extends ChangeNotifier {
  AuthRouterNotifier(this._ref) {
    _ref.listen<AsyncValue<UserModel?>>(authProvider, (_, _) => notifyListeners());
  }

  final Ref _ref;
}

final authRouterNotifierProvider = Provider<AuthRouterNotifier>((ref) {
  return AuthRouterNotifier(ref);
});
