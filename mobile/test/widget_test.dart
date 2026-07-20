// Basic smoke test for the app shell now that the counter boilerplate has
// been replaced by ScfmsApp (see lib/main.dart, lib/app.dart).

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:mobile/app.dart';
import 'package:mobile/core/di/injection.dart';

void main() {
  testWidgets('shows the splash spinner while checking for a session', (
    WidgetTester tester,
  ) async {
    await setupDependencies();
    await tester.pumpWidget(const ScfmsApp());

    // A single frame only: the splash route's `AuthSessionRequested` kicks
    // off an async session check against `flutter_secure_storage`, which
    // has no platform-channel handler under plain `flutter_test` — settling
    // would wait on/surface that. The smoke test only needs to confirm the
    // app shell mounts and shows the splash spinner on its first frame.
    await tester.pump();

    expect(find.byType(CircularProgressIndicator), findsOneWidget);
  });
}
