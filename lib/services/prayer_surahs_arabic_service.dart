import 'dart:convert';
import 'package:flutter/services.dart';

/// Loads prayer surahs Arabic (Fatiha, zammi surahs 97–114) from assets/data/prayerSurahsArabic.json.
class PrayerSurahsArabicService {
  static const _assetPath = 'assets/data/prayerSurahsArabic.json';
  static Map<String, dynamic>? _cache;

  static Future<Map<String, dynamic>> load() async {
    if (_cache != null) return _cache!;
    final str = await rootBundle.loadString(_assetPath);
    _cache = jsonDecode(str) as Map<String, dynamic>;
    return _cache!;
  }

  /// Returns full Arabic text (verses joined by space) for surah number.
  /// surahNumber: 1 = Fatiha, 97–114 = zammi surahs. Returns null if not in JSON.
  static String? getArabic(Map<String, dynamic> data, int surahNumber) {
    final list = getVerses(data, surahNumber);
    if (list == null || list.isEmpty) return null;
    return list.join(' ');
  }

  /// Returns list of Arabic verse texts for surah number (1-based verse index in list).
  static List<String>? getVerses(Map<String, dynamic> data, int surahNumber) {
    final key = surahNumber.toString();
    final surah = data[key] as Map<String, dynamic>?;
    if (surah == null) return null;
    final verses = surah['verses'] as List<dynamic>?;
    if (verses == null || verses.isEmpty) return null;
    return verses.map((e) => e as String).toList();
  }
}
