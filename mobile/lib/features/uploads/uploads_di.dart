import 'package:mobile/core/di/injection.dart';

import 'data/upload_repository.dart';

/// Registers this feature's repository with [getIt].
void registerUploadsDependencies() {
  // Shared with the progress-reports feature, which registers the same
  // singleton with the same guard — whichever module runs first wins.
  if (!getIt.isRegistered<UploadRepository>()) {
    getIt.registerLazySingleton(() => UploadRepository(getIt()));
  }
}
