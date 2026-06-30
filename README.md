# HRM ERP — Flutter + Supabase

Employee Management ERP with Attendance, Leave, Payroll, and CRM modules.

## Architecture (v2 — simplified, no go_router)

This version was rewritten to eliminate the `app_links` Gradle build crash:
- **No go_router** — uses Flutter's built-in `Navigator.push()` + `IndexedStack` bottom nav
- **No code generation** — plain Riverpod providers (`StateProvider` + `FutureProvider`), no `build_runner`
- **Minimal dependencies** — only what's strictly needed

## Setup

```bash
flutter pub get
flutter run --dart-define=SUPABASE_URL=https://iuuzzlcyaduhmhkfecgp.supabase.co \
            --dart-define=SUPABASE_ANON_KEY=<your-anon-key>
```

## Build APK via Codemagic

This repo includes `codemagic.yaml`. Connect the repo at codemagic.io and trigger
the `android-release` workflow — it bootstraps the Android folder, sets SDK
versions, and builds the release APK automatically.

## Structure

```
lib/
├── main.dart                  # App entry + bottom nav shell
├── core/colors.dart           # Color palette
├── providers/providers.dart   # All Riverpod providers (single file)
└── screens/
    ├── login.dart
    ├── dashboard.dart
    ├── employees.dart
    ├── attendance.dart
    ├── leave.dart
    ├── payroll.dart
    └── crm.dart
```

## Backend

Supabase project `iuuzzlcyaduhmhkfecgp` — 16 tables, RLS policies, triggers,
seed data already applied.
