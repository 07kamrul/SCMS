import 'package:equatable/equatable.dart';

/// Events consumed by [TeamMapBloc].
sealed class TeamMapEvent extends Equatable {
  const TeamMapEvent();

  @override
  List<Object?> get props => [];
}

/// Fired to (re)load every team member visible to the caller's
/// tracking-permission tier, for the manager live map. Used both for the
/// initial load and for pull-to-refresh.
final class TeamMapRequested extends TeamMapEvent {
  const TeamMapRequested();
}
