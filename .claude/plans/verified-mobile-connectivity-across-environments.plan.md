# Plan: Verified Mobile Connectivity Across Environments

**Source PRD**: `.claude/prds/mobile-connectivity-namespacing-premium-ui.prd.md`
**Selected Milestone**: 2 — Verified mobile connectivity across environments
**Complexity**: Medium

## Summary
`ApiClient.defaultBaseUrl` (`mobile/lib/core/network/api_client.dart:64-65`) is hardcoded to `http://10.0.2.2:8000/api/v1` — the Android-emulator-only loopback alias — with no way to point the app at a staging or production backend without editing source. This milestone introduces compile-time environment config (`--dart-define`), wires it through DI instead of the hardcoded constant, and verifies CORS/network reachability end-to-end for local, staging, and production. Depends on Milestone 1 only insofar as the "local" default should match whatever host port that milestone lands on (`SCFMS_BACKEND_PORT`, default `18000`) — otherwise independent.

## Patterns to Mirror
| Category | Source | Pattern |
|---|---|---|
| DI wiring | `mobile/lib/core/di/injection.dart:29-38` | Core singletons constructed once in `setupDependencies()` and registered via `getIt.registerLazySingleton` — new config object follows the same registration style |
| Secrets/config | `~/.claude/rules/ecc/dart/security.md` (loaded rule) | Compile-time, non-secret config belongs in `String.fromEnvironment(...)` via `--dart-define`/`--dart-define-from-file`, not hardcoded constants |
| Client construction | `mobile/lib/core/network/api_client.dart:53-58` | `ApiClient` already accepts `baseUrl` as a named constructor param with a default — the fix is to stop relying on the hardcoded default and always pass an explicit value from config |
| Network security | `~/.claude/rules/ecc/dart/security.md` | HTTPS enforced in production; local dev is the only environment allowed to use plain `http://` |
| Backend CORS | `backend/app/main.py:38-39`, `backend/.env.example` | `BACKEND_CORS_ORIGINS` is already a list read from `.env` — CORS only applies to browser-origin requests, so this milestone documents that native Dio requests aren't CORS-gated, while a future Flutter Web build would need real origins listed here |

## Files to Change
| File | Action | Why |
|---|---|---|
| `mobile/lib/core/config/app_config.dart` | CREATE | New `AppConfig` class exposing `apiBaseUrl` via `String.fromEnvironment('API_BASE_URL', defaultValue: ...)`, defaulting to the existing emulator alias so `flutter run` with no flags still works exactly as today |
| `mobile/lib/core/network/api_client.dart` | UPDATE | Remove the hardcoded `defaultBaseUrl` static constant; `baseUrl` becomes a required constructor param (no default) so misconfiguration fails at DI registration, not silently at runtime |
| `mobile/lib/core/di/injection.dart` | UPDATE | Pass `AppConfig.apiBaseUrl` into the `ApiClient(...)` registration |
| `mobile/env/local.json`, `mobile/env/staging.json`, `mobile/env/production.json` (new) | CREATE | Per-environment `--dart-define-from-file` JSON with `API_BASE_URL` set to the local emulator alias, staging host, and production host respectively |
| `mobile/README.md` | UPDATE | Document the three `flutter run --dart-define-from-file=env/<env>.json` invocations, replacing the current generic Flutter boilerplate README |
| `backend/.env.example` | UPDATE | Add one comment clarifying CORS origins are for browser/webview clients only, with an example entry for a future Flutter Web build, so this isn't re-litigated later |

## Tasks
### Task 1: Introduce `AppConfig`
- **Action**: Create `AppConfig` with a single static getter `apiBaseUrl` reading `String.fromEnvironment('API_BASE_URL', defaultValue: 'http://10.0.2.2:8000/api/v1')`
- **Mirror**: `~/.claude/rules/ecc/dart/security.md` compile-time config example (`String.fromEnvironment`)
- **Validate**: `flutter run --dart-define=API_BASE_URL=http://example.test/api/v1` and confirm (via a debug print removed before commit, or a widget test) the value is picked up

### Task 2: Remove the hardcoded default from `ApiClient`
- **Action**: Delete the `defaultBaseUrl` static constant and its use as the `baseUrl` parameter's default value; make `baseUrl` a required named parameter
- **Mirror**: `mobile/lib/core/network/api_client.dart:53-58` (existing constructor shape, just tightened)
- **Validate**: `dart analyze` — any call site missing `baseUrl` now fails to compile, which should only be the DI registration (Task 3) and existing tests

### Task 3: Wire `AppConfig` into DI
- **Action**: Update `getIt.registerLazySingleton<ApiClient>(...)` in `injection.dart` to pass `baseUrl: AppConfig.apiBaseUrl`
- **Mirror**: `mobile/lib/core/di/injection.dart:29-38`
- **Validate**: `flutter test` — existing DI-dependent tests still pass; `flutter run` (no flags) behaves identically to before (still hits the emulator alias)

### Task 4: Per-environment dart-define files
- **Action**: Create `mobile/env/local.json` (`{"API_BASE_URL": "http://10.0.2.2:<SCFMS_BACKEND_PORT default>/api/v1"}`), `staging.json`, and `production.json` (both `https://` placeholders — real hostnames are `TBD`, see Open Questions in the PRD)
- **Mirror**: No existing pattern in this repo; follows Flutter's documented `--dart-define-from-file` convention
- **Validate**: `flutter run --dart-define-from-file=mobile/env/staging.json` launches without a dart-define parse error (placeholder host will fail to connect until Open Question 2 in the PRD is resolved — that's expected and documented, not a bug in this milestone)

### Task 5: Verify connectivity per environment
- **Action**: For local: run the backend via Milestone 1's compose stack and connect from a real Android device on the same network (not just the emulator alias) using its LAN IP as an ad-hoc fourth `--dart-define` value; confirm a request succeeds end-to-end (e.g. `/auth/login` returns a structured error, proving reachability, not a network timeout)
- **Mirror**: `mobile/lib/core/network/api_client.dart` envelope/exception handling (`ApiException.network` vs. a decoded `ErrorDetail`) — use this distinction to tell "unreachable" from "reachable but rejected"
- **Validate**: Manual device test; capture the result (reachable/unreachable) per environment in the PR description

### Task 6: Document CORS scope
- **Action**: Add the clarifying comment to `backend/.env.example` distinguishing CORS (browser/webview only) from native mobile reachability (network/DNS/port only, not CORS-gated)
- **Mirror**: `backend/.env.example` existing comment style
- **Validate**: Read-through; no behavior change, documentation only

## Validation
```bash
cd mobile
dart analyze
flutter test
flutter run --dart-define-from-file=env/local.json          # unchanged behavior vs. today
flutter run --dart-define-from-file=env/staging.json         # new: staging-configured build
```

## Risks
| Risk | Likelihood | Mitigation |
|---|---|---|
| Staging/production hostnames are still `TBD` per the PRD's open questions | High | `env/staging.json` and `env/production.json` ship with placeholder values and a `TBD` comment; connectivity verification for those two environments is blocked until hostnames exist — call this out explicitly rather than faking a value |
| Making `baseUrl` required breaks any existing test that constructs `ApiClient()` with no args | Low | `dart analyze` after Task 2 surfaces every call site immediately; fix alongside the same change |
| Real device on a different network/VPN than the backend host can't reach it even with a correct IP | Medium | Task 5 explicitly tests from a real device on the same LAN first; document that VPN/firewall reachability is a deployment concern, not an app-config one |

## Acceptance
- [ ] All tasks complete
- [ ] Validation passes
- [ ] Patterns mirrored, not reinvented
