import 'package:permission_handler/permission_handler.dart';

/// BLE scanning/advertising needs a cluster of runtime permissions on
/// Android 12+ (BLUETOOTH_SCAN, BLUETOOTH_ADVERTISE, BLUETOOTH_CONNECT) plus
/// location on older Android versions (BLE scan results are treated as
/// location data pre-Android 12). iOS just needs Bluetooth usage description
/// in Info.plist (see README) - no runtime prompt code needed there beyond
/// what permission_handler triggers automatically.
///
/// The manifest scopes ACCESS_FINE_LOCATION to maxSdkVersion=30 and marks
/// BLUETOOTH_SCAN as neverForLocation - meaning on Android 12+ (API 31+)
/// location is genuinely not required at all, and the OS will *always*
/// report it denied there since the permission isn't even declared for
/// that API level. So we request it (it still matters on Android <=11)
/// but only gate app startup on the three Bluetooth permissions actually
/// being granted, not on location.
class PermissionsService {
  static Future<bool> requestAll() async {
    final statuses = await [
      Permission.bluetoothScan,
      Permission.bluetoothAdvertise,
      Permission.bluetoothConnect,
      Permission.locationWhenInUse,
    ].request();

    final bluetoothGranted = [
      Permission.bluetoothScan,
      Permission.bluetoothAdvertise,
      Permission.bluetoothConnect,
    ].every((p) => statuses[p]?.isGranted ?? false);

    return bluetoothGranted;
  }
}