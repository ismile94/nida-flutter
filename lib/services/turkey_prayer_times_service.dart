import 'dart:convert';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;

/// Same as RN services/turkeyPrayerTimes.js: Diyanet vakitleri Cloudflare R2'den.
/// R2_BASE_URL, il_ilceler, buyuksehirler, province/district çözümleme ve tarih formatı birebir aynı.
const String _r2BaseUrl = 'https://pub-9b85b1c9d83c4a44b68f307efc846066.r2.dev';

Map<String, dynamic>? _ilIlceler;
List<dynamic>? _buyuksehirlerList;

Future<Map<String, dynamic>> _loadIlIlceler() async {
  if (_ilIlceler != null) return _ilIlceler!;
  final str = await rootBundle.loadString('assets/data/il_ilceler.json');
  _ilIlceler = jsonDecode(str) as Map<String, dynamic>? ?? {};
  return _ilIlceler!;
}

Future<List<dynamic>> _loadBuyuksehirler() async {
  if (_buyuksehirlerList != null) return _buyuksehirlerList!;
  final str = await rootBundle.loadString('assets/data/buyuksehirler.json');
  final map = jsonDecode(str) as Map<String, dynamic>?;
  _buyuksehirlerList = (map?['buyuksehirler'] as List<dynamic>?) ?? [];
  return _buyuksehirlerList!;
}

/// RN: toLocaleLowerCase('tr-TR') — İ→i, I→ı
String _normalizeTr(String? value) {
  if (value == null || value.isEmpty) return '';
  final s = value.trim();
  final buffer = StringBuffer();
  for (var i = 0; i < s.length; i++) {
    final c = s[i];
    if (c == 'İ') buffer.write('i');
    else if (c == 'I') buffer.write('ı');
    else buffer.write(c.toLowerCase());
  }
  return buffer.toString();
}

/// Nominatim bazen ASCII döner (Sirnak, Istanbul). R2 ve il_ilceler Türkçe karakterle (Şırnak, İstanbul).
/// Karşılaştırma için: ş↔s, ı↔i, ğ↔g, ü↔u, ö↔o, ç↔c — böylece "Sirnak" ile "Şırnak" eşleşir.
String _normalizeTrLoose(String? value) {
  if (value == null || value.isEmpty) return '';
  final s = _normalizeTr(value);
  return s
      .replaceAll('ş', 's')
      .replaceAll('ğ', 'g')
      .replaceAll('ü', 'u')
      .replaceAll('ö', 'o')
      .replaceAll('ç', 'c')
      .replaceAll('ı', 'i');
}

/// data içinde province ile eşleşen anahtarı döndürür (loose norm). Dönen değer R2'deki gerçek anahtar (dosya adı için).
String? _resolveProvinceKey(Map<String, dynamic>? data, String? province) {
  if (data == null || province == null || province.isEmpty) return null;
  final normalized = _normalizeTrLoose(province);
  for (final key in data.keys) {
    if (_normalizeTrLoose(key) == normalized) return key;
  }
  return null;
}

/// districts içinde district ile eşleşen anahtarı döndürür (loose norm).
String? _resolveDistrictKey(Map<String, dynamic>? districts, String? district) {
  if (districts == null || district == null || district.isEmpty) return null;
  final normalized = _normalizeTrLoose(district);
  for (final key in districts.keys) {
    if (_normalizeTrLoose(key) == normalized) return key;
  }
  return null;
}

/// İl adını il_ilceler anahtarlarıyla eşleştirip R2 dosya adında kullanılacak kanonik adı döndürür (Nominatim "Sirnak" → "Şırnak").
Future<String?> _canonicalProvinceForFileName(String? province) async {
  if (province == null || province.isEmpty) return null;
  final ilIlceler = await _loadIlIlceler();
  return _resolveProvinceKey(ilIlceler, province);
}

/// RN: resolveMetropolitanCenterDistrict(province, district)
Future<String?> _resolveMetropolitanCenterDistrict(String? province, String? district) async {
  if (province == null || district == null) return null;
  final list = await _loadBuyuksehirler();
  final normProvince = _normalizeTr(province);
  final normDistrict = _normalizeTr(district);
  for (final e in list) {
    final item = e as Map<String, dynamic>?;
    if (item == null) continue;
    if (_normalizeTr(item['il'] as String?) != normProvince) continue;
    final merkez = item['merkez_ilce'] as String?;
    if (merkez == null) return null;
    if (normDistrict != normProvince) return null;
    return merkez;
  }
  return null;
}

/// RN: findProvinceByDistrict(district)
Future<String?> _findProvinceByDistrict(String? district) async {
  if (district == null || district.isEmpty) return null;
  final ilIlceler = await _loadIlIlceler();
  final normalizedDistrict = _normalizeTr(district);
  for (final entry in ilIlceler.entries) {
    final districts = entry.value;
    if (districts is! List) continue;
    for (final d in districts) {
      if (d is Map && _normalizeTr(d['ilce'] as String?) == normalizedDistrict) {
        return entry.key;
      }
    }
  }
  return null;
}

/// RN: getIstanbulDateKey() — Europe/Istanbul DD.MM.YYYY (Turkey UTC+3).
/// Pass [date] to get key for that day (e.g. tomorrow).
String getIstanbulDateKey([DateTime? date]) {
  final utc = (date ?? DateTime.now()).toUtc();
  final istanbul = utc.add(const Duration(hours: 3));
  final d = istanbul.day.toString().padLeft(2, '0');
  final m = istanbul.month.toString().padLeft(2, '0');
  final y = istanbul.year.toString();
  return '$d.$m.$y';
}

String _getIstanbulDateKey() => getIstanbulDateKey();

/// RN: getTurkeyPrayerTimesForToday({ province, district })
/// Returns today's record map { date, fajr, sunrise, dhuhr, asr, maghrib, isha } or null.
Future<Map<String, dynamic>?> getTurkeyPrayerTimesForToday({
  String? province,
  String? district,
}) async {
  // ignore: avoid_print
  print('[TR-PRAYER] start province=$province district=$district');

  String? resolvedProvince = province;
  if ((resolvedProvince == null || resolvedProvince.isEmpty) && district != null && district.isNotEmpty) {
    resolvedProvince = await _findProvinceByDistrict(district);
    // ignore: avoid_print
    print('[TR-PRAYER] province resolved from district: $resolvedProvince');
  }

  String? resolvedDistrict = district;
  if (resolvedProvince != null && resolvedDistrict != null && resolvedDistrict.isNotEmpty) {
    final metro = await _resolveMetropolitanCenterDistrict(resolvedProvince, resolvedDistrict);
    if (metro != null) {
      resolvedDistrict = metro;
      // ignore: avoid_print
      print('[TR-PRAYER] metropolitan override: $resolvedDistrict');
    }
  }

  // If district is still empty, try the buyuksehirler merkez_ilce for the province (e.g. İstanbul → Fatih).
  if (resolvedProvince != null && resolvedProvince.isNotEmpty && (resolvedDistrict == null || resolvedDistrict.isEmpty)) {
    final list = await _loadBuyuksehirler();
    final normP = _normalizeTrLoose(resolvedProvince);
    for (final e in list) {
      final item = e as Map<String, dynamic>?;
      if (item == null) continue;
      if (_normalizeTrLoose(item['il'] as String?) == normP) {
        resolvedDistrict = item['merkez_ilce'] as String?;
        // ignore: avoid_print
        print('[TR-PRAYER] district resolved from buyuksehirler merkez_ilce: $resolvedDistrict');
        break;
      }
    }
  }

  // Last resort: if district is still empty, use province name as district (many R2 files have province-named district).
  if (resolvedProvince != null && resolvedProvince.isNotEmpty && (resolvedDistrict == null || resolvedDistrict.isEmpty)) {
    resolvedDistrict = resolvedProvince;
    // ignore: avoid_print
    print('[TR-PRAYER] district fallback to province name: $resolvedDistrict');
  }

  if (resolvedProvince == null || resolvedProvince.isEmpty || resolvedDistrict == null || resolvedDistrict.isEmpty) {
    // ignore: avoid_print
    print('[TR-PRAYER] FAIL: missing province or district after resolve. province=$resolvedProvince district=$resolvedDistrict');
    return null;
  }

  final provinceForFile = await _canonicalProvinceForFileName(resolvedProvince) ?? resolvedProvince;
  final fileName = '$provinceForFile.json';
  final url = Uri.parse('$_r2BaseUrl/${Uri.encodeComponent(fileName)}');
  // ignore: avoid_print
  print('[TR-PRAYER] fetching $url');
  try {
    final res = await http.get(url);
    // ignore: avoid_print
    print('[TR-PRAYER] HTTP ${res.statusCode} for $fileName');
    if (res.statusCode != 200) return null;
    final data = jsonDecode(res.body) as Map<String, dynamic>?;
    if (data == null) return null;

    final provinceKey = _resolveProvinceKey(data, resolvedProvince);
    // ignore: avoid_print
    print('[TR-PRAYER] provinceKey=$provinceKey (searched: $resolvedProvince, dataKeys: ${data.keys.take(3).toList()})');
    if (provinceKey == null) return null;

    final districts = data[provinceKey];
    if (districts is! Map<String, dynamic>) {
      // ignore: avoid_print
      print('[TR-PRAYER] FAIL: districts not a Map, type=${districts.runtimeType}');
      return null;
    }

    final districtKey = _resolveDistrictKey(districts, resolvedDistrict);
    // ignore: avoid_print
    print('[TR-PRAYER] districtKey=$districtKey (searched: $resolvedDistrict, districtKeys: ${districts.keys.take(5).toList()})');
    if (districtKey == null) return null;

    final records = districts[districtKey];
    if (records is! List) {
      // ignore: avoid_print
      print('[TR-PRAYER] FAIL: records not a List, type=${records.runtimeType}');
      return null;
    }

    final todayKey = _getIstanbulDateKey();
    // ignore: avoid_print
    print('[TR-PRAYER] todayKey=$todayKey recordCount=${records.length}');
    for (final item in records) {
      if (item is Map<String, dynamic> && item['date'] == todayKey) {
        // ignore: avoid_print
        print('[TR-PRAYER] SUCCESS: found record for $todayKey');
        return item;
      }
    }
    // ignore: avoid_print
    print('[TR-PRAYER] FAIL: no record for date $todayKey');
    return null;
  } catch (e) {
    // ignore: avoid_print
    print('[TR-PRAYER] EXCEPTION: $e');
    return null;
  }
}

/// Returns all records for a given [year] and [month] for a province/district.
/// Each record is a map like { date: "DD.MM.YYYY", fajr, sunrise, dhuhr, asr, maghrib, isha }.
Future<List<Map<String, dynamic>>> getTurkeyPrayerTimesForMonth({
  String? province,
  String? district,
  required int year,
  required int month,
}) async {
  String? resolvedProvince = province;
  if ((resolvedProvince == null || resolvedProvince.isEmpty) && district != null && district.isNotEmpty) {
    resolvedProvince = await _findProvinceByDistrict(district);
  }

  String? resolvedDistrict = district;
  if (resolvedProvince != null && resolvedDistrict != null && resolvedDistrict.isNotEmpty) {
    final metro = await _resolveMetropolitanCenterDistrict(resolvedProvince, resolvedDistrict);
    if (metro != null) resolvedDistrict = metro;
  }

  if (resolvedProvince != null && resolvedProvince.isNotEmpty && (resolvedDistrict == null || resolvedDistrict.isEmpty)) {
    final list = await _loadBuyuksehirler();
    final normP = _normalizeTrLoose(resolvedProvince);
    for (final e in list) {
      final item = e as Map<String, dynamic>?;
      if (item == null) continue;
      if (_normalizeTrLoose(item['il'] as String?) == normP) {
        resolvedDistrict = item['merkez_ilce'] as String?;
        break;
      }
    }
  }

  if (resolvedProvince != null && resolvedProvince.isNotEmpty && (resolvedDistrict == null || resolvedDistrict.isEmpty)) {
    resolvedDistrict = resolvedProvince;
  }

  if (resolvedProvince == null || resolvedProvince.isEmpty || resolvedDistrict == null || resolvedDistrict.isEmpty) {
    return [];
  }

  final provinceForFile = await _canonicalProvinceForFileName(resolvedProvince) ?? resolvedProvince;
  final fileName = '$provinceForFile.json';
  final url = Uri.parse('$_r2BaseUrl/${Uri.encodeComponent(fileName)}');
  try {
    final res = await http.get(url);
    if (res.statusCode != 200) return [];
    final data = jsonDecode(res.body) as Map<String, dynamic>?;
    if (data == null) return [];

    final provinceKey = _resolveProvinceKey(data, resolvedProvince);
    if (provinceKey == null) return [];

    final districts = data[provinceKey];
    if (districts is! Map<String, dynamic>) return [];

    final districtKey = _resolveDistrictKey(districts, resolvedDistrict);
    if (districtKey == null) return [];

    final records = districts[districtKey];
    if (records is! List) return [];

    final monthStr = month.toString().padLeft(2, '0');
    final yearStr = year.toString();
    final result = <Map<String, dynamic>>[];
    for (final item in records) {
      if (item is! Map<String, dynamic>) continue;
      final date = item['date'] as String?;
      if (date == null) continue;
      // date format: DD.MM.YYYY
      final parts = date.split('.');
      if (parts.length != 3) continue;
      if (parts[1] == monthStr && parts[2] == yearStr) {
        result.add(item);
      }
    }
    return result;
  } catch (e) {
    return [];
  }
}
