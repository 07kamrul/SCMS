import 'dart:async';

import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:mobile/core/network/api_exception.dart';

import '../data/issue_models.dart';
import '../data/issue_repository.dart';
import 'issue_detail_event.dart';
import 'issue_detail_state.dart';

/// Loads an issue together with its status history, comments, and photos,
/// and applies all mutations (status/priority/category/assignee changes,
/// new comments, recorded photos) against that same issue.
class IssueDetailBloc extends Bloc<IssueDetailEvent, IssueDetailState> {
  IssueDetailBloc(this._issueRepository) : super(const IssueDetailState()) {
    on<IssueDetailStarted>(_onStarted);
    on<IssueDetailRefreshed>(_onRefreshed);
    on<IssueDetailStatusChanged>(_onStatusChanged);
    on<IssueDetailPriorityChanged>(_onPriorityChanged);
    on<IssueDetailCategoryChanged>(_onCategoryChanged);
    on<IssueDetailAssigneeChanged>(_onAssigneeChanged);
    on<IssueDetailCommentAdded>(_onCommentAdded);
    on<IssueDetailPhotoAttached>(_onPhotoAttached);
  }

  final IssueRepository _issueRepository;

  /// Set on [IssueDetailStarted] and reused by every subsequent mutation —
  /// the id never changes for the lifetime of this bloc instance.
  String? _issueId;

  Future<void> _onStarted(
    IssueDetailStarted event,
    Emitter<IssueDetailState> emit,
  ) async {
    _issueId = event.issueId;
    emit(state.copyWith(status: IssueDetailStatus.loading));
    await _loadAll(emit);
  }

  Future<void> _onRefreshed(
    IssueDetailRefreshed event,
    Emitter<IssueDetailState> emit,
  ) async {
    await _loadAll(emit);
  }

  Future<void> _loadAll(Emitter<IssueDetailState> emit) async {
    final issueId = _issueId;
    if (issueId == null) return;
    try {
      final Issue issue;
      final List<IssueStatusHistoryEntry> history;
      final List<IssueComment> comments;
      final List<IssuePhoto> photos;
      (issue, history, comments, photos) = await (
        _issueRepository.getById(issueId),
        _issueRepository.history(issueId),
        _issueRepository.listComments(issueId),
        _issueRepository.listPhotos(issueId),
      ).wait;
      emit(
        state.copyWith(
          status: IssueDetailStatus.success,
          issue: issue,
          history: history,
          comments: comments,
          photos: photos,
          isMutating: false,
        ),
      );
    } on ApiException catch (e) {
      emit(
        state.copyWith(status: IssueDetailStatus.failure, errorMessage: e.message),
      );
    }
  }

  Future<void> _onStatusChanged(
    IssueDetailStatusChanged event,
    Emitter<IssueDetailState> emit,
  ) async {
    await _mutate(
      emit,
      () => _issueRepository.update(
        _issueId!,
        status: event.status,
        note: event.note,
      ),
      reloadHistory: true,
    );
  }

  Future<void> _onPriorityChanged(
    IssueDetailPriorityChanged event,
    Emitter<IssueDetailState> emit,
  ) async {
    await _mutate(
      emit,
      () => _issueRepository.update(_issueId!, priority: event.priority),
    );
  }

  Future<void> _onCategoryChanged(
    IssueDetailCategoryChanged event,
    Emitter<IssueDetailState> emit,
  ) async {
    await _mutate(
      emit,
      () => _issueRepository.update(_issueId!, category: event.category),
    );
  }

  Future<void> _onAssigneeChanged(
    IssueDetailAssigneeChanged event,
    Emitter<IssueDetailState> emit,
  ) async {
    await _mutate(
      emit,
      () => _issueRepository.update(
        _issueId!,
        assignedToUserId: event.userId,
      ),
    );
  }

  /// Shared path for the four issue-field mutations above: apply the
  /// update, swap in the returned issue, and optionally reload history
  /// (only status changes create a history entry).
  Future<void> _mutate(
    Emitter<IssueDetailState> emit,
    Future<dynamic> Function() update, {
    bool reloadHistory = false,
  }) async {
    final issueId = _issueId;
    if (issueId == null) return;
    emit(state.copyWith(isMutating: true));
    try {
      final updatedIssue = await update();
      final history = reloadHistory
          ? await _issueRepository.history(issueId)
          : state.history;
      emit(
        state.copyWith(
          status: IssueDetailStatus.success,
          issue: updatedIssue,
          history: history,
          isMutating: false,
        ),
      );
    } on ApiException catch (e) {
      emit(state.copyWith(isMutating: false, errorMessage: e.message));
    }
  }

  Future<void> _onCommentAdded(
    IssueDetailCommentAdded event,
    Emitter<IssueDetailState> emit,
  ) async {
    final issueId = _issueId;
    if (issueId == null) return;
    emit(state.copyWith(isMutating: true));
    try {
      final comment = await _issueRepository.addComment(issueId, event.body);
      emit(
        state.copyWith(
          comments: [...state.comments, comment],
          isMutating: false,
        ),
      );
    } on ApiException catch (e) {
      emit(state.copyWith(isMutating: false, errorMessage: e.message));
    }
  }

  /// [PhotoPickerField] has already done presign+PUT+attach as one call by
  /// the time this event fires (see `UploadRepository.captureUploadAndAttach`)
  /// — this just appends the server-confirmed photo, no repository call.
  void _onPhotoAttached(
    IssueDetailPhotoAttached event,
    Emitter<IssueDetailState> emit,
  ) {
    emit(state.copyWith(photos: [...state.photos, event.photo]));
  }
}
