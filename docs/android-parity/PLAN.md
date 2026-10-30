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
5. If an item needs a dashboard, credential, or decision from the user, move it to **Blocked on user**
   with the exact ask, and continue with the next item.
6. Stop the loop when every Work-queue item is ticked or blocked.

## Work queue

### 0. Toolchain
- [ ] T1 Install JDK 17 (`brew install openjdk@17`) and point Flutter at it (`flutter config --jdk-dir`)
- [ ] T2 Install Android platform 36 + build-tools 36 via sdkmanager; accept licenses

### 1. Build & start (A01, A02)
- [ ] B1 Gradle 8.11.1 / AGP 8.10.x / Kotlin, dedupe AGP + google-services, apply google-services to app only, desugar ≥2.1.4, compile/target SDK 36
- [ ] B2 Move `MainActivity`/`CameraActivity` into `android.macrobalance.app` package; drop duplicate plugin registration
- [ ] B3 Debug APK builds and the app launches to the welcome screen on the emulator

### 2. Hide health on Android (replaces A04/A12/A13)
- [ ] H1 Add one capability flag (e.g. `HealthService.isSupported` → false on Android) and short-circuit all health calls there
- [ ] H2 Skip the Apple Health onboarding step on Android (step list + progress count stay consistent)
- [ ] H3 Hide Health Integration entry in settings, and steps/burned-calorie/health-weight UI on dashboard and Progress tabs
- [ ] H4 Remove health permissions/queries from the Android manifest if any are present; make sure `health` plugin doesn't crash at startup

### 3. Camera, barcode, label (A03) — core feature
- [ ] C1 CameraX + ML Kit Android implementation behind the existing `showNativeCamera` channel, same `cameraResult` contract (type/value/mode)
- [ ] C2 Food-photo mode: capture, gallery pick (system photo picker), JPEG compress/orient
- [ ] C3 Barcode mode: live EAN/UPC detection, manual entry, torch
- [ ] C4 Label mode, permission denial/recovery, Back/cancel return exactly one result
- [ ] C5 Remove the Android `UNSUPPORTED_PLATFORM` guard in `CameraService`; verify AppShell, Dashboard and Search entry points end-to-end on emulator

### 4. Auth (A07, A08, A09)
- [ ] U1 Google sign-in: platform-specific clientId (iOS only) + serverClientId on Android
- [ ] U2 Apple sign-in on Android via Supabase browser OAuth (existing Apple users)
- [ ] U3 One deep-link contract: reset password, email verification, OAuth return; manifest intent filters match Supabase redirects
- [ ] U4 Verify email signup/login/reset/logout on emulator

### 5. Subscriptions (A05, A10)
- [ ] P1 Configure RevenueCat on Android branch in `main.dart` (key from user), Superwall Android key
- [ ] P2 `Purchases.logIn/logOut` with Supabase user ID; single exact entitlement check
- [ ] P3 Paywall shows and restore works with a Play license tester

### 6. Notifications (A14)
- [ ] N1 Single channel id shared with server (`meal_reminders`), monochrome status icon, FCM default channel in manifest
- [ ] N2 POST_NOTIFICATIONS request flow; `tz.setLocalLocation` with device zone; tap routing
- [ ] N3 Verify a local and a push notification arrive and open the app on emulator

### 7. Home-screen widget (A11)
- [ ] W1 Kotlin AppWidgetProvider + RemoteViews layouts (calories, macros, recent meals) reading `macro_data`/`daily_meals`
- [ ] W2 Pass `androidName` in `home_widget` updates; tap opens app; clears on logout
- [ ] W3 Verify on emulator: add widget, log food, totals match

### 8. Android UX pass (A16)
- [ ] X1 Edge-to-edge/insets, system Back on sheets/camera/tabs, keyboard over search and manual barcode
- [ ] X2 Walk every screen on emulator (light + dark), fix clipped/iOS-only UI (Cupertino-only pickers, iOS status bar branches)

### 9. Release readiness (A06)
- [ ] R1 Release signing config reading `key.properties` (keystore from user), versionCode from pubspec `+build`
- [ ] R2 `flutter build appbundle --release` succeeds; app runs in release mode on emulator

## Blocked on user
_(loop fills this in with exact asks — e.g. RevenueCat Google API key, Play Console products, Android OAuth client + SHA-1, Apple Services ID, upload keystore)_

## Log
