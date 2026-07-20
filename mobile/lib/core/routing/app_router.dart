import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:mobile/core/auth/permission.dart';
import 'package:mobile/core/auth/role_permissions.dart';
import 'package:mobile/core/di/injection.dart';
import 'package:mobile/core/network/api_exception.dart';
import 'package:mobile/features/auth/bloc/auth_bloc.dart';
import 'package:mobile/features/auth/bloc/auth_state.dart';
import 'package:mobile/features/auth/presentation/login_page.dart';
import 'package:mobile/features/auth/presentation/register_company_page.dart';
import 'package:mobile/features/auth/presentation/splash_page.dart';
import 'package:mobile/features/dashboard/presentation/dashboard_page.dart';
import 'package:mobile/features/issues/bloc/issue_form_state.dart' show IssueAssignee;
import 'package:mobile/features/issues/presentation/issues_list_page.dart';
import 'package:mobile/features/profile/presentation/profile_page.dart';
import 'package:mobile/features/projects/presentation/my_projects_page.dart';
import 'package:mobile/features/projects/presentation/projects_list_page.dart';
import 'package:mobile/features/tasks/presentation/tasks_list_page.dart';
import 'package:mobile/features/team/data/team_repository.dart';
import 'package:mobile/features/team/presentation/team_list_page.dart';
import 'package:mobile/features/tracking/presentation/team_map_page.dart';
import 'package:mobile/features/tracking/presentation/tracking_consent_page.dart';
import 'package:mobile/shared/widgets/loading_view.dart';
import 'package:mobile/shared/widgets/role_nav_scaffold.dart';

/// Builds the app's single [GoRouter] instance.
///
/// This router only defines top-level destinations: the two unauthenticated
/// auth routes and the bottom-nav tabs. Sub-navigation within a feature
/// (detail/form pages) uses plain `Navigator.push` — the convention every
/// feature page already independently settled on — so it is intentionally
/// not duplicated here as named routes.
/// go_router's docs show this class as a snippet to copy into the app —
/// it is not exported by the `go_router` package itself, so it lives here.
/// Turns any [Stream] (here, [AuthBloc]'s state stream) into a
/// [Listenable] `GoRouter.refreshListenable` can react to.
class GoRouterRefreshStream extends ChangeNotifier {
  GoRouterRefreshStream(Stream<dynamic> stream) {
    _subscription = stream.asBroadcastStream().listen(
      (_) => notifyListeners(),
    );
  }

  late final StreamSubscription<dynamic> _subscription;

  @override
  void dispose() {
    _subscription.cancel();
    super.dispose();
  }
}

/// Built once, lazily, on first access (top-level `final`s in Dart are
/// lazy) — must not be rebuilt per `ScfmsApp.build()` call, since a new
/// [GoRouter] would lose navigation state and re-subscribe to
/// [AuthBloc]'s stream on every rebuild.
final appRouter = buildAppRouter();

GoRouter buildAppRouter() {
  final authBloc = getIt<AuthBloc>();

  return GoRouter(
    initialLocation: '/',
    refreshListenable: GoRouterRefreshStream(authBloc.stream),
    redirect: (context, state) {
      final authState = authBloc.state;
      final location = state.matchedLocation;
      final isAuthRoute = location == '/login' || location == '/register-company';
      final isSplash = location == '/';

      if (authState is AuthInitial || authState is AuthLoading) {
        return isSplash ? null : '/';
      }
      if (authState is AuthAuthenticated) {
        return (isAuthRoute || isSplash) ? '/dashboard' : null;
      }
      return isAuthRoute ? null : '/login';
    },
    routes: [
      GoRoute(path: '/', builder: (context, state) => const SplashPage()),
      GoRoute(path: '/login', builder: (context, state) => const LoginPage()),
      GoRoute(
        path: '/register-company',
        builder: (context, state) => const RegisterCompanyPage(),
      ),
      ShellRoute(
        builder: (context, state, child) => RoleNavScaffold(child: child),
        routes: [
          GoRoute(
            path: '/dashboard',
            builder: (context, state) => const DashboardPage(),
          ),
          GoRoute(path: '/projects', builder: (context, state) => const _ProjectsTab()),
          GoRoute(path: '/team', builder: (context, state) => const _TeamTab()),
          GoRoute(path: '/tasks', builder: (context, state) => const _TasksTab()),
          GoRoute(path: '/issues', builder: (context, state) => const _IssuesTab()),
          GoRoute(path: '/tracking', builder: (context, state) => const _TrackingTab()),
          GoRoute(path: '/profile', builder: (context, state) => const _ProfileTab()),
        ],
      ),
    ],
  );
}

Role? _currentRole(BuildContext context) {
  final state = context.watch<AuthBloc>().state;
  return state is AuthAuthenticated ? state.user.role : null;
}

class _ProjectsTab extends StatelessWidget {
  const _ProjectsTab();

  @override
  Widget build(BuildContext context) {
    final role = _currentRole(context);
    if (role == null) return const LoadingView();
    final canEdit = hasPermission(role, Permission.projectUpdate);
    if (hasPermission(role, Permission.projectViewAll)) {
      return ProjectsListPage(
        canCreate: hasPermission(role, Permission.projectCreate),
        canEditProjects: canEdit,
      );
    }
    return MyProjectsPage(canEditProjects: canEdit);
  }
}

class _TeamTab extends StatelessWidget {
  const _TeamTab();

  @override
  Widget build(BuildContext context) {
    final role = _currentRole(context);
    if (role == null) return const LoadingView();
    return TeamListPage(
      canCreateUser: hasPermission(role, Permission.userCreate),
      canUpdateUser: hasPermission(role, Permission.userUpdate),
      canDeactivateUsers: hasPermission(role, Permission.userDeactivate),
      canManageAssignments: hasPermission(role, Permission.assignmentManage),
    );
  }
}

class _TasksTab extends StatelessWidget {
  const _TasksTab();

  @override
  Widget build(BuildContext context) {
    final role = _currentRole(context);
    if (role == null) return const LoadingView();
    return TasksListPage(
      canCreate: hasPermission(role, Permission.taskCreate),
      canApprove: hasPermission(role, Permission.taskApprove),
      canReassign: hasPermission(role, Permission.taskCreate),
    );
  }
}

class _IssuesTab extends StatefulWidget {
  const _IssuesTab();

  @override
  State<_IssuesTab> createState() => _IssuesTabState();
}

class _IssuesTabState extends State<_IssuesTab> {
  late final Future<List<IssueAssignee>> _assignableUsers = _loadAssignableUsers();

  static Future<List<IssueAssignee>> _loadAssignableUsers() async {
    try {
      final page = await getIt<TeamRepository>().listUsers(pageSize: 100);
      return [
        for (final user in page.users)
          IssueAssignee(id: user.id, displayName: user.fullName),
      ];
    } on ApiException {
      // Best-effort: the issue form/list still work, just without an
      // assignee picker, if the roster fetch fails.
      return const [];
    }
  }

  @override
  Widget build(BuildContext context) {
    final role = _currentRole(context);
    if (role == null) return const LoadingView();
    return FutureBuilder<List<IssueAssignee>>(
      future: _assignableUsers,
      builder: (context, snapshot) {
        if (!snapshot.hasData) return const LoadingView();
        return IssuesListPage(
          canCreate: hasPermission(role, Permission.issueCreate),
          canUpdateIssues: hasPermission(role, Permission.issueUpdate),
          canUploadPhoto: hasPermission(role, Permission.photoUpload),
          assignableUsers: snapshot.data!,
        );
      },
    );
  }
}

class _TrackingTab extends StatelessWidget {
  const _TrackingTab();

  @override
  Widget build(BuildContext context) {
    final role = _currentRole(context);
    if (role == null) return const LoadingView();
    // A manager who can view the team map but not their own status (e.g.
    // HR Admin) goes straight to the team map; everyone with a self-status
    // permission sees their own consent/indicator page (which also links
    // to the team map for roles that hold both permissions).
    if (hasPermission(role, Permission.trackingViewSelf)) {
      return const TrackingConsentPage();
    }
    return const TeamMapPage();
  }
}

class _ProfileTab extends StatelessWidget {
  const _ProfileTab();

  @override
  Widget build(BuildContext context) {
    final role = _currentRole(context);
    if (role == null) return const LoadingView();
    return ProfilePage(
      canViewCompanySettings: hasPermission(role, Permission.companyView),
      canManageCompanySettings: hasPermission(
        role,
        Permission.companyManageSettings,
      ),
    );
  }
}
