import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/data/latest.dart' as tz_data;
import 'package:timezone/timezone.dart' as tz;

import 'alarm_settings_service.dart';
import 'prayer_times_service.dart';

/// Flutter port of RN services/notifications.js.
///
/// Scheduling strategy mirrors RN exactly:
///   - alarmType 'default'   → default system notification sound
///   - alarmType 'azan'      → custom MP3 from res/raw (Android) / bundle (iOS)
///
/// Notifications repeat daily at the scheduled local time
/// (matchDateTimeComponents: DateTimeComponents.time).
///
/// Android channels are immutable once created — azan channels include a
/// version suffix (_v3) so that sound changes take effect via a new channel.
class NotificationService {
  NotificationService._();

  static const String _azanChannelVersion = 'v3';

  /// Default adhan file per prayer (raw resource name, no extension).
  static const Map<String, String> defaultAzanSounds = {
    'fajr':    'ali_ahmed_mullah',
    'sunrise': 'muhammad_bin_marwan_qasas',
    'dhuhr':   'muhammad_bin_marwan_qasas',
    'asr':     'hashim_al_saqaaf',
    'maghrib': 'shaya_al_tamimi',
    'isha':    'abdulrahman_al_hindi',
    'tahajjud':'ali_ahmed_mullah',
  };

  static const List<String> _regularKeys = [
    'fajr', 'sunrise', 'dhuhr', 'asr', 'maghrib', 'isha'
  ];

  /// Fixed integer IDs for each notification slot.
  static const Map<String, int> _ids = {
    'fajr-main': 1,    'fajr-pre': 2,
    'sunrise-main': 3, 'sunrise-pre': 4,
    'dhuhr-main': 5,   'dhuhr-pre': 6,
    'asr-main': 7,     'asr-pre': 8,
    'maghrib-main': 9, 'maghrib-pre': 10,
    'isha-main': 11,   'isha-pre': 12,
    'tahajjud-main': 13,
  };

  static final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();

  static bool _initialized = false;

  // ── Initialisation ────────────────────────────────────────────────────────

  static Future<void> initialize() async {
    if (_initialized) return;

    // Only need timezone data loaded; we compute UTC epoch from local DateTime.
    tz_data.initializeTimeZones();

    const initSettings = InitializationSettings(
      android: AndroidInitializationSettings('@mipmap/ic_launcher'),
      iOS: DarwinInitializationSettings(
        requestAlertPermission: false,
        requestBadgePermission: false,
        requestSoundPermission: false,
      ),
    );

    await _plugin.initialize(initSettings);
    await _createAndroidChannels();
    _initialized = true;
  }

  static Future<void> _createAndroidChannels() async {
    final android = _plugin.resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin>();
    if (android == null) return;

    for (final key in [..._regularKeys, 'tahajjud']) {
      // Default alarm channel — high importance so notification shows in shade
      await android.createNotificationChannel(AndroidNotificationChannel(
        'prayer_${key}_alarm',
        'Prayer $key Alarm',
        importance: Importance.high,
        playSound: true,
        enableVibration: false,
        showBadge: true,
      ));

      // Adhan channel (importance MAX, bypass DnD, custom sound)
      final soundName = defaultAzanSounds[key] ?? 'ali_ahmed_mullah';
      await android.createNotificationChannel(AndroidNotificationChannel(
        'prayer_${key}_azan_${soundName}_$_azanChannelVersion',
        'Prayer $key Adhan',
        importance: Importance.max,
        sound: RawResourceAndroidNotificationSound(soundName),
        playSound: true,
        enableVibration: true,
        showBadge: true,
      ));
    }
  }

  // ── Permissions ───────────────────────────────────────────────────────────

  static Future<bool> requestPermission() async {
    final android = _plugin.resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin>();
    if (android != null) {
      final granted = await android.requestNotificationsPermission() ?? false;
      await android.requestExactAlarmsPermission();
      return granted;
    }

    final ios = _plugin.resolvePlatformSpecificImplementation<
        IOSFlutterLocalNotificationsPlugin>();
    if (ios != null) {
      return await ios.requestPermissions(
            alert: true, badge: true, sound: true) ??
          false;
    }
    return false;
  }

  // ── Core scheduling ───────────────────────────────────────────────────────

  static Future<void> cancelAll() async {
    await _plugin.cancelAll();
  }

  /// Schedules prayer alarms for the next occurrence: today (if still in future) or tomorrow.
  /// [tomorrow] is used so that after midnight the correct next-day times fire without opening the app.
  static Future<void> schedulePrayerNotifications(
    PrayerTimesResult today,
    String locationName, {
    PrayerTimesResult? tomorrow,
    String Function(String key)? localize,
  }) async {
    if (!_initialized) await initialize();
    await cancelAll();

    final settings = await AlarmSettingsService.load();
    final now = DateTime.now();
    final tomorrowDate = now.add(const Duration(days: 1));
    final loc = localize ?? (k) => _fallbackLocalize(k);

    for (final key in _regularKeys) {
      final timeStrToday = _timeFor(today, key);
      if (!_isValidTime(timeStrToday)) continue;

      final prayer = Map<String, dynamic>.from(settings[key] as Map);
      final prayerName = loc(key);

      // Main alarm: next occurrence (today if in future, else tomorrow with tomorrow's time)
      if (prayer['enabled'] == true) {
        final dtToday = _resolveDateTimeForDate(timeStrToday, now);
        tz.TZDateTime? dt = dtToday != null && dtToday.isAfter(tz.TZDateTime.from(now, tz.UTC)) ? dtToday : null;
        if (dt == null && tomorrow != null) {
          final timeStrTomorrow = _timeFor(tomorrow, key);
          if (_isValidTime(timeStrTomorrow)) {
            dt = _resolveDateTimeForDate(timeStrTomorrow, tomorrowDate);
          }
        }
        if (dt != null) {
          final title = _format(loc('notificationPrayerTime'), {'prayer': prayerName});
          await _scheduleAt(
            id: _ids['$key-main']!,
            title: title,
            body: locationName.isNotEmpty ? locationName : title,
            dt: dt,
            prayerKey: key,
            alarmType: prayer['alarmType'] as String? ?? 'default',
          );
        }
      }

      // Pre-alarm N minutes before prayer time
      if (prayer['preEnabled'] == true) {
        final preMinutes = (prayer['preMinutes'] as num? ?? 30).toInt();
        final dtToday = _resolveDateTimeForDate(timeStrToday, now, offsetMinutes: -preMinutes);
        tz.TZDateTime? dt = dtToday != null && dtToday.isAfter(tz.TZDateTime.from(now, tz.UTC)) ? dtToday : null;
        if (dt == null && tomorrow != null) {
          final timeStrTomorrow = _timeFor(tomorrow, key);
          if (_isValidTime(timeStrTomorrow)) {
            dt = _resolveDateTimeForDate(timeStrTomorrow, tomorrowDate, offsetMinutes: -preMinutes);
          }
        }
        if (dt != null) {
          final String title;
          if (preMinutes < 60) {
            title = _format(loc('notificationMinutesUntil'), {'count': '$preMinutes', 'prayer': prayerName});
          } else {
            final h = preMinutes ~/ 60;
            final m = preMinutes % 60;
            title = _format(loc('notificationHoursMinutesUntil'), {'hours': '$h', 'minutes': '$m', 'prayer': prayerName});
          }
          await _scheduleAt(
            id: _ids['$key-pre']!,
            title: title,
            body: locationName.isNotEmpty ? locationName : title,
            dt: dt,
            prayerKey: key,
            alarmType: prayer['preAlarmType'] as String? ?? 'default',
          );
        }
      }
    }

    // Tahajjud: next occurrence of (Fajr - minutesBefore)
    final tahajjud = Map<String, dynamic>.from(settings['tahajjud'] as Map);
    if (tahajjud['enabled'] == true) {
      final minutesBefore = (tahajjud['minutesBeforeFajr'] as num? ?? 60).toInt();
      final dtToday = _resolveDateTimeForDate(today.fajr, now, offsetMinutes: -minutesBefore);
      tz.TZDateTime? dt = dtToday != null && dtToday.isAfter(tz.TZDateTime.from(now, tz.UTC)) ? dtToday : null;
      if (dt == null && tomorrow != null && _isValidTime(tomorrow.fajr)) {
        dt = _resolveDateTimeForDate(tomorrow.fajr, tomorrowDate, offsetMinutes: -minutesBefore);
      }
      if (dt != null) {
        final tahajjudName = loc('tahajjud');
        final String title;
        if (minutesBefore < 60) {
          title = _format(loc('notificationMinutesUntil'), {'count': '$minutesBefore', 'prayer': tahajjudName});
        } else {
          final h = minutesBefore ~/ 60;
          final m = minutesBefore % 60;
          title = _format(loc('notificationHoursMinutesUntil'), {'hours': '$h', 'minutes': '$m', 'prayer': tahajjudName});
        }
        await _scheduleAt(
          id: _ids['tahajjud-main']!,
          title: title,
          body: locationName.isNotEmpty ? locationName : title,
          dt: dt,
          prayerKey: 'tahajjud',
          alarmType: tahajjud['alarmType'] as String? ?? 'default',
        );
      }
    }
  }

  static String _format(String template, Map<String, String> params) {
    var s = template;
    for (final e in params.entries) {
      s = s.replaceAll('{${e.key}}', e.value);
    }
    return s;
  }

  static String _fallbackLocalize(String key) {
    const prayerNames = {
      'fajr': 'Fajr', 'sunrise': 'Sunrise', 'dhuhr': 'Dhuhr',
      'asr': 'Asr', 'maghrib': 'Maghrib', 'isha': 'Isha', 'tahajjud': 'Tahajjud',
    };
    if (prayerNames.containsKey(key)) return prayerNames[key]!;
    switch (key) {
      case 'notificationMinutesUntil': return '{count} min until {prayer}';
      case 'notificationHoursMinutesUntil': return '{hours}h {minutes}m until {prayer}';
      case 'notificationPrayerTime': return '{prayer} time';
      default: return key;
    }
  }

  // ── Private helpers ───────────────────────────────────────────────────────

  static String _timeFor(PrayerTimesResult t, String key) {
    switch (key) {
      case 'fajr':    return t.fajr;
      case 'sunrise': return t.sunrise;
      case 'dhuhr':   return t.dhuhr;
      case 'asr':     return t.asr;
      case 'maghrib': return t.maghrib;
      case 'isha':    return t.isha;
      default:        return '00:00';
    }
  }

  static bool _isValidTime(String t) =>
      t.length >= 5 && t != '00:00' && t.contains(':');

  /// Builds TZDateTime for [timeStr] (HH:mm) on the given calendar date [forDate], with optional [offsetMinutes].
  static tz.TZDateTime? _resolveDateTimeForDate(String timeStr, DateTime forDate,
      {int offsetMinutes = 0}) {
    final parts = timeStr.split(':');
    if (parts.length < 2) return null;
    final h = int.tryParse(parts[0]);
    final m = int.tryParse(parts[1]);
    if (h == null || m == null) return null;

    var local = DateTime(forDate.year, forDate.month, forDate.day, h, m, 0);
    if (offsetMinutes != 0) {
      local = local.add(Duration(minutes: offsetMinutes));
    }
    return tz.TZDateTime.fromMillisecondsSinceEpoch(
      tz.UTC,
      local.toUtc().millisecondsSinceEpoch,
    );
  }

  static Future<void> _scheduleAt({
    required int id,
    required String title,
    required String body,
    required tz.TZDateTime dt,
    required String prayerKey,
    required String alarmType,
  }) async {
    final effectiveType = alarmType == 'vibration' ? 'default' : alarmType;
    final soundName = defaultAzanSounds[prayerKey] ?? 'ali_ahmed_mullah';

    final NotificationDetails details;

    switch (effectiveType) {
      case 'azan':
        final channelId =
            'prayer_${prayerKey}_azan_${soundName}_$_azanChannelVersion';
        details = NotificationDetails(
          android: AndroidNotificationDetails(
            channelId,
            'Prayer $prayerKey Adhan',
            importance: Importance.max,
            priority: Priority.max,
            sound: RawResourceAndroidNotificationSound(soundName),
            playSound: true,
            enableVibration: true,
            fullScreenIntent: true,
            visibility: NotificationVisibility.public,
          ),
          iOS: DarwinNotificationDetails(
            sound: '$soundName.mp3',
            presentAlert: true,
            presentBadge: true,
            presentSound: true,
          ),
        );

      default: // 'default' — system alarm sound
        details = NotificationDetails(
          android: AndroidNotificationDetails(
            'prayer_${prayerKey}_alarm',
            'Prayer $prayerKey Alarm',
            importance: Importance.high,
            priority: Priority.high,
            playSound: true,
            visibility: NotificationVisibility.public,
          ),
          iOS: const DarwinNotificationDetails(
            sound: 'default',
            presentAlert: true,
            presentBadge: true,
            presentSound: true,
          ),
        );
    }

    // Prayer times shift daily — app reschedules on each launch.
    // No matchDateTimeComponents needed; just fire once at the next occurrence.
    await _plugin.zonedSchedule(
      id,
      title,
      body.isEmpty ? null : body,
      dt,
      details,
      androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
      uiLocalNotificationDateInterpretation:
          UILocalNotificationDateInterpretation.absoluteTime,
    );
  }

}
