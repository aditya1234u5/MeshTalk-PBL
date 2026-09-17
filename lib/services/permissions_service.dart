import 'package:permission_handler/permission_handler.dart';

/// BLE scanning/advertising needs a cluster of runtime permissions on
/// Android 12+ (BLUETOOTH_SCAN, BLUETOOTH_ADVERTISE, BLUETOOTH_CONNECT) plus
/// location on older Android versions (BLE scan results are treated as
/// location data pre-Android 12). iOS just needs Bluetooth usage description
/// in Info.plist (see README) - no runtime prompt code needed there beyond
/// what permission_handler triggers automatically.
class PermissionsService {
  static Future<bool> requestAll() async {
    final statuses = await [
      Permission.bluetoothScan,
      Permission.bluetoothAdvertise,
      Permission.bluetoothConnect,
      Permission.locationWhenInUse,
    ].request();

    return statuses.values.every((s) => s.isGranted || s.isLimited);
  }
}
