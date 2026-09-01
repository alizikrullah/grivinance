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
final authProvider = AsyncNotifierProvider<AuthNotifier, UserModel?>(AuthNotifier.new);

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
    } catch (_) {
      await ref.read(storageServiceProvider).clear();
      return null;
    }
  }

  Future<void> login({required String email, required String password}) async {
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(() async {
      final result = await _repository.login(email: email, password: password);
      return result.user;
    });
    _rethrowIfFailed();
  }

  Future<void> register({
    required String name,
    required String email,
    required String password,
  }) async {
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(() async {
      final result = await _repository.register(
        name: name,
        email: email,
        password: password,
      );
      return result.user;
    });
    _rethrowIfFailed();
  }

  Future<void> logout() async {
    await _repository.logout();
    state = const AsyncValue.data(null);
  }

  /// Dipanggil interceptor waktu refresh token juga sudah mati.
  void forceLogout() {
    if (state.value != null) state = const AsyncValue.data(null);
  }

  /// AsyncValue.guard nelen error supaya UI nggak crash. Tapi form login butuh
  /// tahu kenapa gagal, jadi errornya dilempar ulang ke pemanggil.
  void _rethrowIfFailed() {
    final error = state.error;
    if (error != null) {
      state = const AsyncValue.data(null);
      throw error is ApiException ? error : ApiService.toApiException(error);
    }
  }
}

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
