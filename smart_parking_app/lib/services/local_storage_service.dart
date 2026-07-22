import 'package:shared_preferences/shared_preferences.dart';

/// Local storage is used ONLY for reconnection convenience — never for
/// live parking data. On every app start, slots begin as [SlotState.unknown]
/// and only become real once a fresh STATUS packet arrives from Arduino.
class LocalStorageService {
  LocalStorageService._();

  static const _keyDeviceAddress = 'last_device_address';
  static const _keyDeviceName = 'last_device_name';

  static Future<void> saveLastDevice(String name, String address) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keyDeviceName, name);
    await prefs.setString(_keyDeviceAddress, address);
  }

  static Future<({String name, String address})?> getLastDevice() async {
    final prefs = await SharedPreferences.getInstance();
    final address = prefs.getString(_keyDeviceAddress);
    final name = prefs.getString(_keyDeviceName);
    if (address == null || name == null) return null;
    return (name: name, address: address);
  }

  static Future<void> clearLastDevice() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_keyDeviceAddress);
    await prefs.remove(_keyDeviceName);
  }
}
