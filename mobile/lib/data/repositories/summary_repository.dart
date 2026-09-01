import '../../core/constants/api_constants.dart';
import '../../core/utils/date_formatter.dart';
import '../models/summary_model.dart';
import '../services/api_service.dart';

class SummaryRepository {
  SummaryRepository(this._api);

  final ApiService _api;

  /// Server yang nentuin batas hari WIB, kita cuma kirim tanggalnya.
  Future<PeriodSummary> daily(DateTime date) async {
    final data = await _api.send(
      () => _api.dio.get(
        ApiConstants.summaryDaily,
        queryParameters: {'date': DateFormatter.isoDate(date)},
      ),
    );
    return PeriodSummary.fromJson(data as Map<String, dynamic>);
  }

  Future<PeriodSummary> monthly(int year, int month) async {
    final data = await _api.send(
      () => _api.dio.get(
        ApiConstants.summaryMonthly,
        queryParameters: {'year': year, 'month': month},
      ),
    );
    return PeriodSummary.fromJson(data as Map<String, dynamic>);
  }

  Future<YearlySummary> yearly(int year) async {
    final data = await _api.send(
      () => _api.dio.get(ApiConstants.summaryYearly, queryParameters: {'year': year}),
    );
    return YearlySummary.fromJson(data as Map<String, dynamic>);
  }
}
