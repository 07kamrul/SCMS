import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:mobile/core/auth/permission.dart';
import 'package:mobile/core/auth/role_permissions.dart';
import 'package:mobile/features/auth/bloc/auth_bloc.dart';
import 'package:mobile/features/auth/bloc/auth_state.dart';
import 'package:mobile/shared/widgets/responsive_scaffold.dart';

class _NavDestination {
  const _NavDestination(this.path, this.icon, this.label);

  final String path;
  final IconData icon;
  final String label;
}

/// Which tabs a role sees is derived entirely from [rolePermissions] — the
/// same source of truth the backend enforces against — rather than a
/// hand-maintained per-role tab list that could drift out of sync.
List<_NavDestination> _destinationsFor(Role role) {
  final destinations = <_NavDestination>[
    const _NavDestination('/dashboard', Icons.dashboard_outlined, 'Home'),
  ];
  if (hasPermission(role, Permission.projectViewAll) ||
      hasPermission(role, Permission.projectViewAssigned)) {
    destinations.add(
      const _NavDestination('/projects', Icons.map_outlined, 'Projects'),
    );
  }
  if (hasPermission(role, Permission.userView)) {
    destinations.add(
      const _NavDestination('/team', Icons.people_outline, 'Team'),
    );
  }
  if (hasPermission(role, Permission.taskView) ||
      hasPermission(role, Permission.taskCreate)) {
    destinations.add(
      const _NavDestination('/tasks', Icons.checklist_outlined, 'Tasks'),
    );
  }
  if (hasPermission(role, Permission.issueView) ||
      hasPermission(role, Permission.issueCreate)) {
    destinations.add(
      const _NavDestination(
        '/issues',
        Icons.report_problem_outlined,
        'Issues',
      ),
    );
  }
  if (hasPermission(role, Permission.trackingViewSelf) ||
      hasPermission(role, Permission.trackingViewAssigned) ||
      hasPermission(role, Permission.trackingViewAll)) {
    destinations.add(
      const _NavDestination(
        '/tracking',
        Icons.location_on_outlined,
        'Tracking',
      ),
    );
  }
  destinations.add(
    const _NavDestination('/profile', Icons.person_outline, 'Profile'),
  );
  return destinations;
}

/// Bottom-nav shell for every authenticated route, wrapping [child] (the
/// current tab's page, which brings its own `AppBar`/`Scaffold` — nesting a
/// bare-bones outer `Scaffold` here for just the nav bar is intentional and
/// standard for a `ShellRoute`).
class RoleNavScaffold extends StatelessWidget {
  const RoleNavScaffold({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final authState = context.watch<AuthBloc>().state;
    if (authState is! AuthAuthenticated) return child;

    final destinations = _destinationsFor(authState.user.role);
    final location = GoRouterState.of(context).uri.toString();
    var currentIndex = destinations.indexWhere(
      (d) => location.startsWith(d.path),
    );
    if (currentIndex == -1) currentIndex = 0;
    void onSelect(int index) => context.go(destinations[index].path);

    return ResponsiveScaffold(
      compact: (context) => Scaffold(
        body: child,
        bottomNavigationBar: NavigationBar(
          selectedIndex: currentIndex,
          onDestinationSelected: onSelect,
          destinations: [
            for (final destination in destinations)
              NavigationDestination(
                icon: Icon(destination.icon),
                label: destination.label,
              ),
          ],
        ),
      ),
      expanded: (context) => Scaffold(
        body: Row(
          children: [
            NavigationRail(
              selectedIndex: currentIndex,
              onDestinationSelected: onSelect,
              labelType: NavigationRailLabelType.all,
              destinations: [
                for (final destination in destinations)
                  NavigationRailDestination(
                    icon: Icon(destination.icon),
                    label: Text(destination.label),
                  ),
              ],
            ),
            const VerticalDivider(width: 1),
            Expanded(child: child),
          ],
        ),
      ),
    );
  }
}
