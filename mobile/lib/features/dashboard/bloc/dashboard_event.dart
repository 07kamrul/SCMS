import 'package:equatable/equatable.dart';

/// Events consumed by [DashboardBloc].
sealed class DashboardEvent extends Equatable {
  const DashboardEvent();

  @override
  List<Object?> get props => [];
}

/// Fired when the dashboard page is first shown, and again on
/// pull-to-refresh — always (re)loads the full summary from scratch.
final class DashboardRequested extends DashboardEvent {
  const DashboardRequested();
}
