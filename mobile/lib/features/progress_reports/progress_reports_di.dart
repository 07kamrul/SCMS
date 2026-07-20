import 'package:mobile/core/di/injection.dart';

import '../uploads/data/upload_repository.dart';
import 'bloc/photo_timeline_bloc.dart';
import 'bloc/progress_report_form_bloc.dart';
import 'bloc/progress_reports_list_bloc.dart';
import 'data/progress_report_repository.dart';

/// Registers this feature's repository and blocs with [getIt].
///
/// Not called from `core/di/injection.dart` yet (same pattern as
/// `auth_di.dart`) — the integration pass wires feature `di.dart` files up
/// once the router exists.
void registerProgressReportsDependencies() {
  // `UploadRepository` is shared with the tasks/issues features — guard so
  // whichever feature module registers first doesn't clash with the others.
  if (!getIt.isRegistered<UploadRepository>()) {
    getIt.registerLazySingleton(() => UploadRepository(getIt()));
  }
  getIt.registerLazySingleton(() => ProgressReportRepository(getIt()));
  getIt.registerFactory(() => ProgressReportsListBloc(getIt()));
  getIt.registerFactory(() => ProgressReportFormBloc(getIt()));
  getIt.registerFactory(() => PhotoTimelineBloc(getIt()));
}
