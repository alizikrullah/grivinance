import 'package:dio/dio.dart';

import '../../core/constants/api_constants.dart';
import 'storage_service.dart';

/// Error yang udah diterjemahin dari respons API, siap ditampilkan ke user.
class ApiException implements Exception {
  ApiException(this.message, {this.statusCode, this.fieldErrors = const []});

  final String message;
  final int? statusCode;
  final List<String> fieldErrors;

  /// Server nggak kejangkau sama sekali (bukan server yang menolak).
  bool get isNetwork => statusCode == null;

  @override
  String toString() => message;
}

/// Hasil mencoba menukar refresh token.
enum _RefreshResult {
  ok,

  /// Server menolak refresh token-nya — sesi memang habis.
  rejected,

  /// Server nggak kejangkau atau sedang error. Sesi belum tentu habis.
  unreachable,
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
          final options = response.requestOptions;
          final expired = response.statusCode == 401 &&
              options.extra['retried'] != true &&
              options.extra['skipAuth'] != true;
          if (!expired) return handler.next(response);

          // Access token kedaluwarsa: tukar pakai refresh token, ulang request asli.
          switch (await _refreshToken()) {
            case _RefreshResult.ok:
              try {
                return handler.resolve(await _retry(options));
              } on DioException catch (e) {
                return handler.reject(e);
              }
            case _RefreshResult.rejected:
              // Cuma di sini token boleh dihapus: server sendiri yang bilang
              // sesinya habis.
              await _storage.clear();
              onSessionExpired?.call();
              return handler.next(response);
            case _RefreshResult.unreachable:
              // Sinyal putus atau server lagi redeploy. Token disimpan; user
              // cukup coba lagi nanti, bukan login ulang (BUG-4).
              return handler.reject(
                DioException(
                  requestOptions: options,
                  type: DioExceptionType.connectionError,
                ),
              );
          }
        },
      ),
    );
  }

  final StorageService _storage;

  /// Dipanggil kalau server menolak refresh token.
  final void Function()? onSessionExpired;

  late final Dio dio;

  /// Satu proses refresh dipakai bersama semua request yang barengan kena 401,
  /// biar nggak ada badai refresh yang saling menimpa.
  Future<_RefreshResult>? _pendingRefresh;

  Future<_RefreshResult> _refreshToken() {
    return _pendingRefresh ??= _doRefresh().whenComplete(() {
      _pendingRefresh = null;
    });
  }

  Future<_RefreshResult> _doRefresh() async {
    final refreshToken = await _storage.readRefreshToken();
    if (refreshToken == null) return _RefreshResult.rejected;

    // Dio polos: kalau lewat instance utama, refresh yang gagal bakal
    // memicu interceptor ini lagi dan looping.
    final plain = Dio(
      BaseOptions(
        baseUrl: ApiConstants.baseUrl,
        connectTimeout: ApiConstants.connectTimeout,
        receiveTimeout: ApiConstants.receiveTimeout,
        validateStatus: (status) => status != null && status < 500,
      ),
    );

    try {
      // rotate: server ngasih refresh token pengganti, jadi sesi terus geser
      // selama app dipakai dan nggak pernah habis di tengah jalan (REQ-7).
      final response = await plain.post(
        ApiConstants.refresh,
        data: {'refreshToken': refreshToken, 'rotate': true},
      );
      if (response.statusCode != 200) return _RefreshResult.rejected;

      final data = response.data['data'] as Map<String, dynamic>;
      await _storage.saveTokens(
        accessToken: data['accessToken'] as String,
        refreshToken: data['refreshToken'] as String? ?? refreshToken,
      );
      return _RefreshResult.ok;
    } on DioException {
      return _RefreshResult.unreachable;
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
        responseType: options.responseType,
        contentType: options.contentType,
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

    // Pesan "Validasi gagal" doang nggak ngasih tahu apa-apa; pakai pesan
    // field pertama kalau ada.
    final message = body['message'] as String? ?? 'Terjadi kesalahan';
    throw ApiException(
      errors.isNotEmpty && message == 'Validasi gagal' ? errors.first : message,
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
        case DioExceptionType.badResponse:
          // 5xx: server hidup dan ngirim pesannya sendiri — tampilkan itu,
          // bukan "kesalahan jaringan".
          final data = error.response?.data;
          final message = data is Map<String, dynamic> ? data['message'] as String? : null;
          return ApiException(
            message ?? 'Server sedang bermasalah, coba lagi sebentar',
            statusCode: error.response?.statusCode,
          );
        default:
          return ApiException('Terjadi kesalahan jaringan');
      }
    }
    return ApiException('Terjadi kesalahan tidak terduga');
  }
}
