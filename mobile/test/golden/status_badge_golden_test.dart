// Golden test for `StatusBadge` (mobile/lib/shared/widgets/status_badge.dart)
// — a design-critical shared widget per Task 6 of
// .claude/plans/premium-responsive-ui-pass.plan.md. Verifies the chip's
// label/color/border rendering after the Task 4 token pass (labelSmall text
// style + AppTheme colors) stays visually stable.
//
// Run `flutter test --update-goldens test/golden/` once to generate the
// baseline PNGs under test/golden/goldens/, then `flutter test test/golden/`
// (no flag) to confirm they pass without regeneration.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/core/theme/app_theme.dart';
import 'package:mobile/shared/widgets/status_badge.dart';

void main() {
  Widget wrap(Widget child) {
    return MaterialApp(
      theme: AppTheme.light(),
      home: Scaffold(body: Center(child: child)),
    );
  }

  testWidgets('StatusBadge renders label/color — light theme', (
    tester,
  ) async {
    await tester.pumpWidget(
      wrap(const StatusBadge(label: 'On site', color: Colors.green)),
    );
    await tester.pumpAndSettle();

    await expectLater(
      find.byType(StatusBadge),
      matchesGoldenFile('goldens/status_badge_light.png'),
    );
  });

  testWidgets('StatusBadge renders label/color — dark theme', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.dark(),
        home: Scaffold(
          body: Center(
            child: StatusBadge(
              label: 'Overdue',
              color: Colors.red.shade300,
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await expectLater(
      find.byType(StatusBadge),
      matchesGoldenFile('goldens/status_badge_dark.png'),
    );
  });
}
