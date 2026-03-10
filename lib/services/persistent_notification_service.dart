import 'dart:async';
import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

import 'notification_service.dart';
import 'prayer_times_service.dart';

/// Persistent notification with live countdown to next prayer.
///
/// On Android: uses a foreground service so the countdown keeps updating every second
/// even when the app is closed. On other platforms: updates only while app is running.
/// Stops when persistentNotificationEnabled is false.
class PersistentNotificationService {
  PersistentNotificationService._();

  static const int _notificationId = 1001;
  static const String _channelId = 'prayer_times_persistent';
  static const String _appTitle = 'Nida Adhan';
  static const MethodChannel _channel =
      MethodChannel('com.nida.islamiuygulama/persistent_notification');

  static Timer? _updateTimer;
  static PrayerTimesResult? _cachedTimes;
  static String _cachedLocationName = '';
  static String Function(String)? _cachedLocalize;

  static final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();

  static bool _channelCreated = false;

  /// Must be called before showing. Creates the low-priority channel.
  static Future<void> _ensureChannel() async {
    if (_channelCreated) return;
    final android = _plugin.resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin>();
    if (android == null) return;

    await android.createNotificationChannel(const AndroidNotificationChannel(
      _channelId,
      'Prayer Times',
      description: 'Continuous prayer times countdown',
      importance: Importance.low,
      playSound: false,
      enableVibration: false,
      showBadge: false,
    ));
    _channelCreated = true;
  }

  /// Format remaining seconds to "H:MM:SS" or "M:SS" or "0:SS"
  static String _formatRemaining(int totalSeconds) {
    if (totalSeconds <= 0) return '0:00';
    final h = totalSeconds ~/ 3600;
    final m = (totalSeconds % 3600) ~/ 60;
    final s = totalSeconds % 60;
    if (h > 0) {
      return '$h:${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
    }
    if (m > 0) return '$m:${s.toString().padLeft(2, '0')}';
    return '0:${s.toString().padLeft(2, '0')}';
  }

  /// Compute remaining seconds until next prayer (same logic as getNextPrayer)
  static int _remainingSeconds(PrayerTimesResult times, DateTime now) {
    final nowSecs = now.hour * 3600 + now.minute * 60 + now.second;
    final prayers = [
      ('fajr', times.fajr),
      ('dhuhr', times.dhuhr),
      ('asr', times.asr),
      ('maghrib', times.maghrib),
      ('isha', times.isha),
    ];

    for (final p in prayers) {
      final parts = p.$2.split(':');
      if (parts.length < 2) continue;
      final pH = int.tryParse(parts[0]) ?? 0;
      final pM = int.tryParse(parts[1]) ?? 0;
      final prayerSecs = pH * 3600 + pM * 60;
      if (prayerSecs > nowSecs) return prayerSecs - nowSecs;
    }

    // Next is tomorrow fajr
    final parts = times.fajr.split(':');
    final fH = int.tryParse(parts.isNotEmpty ? parts[0] : '0') ?? 0;
    final fM = int.tryParse(parts.length > 1 ? parts[1] : '0') ?? 0;
    final tomorrowFajrSecs = (fH + 24) * 3600 + fM * 60;
    return tomorrowFajrSecs - nowSecs;
  }

  /// Get next prayer info for display (remaining is formatted from live seconds for countdown)
  static (String key, String time, String remaining) _nextPrayerInfo(
    PrayerTimesResult times,
    DateTime now,
  ) {
    final secs = _remainingSeconds(times, now);
    final next = getNextPrayer(times, now);
    return (next.key, next.time, _formatRemaining(secs));
  }

  /// Build notification title and body (matches RN PrayerTimeForegroundService)
  static (String title, String body) _buildContent(
    String locationName,
    PrayerTimesResult times,
    DateTime now,
  ) {
    final h = now.hour.toString().padLeft(2, '0');
    final m = now.minute.toString().padLeft(2, '0');
    final title = '$_appTitle • ($h:$m)';

    final (key, time, remaining) = _nextPrayerInfo(times, now);
    final prayerName = _cachedLocalize?.call(key) ?? key;
    final body = key.isNotEmpty
        ? '$locationName. $prayerName $time. ($remaining)'
        : '$locationName • Waiting for prayer times...';

    return (title, body);
  }

  static bool _initDone = false;

  /// Start or update the persistent notification. Call every second when enabled.
  static Future<void> update(
    PrayerTimesResult? times,
    String locationName, {
    String Function(String prayerKey)? localize,
  }) async {
    if (!Platform.isAndroid) return;

    _cachedLocalize = localize;

    if (times == null) {
      await stop();
      return;
    }

    if (!_initDone) {
      await _ensureChannel();
      await NotificationService.initialize();
      await NotificationService.requestPermission();
      _initDone = true;
    }

    _cachedTimes = times;
    _cachedLocationName = locationName.isEmpty ? 'Prayer Times' : locationName;

    final now = DateTime.now();
    final (title, body) = _buildContent(_cachedLocationName, times, now);

    final android = _plugin.resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin>();
    if (android == null) return;

    final details = AndroidNotificationDetails(
      _channelId,
      'Prayer Times',
      channelDescription: 'Continuous prayer times countdown',
      importance: Importance.low,
      priority: Priority.low,
      ongoing: true,
      playSound: false,
      enableVibration: false,
      channelShowBadge: false,
      category: AndroidNotificationCategory.service,
      styleInformation: BigTextStyleInformation(body, contentTitle: title),
    );

    await _plugin.show(
      _notificationId,
      title,
      body,
      NotificationDetails(android: details),
    );
  }

  /// Start the update timer (every 5s to avoid NotificationManager log spam; countdown still works).
  /// On Android starts a foreground service so countdown continues when app is closed.
  static const Duration _updateInterval = Duration(seconds: 5);
  static void startUpdateTimer({
    required PrayerTimesResult times,
    required String locationName,
    required String Function(String) localize,
    String? appTitle,
  }) {
    stopUpdateTimer();
    _cachedTimes = times;
    _cachedLocationName = locationName;
    _cachedLocalize = localize;

    if (Platform.isAndroid) {
      _startAndroidForegroundService(
        times: times,
        locationName: locationName.isEmpty ? 'Prayer Times' : locationName,
        appTitle: appTitle ?? _appTitle,
      );
      return;
    }

    void tick() {
      if (_cachedTimes == null) return;
      update(_cachedTimes, _cachedLocationName, localize: localize);
    }
    tick();
    _updateTimer = Timer.periodic(_updateInterval, (_) => tick());
  }

  static Future<void> _startAndroidForegroundService({
    required PrayerTimesResult times,
    required String locationName,
    required String appTitle,
  }) async {
    try {
      await _channel.invokeMethod('start', {
        'location': locationName,
        'fajr': times.fajr,
        'dhuhr': times.dhuhr,
        'asr': times.asr,
        'maghrib': times.maghrib,
        'isha': times.isha,
        'appTitle': appTitle,
      });
    } catch (_) {}
  }

  static void stopUpdateTimer() {
    _updateTimer?.cancel();
    _updateTimer = null;
  }

  /// Stop the persistent notification and foreground service.
  static Future<void> stop() async {
    stopUpdateTimer();
    _cachedTimes = null;

    if (Platform.isAndroid) {
      try {
        await _channel.invokeMethod('stop');
      } catch (_) {}
      return;
    }
    await _plugin.cancel(_notificationId);
  }
}
