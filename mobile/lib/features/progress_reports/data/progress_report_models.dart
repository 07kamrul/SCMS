/// A single stage-wise progress line item. Free text `stageName` — the
/// backend has no fixed/enum list of stages (see
/// `app/models/progress_report_stage_entry.py`) — the user types it.
///
/// This same shape is used both for entries already returned by the server
/// (with [id] set) and for in-progress form rows (with [id] left `null`,
/// since they don't exist server-side until the report is submitted).
class StageEntry {
  const StageEntry({
    this.id,
    required this.stageName,
    required this.progressPercent,
    this.notes,
  });

  final String? id;
  final String stageName;
  final int progressPercent;
  final String? notes;

  /// Mirrors `backend/app/schemas/progress_report.py::StageEntryPublic`.
  factory StageEntry.fromJson(Map<String, dynamic> json) {
    return StageEntry(
      id: json['id'] as String,
      stageName: json['stage_name'] as String,
      progressPercent: json['progress_percent'] as int,
      notes: json['notes'] as String?,
    );
  }

  /// Serializes as `StageEntryCreate` for `POST /progress-reports`. `id` is
  /// never sent — the server assigns it.
  Map<String, dynamic> toJson() => {
    'stage_name': stageName,
    'progress_percent': progressPercent,
    if (notes != null) 'notes': notes,
  };
}

/// Mirrors `backend/app/schemas/progress_report.py::ProgressReportPublic`.
///
/// Immutable once submitted server-side — this app only ever creates and
/// reads reports, never updates or deletes them.
class ProgressReport {
  const ProgressReport({
    required this.id,
    required this.companyId,
    required this.projectId,
    this.submittedByUserId,
    required this.reportDate,
    this.summary,
    this.overallProgressPercent,
    required this.stageEntries,
    required this.createdAt,
    required this.updatedAt,
  });

  final String id;
  final String companyId;
  final String projectId;
  final String? submittedByUserId;

  /// Date-only on the wire (`YYYY-MM-DD`); kept at local midnight.
  final DateTime reportDate;
  final String? summary;
  final int? overallProgressPercent;
  final List<StageEntry> stageEntries;
  final DateTime createdAt;

  /// The backend schema (`ProgressReportPublic`) doesn't currently expose an
  /// `updated_at` field — reports are immutable once created, so this falls
  /// back to [createdAt] when absent from the response.
  final DateTime updatedAt;

  factory ProgressReport.fromJson(Map<String, dynamic> json) {
    final createdAt = DateTime.parse(json['created_at'] as String);
    final updatedAtRaw = json['updated_at'] as String?;
    return ProgressReport(
      id: json['id'] as String,
      companyId: json['company_id'] as String,
      projectId: json['project_id'] as String,
      submittedByUserId: json['submitted_by_user_id'] as String?,
      reportDate: DateTime.parse(json['report_date'] as String),
      summary: json['summary'] as String?,
      overallProgressPercent: json['overall_progress_percent'] as int?,
      stageEntries: (json['stage_entries'] as List<dynamic>? ?? [])
          .map((e) => StageEntry.fromJson(e as Map<String, dynamic>))
          .toList(),
      createdAt: createdAt,
      updatedAt: updatedAtRaw == null ? createdAt : DateTime.parse(updatedAtRaw),
    );
  }
}

/// Mirrors `backend/app/schemas/progress_report.py::ProgressPhotoPublic`.
/// Returned by both the per-project `/progress-reports/timeline` feed and
/// (implicitly) by `POST /progress-reports/{id}/photos`.
class ProgressPhotoEntry {
  const ProgressPhotoEntry({
    required this.id,
    required this.projectId,
    required this.reportId,
    this.userId,
    required this.photoUrl,
    this.caption,
    required this.createdAt,
  });

  final String id;
  final String projectId;
  final String reportId;
  final String? userId;
  final String photoUrl;
  final String? caption;
  final DateTime createdAt;

  factory ProgressPhotoEntry.fromJson(Map<String, dynamic> json) {
    return ProgressPhotoEntry(
      id: json['id'] as String,
      projectId: json['project_id'] as String,
      reportId: json['report_id'] as String,
      userId: json['user_id'] as String?,
      photoUrl: json['photo_url'] as String,
      caption: json['caption'] as String?,
      createdAt: DateTime.parse(json['created_at'] as String),
    );
  }
}
