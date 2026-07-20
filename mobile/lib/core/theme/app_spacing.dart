/// Named spacing scale — the single source of truth for gaps/padding across
/// the app. Replaces scattered literal `EdgeInsets`/`SizedBox` values in
/// feature pages with a consistent, named scale.
class AppSpacing {
  AppSpacing._();

  static const double xs = 4;
  static const double sm = 8;
  static const double md = 16;
  static const double lg = 24;
  static const double xl = 32;
  static const double xxl = 48;
}
