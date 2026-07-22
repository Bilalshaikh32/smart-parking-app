# Smart Parking App

A professional Smart Parking System repository built around an Arduino Uno + HC-05 Bluetooth module and a Flutter Android dashboard.

This repo contains:

- `smart_parking_app/`: Flutter Android app source and tests
- `smart_parking_app/arduino/`: Arduino firmware for the smart parking hardware
- `smart_parking_app/README.md`: detailed app-specific setup, wiring, and protocol documentation

## What this project includes

- real-time slot monitoring for 4 parking slots
- entry/exit sensors with servo gate control
- traffic light indicator support
- HC-05 Bluetooth Classic communication
- LCD status display
- Flutter dashboard with live slot status, gate control, and Bluetooth diagnostics

## Recommended next steps

1. Open `smart_parking_app/README.md` for app-specific setup and wiring details.
2. Use `flutter pub get` inside `smart_parking_app/` to install dependencies.
3. Flash the Arduino firmware from `smart_parking_app/arduino/smart_parking_arduino.ino`.
4. Build and test the Flutter app with `flutter run` or `flutter build apk --release`.

## Notes

- The repo now excludes local build output and SDK folders via `.gitignore`.
- The important source files are in `smart_parking_app/`.
- If you want, I can also create a `LICENSE` file and add a GitHub release workflow next.
