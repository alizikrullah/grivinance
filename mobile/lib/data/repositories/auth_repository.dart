import 'package:dio/dio.dart';

import '../../core/constants/api_constants.dart';
import '../models/user_model.dart';
import '../services/api_service.dart';
import '../services/storage_service.dart';

class AuthRepository {
  AuthRepository(this._api, this._storage);

  final ApiService _api;
  final StorageService _storage;

  Future<AuthResult> register({
    required String name,
    required String email,
    required String password,
  }) async {
    final result = await _api.send(
      () => _api.dio.post(
        ApiConstants.register,
        data: {'name': name, 'email': email, 'password': password},
        options: _noAuth,
      ),
    );
    return _persist(result);
  }

  Future<AuthResult> login({
    required String email,
    required String password,
  }) async {
    final result = await _api.send(
      () => _api.dio.post(
        ApiConstants.login,
        data: {'email': email, 'password': password},
        options: _noAuth,
      ),
    );
    return _persist(result);
  }

  /// Dipakai route guard waktu cold start: token ada di storage belum tentu
  /// masih valid, jadi harus ditanya ke server.
  Future<UserModel> me() async {
    final data = await _api.send(() => _api.dio.get(ApiConstants.me));
    return UserModel.fromJson(data as Map<String, dynamic>);
  }

  Future<void> logout() async {
    final refreshToken = await _storage.readRefreshToken();
    if (refreshToken != null) {
      try {
        await _api.dio.delete(
          ApiConstants.logout,
          data: {'refreshToken': refreshToken},
        );
      } catch (_) {
        // Server nggak kejangkau bukan alasan buat nahan user tetap login.
      }
    }
    await _storage.clear();
  }

  Future<AuthResult> _persist(dynamic data) async {
    final result = AuthResult.fromJson(data as Map<String, dynamic>);
    await _storage.saveTokens(
      accessToken: result.accessToken,
      refreshToken: result.refreshToken,
    );
    return result;
  }

  static final _noAuth = Options(extra: const {'skipAuth': true});

}
