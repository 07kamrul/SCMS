# Plan: Premium, Fully Responsive UI Pass

**Source PRD**: `.claude/prds/mobile-connectivity-namespacing-premium-ui.prd.md`
**Selected Milestone**: 3 — Premium, fully responsive UI across existing screens
**Complexity**: Large

## Summary
`AppTheme` (`mobile/lib/core/theme/app_theme.dart`) currently defines a single light `ThemeData` with ad-hoc literal values (hardcoded `EdgeInsets`, `BorderRadius.circular(8)`/`(12)`) and no dark theme, no typography scale, no spacing scale, and no responsive layout primitives. There are 26 existing feature pages across 10 features plus 4 shared widgets (`role_nav_scaffold`, `error_view`, `loading_view`, `status_badge`), none of which reference breakpoints today (`grep` for `MediaQuery`/`LayoutBuilder` in `lib/features` returns no matches). This milestone builds the design-system foundation first, then applies it across every existing screen — no new screens or features, per the PRD's explicit out-of-scope.

## Patterns to Mirror
| Category | Source | Pattern |
|---|---|---|
| Theme construction | `mobile/lib/core/theme/app_theme.dart:11-46` | `ThemeData` built via `ColorScheme.fromSeed` + `copyWith`, with per-component theme extensions (`elevatedButtonTheme`, `inputDecorationTheme`, `cardTheme`) — new tokens extend this same structure rather than replacing it |
| Theme application | `mobile/lib/app.dart:20` | Single `theme:` property on `MaterialApp.router` — dark mode addition follows the same wiring (`darkTheme:` + `themeMode:`) |
| Navigation shell | `mobile/lib/shared/widgets/role_nav_scaffold.dart` | Shared scaffold wrapping every role-gated page — the natural seam for injecting responsive breakpoint behavior (e.g. side-rail nav on wide/tablet layouts) without touching each page's internals |
| State-driven UI | `mobile/lib/shared/widgets/{error_view,loading_view,status_badge}.dart` | Existing shared widgets for common states — new responsive layout primitives (e.g. `ResponsiveScaffold`, breakpoint helpers) belong alongside these in `lib/shared/widgets/` |
| Testing | `mobile/test/widget_test.dart`, `mobile/test/core/offline/offline_queue_repository_test.dart` | `flutter_test` widget tests exist already; golden tests do not — new design-critical components should add `test/golden/` per `~/.claude/rules/ecc/dart/testing.md` |

## Files to Change
| File | Action | Why |
|---|---|---|
| `mobile/lib/core/theme/app_theme.dart` | UPDATE | Replace literal values with named design tokens (spacing scale, radius scale, type scale, motion durations/curves); add `AppTheme.dark()` |
| `mobile/lib/core/theme/app_spacing.dart` (new) | CREATE | Named spacing constants (e.g. `xs/sm/md/lg/xl`) replacing scattered literal `EdgeInsets` values across pages |
| `mobile/lib/core/theme/app_breakpoints.dart` (new) | CREATE | Named width breakpoints (compact/medium/expanded, mirroring Material 3 window size classes) plus a `BuildContext` extension (`context.isCompact`, etc.) |
| `mobile/lib/shared/widgets/responsive_scaffold.dart` (new) | CREATE | Layout primitive wrapping `LayoutBuilder`/`MediaQuery` so pages opt into breakpoint-aware layout without duplicating `LayoutBuilder` boilerplate per page |
| `mobile/lib/app.dart` | UPDATE | Wire `darkTheme: AppTheme.dark()` and `themeMode: ThemeMode.system` alongside the existing `theme:` |
| `mobile/lib/shared/widgets/{role_nav_scaffold,error_view,loading_view,status_badge}.dart` (4 files) | UPDATE | Apply new spacing/type tokens; make `role_nav_scaffold` breakpoint-aware (bottom nav on compact, side rail on expanded) since every page composes through it |
| `mobile/lib/features/**/presentation/*.dart` (26 page files, listed below) | UPDATE | Replace literal spacing/radius with tokens from `app_spacing.dart`/`app_theme.dart`; wrap layouts needing reflow (forms, list/detail splits, map pages) in `ResponsiveScaffold`; verify no fixed-width/fixed-height widgets overflow at compact width |
| `mobile/test/golden/` (new directory) | CREATE | Golden tests for `role_nav_scaffold`, `status_badge`, and one representative page per feature at 3 breakpoints (per `~/.claude/rules/ecc/dart/testing.md` golden-test guidance) |

**26 page files covered under the `features/**` row above**, grouped by feature: `auth` (change_password, login, register_company, splash — 4), `dashboard` (dashboard — 1), `issues` (issue_detail, issue_form, issues_list — 3), `notifications` (notifications_list — 1), `profile` (company_settings, profile — 2), `progress_reports` (progress_report_form, progress_reports_list, project_photo_timeline — 3), `projects` (my_projects, project_form, project_map, projects_list — 4), `tasks` (task_detail, task_form, tasks_list — 3), `team` (assignment_form, team_list, user_detail, user_form — 4), `tracking` (team_map, tracking_consent — 2).

## Tasks
### Task 1: Design tokens (spacing, radius, type scale, motion)
- **Action**: Create `app_spacing.dart` and extend `app_theme.dart` with a type scale (`textTheme` overrides) and named radius constants; define standard motion durations/curves (e.g. `AppMotion.fast`/`.medium`, `Curves.easeOutCubic`) for use in transitions
- **Mirror**: `app_theme.dart:11-46` existing `ThemeData` composition style
- **Validate**: `dart analyze`; existing widget tests referencing `AppTheme.light()` still pass unchanged

### Task 2: Dark theme + system-driven theme mode
- **Action**: Add `AppTheme.dark()` mirroring `light()`'s structure with a dark `ColorScheme`; wire `darkTheme` + `themeMode: ThemeMode.system` into `app.dart`
- **Mirror**: `app_theme.dart:11-46`
- **Validate**: Manual check — toggle OS dark mode, app follows without restart

### Task 3: Breakpoints + `ResponsiveScaffold`
- **Action**: Define compact/medium/expanded breakpoints and a `BuildContext` extension; build `ResponsiveScaffold` as a thin `LayoutBuilder` wrapper exposing `compact`/`medium`/`expanded` builder slots, defaulting `medium`/`expanded` to the `compact` builder unless overridden (so adopting it on a page is a no-op until that page opts into a wider layout)
- **Mirror**: `lib/shared/widgets/` existing shared-widget pattern (single-purpose, stateless where possible)
- **Validate**: Widget test rendering `ResponsiveScaffold` at 3 simulated widths (`tester.binding.window.physicalSizeTestValue`), confirming the correct builder slot renders at each

### Task 4: Apply tokens + responsiveness to shared widgets
- **Action**: Update `role_nav_scaffold.dart` to use `ResponsiveScaffold` (bottom nav bar at compact, side navigation rail at expanded); update `error_view`, `loading_view`, `status_badge` to use the new spacing/type tokens instead of literals
- **Mirror**: Existing `role_nav_scaffold.dart` role-gating logic — layout change only, no navigation/permission logic changes
- **Validate**: Widget tests for `role_nav_scaffold` at compact and expanded widths confirm the correct nav pattern renders; existing tests referencing these 4 widgets still pass

### Task 5: Apply tokens + responsiveness across all 26 pages, feature by feature
- **Action**: For each of the 10 feature directories, replace literal spacing/radius with tokens and wrap any page whose content doesn't already reflow safely (multi-column-capable list/detail pages, forms, `project_map_page`, `team_map_page`) in `ResponsiveScaffold`; run each feature's existing test suite before moving to the next
- **Mirror**: Task 4's already-updated shared widgets set the visual/structural pattern each page follows
- **Validate**: Per-feature `flutter test test/features/<feature>/`; manual check on at least one compact-width and one tablet-width device/simulator per feature for overflow (`RenderFlex overflow` warnings in debug console are the fail signal)

### Task 6: Golden tests for design-critical components
- **Action**: Add golden tests under `mobile/test/golden/` for `role_nav_scaffold`, `status_badge`, and one representative page (`dashboard_page`) at compact/medium/expanded widths
- **Mirror**: `~/.claude/rules/ecc/dart/testing.md` golden-test example structure
- **Validate**: `flutter test --update-goldens` once to generate baselines, then `flutter test` clean to confirm they pass without `--update-goldens`

## Validation
```bash
cd mobile
dart analyze
flutter test --coverage
flutter test test/golden/          # confirms goldens pass without regeneration
# Manual: run on a phone-sized and tablet-sized simulator/device per feature, both orientations,
# confirm no RenderFlex overflow warnings in the debug console on any of the 26 pages
```

## Risks
| Risk | Likelihood | Mitigation |
|---|---|---|
| No brand/design reference exists yet (open question in the PRD) — "premium" risks being subjective and reworked later | High | Resolve the PRD's open question on brand reference before Task 1 starts; token names/values in Task 1 are the single point of change if direction shifts |
| 26-page scope is large for one pass — partial completion could leave an inconsistent look | Medium | Task 5 processes feature-by-feature with its own test gate per feature, so the milestone can pause between features with each completed feature fully consistent, rather than all-or-nothing |
| Map pages (`project_map_page`, `team_map_page`, using `flutter_map`) may not reflow cleanly inside `ResponsiveScaffold` | Medium | Treat map pages as a specific sub-task within Task 5; validate manually on tablet width before considering that feature done |
| Golden tests are platform/font-rendering sensitive and may flake across CI/local environments | Low | Scope goldens to 3 representative components (Task 6) rather than all 26 pages, keeping the maintenance surface small |

## Acceptance
- [ ] All tasks complete
- [ ] Validation passes
- [ ] Patterns mirrored, not reinvented
