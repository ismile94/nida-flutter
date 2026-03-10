import 'dart:convert';
import 'package:http/http.dart' as http;
import 'turkey_prayer_times_service.dart';

class HijriDay {
  final int day;
  final int month;
  final int year;
  final String monthName;

  const HijriDay({
    required this.day,
    required this.month,
    required this.year,
    required this.monthName,
  });
}

class CalendarDayData {
  final int day;
  final String fajr;
  final String sunrise;
  final String dhuhr;
  final String asr;
  final String maghrib;
  final String isha;
  final HijriDay? hijri;

  const CalendarDayData({
    required this.day,
    required this.fajr,
    required this.sunrise,
    required this.dhuhr,
    required this.asr,
    required this.maghrib,
    required this.isha,
    this.hijri,
  });
}

/// In-memory cache: key = "lat-lng-year-month-method"
final Map<String, List<CalendarDayData>> _cache = {};

String _fmt(String? t) {
  if (t == null || t.isEmpty) return '00:00';
  final p = t.split(' ').first;
  return p.length >= 5 ? p : '00:00';
}

Future<List<CalendarDayData>> getCalendarMonthData({
  required double latitude,
  required double longitude,
  required int method,
  required int year,
  required int month,
  String madhab = 'standard',
  Map<String, dynamic>? admin,
}) async {
  final cacheKey = '$latitude-$longitude-$year-$month-$method';
  if (_cache.containsKey(cacheKey)) return _cache[cacheKey]!;

  List<CalendarDayData> days;
  if (method == 13) {
    days = await _getTurkeyCalendarMonth(
      latitude: latitude,
      longitude: longitude,
      year: year,
      month: month,
      admin: admin,
    );
  } else {
    days = await _getAladhanCalendarMonth(
      latitude: latitude,
      longitude: longitude,
      method: method,
      madhab: madhab,
      year: year,
      month: month,
    );
  }

  if (days.isNotEmpty) _cache[cacheKey] = days;
  return days;
}

Future<List<CalendarDayData>> _getAladhanCalendarMonth({
  required double latitude,
  required double longitude,
  required int method,
  required String madhab,
  required int year,
  required int month,
}) async {
  final school = madhab.toLowerCase() == 'hanafi' ? 1 : 0;
  final url = Uri.parse(
    'https://api.aladhan.com/v1/calendar/$year/$month'
    '?latitude=$latitude&longitude=$longitude&method=$method&school=$school',
  );
  try {
    final res = await http.get(url);
    if (res.statusCode != 200) return [];
    final data = jsonDecode(res.body) as Map<String, dynamic>?;
    final list = data?['data'] as List<dynamic>?;
    if (list == null) return [];

    final result = <CalendarDayData>[];
    for (final e in list) {
      final dayData = e as Map<String, dynamic>;
      final gregorian = dayData['date']?['gregorian'] as Map<String, dynamic>?;
      final dayNum = int.tryParse(gregorian?['day']?.toString() ?? '');
      if (dayNum == null) continue;

      final timings = dayData['timings'] as Map<String, dynamic>?;
      if (timings == null) continue;

      final hijriRaw = dayData['date']?['hijri'] as Map<String, dynamic>?;
      HijriDay? hijri;
      if (hijriRaw != null) {
        final hDay = int.tryParse(hijriRaw['day']?.toString() ?? '') ?? 0;
        final hMonth = hijriRaw['month'] as Map<String, dynamic>?;
        final hYear = int.tryParse(hijriRaw['year']?.toString() ?? '') ?? 0;
        hijri = HijriDay(
          day: hDay,
          month: int.tryParse(hMonth?['number']?.toString() ?? '') ?? 0,
          year: hYear,
          monthName: (hMonth?['en'] as String?) ?? '',
        );
      }

      result.add(CalendarDayData(
        day: dayNum,
        fajr: _fmt(timings['Fajr'] as String?),
        sunrise: _fmt(timings['Sunrise'] as String?),
        dhuhr: _fmt(timings['Dhuhr'] as String?),
        asr: _fmt(timings['Asr'] as String?),
        maghrib: _fmt(timings['Maghrib'] as String?),
        isha: _fmt(timings['Isha'] as String?),
        hijri: hijri,
      ));
    }
    return result;
  } catch (_) {
    return [];
  }
}

Future<List<CalendarDayData>> _getTurkeyCalendarMonth({
  required double latitude,
  required double longitude,
  required int year,
  required int month,
  Map<String, dynamic>? admin,
}) async {
  final province = admin?['state'] ?? admin?['province'] ?? admin?['city'];
  final district = admin?['district'] ?? admin?['county'];

  final trRecords = await getTurkeyPrayerTimesForMonth(
    province: province?.toString(),
    district: district?.toString(),
    year: year,
    month: month,
  );

  // Fetch hijri data from Aladhan in parallel
  Map<int, HijriDay> hijriMap = {};
  try {
    final hijriUrl = Uri.parse(
      'https://api.aladhan.com/v1/calendar/$year/$month'
      '?latitude=$latitude&longitude=$longitude&method=2',
    );
    final hijriRes = await http.get(hijriUrl);
    if (hijriRes.statusCode == 200) {
      final hijriData = jsonDecode(hijriRes.body) as Map<String, dynamic>?;
      final hijriList = hijriData?['data'] as List<dynamic>?;
      if (hijriList != null) {
        for (final e in hijriList) {
          final dayData = e as Map<String, dynamic>;
          final gregDay = int.tryParse(
              dayData['date']?['gregorian']?['day']?.toString() ?? '');
          final hijriRaw = dayData['date']?['hijri'] as Map<String, dynamic>?;
          if (gregDay != null && hijriRaw != null) {
            final hMonth = hijriRaw['month'] as Map<String, dynamic>?;
            hijriMap[gregDay] = HijriDay(
              day: int.tryParse(hijriRaw['day']?.toString() ?? '') ?? 0,
              month: int.tryParse(hMonth?['number']?.toString() ?? '') ?? 0,
              year: int.tryParse(hijriRaw['year']?.toString() ?? '') ?? 0,
              monthName: (hMonth?['en'] as String?) ?? '',
            );
          }
        }
      }
    }
  } catch (_) {}

  final result = <CalendarDayData>[];
  for (final rec in trRecords) {
    final date = rec['date'] as String?;
    if (date == null) continue;
    final parts = date.split('.');
    if (parts.length != 3) continue;
    final dayNum = int.tryParse(parts[0]);
    if (dayNum == null) continue;

    result.add(CalendarDayData(
      day: dayNum,
      fajr: _fmt(rec['fajr'] as String?),
      sunrise: _fmt(rec['sunrise'] as String?),
      dhuhr: _fmt(rec['dhuhr'] as String?),
      asr: _fmt(rec['asr'] as String?),
      maghrib: _fmt(rec['maghrib'] as String?),
      isha: _fmt(rec['isha'] as String?),
      hijri: hijriMap[dayNum],
    ));
  }
  result.sort((a, b) => a.day.compareTo(b.day));
  return result;
}
