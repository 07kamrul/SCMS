import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:mobile/core/auth/permission.dart';
import 'package:mobile/features/auth/bloc/auth_bloc.dart';
import 'package:mobile/features/auth/bloc/auth_event.dart';
import 'package:mobile/features/auth/bloc/auth_state.dart';
import 'package:mobile/features/auth/data/auth_models.dart';
import 'package:mobile/features/auth/presentation/change_password_page.dart';
import 'package:mobile/core/theme/app_spacing.dart';
import 'package:mobile/shared/widgets/loading_view.dart';
import 'package:mobile/shared/widgets/responsive_scaffold.dart';

import 'company_settings_page.dart';

const double _kMaxContentWidth = 480;

/// Human-readable labels for the 5 fixed product roles. Kept local to this
/// feature since no shared label helper exists yet on [Role] itself.
extension _RoleLabel on Role {
  String get label => switch (this) {
    Role.companyOwner => 'Company Owner',
    Role.hrAdmin => 'HR Admin',
    Role.projectEngineer => 'Project Engineer',
    Role.siteEngineer => 'Site Engineer',
    Role.employee => 'Employee',
  };
}

/// Read-only profile view for the current user, sourced entirely from
/// [AuthBloc]'s `AuthAuthenticated` state — this page should only ever be
/// reachable while a session is active, so the non-authenticated branches
/// below are defensive, not expected navigation targets.
///
/// [canViewCompanySettings] and [canManageCompanySettings] are passed in by
/// the caller (typically derived from `hasPermission(user.role, ...)`)
/// rather than recomputed here, keeping this widget free of a direct
/// dependency on where permission-checking happens in the app shell.
class ProfilePage extends StatelessWidget {
  const ProfilePage({
    super.key,
    this.canViewCompanySettings = false,
    this.canManageCompanySettings = false,
  });

  final bool canViewCompanySettings;
  final bool canManageCompanySettings;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Profile')),
      body: SafeArea(
        child: BlocBuilder<AuthBloc, AuthState>(
          builder: (context, state) {
            if (state is! AuthAuthenticated) {
              return const LoadingView();
            }
            final body = _ProfileBody(
              user: state.user,
              canViewCompanySettings: canViewCompanySettings,
              canManageCompanySettings: canManageCompanySettings,
            );
            return ResponsiveScaffold(
              compact: (context) => body,
              expanded: (context) => Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: _kMaxContentWidth),
                  child: body,
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}

class _ProfileBody extends StatelessWidget {
  const _ProfileBody({
    required this.user,
    required this.canViewCompanySettings,
    required this.canManageCompanySettings,
  });

  final UserPublic user;
  final bool canViewCompanySettings;
  final bool canManageCompanySettings;

  @override
  Widget build(BuildContext context) {
    final showCompanySettings =
        canViewCompanySettings || canManageCompanySettings;
    final theme = Theme.of(context);

    return ListView(
      padding: const EdgeInsets.all(AppSpacing.lg),
      children: [
        CircleAvatar(
          radius: 40,
          backgroundImage: user.profilePhotoUrl != null
              ? NetworkImage(user.profilePhotoUrl!)
              : null,
          child: user.profilePhotoUrl == null
              ? Text(
                  user.fullName.isNotEmpty
                      ? user.fullName[0].toUpperCase()
                      : '?',
                  style: theme.textTheme.headlineMedium,
                )
              : null,
        ),
        const SizedBox(height: AppSpacing.md),
        Center(
          child: Text(user.fullName, style: theme.textTheme.headlineSmall),
        ),
        if (user.jobTitle != null)
          Center(
            child: Text(
              user.jobTitle!,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ),
        const SizedBox(height: AppSpacing.lg),
        Card(
          child: Column(
            children: [
              ListTile(
                leading: const Icon(Icons.badge_outlined),
                title: const Text('Role'),
                subtitle: Text(user.role.label),
              ),
              if (user.email != null)
                ListTile(
                  leading: const Icon(Icons.email_outlined),
                  title: const Text('Email'),
                  subtitle: Text(user.email!),
                ),
              if (user.phone != null)
                ListTile(
                  leading: const Icon(Icons.phone_outlined),
                  title: const Text('Phone'),
                  subtitle: Text(user.phone!),
                ),
            ],
          ),
        ),
        const SizedBox(height: AppSpacing.lg),
        FilledButton.tonalIcon(
          onPressed: () {
            Navigator.of(context).push(
              MaterialPageRoute<void>(
                builder: (_) => const ChangePasswordPage(),
              ),
            );
          },
          icon: const Icon(Icons.lock_outline),
          label: const Text('Change password'),
        ),
        if (showCompanySettings) ...[
          const SizedBox(height: AppSpacing.sm),
          OutlinedButton.icon(
            onPressed: () {
              Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (_) => CompanySettingsPage(
                    canManageCompanySettings: canManageCompanySettings,
                  ),
                ),
              );
            },
            icon: const Icon(Icons.settings_outlined),
            label: const Text('Company settings'),
          ),
        ],
        const SizedBox(height: AppSpacing.sm),
        OutlinedButton.icon(
          onPressed: () {
            context.read<AuthBloc>().add(const AuthLogoutRequested());
          },
          icon: const Icon(Icons.logout),
          label: const Text('Log out'),
          style: OutlinedButton.styleFrom(
            foregroundColor: theme.colorScheme.error,
            side: BorderSide(color: theme.colorScheme.error),
          ),
        ),
      ],
    );
  }
}
