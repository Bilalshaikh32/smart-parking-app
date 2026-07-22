# Build & Verification Report — Honest Status

This sandbox environment has **no network access to Flutter's package
registry (pub.dev) or engine artifact servers (storage.googleapis.com)** —
both are outside the allowed domain list, and requests to them return
`403`. Practically, this means `flutter pub get`, `flutter analyze`,
`flutter test`, and `flutter build apk` **could not be executed inside
this sandbox**, and I am not going to claim they passed when they were
never actually run here.

## Update — two real, confirmed-breaking bugs found and fixed

After the person reported build problems, I re-audited the project against
the actual source of its dependencies (fetched from GitHub, which this
sandbox *can* reach) instead of only re-checking my own code in isolation.
That surfaced two genuine, verified bugs — not guesses:

1. **`flutter_bluetooth_serial: ^0.4.0`'s own `pubspec.yaml` declares
   `sdk: '>=2.12.0 <3.0.0'`.** Every current Flutter install ships Dart
   3.x, which is outside that range. This makes `flutter pub get` fail
   version solving *immediately*, before any code is even compiled —
   confirmed by fetching the package's real `pubspec.yaml` from its
   GitHub repo, not assumed.
2. **That same package's `android/build.gradle` declares no `namespace`.**
   Android Gradle Plugin 8+ (used by all current Flutter versions) requires
   every Android library module to declare one, or the build fails with
   "Namespace not specified" — confirmed by fetching the actual file.

**Fix applied:**
- Switched `pubspec.yaml` and the one file that imports it
  (`lib/services/bluetooth_service.dart`) to
  `flutter_bluetooth_serial_plus: ^0.5.3` — an actively maintained fork
  with an identical API (verified class-by-class against its GitHub
  source: `BluetoothConnection`, `FlutterBluetoothSerial`,
  `BluetoothDevice` all match) but a fixed SDK constraint
  (`>=2.12.0 <4.0.0`) and a declared `namespace`. No other code changes
  were needed — it's a drop-in replacement.
- Added a defensive namespace patch to `android/build.gradle.kts` as a
  safety net for any *other* older plugin that might have the same
  missing-namespace problem in the future.

## What WAS actually done and verified in this environment

- Full source tree written by hand against the spec (models, services,
  controllers, screens, widgets, tests, Android config).
- **Manual brace/paren balance check** across every `.dart` file (script-
  verified, zero mismatches, re-run after every edit).
- **Manual import audit**: every class referenced across files was
  cross-checked against its defining file's import path.
- **Manual constructor/parameter audit**: every widget's `required`
  parameters were diffed against every call site by hand.
- **Dependency source audit** (this round): fetched and read the actual
  source of `flutter_bluetooth_serial`, confirmed the SDK-constraint and
  namespace bugs directly against real files rather than assumption, then
  fetched and cross-checked the replacement fork's API before switching.
- Removed the earlier `google_fonts` bug (fetches fonts over the network,
  contradicting the offline-only requirement) — bundled system fonts used
  instead, dependency removed entirely.
- Confirmed via `curl` that this sandbox cannot reach
  `storage.googleapis.com` (Flutter's engine/SDK host), which is *why*
  `flutter` itself isn't runnable here — not guessed, tested directly.

## What was NOT run here (and why)

| Step | Status | Why |
|---|---|---|
| `flutter pub get` | Not run | No pub.dev access in this sandbox |
| `flutter analyze` | Not run | Requires the Dart analyzer from the Flutter SDK, which requires `pub get` first |
| `flutter test` | Not run | Same — requires the Flutter SDK |
| `flutter build apk --release` | Not run | Same — requires the Flutter SDK + Android Gradle toolchain |

I have **not** patched, unzipped, or repacked any compiled APK for this
delivery — per the spec's explicit instruction, none is included from
this environment. Producing a real, normally-built APK requires an
actual Flutter toolchain.

## How to get the real, verified build

**Option A — GitHub Actions (recommended, no local install needed).**
`.github/workflows/build-apk.yml` runs the exact required sequence —
`flutter clean` → `pub get` → `analyze` → `test` → `build apk --release`
(and `--debug`) — on GitHub's runners, which DO have full internet
access. Push this project to a GitHub repo and open the **Actions** tab;
both APKs are attached as downloadable build artifacts. If `analyze` or
`test` fails, the build stops there and you'll see exactly which one and
why, in the Actions log.

**Option B — Your own machine:**
```bash
flutter --version   # confirm 3.24.x or newer
flutter clean
flutter pub get
flutter analyze
flutter test
flutter build apk --release
```

Only after one of these two has actually completed can "the APK builds
and installs normally" be treated as verified — not before.

If `flutter pub get` still fails after this fix, please paste the exact
error text — that turns the next round into a targeted fix instead of
another blind full audit.

| Step | Status | Why |
|---|---|---|
| `flutter pub get` | Not run | No pub.dev access in this sandbox |
| `flutter analyze` | Not run | Requires the Dart analyzer from the Flutter SDK, which requires `pub get` first |
| `flutter test` | Not run | Same — requires the Flutter SDK |
| `flutter build apk --release` | Not run | Same — requires the Flutter SDK + Android Gradle toolchain |

I have **not** patched, unzipped, or repacked any compiled APK for this
delivery — per the spec's explicit instruction, none is included from
this environment. Producing a real, normally-built APK requires an
actual Flutter toolchain.

## How to get the real, verified build

**Option A — GitHub Actions (recommended, no local install needed).**
`.github/workflows/build-apk.yml` runs the exact required sequence —
`flutter clean` → `pub get` → `analyze` → `test` → `build apk --release`
(and `--debug`) — on GitHub's runners, which DO have full internet
access. Push this project to a GitHub repo and open the **Actions** tab;
both APKs are attached as downloadable build artifacts. If `analyze` or
`test` fails, the build stops there and you'll see exactly which one and
why, in the Actions log.

**Option B — Your own machine:**
```bash
flutter --version   # confirm 3.24.x or newer
flutter clean
flutter pub get
flutter analyze
flutter test
flutter build apk --release
```

Only after one of these two has actually completed can "the APK builds
and installs normally" be treated as verified — not before.
