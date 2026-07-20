import 'package:flutter/widgets.dart';

/// Window-size classes mirroring Material 3's compact/medium/expanded
/// breakpoints, used to decide when a page should reflow (e.g. bottom nav
/// vs. side rail, single-column vs. list/detail split).
enum AppWindowSizeClass { compact, medium, expanded }

/// Named width breakpoints (Material 3 window size classes). Compact is
/// most phones in portrait; medium is most phones in landscape / small
/// tablets in portrait; expanded is tablets in landscape and larger.
class AppBreakpoints {
  AppBreakpoints._();

  static const double medium = 600;
  static const double expanded = 840;
}

/// Convenience accessors so pages/widgets can branch on window size class
/// without re-deriving the thresholds from `MediaQuery` each time.
extension AppBreakpointsContext on BuildContext {
  double get _width => MediaQuery.sizeOf(this).width;

  AppWindowSizeClass get windowSizeClass {
    final width = _width;
    if (width >= AppBreakpoints.expanded) return AppWindowSizeClass.expanded;
    if (width >= AppBreakpoints.medium) return AppWindowSizeClass.medium;
    return AppWindowSizeClass.compact;
  }

  bool get isCompact => windowSizeClass == AppWindowSizeClass.compact;
  bool get isMedium => windowSizeClass == AppWindowSizeClass.medium;
  bool get isExpanded => windowSizeClass == AppWindowSizeClass.expanded;

  /// True for medium or expanded — the common "give this more room" check
  /// pages use to opt into a wider layout without caring which of the two
  /// wider classes it is.
  bool get isAtLeastMedium => !isCompact;
}
