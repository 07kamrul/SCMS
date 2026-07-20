import '../../../core/network/api_client.dart';
import 'dashboard_models.dart';

/// Repository for the dashboard feature. Wraps the single
/// `GET /dashboard/me` call.
class DashboardRepository {
  DashboardRepository(this._apiClient);

  final ApiClient _apiClient;

  Future<DashboardSummary> getMyDashboard() async {
    final envelope = await _apiClient.get<DashboardSummary>(
      '/dashboard/me',
      fromData: (json) =>
          DashboardSummary.fromJson(json as Map<String, dynamic>),
    );
    return envelope.data!;
  }
}
