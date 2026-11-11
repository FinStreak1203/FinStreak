# Finella

Finella (product name **FinStreak**) is a personal-finance app for the Indian
market. It tracks accounts, transactions, budgets, goals and loans locally, and
turns a daily balance **reconcile** into a streak that feeds a 0–100 financial
health score (**FinScore**). Transactions can be captured automatically from
bank SMS, Gmail receipts and PDF statements, with Google's Gemini powering
categorisation, insights and an AI coach.

## Tech stack

- **Flutter** (Dart SDK `^3.11.5`), Material, force-light green/white theme
- **Riverpod** for state, **go_router** for navigation (5-tab shell + root routes)
- **Drift / SQLite** for all financial data (schema v12, local `finella.db`)
- **Firebase** Auth + Firestore (identity, user profile, streak)
- **Gemini** (`google_generative_ai`) for AI features — optional, see `.env`
- Android-first: real-time bank-SMS capture via `another_telephony`

## Prerequisites

- Flutter SDK matching `environment.sdk` in [`pubspec.yaml`](pubspec.yaml)
  (`flutter --version`; run `flutter doctor` to validate your toolchain)
- Android Studio / Xcode for device or emulator targets
- A Firebase project (the committed config points at `finella-dev`)
- (Optional) A Google Gemini API key for AI features

## Setup

1. **Install dependencies**

   ```bash
   flutter pub get
   ```

2. **Configure secrets (`.env`)** — copied into the app bundle as an asset.
   Create `finella/.env` (it is git-ignored) with:

   ```env
   GEMINI_API_KEY=your_actual_api_key_here
   ```

   The key is optional: if it's missing or left as the placeholder, AI features
   silently fall back to non-AI defaults and the rest of the app works normally.

3. **Firebase** — this repo ships a working `finella-dev` configuration
   (`lib/firebase_options.dart`, `android/app/google-services.json`,
   `ios/Runner/GoogleService-Info.plist`). To point at your own project:

   ```bash
   dart pub global activate flutterfire_cli
   flutterfire configure
   ```

   Enable **Email/Password** and **Google** sign-in in the Firebase console, and
   add your SHA-1/SHA-256 fingerprints for Google Sign-In on Android.

4. **Code generation** (Drift tables + Riverpod providers). Re-run after editing
   any `@DriftDatabase` table or generated provider:

   ```bash
   dart run build_runner build --delete-conflicting-outputs
   ```

## Run

```bash
flutter run
```

Pick a target with `flutter devices` / `flutter run -d <id>`. Android is the
primary platform; bank-SMS capture is Android-only and requires granting the SMS
permission on first use of the import screen.

## Build

```bash
flutter build apk           # Android APK
flutter build appbundle     # Android App Bundle (Play Store)
flutter build ios           # iOS (needs macOS + Xcode signing)
```

## Tests & analysis

```bash
flutter test                # unit/widget tests (see test/)
flutter analyze             # static analysis (rules in analysis_options.yaml)
```

## Project layout

```
lib/
  core/
    database/   Drift tables, DAOs, schema & migrations (app_database.dart)
    services/   SMS/Gmail/PDF import, Gemini, notifications, streak
    providers/  app-wide Riverpod providers (db, settings, subscription…)
    router/     go_router config + bottom-nav shell
    theme/      app theme
  features/     feature-first modules (home, transactions, loans, finsco,
                goals, budgets, streak, auth, onboarding, insights, ai, …)
```

## Notes

- **Schema migrations** live in `AppDatabase.migration`
  ([`lib/core/database/app_database.dart`](lib/core/database/app_database.dart)).
  Bump `schemaVersion` and add an `onUpgrade` step for any table/column change,
  then regenerate with `build_runner`.
- The `GEMINI_API_KEY` is bundled into the client app; treat it as a
  low-privilege, restricted, rotatable key (ideally proxied through a backend
  before a production release).
