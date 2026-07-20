import 'package:flutter/material.dart';

import 'package:mobile/core/theme/app_theme.dart';

/// Centered spinner — the common shape most feature pages already
/// hand-roll for an in-flight fetch. Fades in rather than appearing
/// instantly, so quick loads don't flash the indicator abruptly.
class LoadingView extends StatelessWidget {
  const LoadingView({super.key});

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: AppMotion.medium,
      curve: AppMotion.curve,
      builder: (context, opacity, child) =>
          Opacity(opacity: opacity, child: child),
      child: const Center(child: CircularProgressIndicator()),
    );
  }
}
