import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:mobile/core/network/api_exception.dart';

import '../data/dashboard_repository.dart';
import 'dashboard_event.dart';
import 'dashboard_state.dart';

/// Loads the role-tailored `GET /dashboard/me` summary. Single-fetch bloc —
/// mirrors `PhotoTimelineBloc`'s lean shape (no pagination, no filters).
class DashboardBloc extends Bloc<DashboardEvent, DashboardState> {
  DashboardBloc(this._repository) : super(const DashboardInitial()) {
    on<DashboardRequested>(_onRequested);
  }

  final DashboardRepository _repository;

  Future<void> _onRequested(
    DashboardRequested event,
    Emitter<DashboardState> emit,
  ) async {
    emit(const DashboardLoading());
    try {
      final summary = await _repository.getMyDashboard();
      emit(DashboardLoaded(summary));
    } on ApiException catch (e) {
      emit(DashboardFailure(e.message));
    }
  }
}
