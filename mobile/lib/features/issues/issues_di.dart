import 'package:mobile/core/di/injection.dart';

import 'bloc/issue_detail_bloc.dart';
import 'bloc/issue_form_bloc.dart';
import 'bloc/issues_list_bloc.dart';
import 'data/issue_repository.dart';

/// Registers this feature's repository and blocs with [getIt].
void registerIssuesDependencies() {
  getIt.registerLazySingleton(() => IssueRepository(getIt()));
  getIt.registerFactory(() => IssuesListBloc(getIt()));
  getIt.registerFactory(() => IssueDetailBloc(getIt()));
  getIt.registerFactory(() => IssueFormBloc(getIt()));
}
