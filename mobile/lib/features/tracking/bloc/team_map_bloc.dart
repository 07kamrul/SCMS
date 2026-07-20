import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:mobile/core/network/api_exception.dart';

import '../data/location_repository.dart';
import 'team_map_event.dart';
import 'team_map_state.dart';

/// Loads `GET /locations/team` for the manager live map: every team member
/// visible to the caller's tracking-permission tier, each with their own
/// [LocationStatus] and last-known position.
class TeamMapBloc extends Bloc<TeamMapEvent, TeamMapState> {
  TeamMapBloc(this._locationRepository) : super(const TeamMapState()) {
    on<TeamMapRequested>(_onRequested);
  }

  final LocationRepository _locationRepository;

  Future<void> _onRequested(
    TeamMapRequested event,
    Emitter<TeamMapState> emit,
  ) async {
    emit(TeamMapState(members: state.members, isLoading: true));
    try {
      final members = await _locationRepository.teamStatus();
      emit(TeamMapState(members: members, isLoading: false));
    } on ApiException catch (e) {
      emit(
        TeamMapState(members: state.members, isLoading: false, error: e.message),
      );
    }
  }
}
