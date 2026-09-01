/// Semua alamat API dikumpulin di sini. Jangan hardcode URL di tempat lain.
class ApiConstants {
  ApiConstants._();

  /// Bisa ditimpa waktu build tanpa ubah kode:
  /// flutter run --dart-define=API_BASE_URL=http://192.168.1.100
  static const String baseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: 'https://grivinance-api.grivilabs.my.id',
  );

  static const Duration connectTimeout = Duration(seconds: 15);
  static const Duration receiveTimeout = Duration(seconds: 15);

  // Auth
  static const String register = '/api/auth/register';
  static const String login = '/api/auth/login';
  static const String refresh = '/api/auth/refresh';
  static const String me = '/api/auth/me';
  static const String logout = '/api/auth/logout';

  // Wallets
  static const String wallets = '/api/wallets';
  static String wallet(String id) => '/api/wallets/$id';

  // Categories
  static const String categories = '/api/categories';
  static String category(String id) => '/api/categories/$id';

  // Transactions
  static const String transactions = '/api/transactions';
  static String transaction(String id) => '/api/transactions/$id';

  // Summary
  static const String summaryDaily = '/api/summary/daily';
  static const String summaryMonthly = '/api/summary/monthly';
  static const String summaryYearly = '/api/summary/yearly';
}
