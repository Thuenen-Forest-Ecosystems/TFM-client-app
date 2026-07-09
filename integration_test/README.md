# Integration tests (Patrol, on-emulator E2E)

These tests drive the **real app on an emulator/device**, tapping real widgets
*and* native OS dialogs (location / Bluetooth permission prompts). They use
[Patrol](https://patrol.leancode.co) `^4.6.1`, which is built on top of
Flutter's official `integration_test` package but adds native automation.

> Plain `flutter test integration_test/…` will **not** work for these — Patrol
> tests must be launched with the `patrol` CLI. ([Why?](https://patrol.leancode.co/documentation#faq))

## One-time setup (already done in this repo)

- `pubspec.yaml`: `integration_test` + `patrol` dev deps and a top-level
  `patrol:` config block (`test_directory: integration_test`).
- `android/app/build.gradle`: `PatrolJUnitRunner`, `testOptions` orchestrator,
  and `androidTestUtil` orchestrator dependency.
- `android/app/src/androidTest/java/de/thuenen/terrestrial_forest_monitor/MainActivityTest.java`.

Each developer still needs the CLI once:

```bash
flutter pub global activate patrol_cli   # installs the `patrol` command
# ensure ~/.pub-cache/bin is on your PATH
patrol doctor                            # all checks green for Android
```

> **iOS not set up yet.** Only Android is configured. iOS needs an
> `RunnerUITests` target in Xcode (see the Patrol "iOS setup" docs) before
> `patrol test` will run on the iOS simulator.

## Running

```bash
# 1) Boot an emulator
flutter emulators --launch Pixel_8_Pro_API_35

# 2) Verify the Patrol toolchain itself (does NOT boot the app)
patrol test -t integration_test/patrol_smoke_test.dart

# 3) Run the real-app tests. The authenticated walkthrough reads credentials
#    from TFM-app/.env (git-ignored):
#        TFM_TEST_EMAIL=you@thuenen.de
#        TFM_TEST_PASSWORD=your-password
#    Without them, the walkthrough skips itself (the boot test still runs).
patrol test -t integration_test/app_test.dart

# In CI (no .env) supply the same names via --dart-define, which overrides .env:
patrol test -t integration_test/app_test.dart \
  --dart-define=TFM_TEST_EMAIL=you@thuenen.de \
  --dart-define=TFM_TEST_PASSWORD=your-password

# Run everything in integration_test/
patrol test
```

Interactive/hot-restart mode while writing tests: `patrol develop -t <file>`.

## Files

- **`patrol_smoke_test.dart`** — Validates the Patrol setup end-to-end without
  the app. Run this first: if it passes, failures elsewhere are about the app,
  not the setup.
- **`app_test.dart`** — Boots the real app, grants the native location
  permission, and drives real user flows:
  - login → home
  - settings walkthrough (open the settings/Profile page, switch language and
    theme, asserting each selection indicator follows)
  - **offline login** — logs in online (to cache credentials), logs out, then
    uses Patrol's native `disableWifi()`/`disableCellular()` to force the app's
    offline path and signs back in with the cached credentials, restoring the
    network in a `finally`.

  The place to grow "click every button / use every feature" coverage. Shared
  setup lives in the `_bootAndLogin($)` helper — call it at the top of any new
  authenticated test, `return` early if it returns `false` (no credentials),
  then drive your flow from the home screen. Credentials resolve via
  `_resolveCreds()` (`--dart-define` over `.env`).

## Extending toward full-feature coverage

`app_test.dart` boots the app by calling its real `main()`. That works because
this app does not override `FlutterError.onError` or use `runZonedGuarded`. To
grow coverage, add steps after login: open a record, fill a form field, trigger
validation, assert the result — one small, asserted flow at a time.

Two things make this much easier and more robust; do them when you start
writing real flows:

1. **Add `Key`s to interactive widgets** you assert on, so finders don't depend
   on German/English label text or widget order. Already keyed (find them in
   Patrol with e.g. `$(#loginEmailField)`):
   - Login: `#loginEmailField`, `#loginPasswordField`, `#loginSubmitButton`,
     `#loginOfflineSubmitButton`
   - Home (Schema) app bar: `#homeSettingsButton` (opens the settings/Profile
     page), `#homeAccountMenuButton` (account menu) + `#logoutMenuItem`
   - Settings — language: `#langOption_de`, `#langOption_en`, `#langOption_system`
   - Settings — theme: `#themeOption_light`, `#themeOption_dark`, `#themeOption_system`

   The selected language/theme option shows a `check_circle`; assert it with a
   descendant finder, e.g. `$(#langOption_en).$(Icons.check_circle)`. Follow the
   same pattern on new screens you test.
2. **Extract a `createTfmApp()` seam** from `main()` — a function that runs the
   async startup and returns the root `MultiProvider(...)` widget *without*
   calling `runApp()`/`WidgetsFlutterBinding.ensureInitialized()`. Tests then do
   `await $.pumpWidgetAndSettle(await createTfmApp())`, which is Patrol's
   recommended pattern and avoids the whole-`main()` caveats.

Consider a **`TEST_MODE` dart-define** that enables playground mode
(`PlaygroundModeProvider`), seeds a fake auth token to skip the real Supabase
login, and swaps the Bluetooth/GPS source for the existing NMEA replay
(`test/nmea_replay_test.dart`) — an emulator has no real GPS/Bluetooth device.

## Gotchas

- **`pumpAndSettle` can hang/timeout** on screens with a live map or GPS marker
  that never stop animating. Poll for a specific widget instead (see the login
  loop in `app_test.dart`) or use `$.pump(Duration(...))`.
- **Bluetooth GPS hardware can't be tested on an emulator** — inject mock/replay
  NMEA behind a test flag.
- **Orchestrator hang**: if `patrol test` stalls at
  `flutter build apk --config-only`, bump the `androidTestUtil` orchestrator in
  `android/app/build.gradle` from `1.5.1` to `1.6.1`.
- `integration_test/test_bundle.dart` is generated by Patrol and git-ignored —
  never commit it.
