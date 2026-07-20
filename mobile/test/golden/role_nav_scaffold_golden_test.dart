// Golden test for `RoleNavScaffold`
// (mobile/lib/shared/widgets/role_nav_scaffold.dart) — the navigation shell
// every authenticated page composes through, and the specific widget Task 4
// of .claude/plans/premium-responsive-ui-pass.plan.md made breakpoint-aware
// (bottom `NavigationBar` on compact/medium, side `NavigationRail` on
// expanded). This verifies both layouts render as intended.
//
// Run `flutter test --update-goldens test/golden/` once to generate the
// baseline PNGs under test/golden/goldens/, then `flutter test test/golden/`
// (no flag) to confirm they pass without regeneration.
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:mobile/core/auth/role_permissions.dart';
import 'package:mobile/core/theme/app_theme.dart';
import 'package:mobile/features/auth/bloc/auth_bloc.dart';
import 'package:mobile/features/auth/bloc/auth_event.dart';
import 'package:mobile/features/auth/bloc/auth_state.dart';
import 'package:mobile/features/auth/data/auth_models.dart';
import 'package:mobile/shared/widgets/role_nav_scaffold.dart';

/// A minimal, test-only [AuthBloc] substitute seeded with a fixed state and
/// no registered event handlers — avoids constructing the real bloc's
/// `AuthRepository`/`SecureTokenStorage` dependencies, which this golden
/// test has no need to exercise.
class _FixedAuthBloc extends Bloc<AuthEvent, AuthState> implements AuthBloc {
  _FixedAuthBloc(super.state);
}

const _testUser = UserPublic(
  id: 'user-1',
  companyId: 'company-1',
  fullName: 'Jordan Rivera',
  email: 'jordan@example.com',
  role: Role.companyOwner,
  status: UserStatus.active,
  isIdentityVerified: true,
);

Widget _buildApp(AuthBloc bloc) {
  final router = GoRouter(
    initialLocation: '/dashboard',
    routes: [
      ShellRoute(
        builder: (context, state, child) => RoleNavScaffold(child: child),
        routes: [
          GoRoute(
            path: '/dashboard',
            builder: (context, state) =>
                const Scaffold(body: Center(child: Text('Dashboard'))),
          ),
        ],
      ),
    ],
  );

  return BlocProvider<AuthBloc>.value(
    value: bloc,
    child: MaterialApp.router(theme: AppTheme.light(), routerConfig: router),
  );
}

void main() {
  testWidgets('RoleNavScaffold shows bottom NavigationBar at compact width', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(390, 844));
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(() => tester.binding.setSurfaceSize(null));

    final bloc = _FixedAuthBloc(const AuthAuthenticated(_testUser));
    addTearDown(bloc.close);

    await tester.pumpWidget(_buildApp(bloc));
    await tester.pumpAndSettle();

    expect(find.byType(NavigationBar), findsOneWidget);
    expect(find.byType(NavigationRail), findsNothing);

    await expectLater(
      find.byType(MaterialApp),
      matchesGoldenFile('goldens/role_nav_scaffold_compact.png'),
    );
  });

  testWidgets('RoleNavScaffold shows side NavigationRail at expanded width', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(1280, 800));
    tester.view.physicalSize = const Size(1280, 800);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(() => tester.binding.setSurfaceSize(null));

    final bloc = _FixedAuthBloc(const AuthAuthenticated(_testUser));
    addTearDown(bloc.close);

    await tester.pumpWidget(_buildApp(bloc));
    await tester.pumpAndSettle();

    expect(find.byType(NavigationRail), findsOneWidget);
    expect(find.byType(NavigationBar), findsNothing);

    await expectLater(
      find.byType(MaterialApp),
      matchesGoldenFile('goldens/role_nav_scaffold_expanded.png'),
    );
  });
}
