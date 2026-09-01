import '../../core/constants/api_constants.dart';
import '../models/wallet_model.dart';
import '../services/api_service.dart';

class WalletRepository {
  WalletRepository(this._api);

  final ApiService _api;

  Future<List<WalletModel>> list() async {
    final data = await _api.send(() => _api.dio.get(ApiConstants.wallets));
    return (data as List<dynamic>)
        .map((e) => WalletModel.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<WalletModel> create({
    required String name,
    required WalletType type,
    required String icon,
    required String color,
    required double balance,
  }) async {
    final data = await _api.send(
      () => _api.dio.post(
        ApiConstants.wallets,
        data: {
          'name': name,
          'type': type.apiValue,
          'icon': icon,
          'color': color,
          'balance': balance.toStringAsFixed(2),
        },
      ),
    );
    return WalletModel.fromJson(data as Map<String, dynamic>);
  }

  Future<WalletModel> update({
    required String id,
    required String name,
    required WalletType type,
    required String icon,
    required String color,
  }) async {
    final data = await _api.send(
      () => _api.dio.put(
        ApiConstants.wallet(id),
        data: {'name': name, 'type': type.apiValue, 'icon': icon, 'color': color},
      ),
    );
    return WalletModel.fromJson(data as Map<String, dynamic>);
  }

  Future<void> delete(String id) =>
      _api.send(() => _api.dio.delete(ApiConstants.wallet(id)));
}
