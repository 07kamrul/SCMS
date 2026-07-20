import 'package:mobile/core/di/injection.dart';

import 'bloc/task_detail_bloc.dart';
import 'bloc/task_form_bloc.dart';
import 'bloc/tasks_list_bloc.dart';
import 'data/task_repository.dart';

/// Registers this feature's repository and blocs with [getIt].
void registerTasksDependencies() {
  getIt.registerLazySingleton(() => TaskRepository(getIt()));
  getIt.registerFactory(() => TasksListBloc(getIt()));
  getIt.registerFactory(() => TaskDetailBloc(getIt()));
  getIt.registerFactory(() => TaskFormBloc(getIt()));
}
