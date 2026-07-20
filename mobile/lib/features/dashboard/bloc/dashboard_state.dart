import 'package:equatable/equatable.dart';

import '../data/dashboard_models.dart';

/// States emitted by [DashboardBloc].
sealed class DashboardState extends Equatable {
  const DashboardState();

  @override
  List<Object?> get props => [];
}

/// Before the first load has run.
final class DashboardInitial extends DashboardState {
  const DashboardInitial();
}

final class DashboardLoading extends DashboardState {
  const DashboardLoading();
}

final class DashboardLoaded extends DashboardState {
  const DashboardLoaded(this.summary);

  final DashboardSummary summary;

  @override
  List<Object?> get props => [summary];
}

final class DashboardFailure extends DashboardState {
  const DashboardFailure(this.message);

  final String message;

  @override
  List<Object?> get props => [message];
}
