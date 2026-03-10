import 'package:permission_handler/permission_handler.dart';

/// Central place for runtime permission requests: location and notifications.
/// Call before using "current location" or when enabling prayer time notifications.
class AppPermissionService {
  AppPermissionService._();

  /// Request location permission (for "use current location" and prayer times).
  /// Returns true if granted or already granted, false if denied.
  static Future<bool> requestLocation() async {
    final status = await Permission.locationWhenInUse.request();
    if (status.isGranted) return true;
    if (status.isPermanentlyDenied) return false;
    return false;
  }

  /// Request notification permission (required for prayer time reminders on Android 13+ and iOS).
  /// Returns true if granted or already granted, false if denied.
  static Future<bool> requestNotification() async {
    final status = await Permission.notification.request();
    if (status.isGranted) return true;
    if (status.isPermanentlyDenied) return false;
    return false;
  }

  /// Check if notification permission is granted (e.g. to show "enable notifications" state).
  static Future<bool> isNotificationGranted() async {
    final status = await Permission.notification.status;
    return status.isGranted;
  }

  /// Check if location permission is granted.
  static Future<bool> isLocationGranted() async {
    final status = await Permission.locationWhenInUse.status;
    return status.isGranted;
  }

  /// Open app settings so user can grant permission manually.
  static Future<bool> openSettings() => openAppSettings();
}
