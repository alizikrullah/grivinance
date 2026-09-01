import '../../core/constants/api_constants.dart';
import '../../core/utils/date_formatter.dart';
import '../models/category_model.dart';
import '../models/transaction_model.dart';
import '../services/api_service.dart';

class TransactionRepository {
  TransactionRepository(this._api);

  final ApiService _api;

  Future<TransactionPage> list({
    int page = 1,
    int limit = 20,
    TransactionFilter filter = const TransactionFilter(),
  }) async {
    final data = await _api.send(
      () => _api.dio.get(
        ApiConstants.transactions,
        queryParameters: {
          'page': page,
          'limit': limit,
          if (filter.walletId != null) 'walletId': filter.walletId,
          if (filter.categoryId != null) 'categoryId': filter.categoryId,
          if (filter.type != null) 'type': filter.type!.apiValue,
          // Backend menafsirkan tanggal ini sebagai batas hari WIB.
          if (filter.startDate != null)
            'startDate': DateFormatter.isoDate(filter.startDate!),
          if (filter.endDate != null) 'endDate': DateFormatter.isoDate(filter.endDate!),
        },
      ),
    );
    return TransactionPage.fromJson(data as Map<String, dynamic>);
  }

  Future<TransactionModel> detail(String id) async {
    final data = await _api.send(() => _api.dio.get(ApiConstants.transaction(id)));
    return TransactionModel.fromJson(data as Map<String, dynamic>);
  }

  Future<TransactionModel> create({
    required String walletId,
    required String categoryId,
    required TxType type,
    required double amount,
    required DateTime date,
    String? note,
  }) async {
    final data = await _api.send(
      () => _api.dio.post(
        ApiConstants.transactions,
        data: _body(
          walletId: walletId,
          categoryId: categoryId,
          type: type,
          amount: amount,
          date: date,
          note: note,
        ),
      ),
    );
    return TransactionModel.fromJson(data as Map<String, dynamic>);
  }

  Future<TransactionModel> update({
    required String id,
    required String walletId,
    required String categoryId,
    required TxType type,
    required double amount,
    required DateTime date,
    String? note,
  }) async {
    final data = await _api.send(
      () => _api.dio.put(
        ApiConstants.transaction(id),
        data: _body(
          walletId: walletId,
          categoryId: categoryId,
          type: type,
          amount: amount,
          date: date,
          note: note,
        ),
      ),
    );
    return TransactionModel.fromJson(data as Map<String, dynamic>);
  }

  Future<void> delete(String id) =>
      _api.send(() => _api.dio.delete(ApiConstants.transaction(id)));

  Map<String, dynamic> _body({
    required String walletId,
    required String categoryId,
    required TxType type,
    required double amount,
    required DateTime date,
    String? note,
  }) {
    return {
      'walletId': walletId,
      'categoryId': categoryId,
      'type': type.apiValue,
      'amount': amount.toStringAsFixed(2),
      // Kirim dengan offset, biar server tahu ini jam berapa menurut user.
      'date': date.toIso8601String(),
      'note': (note?.trim().isEmpty ?? true) ? null : note!.trim(),
    };
  }
}
