// Golden test for `DashboardPage`
// (mobile/lib/features/dashboard/presentation/dashboard_page.dart) — the
// representative full page picked for Task 6 of
// .claude/plans/premium-responsive-ui-pass.plan.md, verifying the
// token/spacing pass (Task 5) and the responsive grid column count
// (2 columns compact, 4 columns medium/expanded) render correctly at all
// three window size classes.
//
// Run `flutter test --update-goldens test/golden/` once to generate the
// baseline PNGs under test/golden/goldens/, then `flutter test test/golden/`
// (no flag) to confirm they pass without regeneration.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/core/auth/role_permissions.dart';
import 'package:mobile/core/di/injection.dart';
import 'package:mobile/core/theme/app_theme.dart';
import 'package:mobile/features/dashboard/bloc/dashboard_bloc.dart';
import 'package:mobile/features/dashboard/data/dashboard_models.dart';
import 'package:mobile/features/dashboard/data/dashboard_repository.dart';
import 'package:mobile/features/dashboard/presentation/dashboard_page.dart';
import 'package:mocktail/mocktail.dart';

class _MockDashboardRepository extends Mock implements DashboardRepository {}

const _summary = DashboardSummary(
  role: Role.projectEngineer,
  myOpenTasks: 4,
  myOverdueTasks: 1,
  myOpenIssues: 2,
  visibleProjectCount: 3,
  unreadNotifications: 5,
  pendingTaskApprovals: 7,
  teamStatusCounts: {'on_site': 3, 'off_site': 1},
);

Future<void> _pumpDashboardAt(WidgetTester tester, Size size) async {
  await tester.binding.setSurfaceSize(size);
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  addTearDown(() => tester.binding.setSurfaceSize(null));

  final repository = _MockDashboardRepository();
  when(() => repository.getMyDashboard()).thenAnswer((_) async => _summary);
  getIt.registerFactory<DashboardBloc>(() => DashboardBloc(repository));
  addTearDown(() => getIt.unregister<DashboardBloc>());

  await tester.pumpWidget(
    MaterialApp(theme: AppTheme.light(), home: const DashboardPage()),
  );
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('DashboardPage at compact width (2-column grid)', (
    tester,
  ) async {
    await _pumpDashboardAt(tester, const Size(390, 844));

    await expectLater(
      find.byType(DashboardPage),
      matchesGoldenFile('goldens/dashboard_page_compact.png'),
    );
  });

  testWidgets('DashboardPage at medium width (4-column grid)', (
    tester,
  ) async {
    await _pumpDashboardAt(tester, const Size(700, 900));

    await expectLater(
      find.byType(DashboardPage),
      matchesGoldenFile('goldens/dashboard_page_medium.png'),
    );
  });

  testWidgets('DashboardPage at expanded width (4-column grid)', (
    tester,
  ) async {
    await _pumpDashboardAt(tester, const Size(1280, 900));

    await expectLater(
      find.byType(DashboardPage),
      matchesGoldenFile('goldens/dashboard_page_expanded.png'),
    );
  });
}
