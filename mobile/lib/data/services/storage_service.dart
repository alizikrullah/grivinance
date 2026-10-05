import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// Token disimpan di secure storage OS (Keystore di Android), bukan SharedPreferences.
class StorageService {
  StorageService([FlutterSecureStorage? storage])
    : _storage = storage ?? const FlutterSecureStorage();

  final FlutterSecureStorage _storage;

  static const String _accessTokenKey = 'access_token';
  static const String _refreshTokenKey = 'refresh_token';
  static const String _hideBalanceKey = 'hide_balance';

  Future<String?> readAccessToken() => _storage.read(key: _accessTokenKey);

  Future<String?> readRefreshToken() => _storage.read(key: _refreshTokenKey);

  Future<void> saveTokens({
    required String accessToken,
    required String refreshToken,
  }) async {
    await _storage.write(key: _accessTokenKey, value: accessToken);
    await _storage.write(key: _refreshTokenKey, value: refreshToken);
  }

  Future<void> saveAccessToken(String accessToken) =>
      _storage.write(key: _accessTokenKey, value: accessToken);

  Future<void> clear() async {
    await _storage.delete(key: _accessTokenKey);
    await _storage.delete(key: _refreshTokenKey);
  }

  /// Pilihan "sembunyikan saldo" di Beranda. Preferensi per HP, bukan per akun.
  Future<bool> readHideBalance() async =>
      await _storage.read(key: _hideBalanceKey) == 'true';

  Future<void> saveHideBalance(bool hide) =>
      _storage.write(key: _hideBalanceKey, value: '$hide');
}
