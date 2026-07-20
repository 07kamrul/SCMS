import 'package:get_it/get_it.dart';
import 'package:mobile/features/auth/auth_di.dart';
import 'package:mobile/features/auth/bloc/auth_bloc.dart';
import 'package:mobile/features/auth/bloc/auth_event.dart';
import 'package:mobile/features/dashboard/dashboard_di.dart';
import 'package:mobile/features/issues/issues_di.dart';
import 'package:mobile/features/notifications/notifications_di.dart';
import 'package:mobile/features/profile/profile_di.dart';
import 'package:mobile/features/progress_reports/progress_reports_di.dart';
import 'package:mobile/features/projects/projects_di.dart';
import 'package:mobile/features/tasks/tasks_di.dart';
import 'package:mobile/features/team/team_di.dart';
import 'package:mobile/features/tracking/tracking_di.dart';
import 'package:mobile/features/uploads/uploads_di.dart';

import '../config/app_config.dart';
import '../network/api_client.dart';
import '../storage/secure_token_storage.dart';

/// Global service locator. Core singletons are registered here;
/// feature repositories/blocs register themselves via <feature>/di.dart.
final getIt = GetIt.instance;

Future<void> setupDependencies() async {
  // Idempotent: a hot restart (or a test calling this more than once) must
  // not re-register everything and throw.
  if (getIt.isRegistered<SecureTokenStorage>()) return;

  getIt.registerLazySingleton<SecureTokenStorage>(() => SecureTokenStorage());

  getIt.registerLazySingleton<ApiClient>(
    () => ApiClient(
      tokenStorage: getIt<SecureTokenStorage>(),
      baseUrl: AppConfig.apiBaseUrl,
      // Deferred lookup: only invoked on an actual 401-after-refresh-failure,
      // by which point AuthBloc is always already resolved — this does not
      // construct AuthBloc eagerly, so no circular-dependency issue at
      // registration time.
      onSessionExpired: () => getIt<AuthBloc>().add(const AuthSessionExpired()),
    ),
  );

  // Auth first: AuthBloc depends on NotificationRepository, and the router's
  // redirect guard depends on AuthBloc existing before any page resolves it.
  registerNotificationsDependencies();
  registerAuthDependencies();

  registerDashboardDependencies();
  registerIssuesDependencies();
  registerProfileDependencies();
  registerProgressReportsDependencies();
  registerProjectsDependencies();
  registerTasksDependencies();
  registerTeamDependencies();
  registerTrackingDependencies();
  registerUploadsDependencies();
}
