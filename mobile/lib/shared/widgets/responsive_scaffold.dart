import 'package:flutter/widgets.dart';

import 'package:mobile/core/theme/app_breakpoints.dart';

/// Builder signature for a single window-size-class slot.
typedef ResponsiveWidgetBuilder = Widget Function(BuildContext context);

/// Thin `LayoutBuilder` wrapper so pages opt into breakpoint-aware layout
/// without duplicating `LayoutBuilder`/width-threshold boilerplate per page.
///
/// Only [compact] is required. [medium] and [expanded] default to
/// [compact], so wrapping an existing page in `ResponsiveScaffold` is a
/// no-op until that page explicitly supplies a wider-layout builder.
class ResponsiveScaffold extends StatelessWidget {
  const ResponsiveScaffold({
    super.key,
    required this.compact,
    this.medium,
    this.expanded,
  });

  final ResponsiveWidgetBuilder compact;
  final ResponsiveWidgetBuilder? medium;
  final ResponsiveWidgetBuilder? expanded;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;
        if (width >= AppBreakpoints.expanded) {
          return (expanded ?? medium ?? compact)(context);
        }
        if (width >= AppBreakpoints.medium) {
          return (medium ?? compact)(context);
        }
        return compact(context);
      },
    );
  }
}
