# mobile

SCFMS mobile app (Flutter).

## Environment configuration

The backend base URL is compile-time config, supplied via
`--dart-define-from-file` — never hardcoded. Pick the file matching where
the backend you're targeting is running:

```bash
flutter run --dart-define-from-file=env/local.json        # local docker compose backend
flutter run --dart-define-from-file=env/staging.json       # staging (host is TBD — placeholder value)
flutter run --dart-define-from-file=env/production.json    # production (host is TBD — placeholder value)
```

Running `flutter run` with no flags falls back to the local emulator alias
(`http://10.0.2.2:18000/api/v1`), matching `env/local.json` and the backend's
default `SCFMS_BACKEND_PORT` (see the repo-root `.env.example`).

## Getting Started

This project is a starting point for a Flutter application.

A few resources to get you started if this is your first Flutter project:

- [Learn Flutter](https://docs.flutter.dev/get-started/learn-flutter)
- [Write your first Flutter app](https://docs.flutter.dev/get-started/codelab)
- [Flutter learning resources](https://docs.flutter.dev/reference/learning-resources)

For help getting started with Flutter development, view the
[online documentation](https://docs.flutter.dev/), which offers tutorials,
samples, guidance on mobile development, and a full API reference.
