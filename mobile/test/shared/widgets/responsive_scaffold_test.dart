// Widget test for `ResponsiveScaffold`
// (mobile/lib/shared/widgets/responsive_scaffold.dart), per Task 3's
// validation step in .claude/plans/premium-responsive-ui-pass.plan.md:
// "Widget test rendering ResponsiveScaffold at 3 simulated widths ...
// confirming the correct builder slot renders at each."
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/shared/widgets/responsive_scaffold.dart';

Future<void> _pumpAt(WidgetTester tester, Size size, Widget child) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  await tester.pumpWidget(MaterialApp(home: child));
}

void main() {
  testWidgets('renders the compact builder at a compact width', (
    tester,
  ) async {
    await _pumpAt(
      tester,
      const Size(390, 844),
      ResponsiveScaffold(
        compact: (_) => const Text('compact'),
        medium: (_) => const Text('medium'),
        expanded: (_) => const Text('expanded'),
      ),
    );

    expect(find.text('compact'), findsOneWidget);
    expect(find.text('medium'), findsNothing);
    expect(find.text('expanded'), findsNothing);
  });

  testWidgets('renders the medium builder at a medium width', (tester) async {
    await _pumpAt(
      tester,
      const Size(700, 900),
      ResponsiveScaffold(
        compact: (_) => const Text('compact'),
        medium: (_) => const Text('medium'),
        expanded: (_) => const Text('expanded'),
      ),
    );

    expect(find.text('medium'), findsOneWidget);
    expect(find.text('compact'), findsNothing);
    expect(find.text('expanded'), findsNothing);
  });

  testWidgets('renders the expanded builder at an expanded width', (
    tester,
  ) async {
    await _pumpAt(
      tester,
      const Size(1280, 900),
      ResponsiveScaffold(
        compact: (_) => const Text('compact'),
        medium: (_) => const Text('medium'),
        expanded: (_) => const Text('expanded'),
      ),
    );

    expect(find.text('expanded'), findsOneWidget);
    expect(find.text('compact'), findsNothing);
    expect(find.text('medium'), findsNothing);
  });

  testWidgets(
    'medium/expanded default to the compact builder when omitted',
    (tester) async {
      await _pumpAt(
        tester,
        const Size(1280, 900),
        ResponsiveScaffold(compact: (_) => const Text('compact only')),
      );

      expect(find.text('compact only'), findsOneWidget);
    },
  );
}
