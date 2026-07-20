import 'package:mobile/core/di/injection.dart';

import 'data/company_settings_repository.dart';

/// Registers this feature's repository with [getIt].
///
/// Not called from `core/di/injection.dart` yet — matches the convention in
/// `auth_di.dart`, where each feature module's registration is wired up by
/// an integration pass once the router/app shell exists to call it.
void registerProfileDependencies() {
  getIt.registerLazySingleton(() => CompanySettingsRepository(getIt()));
}
