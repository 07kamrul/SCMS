import 'package:mobile/core/di/injection.dart';

import 'bloc/dashboard_bloc.dart';
import 'data/dashboard_repository.dart';

/// Registers this feature's repository and bloc with [getIt].
///
/// Not called from `core/di/injection.dart` yet — following the same
/// convention as `team_di.dart`/`auth_di.dart`, integration happens once the
/// app shell wires up feature modules together.
void registerDashboardDependencies() {
  getIt.registerLazySingleton(() => DashboardRepository(getIt()));
  getIt.registerFactory(() => DashboardBloc(getIt()));
}
