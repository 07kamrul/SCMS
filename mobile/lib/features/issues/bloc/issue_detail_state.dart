import 'package:equatable/equatable.dart';

import '../data/issue_models.dart';

enum IssueDetailStatus { initial, loading, success, failure }

/// Combined state for [IssueDetailBloc]: the issue itself plus its status
/// history, comments, and photos, loaded together as one screen's worth of
/// data. [isMutating] covers in-flight status/priority/category/assignee
/// updates, comment posts, and photo recordings so the UI can disable
/// controls without hiding the data already on screen.
class IssueDetailState extends Equatable {
  const IssueDetailState({
    this.status = IssueDetailStatus.initial,
    this.issue,
    this.history = const [],
    this.comments = const [],
    this.photos = const [],
    this.isMutating = false,
    this.errorMessage,
  });

  final IssueDetailStatus status;
  final Issue? issue;
  final List<IssueStatusHistoryEntry> history;
  final List<IssueComment> comments;
  final List<IssuePhoto> photos;
  final bool isMutating;
  final String? errorMessage;

  IssueDetailState copyWith({
    IssueDetailStatus? status,
    Issue? issue,
    List<IssueStatusHistoryEntry>? history,
    List<IssueComment>? comments,
    List<IssuePhoto>? photos,
    bool? isMutating,
    String? errorMessage,
  }) {
    return IssueDetailState(
      status: status ?? this.status,
      issue: issue ?? this.issue,
      history: history ?? this.history,
      comments: comments ?? this.comments,
      photos: photos ?? this.photos,
      isMutating: isMutating ?? this.isMutating,
      errorMessage: errorMessage,
    );
  }

  @override
  List<Object?> get props => [
    status,
    issue,
    history,
    comments,
    photos,
    isMutating,
    errorMessage,
  ];
}
