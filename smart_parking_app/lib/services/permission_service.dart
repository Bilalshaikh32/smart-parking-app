import 'package:permission_handler/permission_handler.dart';

enum PermissionOutcome { granted, denied, permanentlyDenied }

/// Wraps permission_handler for the exact set of permissions this app
/// needs. On Android 12+ (API 31+), BLUETOOTH_CONNECT / BLUETOOTH_SCAN are
/// the ones that actually gate Bluetooth Classic APIs; on older Android
/// versions the legacy manifest-only BLUETOOTH/BLUETOOTH_ADMIN permissions
/// are sufficient and nothing needs to be requested at runtime for them.
class PermissionService {
  PermissionService._();

  static Future<PermissionOutcome> requestBluetoothPermissions() async {
    final statuses = await [
      Permission.bluetoothConnect,
      Permission.bluetoothScan,
      Permission.locationWhenInUse,
    ].request();

    if (statuses.values.any((s) => s.isPermanentlyDenied)) {
      return PermissionOutcome.permanentlyDenied;
    }
    if (statuses.values.every((s) => s.isGranted)) {
      return PermissionOutcome.granted;
    }
    return PermissionOutcome.denied;
  }

  static Future<bool> hasBluetoothPermissions() async {
    final connect = await Permission.bluetoothConnect.status;
    final scan = await Permission.bluetoothScan.status;
    return connect.isGranted && scan.isGranted;
  }

  static Future<void> openSettings() => openAppSettings();
}
