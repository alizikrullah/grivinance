import 'package:dio/dio.dart';

import '../../core/constants/api_constants.dart';
import 'storage_service.dart';

/// Error yang udah diterjemahin dari respons API, siap ditampilkan ke user.
class ApiException implements Exception {
  ApiException(this.message, {this.statusCode, this.fieldErrors = const []});

  final String message;
  final int? statusCode;
  final List<String> fieldErrors;

  @override
  String toString() => message;
}

class ApiService {
  ApiService(this._storage, {this.onSessionExpired}) {
    dio = Dio(
      BaseOptions(
        baseUrl: ApiConstants.baseUrl,
        connectTimeout: ApiConstants.connectTimeout,
        receiveTimeout: ApiConstants.receiveTimeout,
        headers: {'Content-Type': 'application/json'},
        // Biar 4xx nggak dilempar sebagai error mentah; kita mau baca body-nya.
        validateStatus: (status) => status != null && status < 500,
      ),
    );

    dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) async {
          if (options.extra['skipAuth'] != true) {
            final token = await _storage.readAccessToken();
            if (token != null) {
              options.headers['Authorization'] = 'Bearer $token';
            }
          }
          handler.next(options);
        },
        onResponse: (response, handler) async {
          // Access token kedaluwarsa: tukar pakai refresh token, ulang request asli.
          if (response.statusCode == 401 &&
              response.requestOptions.extra['retried'] != true &&
              response.requestOptions.extra['skipAuth'] != true) {
            final refreshed = await _refreshToken();
            if (refreshed) {
              try {
                final retried = await _retry(response.requestOptions);
                return handler.resolve(retried);
              } on DioException catch (e) {
                return handler.next(e.response ?? response);
              }
            }
            await _storage.clear();
            onSessionExpired?.call();
          }
          handler.next(response);
        },
      ),
    );
  }

  final StorageService _storage;

  /// Dipanggil kalau refresh token juga sudah tidak valid.
  final void Function()? onSessionExpired;

  late final Dio dio;

  /// Satu proses refresh dipakai bersama semua request yang barengan kena 401,
  /// biar nggak ada badai refresh yang saling menimpa.
  Future<bool>? _pendingRefresh;

  Future<bool> _refreshToken() {
    return _pendingRefresh ??= _doRefresh().whenComplete(() {
      _pendingRefresh = null;
    });
  }

  Future<bool> _doRefresh() async {
    final refreshToken = await _storage.readRefreshToken();
    if (refreshToken == null) return false;

    // Dio polos: kalau lewat instance utama, refresh yang gagal bakal
    // memicu interceptor ini lagi dan looping.
    final plain = Dio(BaseOptions(baseUrl: ApiConstants.baseUrl));
    try {
      final response = await plain.post(
        ApiConstants.refresh,
        data: {'refreshToken': refreshToken},
      );
      final token = response.data['data']['accessToken'] as String;
      await _storage.saveAccessToken(token);
      return true;
    } catch (_) {
      return false;
    }
  }

  /// Header Authorization lama dibuang supaya interceptor onRequest masang
  /// token yang baru. 'retried' nandain request ini nggak boleh di-refresh lagi.
  Future<Response<dynamic>> _retry(RequestOptions options) {
    return dio.request<dynamic>(
      options.path,
      data: options.data,
      queryParameters: options.queryParameters,
      options: Options(
        method: options.method,
        headers: {...options.headers}..remove('Authorization'),
        extra: {...options.extra, 'retried': true},
      ),
    );
  }

  /// Jalur standar semua repository: kirim request, buka amplop responsnya,
  /// dan seragamkan errornya jadi ApiException.
  Future<dynamic> send(Future<Response<dynamic>> Function() request) async {
    try {
      return unwrap(await request());
    } catch (e) {
      throw toApiException(e);
    }
  }

  /// Buka amplop { success, message, data } dan lempar ApiException kalau gagal.
  static dynamic unwrap(Response<dynamic> response) {
    final body = response.data;

    if (body is! Map<String, dynamic>) {
      throw ApiException(
        'Respons server tidak dikenali',
        statusCode: response.statusCode,
      );
    }

    if (body['success'] == true) return body['data'];

    final errors = (body['errors'] as List<dynamic>? ?? [])
        .map((e) => e is Map<String, dynamic> ? '${e['msg']}' : '$e')
        .toList();

    throw ApiException(
      body['message'] as String? ?? 'Terjadi kesalahan',
      statusCode: response.statusCode,
      fieldErrors: errors,
    );
  }

  /// Bungkus error jaringan jadi pesan yang bisa dibaca user.
  static ApiException toApiException(Object error) {
    if (error is ApiException) return error;
    if (error is DioException) {
      switch (error.type) {
        case DioExceptionType.connectionTimeout:
        case DioExceptionType.receiveTimeout:
        case DioExceptionType.sendTimeout:
          return ApiException('Koneksi ke server timeout');
        case DioExceptionType.connectionError:
          return ApiException('Tidak bisa terhubung ke server');
        default:
          return ApiException('Terjadi kesalahan jaringan');
      }
    }
    return ApiException('Terjadi kesalahan tidak terduga');
  }
}
