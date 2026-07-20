import 'package:equatable/equatable.dart';

import '../data/notification_models.dart';

/// Sentinel used by [NotificationsListState.copyWith] so [errorMessage] can
/// be explicitly cleared (set to `null`) as opposed to left unchanged.
const Object _unset = Object();

/// Single state for the notifications list page: current page of
/// [notifications], the unread-only filter, and pagination/loading flags.
class NotificationsListState extends Equatable {
  const NotificationsListState({
    this.unreadOnly = false,
    this.notifications = const [],
    this.page = 1,
    this.pageSize = 20,
    this.total = 0,
    this.isLoading = false,
    this.isLoadingMore = false,
    this.errorMessage,
  });

  final bool unreadOnly;
  final List<AppNotification> notifications;
  final int page;
  final int pageSize;
  final int total;

  /// True while loading page 1 (initial load, refresh, or filter change).
  final bool isLoading;

  /// True while appending a subsequent page.
  final bool isLoadingMore;

  final String? errorMessage;

  bool get hasMore => notifications.length < total;

  NotificationsListState copyWith({
    bool? unreadOnly,
    List<AppNotification>? notifications,
    int? page,
    int? pageSize,
    int? total,
    bool? isLoading,
    bool? isLoadingMore,
    Object? errorMessage = _unset,
  }) {
    return NotificationsListState(
      unreadOnly: unreadOnly ?? this.unreadOnly,
      notifications: notifications ?? this.notifications,
      page: page ?? this.page,
      pageSize: pageSize ?? this.pageSize,
      total: total ?? this.total,
      isLoading: isLoading ?? this.isLoading,
      isLoadingMore: isLoadingMore ?? this.isLoadingMore,
      errorMessage: identical(errorMessage, _unset)
          ? this.errorMessage
          : errorMessage as String?,
    );
  }

  @override
  List<Object?> get props => [
    unreadOnly,
    notifications,
    page,
    pageSize,
    total,
    isLoading,
    isLoadingMore,
    errorMessage,
  ];
}
