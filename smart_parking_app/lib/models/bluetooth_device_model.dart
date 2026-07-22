/// Lightweight, UI/testing-friendly wrapper around a paired Bluetooth
/// Classic device. Kept separate from the flutter_bluetooth_serial
/// package's own BluetoothDevice so widgets and tests don't need the
/// platform plugin to build.
class BluetoothDeviceInfo {
  final String name;
  final String address;
  final bool isBonded;

  const BluetoothDeviceInfo({
    required this.name,
    required this.address,
    this.isBonded = true,
  });

  /// HC-05 / HC-06 are the two modules this project supports. Devices
  /// matching this are surfaced first in the picker with a badge.
  bool get isLikelyHc05 {
    final n = name.toUpperCase();
    return n.contains('HC-05') || n.contains('HC-06') || n.contains('HC05') || n.contains('HC06');
  }
}
