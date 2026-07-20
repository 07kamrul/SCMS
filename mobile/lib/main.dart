import 'dart:async';

import 'package:flutter/material.dart';

import 'app.dart';
import 'core/di/injection.dart';
import 'core/offline/submission_retry_service.dart';
import 'features/uploads/services/photo_upload_retry_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await setupDependencies();

  // Started once here (not per-bloc/per-page) so photo uploads and
  // task/progress-report submissions queued while offline are replayed for
  // the whole lifetime of the app process, as soon as connectivity returns.
  unawaited(PhotoUploadRetryService().start());
  unawaited(SubmissionRetryService().start());

  runApp(const ScfmsApp());
}
