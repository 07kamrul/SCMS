import 'package:equatable/equatable.dart';

/// Events consumed by [TrackingBloc].
sealed class TrackingEvent extends Equatable {
  const TrackingEvent();

  @override
  List<Object?> get props => [];
}

/// Fired once when the tracking page is first shown. Reads locally-recorded
/// consent, checks whether the foreground service is already running, and —
/// if consent has been given — fetches the current status and starts
/// polling it.
final class TrackingStarted extends TrackingEvent {
  const TrackingStarted();
}

/// User tapped the consent action. Calls `POST /locations/consent`, persists
/// the result locally (see `consent_storage.dart`), then behaves like
/// [TrackingStarted] having just learned consent is now given.
final class TrackingConsentRequested extends TrackingEvent {
  const TrackingConsentRequested();
}

/// User tapped "start sharing". Requests location (and, on Android,
/// background-location) permission if needed, then starts the persistent
/// foreground service.
final class TrackingStartRequested extends TrackingEvent {
  const TrackingStartRequested();
}

/// User tapped "stop sharing". Stops the foreground service and its
/// notification.
final class TrackingStopRequested extends TrackingEvent {
  const TrackingStopRequested();
}

/// Internal: fired on a timer and by pull-to-refresh to reload the caller's
/// own current [LocationStatus] from `GET /locations/me`.
final class TrackingStatusRefreshed extends TrackingEvent {
  const TrackingStatusRefreshed();
}
