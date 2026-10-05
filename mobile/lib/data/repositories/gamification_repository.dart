import '../../core/constants/api_constants.dart';
import '../models/gamification_model.dart';
import '../services/api_service.dart';

class GamificationRepository {
  GamificationRepository(this._api);

  final ApiService _api;

  Future<GamificationState> state() async {
    final data = await _api.send(() => _api.dio.get(ApiConstants.gamification));
    return GamificationState.fromJson(data as Map<String, dynamic>);
  }

  /// Server memvalidasi misinya beneran selesai; balikannya keadaan terbaru.
  Future<GamificationState> claim(String missionKey) async {
    final data = await _api.send(
      () => _api.dio.post(ApiConstants.claimMission(missionKey)),
    );
    return GamificationState.fromJson(data as Map<String, dynamic>);
  }
}
