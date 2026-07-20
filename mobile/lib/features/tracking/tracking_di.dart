import 'package:mobile/core/di/injection.dart';

import 'bloc/team_map_bloc.dart';
import 'bloc/tracking_bloc.dart';
import 'consent_storage.dart';
import 'data/location_repository.dart';

/// Registers this feature's repository and blocs with [getIt].
///
/// Not called from `core/di/injection.dart` yet — following the same
/// convention as `team_di.dart`, integration happens once the app shell
/// wires up feature modules together.
void registerTrackingDependencies() {
  getIt.registerLazySingleton(() => LocationRepository(getIt()));
  getIt.registerLazySingleton(() => LocationConsentStorage());
  getIt.registerFactory(
    () => TrackingBloc(getIt(), getIt(), getIt()),
  );
  getIt.registerFactory(() => TeamMapBloc(getIt()));
}
