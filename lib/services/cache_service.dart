// RN services/cache.js – SharedPreferences ile aynı mantık.

import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';

const int expiryPrayerTimes = 60 * 60 * 1000;
const int expiryLocation = 24 * 60 * 60 * 1000;
const int expiryQibla = 24 * 60 * 60 * 1000;
const int expiryMosques = 7 * 24 * 60 * 60 * 1000;
const int expiryRoute = 7 * 24 * 60 * 60 * 1000;

String cacheKeyLocationName(String lat, String lng) => '@cache_location_name_${lat}_$lng';
String cacheKeyQiblaDirection(String lat, String lng) => '@cache_qibla_${lat}_$lng';
/// v2: sadece en az 1 review'u olan camiler cache'lenir; eski cache devre dışı kalır.
String cacheKeyMosques(String lat, String lng, int radius) => '@cache_mosques_v2_${lat}_${lng}_$radius';
String cacheKeyRoute(String fromLat, Object fromLng, Object toLat, Object toLng, String mode) =>
    '@cache_route_${fromLat}_${fromLng}_${toLat}_${toLng}_$mode';

const String cacheKeyLocation = '@cache_location';
const String cacheKeyLastKnownLocation = '@cache_last_known_location';

Future<SharedPreferences> _prefs() async => SharedPreferences.getInstance();

Future<void> setCache(String key, dynamic data, [int expiryMs = expiryLocation]) async {
  try {
    final prefs = await _prefs();
    final cacheData = {'data': data, 'timestamp': DateTime.now().millisecondsSinceEpoch, 'expiry': expiryMs};
    await prefs.setString(key, jsonEncode(cacheData));
  } catch (_) {}
}

Future<Map<String, dynamic>> getCache(String key) async {
  try {
    final prefs = await _prefs();
    final raw = prefs.getString(key);
    if (raw == null) return {'success': false, 'cached': false};
    final decoded = jsonDecode(raw) as Map<String, dynamic>;
    final data = decoded['data'];
    final timestamp = decoded['timestamp'] as int? ?? 0;
    final expiry = decoded['expiry'] as int? ?? expiryLocation;
    final age = DateTime.now().millisecondsSinceEpoch - timestamp;
    if (age > expiry) {
      await prefs.remove(key);
      return {'success': false, 'cached': false, 'expired': true};
    }
    return {'success': true, 'data': data, 'cached': true, 'age': age};
  } catch (_) {
    return {'success': false, 'cached': false};
  }
}

Future<void> clearCache(String key) async {
  try {
    final prefs = await _prefs();
    await prefs.remove(key);
  } catch (_) {}
}
