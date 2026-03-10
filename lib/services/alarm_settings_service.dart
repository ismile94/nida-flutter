import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';

/// Mirrors the RN AlarmSettingsModal's AsyncStorage key and data shape.
/// Each prayer has: enabled, preEnabled, preMinutes, alarmType.
/// tahajjud has: enabled, minutesBeforeFajr, alarmType.
class AlarmSettingsService {
  static const String _key = 'prayer_alarm_settings';

  static Map<String, dynamic> get defaultSettings => {
        'fajr':    _defaultPrayer(),
        'sunrise': _defaultPrayer(),
        'dhuhr':   _defaultPrayer(),
        'asr':     _defaultPrayer(),
        'maghrib': _defaultPrayer(),
        'isha':    _defaultPrayer(),
        'tahajjud': {
          'enabled': false,
          'minutesBeforeFajr': 60,
          'alarmType': 'default',
        },
        'persistentNotificationEnabled': true,
      };

  static Map<String, dynamic> _defaultPrayer() => {
        'enabled': false,
        'preEnabled': false,
        'preMinutes': 10,
        'alarmType': 'default',
        'preAlarmType': 'default',
      };

  /// Loads and returns settings, merged with defaults for any missing keys.
  static Future<Map<String, dynamic>> load() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_key);
      if (raw == null) return Map<String, dynamic>.from(defaultSettings);
      final parsed = Map<String, dynamic>.from(jsonDecode(raw) as Map);
      final merged = Map<String, dynamic>.from(defaultSettings);
      // Merge top-level prayer keys
      for (final k in ['fajr', 'sunrise', 'dhuhr', 'asr', 'maghrib', 'isha']) {
        if (parsed[k] is Map) {
          final p = Map<String, dynamic>.from(parsed[k] as Map);
          if (p['alarmType'] == 'vibration') p['alarmType'] = 'default';
          if (p['preAlarmType'] == 'vibration') p['preAlarmType'] = 'default';
          merged[k] = Map<String, dynamic>.from(
              {...(merged[k] as Map), ...p});
        }
      }
      if (parsed['tahajjud'] is Map) {
        final t = Map<String, dynamic>.from(parsed['tahajjud'] as Map);
        t.remove('mode');
        t.remove('time');
        if ((t['minutesBeforeFajr'] as num? ?? 0) == 0) {
          t['minutesBeforeFajr'] = 60;
        }
        if (t['alarmType'] == 'vibration') t['alarmType'] = 'default';
        merged['tahajjud'] = {...(merged['tahajjud'] as Map), ...t};
      }
      if (parsed.containsKey('persistentNotificationEnabled')) {
        merged['persistentNotificationEnabled'] =
            parsed['persistentNotificationEnabled'];
      }
      return merged;
    } catch (_) {
      return Map<String, dynamic>.from(defaultSettings);
    }
  }

  /// Persists the given settings object.
  static Future<void> save(Map<String, dynamic> settings) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_key, jsonEncode(settings));
  }
}
