import 'package:mobile/core/di/injection.dart';

import 'bloc/notifications_list_bloc.dart';
import 'data/notification_repository.dart';

/// Registers this feature's repository and bloc with [getIt].
///
/// Not called from `core/di/injection.dart` yet — following the same
/// convention as `team_di.dart`/`auth_di.dart`, integration happens once the
/// app shell wires up feature modules together.
void registerNotificationsDependencies() {
  getIt.registerLazySingleton(() => NotificationRepository(getIt()));
  getIt.registerFactory(() => NotificationsListBloc(getIt()));
}
