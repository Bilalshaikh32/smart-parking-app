/// Overall Bluetooth link state, shown throughout the dashboard.
enum BtConnectionState { disconnected, connecting, connected, error }

/// Gate barrier state. [commandSent] is a transient "waiting for Arduino
/// to confirm" state shown right after OPEN/CLOSE is tapped — the UI must
/// NOT show Open/Closed just because a button was pressed; it waits for a
/// real G: line or event from the Arduino.
enum GateState { unknown, open, closed, commandSent }

const int kTotalSlots = 4;
const Duration kStaleDataThreshold = Duration(seconds: 8);
const int kMaxEventLogEntries = 50;
const int kMaxDiagnosticLogEntries = 200;
