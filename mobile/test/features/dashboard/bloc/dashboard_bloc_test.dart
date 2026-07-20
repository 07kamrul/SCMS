import 'package:bloc_test/bloc_test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/core/auth/permission.dart';
import 'package:mobile/core/network/api_exception.dart';
import 'package:mobile/features/dashboard/bloc/dashboard_bloc.dart';
import 'package:mobile/features/dashboard/bloc/dashboard_event.dart';
import 'package:mobile/features/dashboard/bloc/dashboard_state.dart';
import 'package:mobile/features/dashboard/data/dashboard_models.dart';
import 'package:mobile/features/dashboard/data/dashboard_repository.dart';
import 'package:mocktail/mocktail.dart';

class MockDashboardRepository extends Mock implements DashboardRepository {}

void main() {
  late MockDashboardRepository dashboardRepository;

  // Project Engineer: pending approvals + team status counts populated.
  const projectEngineerSummary = DashboardSummary(
    role: Role.projectEngineer,
    myOpenTasks: 4,
    myOverdueTasks: 1,
    myOpenIssues: 2,
    visibleProjectCount: 3,
    unreadNotifications: 5,
    pendingTaskApprovals: 7,
    teamStatusCounts: {'on_site': 3, 'off_site': 1},
  );

  // Employee: role that cannot approve tasks or view team tracking, so
  // both nullable fields come back null.
  const employeeSummary = DashboardSummary(
    role: Role.employee,
    myOpenTasks: 2,
    myOverdueTasks: 0,
    myOpenIssues: 1,
    visibleProjectCount: 1,
    unreadNotifications: 0,
  );

  setUp(() {
    dashboardRepository = MockDashboardRepository();
  });

  DashboardBloc buildBloc() => DashboardBloc(dashboardRepository);

  group('DashboardRequested', () {
    blocTest<DashboardBloc, DashboardState>(
      'emits [DashboardLoading, DashboardLoaded] with populated '
      'pendingTaskApprovals/teamStatusCounts for a role that holds those '
      'permissions',
      setUp: () {
        when(
          () => dashboardRepository.getMyDashboard(),
        ).thenAnswer((_) async => projectEngineerSummary);
      },
      build: buildBloc,
      act: (bloc) => bloc.add(const DashboardRequested()),
      expect: () => [
        const DashboardLoading(),
        const DashboardLoaded(projectEngineerSummary),
      ],
      verify: (_) {
        verify(() => dashboardRepository.getMyDashboard()).called(1);
      },
    );

    blocTest<DashboardBloc, DashboardState>(
      'emits [DashboardLoading, DashboardLoaded] with null '
      'pendingTaskApprovals/teamStatusCounts for a role without those '
      'permissions',
      setUp: () {
        when(
          () => dashboardRepository.getMyDashboard(),
        ).thenAnswer((_) async => employeeSummary);
      },
      build: buildBloc,
      act: (bloc) => bloc.add(const DashboardRequested()),
      expect: () => [
        const DashboardLoading(),
        const DashboardLoaded(employeeSummary),
      ],
      verify: (bloc) {
        final state = bloc.state as DashboardLoaded;
        expect(state.summary.pendingTaskApprovals, isNull);
        expect(state.summary.teamStatusCounts, isNull);
      },
    );

    blocTest<DashboardBloc, DashboardState>(
      'emits [DashboardLoading, DashboardFailure] when the repository '
      'throws an ApiException',
      setUp: () {
        when(() => dashboardRepository.getMyDashboard()).thenThrow(
          const ApiException(
            statusCode: 500,
            errorCode: 'server_error',
            message: 'Something went wrong.',
          ),
        );
      },
      build: buildBloc,
      act: (bloc) => bloc.add(const DashboardRequested()),
      expect: () => [
        const DashboardLoading(),
        const DashboardFailure('Something went wrong.'),
      ],
    );

    blocTest<DashboardBloc, DashboardState>(
      'refetches from scratch on a second DashboardRequested (e.g. '
      'pull-to-refresh)',
      setUp: () {
        when(
          () => dashboardRepository.getMyDashboard(),
        ).thenAnswer((_) async => projectEngineerSummary);
      },
      build: buildBloc,
      act: (bloc) {
        bloc.add(const DashboardRequested());
        bloc.add(const DashboardRequested());
      },
      expect: () => [
        const DashboardLoading(),
        const DashboardLoaded(projectEngineerSummary),
        const DashboardLoading(),
        const DashboardLoaded(projectEngineerSummary),
      ],
      verify: (_) {
        verify(() => dashboardRepository.getMyDashboard()).called(2);
      },
    );
  });
}
