import 'package:mobile/core/di/injection.dart';

import 'bloc/my_projects_bloc.dart';
import 'bloc/project_form_bloc.dart';
import 'bloc/project_map_bloc.dart';
import 'bloc/projects_list_bloc.dart';
import 'data/project_repository.dart';

/// Registers this feature's repository and blocs with [getIt].
///
/// Not called from `core/di/injection.dart` yet — following the same
/// convention as `team_di.dart`, integration happens once the app shell
/// wires up feature modules together.
void registerProjectsDependencies() {
  getIt.registerLazySingleton(() => ProjectRepository(getIt()));
  getIt.registerFactory(() => ProjectsListBloc(getIt()));
  getIt.registerFactory(() => MyProjectsBloc(getIt()));
  getIt.registerFactory(() => ProjectMapBloc(getIt()));
  getIt.registerFactory(() => ProjectFormBloc(getIt()));
}
