import 'package:mobile/core/network/api_client.dart';
import 'package:mobile/core/network/envelope.dart';

import 'progress_report_models.dart';

/// Repository for the progress-reports feature. Wraps [ApiClient] calls
/// against `/progress-reports/*`.
///
/// `DailyProgressReport` is immutable once submitted — the backend exposes
/// only create + list + get (plus the nested photo endpoints), never
/// update/delete — so this repository has no `update`/`delete` methods.
class ProgressReportRepository {
  ProgressReportRepository(this._apiClient);

  final ApiClient _apiClient;

  /// Creates a report. If [overallProgressPercent] is set, the backend
  /// applies it to the parent Project's `progress_percent` automatically —
  /// no separate client call needed for that.
  Future<ProgressReport> create({
    required String projectId,
    required DateTime reportDate,
    String? summary,
    int? overallProgressPercent,
    List<StageEntry> stageEntries = const [],
  }) async {
    final envelope = await _apiClient.post<ProgressReport>(
      '/progress-reports',
      body: {
        'project_id': projectId,
        'report_date': _formatDate(reportDate),
        if (summary != null) 'summary': summary,
        if (overallProgressPercent != null) 'overall_progress_percent': overallProgressPercent,
        'stage_entries': stageEntries.map((e) => e.toJson()).toList(),
      },
      fromData: (json) => ProgressReport.fromJson(json as Map<String, dynamic>),
    );
    return envelope.data!;
  }

  /// Lists reports, optionally filtered by [projectId], paginated.
  Future<({List<ProgressReport> reports, int total})> list({
    String? projectId,
    int page = 1,
    int pageSize = 20,
  }) async {
    final envelope = await _apiClient.get<List<ProgressReport>>(
      '/progress-reports',
      query: {
        if (projectId != null) 'project_id': projectId,
        'page': page,
        'page_size': pageSize,
      },
      fromData: (json) => listFromJson(json, ProgressReport.fromJson),
    );
    return (reports: envelope.data ?? const [], total: envelope.meta?.total ?? 0);
  }

  Future<ProgressReport> getById(String id) async {
    final envelope = await _apiClient.get<ProgressReport>(
      '/progress-reports/$id',
      fromData: (json) => ProgressReport.fromJson(json as Map<String, dynamic>),
    );
    return envelope.data!;
  }

  /// All photos across the whole project in chronological order — the
  /// server does no date-grouping, callers group client-side (see
  /// `PhotoTimelineBloc`).
  Future<List<ProgressPhotoEntry>> timeline({required String projectId}) async {
    final envelope = await _apiClient.get<List<ProgressPhotoEntry>>(
      '/progress-reports/timeline',
      query: {'project_id': projectId},
      fromData: (json) => listFromJson(json, ProgressPhotoEntry.fromJson),
    );
    return envelope.data ?? const [];
  }

  /// Attaches a photo to an already-created report. The report must exist
  /// first — upload the bytes via `UploadRepository.captureAndUpload`, then
  /// call this with the returned `photo_url`.
  Future<void> addPhoto(String reportId, {required String photoUrl, String? caption}) async {
    await _apiClient.post<Map<String, dynamic>>(
      '/progress-reports/$reportId/photos',
      body: {'photo_url': photoUrl, if (caption != null) 'caption': caption},
      fromData: (json) => json as Map<String, dynamic>,
    );
  }

  String _formatDate(DateTime date) {
    final year = date.year.toString().padLeft(4, '0');
    final month = date.month.toString().padLeft(2, '0');
    final day = date.day.toString().padLeft(2, '0');
    return '$year-$month-$day';
  }
}
