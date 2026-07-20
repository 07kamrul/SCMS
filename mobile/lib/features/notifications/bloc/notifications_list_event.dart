import 'package:equatable/equatable.dart';

/// Events consumed by [NotificationsListBloc].
sealed class NotificationsListEvent extends Equatable {
  const NotificationsListEvent();

  @override
  List<Object?> get props => [];
}

/// Fired once when the list page is first shown. Resets any previous
/// pagination and loads page 1.
final class NotificationsListSubscriptionRequested
    extends NotificationsListEvent {
  const NotificationsListSubscriptionRequested({this.unreadOnly = false});

  final bool unreadOnly;

  @override
  List<Object?> get props => [unreadOnly];
}

/// Pull-to-refresh: reloads page 1 with the current filter.
final class NotificationsListRefreshed extends NotificationsListEvent {
  const NotificationsListRefreshed();
}

/// Infinite-scroll: loads the next page and appends it to the current list.
final class NotificationsListNextPageRequested
    extends NotificationsListEvent {
  const NotificationsListNextPageRequested();
}

/// Toggles the "unread only" filter and reloads from page 1.
final class NotificationsListUnreadOnlyToggled
    extends NotificationsListEvent {
  const NotificationsListUnreadOnlyToggled(this.unreadOnly);

  final bool unreadOnly;

  @override
  List<Object?> get props => [unreadOnly];
}

/// Marks a single notification read (e.g. on tap) and reflects the result
/// in-place in [NotificationsListState.notifications].
final class NotificationsListMarkReadRequested
    extends NotificationsListEvent {
  const NotificationsListMarkReadRequested(this.notificationId);

  final String notificationId;

  @override
  List<Object?> get props => [notificationId];
}
