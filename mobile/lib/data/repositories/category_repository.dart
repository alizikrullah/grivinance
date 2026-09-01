import '../../core/constants/api_constants.dart';
import '../models/category_model.dart';
import '../services/api_service.dart';

class CategoryRepository {
  CategoryRepository(this._api);

  final ApiService _api;

  /// Balikin preset global + kategori custom milik user sekaligus.
  Future<List<CategoryModel>> list() async {
    final data = await _api.send(() => _api.dio.get(ApiConstants.categories));
    return (data as List<dynamic>)
        .map((e) => CategoryModel.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<CategoryModel> create({
    required String name,
    required TxType type,
    required String icon,
    required String color,
  }) async {
    final data = await _api.send(
      () => _api.dio.post(
        ApiConstants.categories,
        data: {'name': name, 'type': type.apiValue, 'icon': icon, 'color': color},
      ),
    );
    return CategoryModel.fromJson(data as Map<String, dynamic>);
  }

  Future<CategoryModel> update({
    required String id,
    required String name,
    required TxType type,
    required String icon,
    required String color,
  }) async {
    final data = await _api.send(
      () => _api.dio.put(
        ApiConstants.category(id),
        data: {'name': name, 'type': type.apiValue, 'icon': icon, 'color': color},
      ),
    );
    return CategoryModel.fromJson(data as Map<String, dynamic>);
  }

  Future<void> delete(String id) =>
      _api.send(() => _api.dio.delete(ApiConstants.category(id)));
}
