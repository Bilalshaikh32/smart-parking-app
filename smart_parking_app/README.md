# Smart Parking System — Flutter Android App

A production Android app that talks directly to an Arduino Uno over
**Bluetooth Classic SPP (HC-05/HC-06)** — no internet, no cloud, no BLE,
no Firebase. The Arduino is the single source of truth for every parking
slot; the app only ever displays what the Arduino tells it.

---

## 1. Requirements

- Flutter **3.24.x** (stable channel) — check with `flutter --version`
- Android Studio or VS Code with the Flutter/Dart plugins
- An Android phone (or emulator with a virtual serial port) running
  Android 6.0 (API 23) or newer
- A paired HC-05 or HC-06 module

## 2. Install dependencies

```bash
flutter pub get
```

## 3. Pair the HC-05 (before opening the app)

1. Power the Arduino + HC-05 on.
2. On the phone: **Settings → Bluetooth → Pair new device**.
3. Select `HC-05` (or your module's name).
4. Enter PIN **`1234`** (some modules use `0000`).
5. Once "Paired" appears in Android Bluetooth settings, open the app.

The app only lists **already-paired** devices — it does not do a BLE-style
discovery scan, because HC-05 is Bluetooth Classic.

## 4. Grant permissions

On first "CONNECT HC-05" tap, Android will ask for **Nearby Devices**
permission (Android 12+) or Location (older Android, required by the
Bluetooth Classic plugin for device discovery). Allow it. If you
accidentally deny it permanently, the app shows an **Open Settings**
button to fix it manually.

## 5. Run the app

```bash
flutter run
```

## 6. Build a release APK

```bash
flutter clean
flutter pub get
flutter analyze
flutter test
flutter build apk --release
```

Output: `build/app/outputs/flutter-apk/app-release.apk`

> **This sandbox could not run these commands itself** (no network access
> to Flutter's package/engine servers from this environment) — see
> `BUILD_REPORT.md` for exactly what was and wasn't verified, and how to
> get a real compiled APK via the included GitHub Actions workflow if you
> don't want to install Flutter locally.

---

## 7. Hardware wiring

| Component            | Arduino Pin |
|-----------------------|------------|
| Entry IR sensor OUT    | D2 |
| Exit IR sensor OUT     | D3 |
| Servo signal           | D9 |
| LCD SDA                | A4 |
| LCD SCL                | A5 |
| LCD I2C address         | 0x27 |
| Red traffic light       | D4 |
| Yellow traffic light    | D5 |
| Green traffic light     | D6 |
| Slot 1 IR OUT           | D7 |
| Slot 2 IR OUT           | D8 |
| Slot 3 IR OUT           | D12 |
| Slot 4 IR OUT           | D13 |
| HC-05 TX → Arduino RX   | D10 |
| HC-05 RX ← Arduino TX   | D11 (via voltage divider) |

Gate: 0° = closed, 90° = open, stays open ~3 seconds.
Slot confirmation: occupied after 1s continuous detection; available only
after 5s continuous clear (prevents flicker when a car briefly blocks a
sensor while parking).

The canonical firmware is `arduino/smart_parking_arduino.ino` — flash this
exact file; the app's parser is written against it byte-for-byte.

---

## 8. Bluetooth wire protocol

All messages are newline-terminated ASCII. The app buffers partial chunks
(a Bluetooth read event is NOT guaranteed to contain a whole line) and
only processes complete lines — see `lib/services/parking_protocol_parser.dart`.

### Arduino → App

| Message | Meaning |
|---|---|
| `S1:0,S2:1,S3:0,S4:1` | Slot status. `0`=available, `1`=occupied. Any order, any subset. |
| `G:1` / `G:0` | Gate opening-or-open / closing-or-closed |
| `L1:<text>` | LCD row 1 (verbatim) |
| `L2:<text>` | LCD row 2 (verbatim) |
| `E:ENTRY_DENIED` | Car tried to enter, parking full |
| `E:MANUAL_OPEN` / `E:MANUAL_CLOSE` | Gate moved via app command |
| `E:SLOTn_OCCUPIED` / `E:SLOTn_AVAILABLE` | Slot n confirmed |
| `E:SLOTn_CHECKING` | Slot n momentarily lost detection; still counts as occupied for up to 5s while Arduino confirms |
| `PONG` | Reply to `PING` |

### App → Arduino

| Command | Effect |
|---|---|
| `STATUS\n` | Ask for a full status re-broadcast (sent automatically right after connecting) |
| `PING\n` | Connectivity test, expects `PONG` back |
| `OPEN\n` | Open gate (confirmation dialog shown before sending) |
| `CLOSE\n` | Close gate |

The gate UI never flips to "Open"/"Closed" just because a button was
tapped — it shows **"Command sent..."** and waits for a real `G:` line or
`E:MANUAL_*` event from the Arduino.

---

## 9. Architecture

```
lib/
  main.dart                    — entry point
  app.dart                     — Provider wiring (the ONE place Bluetooth
                                  and parking state are connected)
  models/
    parking_slot.dart          — SlotState enum (available/occupied/checking/unknown)
    parking_event.dart         — E: event parsing → typed ParkingEvent
    bluetooth_device_model.dart
    parking_state.dart         — shared enums/constants
  services/
    bluetooth_service.dart     — raw Bluetooth Classic I/O only, no app state
    parking_protocol_parser.dart — LineBuffer + pure parseLine() — unit tested
    permission_service.dart    — Android runtime permission requests
    local_storage_service.dart — remembers last device (SharedPreferences)
  controllers/
    bluetooth_controller.dart  — connection lifecycle, diagnostics log
    parking_controller.dart    — slot/gate/LCD/event domain state
  screens/
    splash_screen.dart
    dashboard_screen.dart
    device_picker_screen.dart
    diagnostics_screen.dart
  widgets/
    parking_slot_card.dart, connection_card.dart, parking_summary_card.dart,
    gate_control_card.dart, lcd_display_card.dart, status_indicator.dart
```

State management: **Provider** (`ChangeNotifier` + `ChangeNotifierProxyProvider`),
used consistently everywhere — no mixed state solutions.

Bluetooth I/O, protocol parsing, and UI are in three separate layers on
purpose: `BluetoothIoService` never touches app state, `ParkingProtocolParser`
is a pure function with no I/O (fully unit-testable), and `ParkingController`
never talks to the Bluetooth plugin directly.

## 10. Packages used

| Package | Why |
|---|---|
| `flutter_bluetooth_serial_plus` | Bluetooth **Classic SPP** support (required — BLE-only packages can't talk to HC-05). A maintained fork of `flutter_bluetooth_serial`; the original's last published version is capped at Dart `<3.0.0` and its Android module has no `namespace`, so it fails `pub get`/build on any current Flutter install. |
| `provider` | State management |
| `permission_handler` | Android 12+ runtime Bluetooth permissions |
| `shared_preferences` | Remembers last-connected device address only |
| `google_fonts` | Space Grotesk / JetBrains Mono / Inter |
| `flutter_animate` | Lightweight fade/scale transitions |
| `cupertino_icons` | Icon set |

## 11. Testing

```bash
flutter test
```

`test/parking_protocol_parser_test.dart` — buffered-chunk reconstruction,
`\n`/`\r\n`/bare `\r` handling, multi-message chunks, malformed/duplicate/
missing slot tokens, gate/LCD/event/PONG parsing, unknown input safety.

`test/parking_controller_test.dart` — checking-state still counts as
occupied, malformed packets preserve previous state, gate UI only confirms
from a real Arduino message (never from the button tap itself), unknown
events never throw, reconnect never shows stale data as live.

A full widget-test suite (pumping the dashboard through every connection/
slot/gate state) was intentionally not included to keep this deliverable
focused — the parser and controller tests cover 100% of the *data
correctness* rules in the spec, which is where a wiring bug would actually
hide.

## 12. Troubleshooting

| Symptom | Likely cause |
|---|---|
| `flutter pub get` fails with a version-solving error mentioning an SDK constraint | You're on an old copy of this project using `flutter_bluetooth_serial` directly — make sure `pubspec.yaml` says `flutter_bluetooth_serial_plus` (this was fixed; see `BUILD_REPORT.md`) |
| Gradle build fails with "Namespace not specified" | Same root cause as above — confirm the fork is in use and `android/build.gradle.kts` still has the namespace-patch `subprojects` block |
| No paired devices in the picker | HC-05 not paired yet — pair it in Android Bluetooth Settings first |
| "Could not connect" | Another app (e.g. a Bluetooth terminal) already holds the HC-05 serial port — close it and retry |
| Connects but no data ever arrives | Arduino not powered, or TX/RX swapped, or baud rate isn't 9600 |
| Slots stuck on "UNKNOWN" | No `S1:...` packet received yet — check Arduino is sending `sendCompleteStatus()` and that STATUS was requested |
| "Data may be stale" banner | No valid packet in the last 8 seconds — check Arduino power/range |
| Gate stuck on "Command sent..." | Arduino never replied with `G:` — check wiring/power, or servo is jammed |
| Permission denied every time | Tap **Open Settings** in the permission dialog and enable Nearby Devices manually |
