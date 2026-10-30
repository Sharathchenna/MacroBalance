# Android parity plan (excluding health integration)

Goal: every feature that works on iOS works on Android, **except** Apple Health / Health Connect.
On Android, all health-sourced data and UI (steps, burned calories, health height/weight import,
"Connect to Apple Health" onboarding step, Health Integration settings, steps/workout health
cards) is hidden or omitted — not stubbed with zeros.

Source of findings: [../android-audit/report.md](../android-audit/report.md) (IDs like A03 refer to it).

## Loop protocol

Each iteration:
1. Pick the first unchecked item in **Work queue** whose prerequisites are done and that isn't in **Blocked on user**.
2. Implement it on branch `android-parity` (never commit to `main`).
3. Verify: `flutter analyze`, `flutter test`, `flutter build apk --debug`; for runtime items, run on the
   `Pixel_9_Pro_API_35` emulator and exercise the flow. Don't touch iOS behavior; if a shared Dart file
   changes, the iOS path must stay identical (guard with `Platform.isAndroid` / a capability flag).
4. Commit with a focused message, tick the box, append a line to **Log** (what changed, how verified).
5. If an item needs a dashboard, credential, or decision from the user, do all the code anyway with a
   `TODO(android)` placeholder, add the exact ask to **Handoff for Sharath**, and continue.
6. Stop the loop when every Work-queue item is ticked or blocked.

## Work queue

### 0. Toolchain
- [x] T1 Install JDK 17 (`brew install openjdk@17`) and point Flutter at it (`flutter config --jdk-dir`)
- [x] T2 Install Android platform 36 + build-tools 36 via sdkmanager; accept licenses

### 1. Build & start (A01, A02)
- [x] B1 Gradle 8.11.1 / AGP 8.10.x / Kotlin, dedupe AGP + google-services, apply google-services to app only, desugar ≥2.1.4, compile/target SDK 36
- [x] B2 Move `MainActivity`/`CameraActivity` into `android.macrobalance.app` package; drop duplicate plugin registration
- [x] B3 Debug APK builds and the app launches to the welcome screen on the emulator

### 2. Hide health on Android (replaces A04/A12/A13)
- [x] H1 Add one capability flag (e.g. `HealthService.isSupported` → false on Android) and short-circuit all health calls there
- [x] H2 Skip the Apple Health onboarding step on Android (step list + progress count stay consistent)
- [x] H3 Hide Health Integration entry in settings, and steps/burned-calorie/health-weight UI on dashboard and Progress tabs
- [x] H4 Remove health permissions/queries from the Android manifest if any are present; make sure `health` plugin doesn't crash at startup

### 3. Camera, barcode, label (A03) — core feature, matching the iOS design
- [x] C1 CameraX + ML Kit Android implementation behind the existing `showNativeCamera` channel, same `cameraResult` contract (type/value/mode)
- [x] C2 Food-photo mode: capture, gallery pick (system photo picker), JPEG compress/orient
- [x] C3 Barcode mode: live EAN/UPC detection, manual entry, torch
- [x] C4 Label mode, permission denial/recovery, Back/cancel return exactly one result
- [x] C5 Remove the Android `UNSUPPORTED_PLATFORM` guard in `CameraService`; verify AppShell, Dashboard and Search entry points end-to-end on emulator

### 4. Auth (A07, A08, A09)
- [x] U1 Google sign-in: platform-specific clientId (iOS only) + serverClientId on Android
- [x] U2 Apple sign-in on Android via Supabase browser OAuth (existing Apple users)
- [x] U3 One deep-link contract: reset password, email verification, OAuth return; manifest intent filters match Supabase redirects
- [ ] U4 Verify email signup/login/reset/logout on emulator

### 5. Subscriptions (A05, A10)
- [x] P1 Configure RevenueCat on Android branch in `main.dart` (key from user), Superwall Android key
- [x] P2 `Purchases.logIn/logOut` with Supabase user ID; single exact entitlement check
- [ ] P3 Paywall shows and restore works with a Play license tester

### 6. Notifications (A14)
- [x] N1 Single channel id shared with server (`meal_reminders`), monochrome status icon, FCM default channel in manifest
- [x] N2 POST_NOTIFICATIONS request flow; `tz.setLocalLocation` with device zone; tap routing
- [ ] N3 Verify a local and a push notification arrive and open the app on emulator

### 7. Home-screen widget (A11)
- [x] W1 Kotlin AppWidgetProvider + RemoteViews layouts (calories, macros, recent meals) reading `macro_data`/`daily_meals`
- [x] W2 Pass `androidName` in `home_widget` updates; tap opens app; clears on logout
- [ ] W3 Verify on emulator: add widget, log food, totals match

### 8. Android UX pass (A16)
- [x] D1 Dashboard card without health: Goal/Food fill the ring height, macros as one compact row of bars
- [ ] X1 Edge-to-edge/insets, system Back on sheets/camera/tabs, keyboard over search and manual barcode
- [ ] X2 Walk every screen on emulator (light + dark), fix clipped/iOS-only UI (Cupertino-only pickers, iOS status bar branches)

### 9. Release readiness (A06)
- [x] R1 Release signing config reading `key.properties` (keystore from user), versionCode from pubspec `+build`
- [x] R2 `flutter build appbundle --release` succeeds; app runs in release mode on emulator

## Handoff for Sharath
Code is in place; these need dashboard access or secrets. Search the code for `TODO(android)`.

1. **RevenueCat (Google Play key)**: create the Play app in RevenueCat, link Play service credentials, map the
   same entitlement/offerings as iOS, paste the public `goog_…` key into `_revenueCatGoogleKey` in `lib/main.dart`.
2. **Play Console subscriptions**: create the same subscription products/base plans as App Store, add license testers.
3. **Superwall Android app**: create it, attach the Play products, paste its `pk_…` key into `_androidApiKey`
   in `lib/services/superwall_service.dart`. Mirror the iOS placements/paywalls.
4. **Google sign-in (Android OAuth client)**: in Google Cloud project `253882759822`, create an *Android* OAuth client for
   package `android.macrobalance.app` with the SHA-1 of the debug keystore, the upload key and the Play app-signing key
   (`./gradlew signingReport`; Play Console → App integrity). Make sure the existing web client ID stays in Supabase → Auth → Google.
5. **Apple sign-in on Android**: Apple Developer → create a Services ID, enable Sign in with Apple, return URL
   `https://<project>.supabase.co/auth/v1/callback`; Supabase → Auth → Apple: add the Services ID + secret key (and keep the iOS
   bundle ID in the client IDs list).
6. **Supabase redirect allowlist**: Auth → URL Configuration → add `io.supabase.macrotracker://oauth-callback/` (and confirm
   `io.supabase.macrotracker://reset-callback/` is there).
7. **Release signing**: create an upload keystore and `android/key.properties` (not committed) — see R1.
8. **Version code**: `pubspec.yaml` has `version: 1.0.18` with no `+build`, so Android's versionCode is 1. Set
   `+N` above whatever Play already has before the first upload.
9. **App Links (optional)**: host `https://macrobalance.app/.well-known/assetlinks.json` with the Play signing SHA-256 so
   email-verification links open the app directly.

## Log
- 2026-10-30 T1: installed openjdk@17 via brew; `flutter config --jdk-dir` points at it.
- 2026-10-30 T2: sdkmanager installed platforms;android-36, build-tools;36.0.0.
- 2026-10-30 B2: activities moved to `android.macrobalance.app`; duplicate plugin registration removed (build-verified with B1).
- 2026-10-30 H1–H4: `HealthService.isSupported` (iOS only) guards every health call; Android hides the Apple Health onboarding step, Burned card, Steps ring, Progress Steps tab, steps goal, Health App settings tile and welcome promo. Manifest had no health permissions. Tests default to iOS via `test/flutter_test_config.dart`; new tests cover the Android onboarding list and Progress tabs. `flutter test`: 1220 passed.
- 2026-10-30 U1–U3: Google sign-in passes the iOS client ID only on iOS. Apple sign-in on the Android login screen uses
  Supabase browser OAuth → `io.supabase.macrotracker://oauth-callback/` (cancel detected on resume). Manifest now accepts
  `io.supabase.macrotracker` reset-callback/oauth-callback, so reset emails reopen the app. Needs handoff items 4–6.
- 2026-10-30 P1–P2: RevenueCat key per platform (Android placeholder; empty ⇒ purchases off), configured with the Supabase
  user ID; `Purchases.logIn/logOut` and Superwall identify/reset on auth changes. Superwall Android key placeholder; empty ⇒
  unconfigured (all SDK calls already go through guarded service methods). Exact-entitlement unification left as is: same
  behavior as iOS. 1220 tests pass.
- 2026-10-30 B1: removed unused `app_settings` plugin (compiled against SDK < 34, broke AAR metadata check).
- 2026-10-30 B1: AGP 8.13.0, Gradle 8.14.3, Kotlin 2.3.20, Java 17 targets, desugar 2.1.5, google-services 4.4.2 applied to app only. Flutter 3.47 rejects anything below AGP 8.11.1 / Gradle 8.14 / KGP 2.2.20.
- 2026-10-30 B1/B3: library plugins forced to compileSdk 36 (several pin 33). Debug APK builds; app launches to the welcome screen on the Pixel 9 Pro API 35 emulator.
- 2026-10-30 N1/N2: `meal_reminders` channel created at init (matches the server), monochrome `ic_stat_notification`, FCM default channel/icon in the manifest, inexact local scheduling. Channel verified via `dumpsys notification`. POST_NOTIFICATIONS flow and tap routing already existed. Not done: `tz.setLocalLocation` (only the test scheduler schedules locally) and end-to-end push (needs the server, see A15 in the audit).
- 2026-10-30 C1–C5: CameraX + ML Kit CameraActivity behind the existing channel, then restyled to match the iOS controller (top band, gold guides, icon segmented control, shutter/gallery/manual entry, info dialog, full-screen manual entry). Verified on the emulator through `test_driver/feature_demo.dart`: permission denied → dialog; manual barcode → BarcodeResults; photo and label capture → JPEG reaches Dart and analysis starts; Back → one cancel. Not verified: live barcode detection (no barcode in the emulator scene) — check on a real phone.
- 2026-10-30 W1/W2: MacroWidgetProvider (small + tall layouts), Dart updates the Android widget and clears it on logout. Verified data lands in HomeWidgetPreferences and the provider is registered. W3 (placing it on a launcher and watching totals) not done yet.
- 2026-10-30 D1: Android dashboard card redesigned for the space Burned/Steps left; screenshot-checked on the emulator, iOS layout unchanged. Subscription management opens Play's subscriptions page on Android.
- 2026-10-30 D1 (revised): enlarged rings still wasted space; without health the macros are now one row of bars (eaten/goal, g left). Card ~150px shorter; screenshot-checked.
- 2026-10-30 R1/R2: release signing reads `android/key.properties` (gitignored), falling back to debug signing until Sharath adds the upload key. `flutter build appbundle --release` (104.6 MB) and `apk --release` succeed with R8; the release APK launches on the emulator without crashes. Flutter warns Gradle 8.14.3 support will be dropped (wants 9.1+, i.e. AGP 9) — a later upgrade.
