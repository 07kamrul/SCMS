import 'package:mobile/core/di/injection.dart';

import 'bloc/assignment_form_bloc.dart';
import 'bloc/team_list_bloc.dart';
import 'bloc/user_form_bloc.dart';
import 'data/team_repository.dart';

/// Registers this feature's repository and blocs with [getIt].
///
/// Not called from `core/di/injection.dart` yet — following the same
/// convention as `auth_di.dart`, integration happens once the app shell
/// wires up feature modules together.
void registerTeamDependencies() {
  getIt.registerLazySingleton(() => TeamRepository(getIt()));
  getIt.registerFactory(() => TeamListBloc(getIt()));
  getIt.registerFactory(() => UserFormBloc(getIt()));
  getIt.registerFactory(() => AssignmentFormBloc(getIt()));
}
