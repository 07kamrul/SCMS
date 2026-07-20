import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../core/network/api_exception.dart';
import '../data/notification_repository.dart';
import 'notifications_list_event.dart';
import 'notifications_list_state.dart';

/// Loads, paginates, and mark-reads the current user's notification list.
/// Mirrors `TasksListBloc`'s pagination pattern.
class NotificationsListBloc
    extends Bloc<NotificationsListEvent, NotificationsListState> {
  NotificationsListBloc(this._repository)
    : super(const NotificationsListState()) {
    on<NotificationsListSubscriptionRequested>(_onSubscriptionRequested);
    on<NotificationsListRefreshed>(_onRefreshed);
    on<NotificationsListNextPageRequested>(_onNextPageRequested);
    on<NotificationsListUnreadOnlyToggled>(_onUnreadOnlyToggled);
    on<NotificationsListMarkReadRequested>(_onMarkReadRequested);
  }

  final NotificationRepository _repository;

  Future<void> _onSubscriptionRequested(
    NotificationsListSubscriptionRequested event,
    Emitter<NotificationsListState> emit,
  ) async {
    emit(NotificationsListState(unreadOnly: event.unreadOnly, isLoading: true));
    await _loadFirstPage(emit);
  }

  Future<void> _onRefreshed(
    NotificationsListRefreshed event,
    Emitter<NotificationsListState> emit,
  ) async {
    emit(state.copyWith(isLoading: true, errorMessage: null));
    await _loadFirstPage(emit);
  }

  Future<void> _onUnreadOnlyToggled(
    NotificationsListUnreadOnlyToggled event,
    Emitter<NotificationsListState> emit,
  ) async {
    emit(
      state.copyWith(
        unreadOnly: event.unreadOnly,
        isLoading: true,
        errorMessage: null,
      ),
    );
    await _loadFirstPage(emit);
  }

  Future<void> _onNextPageRequested(
    NotificationsListNextPageRequested event,
    Emitter<NotificationsListState> emit,
  ) async {
    if (state.isLoading || state.isLoadingMore || !state.hasMore) return;
    emit(state.copyWith(isLoadingMore: true, errorMessage: null));
    final nextPage = state.page + 1;
    try {
      final (notifications, total) = await _repository.listMine(
        unreadOnly: state.unreadOnly,
        page: nextPage,
        pageSize: state.pageSize,
      );
      emit(
        state.copyWith(
          notifications: [...state.notifications, ...notifications],
          page: nextPage,
          total: total,
          isLoadingMore: false,
        ),
      );
    } on ApiException catch (e) {
      emit(state.copyWith(isLoadingMore: false, errorMessage: e.message));
    }
  }

  Future<void> _onMarkReadRequested(
    NotificationsListMarkReadRequested event,
    Emitter<NotificationsListState> emit,
  ) async {
    try {
      final updated = await _repository.markRead(event.notificationId);
      emit(
        state.copyWith(
          notifications: [
            for (final notification in state.notifications)
              if (notification.id == updated.id) updated else notification,
          ],
        ),
      );
    } on ApiException catch (e) {
      emit(state.copyWith(errorMessage: e.message));
    }
  }

  Future<void> _loadFirstPage(Emitter<NotificationsListState> emit) async {
    try {
      final (notifications, total) = await _repository.listMine(
        unreadOnly: state.unreadOnly,
        page: 1,
        pageSize: state.pageSize,
      );
      emit(
        state.copyWith(
          notifications: notifications,
          page: 1,
          total: total,
          isLoading: false,
        ),
      );
    } on ApiException catch (e) {
      emit(state.copyWith(isLoading: false, errorMessage: e.message));
    }
  }
}
