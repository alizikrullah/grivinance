import '../../core/constants/api_constants.dart';
import '../models/budget_model.dart';
import '../services/api_service.dart';

class BudgetRepository {
  BudgetRepository(this._api);

  final ApiService _api;

  Future<BudgetSummary> month(int year, int month) async {
    final data = await _api.send(
      () => _api.dio.get(
        ApiConstants.budgets,
        queryParameters: {'year': year, 'month': month},
      ),
    );
    return BudgetSummary.fromJson(data as Map<String, dynamic>);
  }

  /// Atur atau ganti budget sebuah kategori — satu budget per kategori.
  Future<void> set(String categoryId, double amount) => _api.send(
    () => _api.dio.put(
      ApiConstants.budget(categoryId),
      data: {'amount': amount.toStringAsFixed(2)},
    ),
  );

  Future<void> delete(String categoryId) =>
      _api.send(() => _api.dio.delete(ApiConstants.budget(categoryId)));
}
