import 'package:equatable/equatable.dart';

import '../data/location_models.dart';

/// State for [TeamMapBloc].
class TeamMapState extends Equatable {
  const TeamMapState({
    this.members = const [],
    this.isLoading = false,
    this.error,
  });

  final List<TeamMemberStatus> members;
  final bool isLoading;
  final String? error;

  @override
  List<Object?> get props => [members, isLoading, error];
}
