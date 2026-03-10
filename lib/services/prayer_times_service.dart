import 'dart:convert';
import 'package:http/http.dart' as http;
import 'turkey_prayer_times_service.dart';

/// Prayer times from Aladhan API. Same logic as RN services/prayerTimes.js:
/// method = calculation method ID, school: 0 = Shafi/Maliki/Hanbali, 1 = Hanafi.
/// Turkey (method 13) is not supported by Aladhan; returns fallback times.
class PrayerTimesResult {
  final String fajr;
  final String sunrise;
  final String dhuhr;
  final String asr;
  final String maghrib;
  final String isha;
  const PrayerTimesResult({
    required this.fajr,
    required this.sunrise,
    required this.dhuhr,
    required this.asr,
    required this.maghrib,
    required this.isha,
  });

  static const PrayerTimesResult fallback = PrayerTimesResult(
    fajr: '05:12',
    sunrise: '06:45',
    dhuhr: '12:30',
    asr: '16:15',
    maghrib: '19:02',
    isha: '20:15',
  );
}

/// Format "05:12 (GMT+3)" -> "05:12"
String _formatTime(String? timeString) {
  if (timeString == null || timeString.isEmpty) return '00:00';
  final part = timeString.split(' ').first;
  return part.length >= 5 ? part : '00:00';
}

/// Fetch today's prayer times for a location with given method and madhab.
/// method: Aladhan method ID (2 = ISNA, 3 = MWL, etc.). 13 = Turkey (Diyanet) → R2 (same as RN).
/// madhab: 'hanafi' -> school=1, else school=0.
/// admin: for method 13, province (state) and district from admin for R2 il/ilçe lookup.
Future<PrayerTimesResult> getPrayerTimes({
  required double latitude,
  required double longitude,
  required int method,
  String madhab = 'standard',
  DateTime? date,
  Map<String, dynamic>? admin,
}) async {
  final now = date ?? DateTime.now();
  final year = now.year;
  final month = now.month;
  final day = now.day;

  if (method == 13) {
    final province = admin?['state'] ?? admin?['province'] ?? admin?['city'];
    final district = admin?['district'] ?? admin?['county'];
    // ignore: avoid_print
    print('[PRAYER] method=13 admin=$admin → province=$province district=$district');
    final trToday = await getTurkeyPrayerTimesForToday(
      province: province?.toString(),
      district: district?.toString(),
    );
    if (trToday != null) {
      String s(String key) => (trToday[key] is String) ? (trToday[key] as String) : '00:00';
      return PrayerTimesResult(
        fajr: s('fajr'),
        sunrise: s('sunrise'),
        dhuhr: s('dhuhr'),
        asr: s('asr'),
        maghrib: s('maghrib'),
        isha: s('isha'),
      );
    }
    return PrayerTimesResult.fallback;
  }

  final school = madhab.toLowerCase() == 'hanafi' ? 1 : 0;
  final url = Uri.parse(
    'https://api.aladhan.com/v1/calendar/$year/$month'
    '?latitude=$latitude&longitude=$longitude&method=$method&school=$school',
  );
  try {
    final res = await http.get(url);
    if (res.statusCode != 200) return PrayerTimesResult.fallback;
    final data = jsonDecode(res.body) as Map<String, dynamic>?;
    final list = data?['data'] as List<dynamic>?;
    if (list == null) return PrayerTimesResult.fallback;
    for (final e in list) {
      final dayData = e as Map<String, dynamic>;
      final gregorian = dayData['date']?['gregorian'] as Map<String, dynamic>?;
      final dayStr = gregorian?['day']?.toString();
      if (dayStr != null && int.tryParse(dayStr) == day) {
        final timings = dayData['timings'] as Map<String, dynamic>?;
        if (timings == null) return PrayerTimesResult.fallback;
        return PrayerTimesResult(
          fajr: _formatTime(timings['Fajr'] as String?),
          sunrise: _formatTime(timings['Sunrise'] as String?),
          dhuhr: _formatTime(timings['Dhuhr'] as String?),
          asr: _formatTime(timings['Asr'] as String?),
          maghrib: _formatTime(timings['Maghrib'] as String?),
          isha: _formatTime(timings['Isha'] as String?),
        );
      }
    }
  } catch (_) {}
  return PrayerTimesResult.fallback;
}

/// Fetches today's and tomorrow's prayer times so alarms can be scheduled for the next day without opening the app after midnight.
/// Returns (today, tomorrow). Tomorrow may be null if fetch fails for that day.
Future<(PrayerTimesResult, PrayerTimesResult?)> getPrayerTimesTodayAndTomorrow({
  required double latitude,
  required double longitude,
  required int method,
  String madhab = 'standard',
  Map<String, dynamic>? admin,
}) async {
  final now = DateTime.now();
  final today = await getPrayerTimes(
    latitude: latitude,
    longitude: longitude,
    method: method,
    madhab: madhab,
    date: now,
    admin: admin,
  );

  final tomorrowDate = now.add(const Duration(days: 1));
  PrayerTimesResult? tomorrow;

  if (method == 13) {
    final province = admin?['state'] ?? admin?['province'] ?? admin?['city'];
    final district = admin?['district'] ?? admin?['county'];
    final monthRecords = await getTurkeyPrayerTimesForMonth(
      province: province?.toString(),
      district: district?.toString(),
      year: tomorrowDate.year,
      month: tomorrowDate.month,
    );
    final tomorrowKey = getIstanbulDateKey(tomorrowDate);
    for (final item in monthRecords) {
      if (item['date'] == tomorrowKey) {
        String s(String key) => (item[key] is String) ? (item[key] as String) : '00:00';
        tomorrow = PrayerTimesResult(
          fajr: s('fajr'),
          sunrise: s('sunrise'),
          dhuhr: s('dhuhr'),
          asr: s('asr'),
          maghrib: s('maghrib'),
          isha: s('isha'),
        );
        break;
      }
    }
  } else {
    final school = madhab.toLowerCase() == 'hanafi' ? 1 : 0;
    final year = tomorrowDate.year;
    final month = tomorrowDate.month;
    final url = Uri.parse(
      'https://api.aladhan.com/v1/calendar/$year/$month'
      '?latitude=$latitude&longitude=$longitude&method=$method&school=$school',
    );
    try {
      final res = await http.get(url);
      if (res.statusCode == 200) {
        final data = jsonDecode(res.body) as Map<String, dynamic>?;
        final list = data?['data'] as List<dynamic>?;
        final day = tomorrowDate.day;
        if (list != null) {
          for (final e in list) {
            final dayData = e as Map<String, dynamic>;
            final gregorian = dayData['date']?['gregorian'] as Map<String, dynamic>?;
            final dayStr = gregorian?['day']?.toString();
            if (dayStr != null && int.tryParse(dayStr) == day) {
              final timings = dayData['timings'] as Map<String, dynamic>?;
              if (timings != null) {
                tomorrow = PrayerTimesResult(
                  fajr: _formatTime(timings['Fajr'] as String?),
                  sunrise: _formatTime(timings['Sunrise'] as String?),
                  dhuhr: _formatTime(timings['Dhuhr'] as String?),
                  asr: _formatTime(timings['Asr'] as String?),
                  maghrib: _formatTime(timings['Maghrib'] as String?),
                  isha: _formatTime(timings['Isha'] as String?),
                );
              }
              break;
            }
          }
        }
      }
    } catch (_) {}
  }

  return (today, tomorrow ?? today);
}

/// Next prayer key: fajr, dhuhr, asr, maghrib, isha.
class NextPrayer {
  final String key;
  final String time;
  final String remaining;
  const NextPrayer({required this.key, required this.time, required this.remaining});
}

/// Same as RN getNextPrayerTime: which prayer is next and remaining time.
NextPrayer getNextPrayer(PrayerTimesResult times, DateTime currentTime) {
  final hours = currentTime.hour;
  final minutes = currentTime.minute;
  final seconds = currentTime.second;
  int currentTotalSeconds = hours * 3600 + minutes * 60 + seconds;

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
    final prayerHours = int.tryParse(parts[0]) ?? 0;
    final prayerMinutes = int.tryParse(parts[1]) ?? 0;
    final prayerTotalSeconds = prayerHours * 3600 + prayerMinutes * 60;
    if (prayerTotalSeconds > currentTotalSeconds) {
      int remainingSeconds = prayerTotalSeconds - currentTotalSeconds;
      final remainingHours = remainingSeconds ~/ 3600;
      final remainingMins = (remainingSeconds % 3600) ~/ 60;
      final remainingSecs = remainingSeconds % 60;
      final formatted = remainingHours > 0
          ? '$remainingHours:${remainingMins.toString().padLeft(2, '0')}:${remainingSecs.toString().padLeft(2, '0')}'
          : '${remainingMins}:${remainingSecs.toString().padLeft(2, '0')}';
      return NextPrayer(key: p.$1, time: p.$2, remaining: formatted);
    }
  }
  final parts = times.fajr.split(':');
  final fajrH = int.tryParse(parts.isNotEmpty ? parts[0] : '0') ?? 0;
  final fajrM = int.tryParse(parts.length > 1 ? parts[1] : '0') ?? 0;
  final tomorrowFajrSeconds = (fajrH + 24) * 3600 + fajrM * 60;
  int remainingSeconds = tomorrowFajrSeconds - currentTotalSeconds;
  final remainingHours = remainingSeconds ~/ 3600;
  final remainingMins = (remainingSeconds % 3600) ~/ 60;
  final remainingSecs = remainingSeconds % 60;
  final formatted = remainingHours > 0
      ? '$remainingHours:${remainingMins.toString().padLeft(2, '0')}:${remainingSecs.toString().padLeft(2, '0')}'
      : '${remainingMins}:${remainingSecs.toString().padLeft(2, '0')}';
  return NextPrayer(key: 'fajr', time: times.fajr, remaining: formatted);
}
