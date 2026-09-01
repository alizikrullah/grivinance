import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/models/category_model.dart';
import '../data/repositories/category_repository.dart';
import 'auth_provider.dart';

final categoryRepositoryProvider = Provider<CategoryRepository>((ref) {
  return CategoryRepository(ref.watch(apiServiceProvider));
});

final categoriesProvider =
    AsyncNotifierProvider<CategoriesNotifier, List<CategoryModel>>(
  CategoriesNotifier.new,
);

class CategoriesNotifier extends AsyncNotifier<List<CategoryModel>> {
  CategoryRepository get _repository => ref.read(categoryRepositoryProvider);

  @override
  Future<List<CategoryModel>> build() => _repository.list();

  Future<void> refresh() async {
    state = await AsyncValue.guard(_repository.list);
  }

  Future<void> create({
    required String name,
    required TxType type,
    required String icon,
    required String color,
  }) async {
    await _repository.create(name: name, type: type, icon: icon, color: color);
    await refresh();
  }

  Future<void> edit({
    required String id,
    required String name,
    required TxType type,
    required String icon,
    required String color,
  }) async {
    await _repository.update(id: id, name: name, type: type, icon: icon, color: color);
    await refresh();
  }

  Future<void> delete(String id) async {
    await _repository.delete(id);
    await refresh();
  }
}

/// Kategori yang sudah disaring per tipe — form transaksi cuma boleh nawarin
/// kategori yang tipenya cocok, karena backend nolak yang nggak cocok (422).
final categoriesByTypeProvider =
    Provider.family<List<CategoryModel>, TxType>((ref, type) {
  final all = ref.watch(categoriesProvider).value ?? const [];
  return all.where((c) => c.type == type).toList();
});
