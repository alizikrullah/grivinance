import 'dart:typed_data';

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

  Future<AuthResult> login({required String email, required String password}) async {
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
        await _api.dio.delete(ApiConstants.logout, data: {'refreshToken': refreshToken});
      } catch (_) {
        // Server nggak kejangkau bukan alasan buat nahan user tetap login.
      }
    }
    await _storage.clear();
  }

  /// PUT = ganti seluruh profil: field opsional yang kosong berarti dihapus.
  Future<UserModel> updateProfile({
    required String name,
    String? nickname,
    String? phone,
    DateTime? birthDate,
  }) async {
    final data = await _api.send(
      () => _api.dio.put(
        ApiConstants.me,
        data: {
          'name': name,
          'nickname': nickname,
          'phone': phone,
          'birthDate': birthDate == null
              ? null
              : '${birthDate.year.toString().padLeft(4, '0')}-'
                    '${birthDate.month.toString().padLeft(2, '0')}-'
                    '${birthDate.day.toString().padLeft(2, '0')}',
        },
      ),
    );
    return UserModel.fromJson(data as Map<String, dynamic>);
  }

  Future<UserModel> changeEmail({required String email, required String currentPassword}) async {
    final data = await _api.send(
      () => _api.dio.put(
        ApiConstants.meEmail,
        data: {'email': email, 'currentPassword': currentPassword},
      ),
    );
    return UserModel.fromJson(data as Map<String, dynamic>);
  }

  /// Server mematikan semua sesi lain dan ngasih pasangan token baru buat HP ini.
  Future<void> changePassword({
    required String currentPassword,
    required String newPassword,
  }) async {
    final data = await _api.send(
      () => _api.dio.put(
        ApiConstants.mePassword,
        data: {'currentPassword': currentPassword, 'newPassword': newPassword},
      ),
    );
    final tokens = data as Map<String, dynamic>;
    await _storage.saveTokens(
      accessToken: tokens['accessToken'] as String,
      refreshToken: tokens['refreshToken'] as String,
    );
  }

  /// null = belum ada foto. Lewat Dio (bukan Image.network) supaya ikut alur
  /// refresh token: Image.network nggak lewat interceptor dan fotonya bakal
  /// rusak tiap access token kedaluwarsa.
  Future<Uint8List?> avatar() async {
    try {
      final response = await _api.dio.get<List<int>>(
        ApiConstants.meAvatar,
        options: Options(responseType: ResponseType.bytes),
      );
      if (response.statusCode == 404) return null;
      if (response.statusCode != 200 || response.data == null) {
        throw ApiException('Gagal memuat foto profil', statusCode: response.statusCode);
      }
      return Uint8List.fromList(response.data!);
    } catch (e) {
      throw ApiService.toApiException(e);
    }
  }

  Future<void> uploadAvatar(Uint8List bytes, String mimeType) => _api.send(
    () => _api.dio.put(
      ApiConstants.meAvatar,
      data: bytes,
      options: Options(contentType: mimeType),
    ),
  );

  Future<void> deleteAvatar() => _api.send(() => _api.dio.delete(ApiConstants.meAvatar));

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
