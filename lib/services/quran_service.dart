// Port of RN services/quran.js – api.alquran.cloud API + cache.
// Arabic verse text is taken from assets/data/quran.json (avoids API typos).

import 'dart:convert';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

const String _apiBase = 'https://api.alquran.cloud/v1';

const String _basmalaEnd = 'رَّحِيمِ';

/// Local Arabic text: chapter -> verse number in surah -> text. Loaded from assets/data/quran.json.
Map<int, Map<int, String>>? _localArabicCache;

Future<void> _ensureLocalArabicLoaded() async {
  if (_localArabicCache != null) return;
  try {
    final raw = await rootBundle.loadString('assets/data/quran.json');
    final map = jsonDecode(raw) as Map<String, dynamic>;
    _localArabicCache = {};
    for (final entry in map.entries) {
      final chapter = int.tryParse(entry.key);
      if (chapter == null) continue;
      final list = entry.value as List<dynamic>?;
      if (list == null) continue;
      _localArabicCache![chapter] = {};
      for (final item in list) {
        final m = item as Map<String, dynamic>?;
        if (m == null) continue;
        final verse = (m['verse'] as num?)?.toInt();
        final text = m['text'] as String?;
        if (verse != null && text != null)
          _localArabicCache![chapter]![verse] = text;
      }
    }
  } catch (_) {
    _localArabicCache = {};
  }
}

/// Returns local Arabic text for (surahNumber, verseNumberInSurah), or null if not in assets.
Future<String?> getLocalArabicVerseText(
    int surahNumber, int verseNumberInSurah) async {
  await _ensureLocalArabicLoaded();
  return _localArabicCache?[surahNumber]?[verseNumberInSurah];
}

/// Replaces verse texts in [data] with local Arabic from assets/data/quran.json where available.
SurahData _applyLocalArabicToSurahData(SurahData data) {
  final local = _localArabicCache?[data.number];
  if (local == null) return data;
  final newVerses = <VerseItem>[];
  for (final v in data.verses) {
    final text = local[v.numberInSurah];
    newVerses.add(text != null
        ? VerseItem(
            number: v.number,
            numberInSurah: v.numberInSurah,
            text: text,
            translation: v.translation,
            transliteration: v.transliteration,
            juz: v.juz,
            page: v.page,
          )
        : v);
  }
  return SurahData(
    number: data.number,
    name: data.name,
    nameArabic: data.nameArabic,
    nameTransliterated: data.nameTransliterated,
    numberOfAyahs: data.numberOfAyahs,
    revelationType: data.revelationType,
    verses: newVerses,
    showBasmalaAtTop: data.showBasmalaAtTop,
    basmalaText: data.basmalaText,
  );
}

/// Single surah list item (from getAllSurahs).
class SurahListItem {
  final int number;
  final String name;
  final String? nameArabic;
  final String? nameTransliterated;
  final int numberOfAyahs;
  final String? revelationType;

  SurahListItem({
    required this.number,
    required this.name,
    this.nameArabic,
    this.nameTransliterated,
    required this.numberOfAyahs,
    this.revelationType,
  });

  factory SurahListItem.fromJson(Map<String, dynamic> j) {
    return SurahListItem(
      number: (j['number'] as num?)?.toInt() ?? 0,
      name: j['name'] as String? ?? '',
      nameArabic: j['nameArabic'] as String?,
      nameTransliterated: j['nameTransliterated'] as String?,
      numberOfAyahs: (j['numberOfAyahs'] as num?)?.toInt() ?? 0,
      revelationType: j['revelationType'] as String?,
    );
  }

  Map<String, dynamic> toJson() => {
        'number': number,
        'name': name,
        'nameArabic': nameArabic,
        'nameTransliterated': nameTransliterated,
        'numberOfAyahs': numberOfAyahs,
        'revelationType': revelationType,
      };
}

/// Single verse in a surah.
class VerseItem {
  final int number;
  final int numberInSurah;
  final String text;
  final String? translation;
  final String? transliteration;
  final int? juz;
  final int? page;

  VerseItem({
    required this.number,
    required this.numberInSurah,
    required this.text,
    this.translation,
    this.transliteration,
    this.juz,
    this.page,
  });

  Map<String, dynamic> toJson() => {
        'number': number,
        'numberInSurah': numberInSurah,
        'text': text,
        'translation': translation,
        'transliteration': transliteration,
        'juz': juz,
        'page': page,
      };
}

/// Full surah with verses (from getSurah).
class SurahData {
  final int number;
  final String name;
  final String? nameArabic;
  final String? nameTransliterated;
  final int numberOfAyahs;
  final String? revelationType;
  final List<VerseItem> verses;
  final bool showBasmalaAtTop;
  final String? basmalaText;

  SurahData({
    required this.number,
    required this.name,
    this.nameArabic,
    this.nameTransliterated,
    required this.numberOfAyahs,
    this.revelationType,
    required this.verses,
    this.showBasmalaAtTop = false,
    this.basmalaText,
  });

  Map<String, dynamic> toJson() => {
        'number': number,
        'name': name,
        'nameArabic': nameArabic,
        'nameTransliterated': nameTransliterated,
        'numberOfAyahs': numberOfAyahs,
        'revelationType': revelationType,
        'verses': verses.map((v) => v.toJson()).toList(),
        'showBasmalaAtTop': showBasmalaAtTop,
        'basmalaText': basmalaText,
      };

  static SurahData fromJson(Map<String, dynamic> j) {
    final versesList = j['verses'] as List<dynamic>? ?? [];
    return SurahData(
      number: (j['number'] as num?)?.toInt() ?? 0,
      name: j['name'] as String? ?? '',
      nameArabic: j['nameArabic'] as String?,
      nameTransliterated: j['nameTransliterated'] as String?,
      numberOfAyahs: (j['numberOfAyahs'] as num?)?.toInt() ?? 0,
      revelationType: j['revelationType'] as String?,
      verses: versesList
          .map((v) => VerseItem(
                number: (v['number'] as num?)?.toInt() ?? 0,
                numberInSurah: (v['numberInSurah'] as num?)?.toInt() ?? 0,
                text: v['text'] as String? ?? '',
                translation: v['translation'] as String?,
                transliteration: v['transliteration'] as String?,
                juz: (v['juz'] as num?)?.toInt(),
                page: (v['page'] as num?)?.toInt(),
              ))
          .toList(),
      showBasmalaAtTop: j['showBasmalaAtTop'] as bool? ?? false,
      basmalaText: j['basmalaText'] as String?,
    );
  }
}

/// Translation edition by locale (same as RN).
String _translationEdition(String locale) {
  switch (locale) {
    case 'tr':
      return 'tr.yazir';
    case 'ar':
      return 'ar.jalalayn';
    case 'pt':
      return 'pt.elhayek';
    case 'es':
      return 'es.asad';
    case 'de':
      return 'de.aburida';
    case 'nl':
      return 'nl.keyzer';
    default:
      return 'en.sahih';
  }
}

/// Get device/lang locale (e.g. from app – pass from context).
String getTranslationLanguageFromLocale(String? locale) {
  if (locale == null || locale.isEmpty) return 'en';
  final code = locale.split('-').first.toLowerCase();
  if (code == 'tr' ||
      code == 'ar' ||
      code == 'pt' ||
      code == 'es' ||
      code == 'de' ||
      code == 'nl') {
    return code;
  }
  return 'en';
}

/// Fetch all surahs (chapters). Cached per language.
Future<({bool success, List<SurahListItem>? data, String? error})>
    getAllSurahs({
  required String languageCode,
  bool forceRefresh = false,
}) async {
  final cacheKey = '@quran_cache_$languageCode';
  if (!forceRefresh) {
    try {
      final prefs = await SharedPreferences.getInstance();
      final cached = prefs.getString(cacheKey);
      if (cached != null) {
        final decoded = jsonDecode(cached) as Map<String, dynamic>;
        final data = decoded['data'] as List<dynamic>?;
        if (data != null && data.isNotEmpty) {
          final list = data
              .map((e) =>
                  SurahListItem.fromJson(Map<String, dynamic>.from(e as Map)))
              .toList();
          return (success: true, data: list, error: null);
        }
      }
    } catch (_) {}
  }

  try {
    final res = await http.get(Uri.parse('$_apiBase/quran/chapters'));
    if (res.statusCode != 200) {
      return (success: false, data: null, error: 'HTTP ${res.statusCode}');
    }
    final body = jsonDecode(res.body) as Map<String, dynamic>;
    final code = body['code'] as int?;
    final data = body['data'] as Map<String, dynamic>?;
    final surahsRaw = data?['surahs'] as List<dynamic>?;
    if (code != 200 || surahsRaw == null) {
      return (success: false, data: null, error: 'Invalid API response');
    }

    // SURAH_NAMES mapping (1–114) for name/transliteration – use first 50 from RN
    final names = <int, Map<String, String>>{
      1: {'name': 'الفاتحة', 'transliteration': 'Al-Fatiha'},
      2: {'name': 'البقرة', 'transliteration': 'Al-Baqarah'},
      3: {'name': 'آل عمران', 'transliteration': 'Ali Imran'},
      4: {'name': 'النساء', 'transliteration': 'An-Nisa'},
      5: {'name': 'المائدة', 'transliteration': 'Al-Maidah'},
      6: {'name': 'الأنعام', 'transliteration': 'Al-An\'am'},
      7: {'name': 'الأعراف', 'transliteration': 'Al-A\'raf'},
      8: {'name': 'الأنفال', 'transliteration': 'Al-Anfal'},
      9: {'name': 'التوبة', 'transliteration': 'At-Tawbah'},
      10: {'name': 'يونس', 'transliteration': 'Yunus'},
    };
    for (int i = 11; i <= 114; i++) {
      names[i] ??= {'name': 'Surah $i', 'transliteration': 'Surah $i'};
    }

    final list = <SurahListItem>[];
    for (final s in surahsRaw) {
      final m = Map<String, dynamic>.from(s as Map);
      final n = (m['number'] as num?)?.toInt() ?? 0;
      final info = names[n];
      list.add(SurahListItem(
        number: n,
        name: info?['transliteration'] ??
            m['englishName'] as String? ??
            'Surah $n',
        nameArabic: info?['name'] ?? m['name'] as String?,
        nameTransliterated: m['englishNameTranslation'] as String?,
        numberOfAyahs: (m['numberOfAyahs'] as num?)?.toInt() ?? 0,
        revelationType: m['revelationType'] as String?,
      ));
    }

    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(
        cacheKey,
        jsonEncode({
          'data': list.map((e) => e.toJson()).toList(),
          '_ts': DateTime.now().millisecondsSinceEpoch
        }),
      );
    } catch (_) {}

    return (success: true, data: list, error: null);
  } catch (e) {
    return (success: false, data: null, error: e.toString());
  }
}

/// Fetch one surah with verses. Cached per surah+language.
Future<({bool success, SurahData? data, String? error})> getSurah(
  int surahNumber, {
  required String languageCode,
}) async {
  final cacheKey = '@surah_${surahNumber}_${languageCode}_v4';
  try {
    final prefs = await SharedPreferences.getInstance();
    final cached = prefs.getString(cacheKey);
    if (cached != null) {
      final decoded = jsonDecode(cached) as Map<String, dynamic>;
      final data = decoded['data'] as Map<String, dynamic>?;
      if (data != null) {
        SurahData surahData = SurahData.fromJson(data);
        await _ensureLocalArabicLoaded();
        surahData = _applyLocalArabicToSurahData(surahData);
        return (success: true, data: surahData, error: null);
      }
    }
  } catch (_) {}

  final edition = _translationEdition(languageCode);
  final url = '$_apiBase/surah/$surahNumber/editions/quran-uthmani,$edition';

  try {
    final res = await http.get(Uri.parse(url));
    if (res.statusCode != 200) {
      return (success: false, data: null, error: 'HTTP ${res.statusCode}');
    }
    final body = jsonDecode(res.body) as Map<String, dynamic>;
    final data = body['data'] as List<dynamic>?;
    if (data == null || data.length < 2) {
      return (success: false, data: null, error: 'Invalid API response');
    }

    final arabicSurah = Map<String, dynamic>.from(data[0] as Map);
    final translationSurah = Map<String, dynamic>.from(data[1] as Map);
    final arabicAyahs = arabicSurah['ayahs'] as List<dynamic>? ?? [];
    final translationAyahs = translationSurah['ayahs'] as List<dynamic>? ?? [];

    await _ensureLocalArabicLoaded();

    final verses = <VerseItem>[];
    for (int i = 0; i < arabicAyahs.length; i++) {
      final a = Map<String, dynamic>.from(arabicAyahs[i] as Map);
      final t = i < translationAyahs.length
          ? (translationAyahs[i] as Map)['text'] as String?
          : null;
      final numberInSurah = (a['numberInSurah'] as num?)?.toInt() ?? 0;
      final localText = _localArabicCache?[surahNumber]?[numberInSurah];
      verses.add(VerseItem(
        number: (a['number'] as num?)?.toInt() ?? 0,
        numberInSurah: numberInSurah,
        text: localText ?? (a['text'] as String? ?? ''),
        translation: t,
        transliteration: a['transliteration'] as String?,
        juz: (a['juz'] as num?)?.toInt(),
        page: (a['page'] as num?)?.toInt(),
      ));
    }

    bool showBasmalaAtTop = false;
    String? basmalaText;
    if (surahNumber != 1 && surahNumber != 9 && verses.isNotEmpty) {
      final first = verses[0].text.trimLeft();
      if (first.startsWith('بِسْمِ')) {
        final endIdx = first.indexOf(_basmalaEnd);
        if (endIdx != -1) {
          final end = endIdx + _basmalaEnd.length;
          basmalaText = first.substring(0, end).trim();
          verses[0] = VerseItem(
            number: verses[0].number,
            numberInSurah: verses[0].numberInSurah,
            text: first.substring(end).trim(),
            translation: verses[0].translation,
            transliteration: verses[0].transliteration,
            juz: verses[0].juz,
            page: verses[0].page,
          );
          showBasmalaAtTop = true;
        }
      } else {
        showBasmalaAtTop = true;
        basmalaText = _localArabicCache?[1]?[1];
      }
    }

    final surahData = SurahData(
      number: (arabicSurah['number'] as num?)?.toInt() ?? surahNumber,
      name: arabicSurah['englishName'] as String? ?? 'Surah $surahNumber',
      nameArabic: arabicSurah['name'] as String?,
      nameTransliterated: arabicSurah['englishNameTranslation'] as String?,
      numberOfAyahs:
          (arabicSurah['numberOfAyahs'] as num?)?.toInt() ?? verses.length,
      revelationType: arabicSurah['revelationType'] as String?,
      verses: verses,
      showBasmalaAtTop: showBasmalaAtTop,
      basmalaText: basmalaText,
    );

    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(
          cacheKey,
          jsonEncode({
            'data': surahData.toJson(),
            '_ts': DateTime.now().millisecondsSinceEpoch
          }));
    } catch (_) {}

    return (success: true, data: surahData, error: null);
  } catch (e) {
    return (success: false, data: null, error: e.toString());
  }
}

/// RN: getAyahTranslation – tek ayet çevirisi (translation modal için).
Future<({bool success, String? text, String? error})> getAyahTranslation(
  int surahNumber,
  int ayahNumber, {
  String? languageCode,
}) async {
  final lang = languageCode ?? 'en';
  final result = await getSurah(surahNumber, languageCode: lang);
  if (!result.success || result.data == null) {
    return (success: false, text: null, error: result.error);
  }
  final list =
      result.data!.verses.where((v) => v.numberInSurah == ayahNumber).toList();
  if (list.isEmpty) {
    return (success: false, text: null, error: 'Verse not found');
  }
  return (success: true, text: list.first.translation, error: null);
}

/// RN: searchInQuran – ayet metni/çeviri araması (api.alquran.cloud).
class AyahSearchMatch {
  final int surah;
  final int ayah;
  final String text;
  final String translation;

  AyahSearchMatch({
    required this.surah,
    required this.ayah,
    required this.text,
    required this.translation,
  });
}

Future<({bool success, List<AyahSearchMatch>? data, String? error})>
    searchInQuran(
  String query, {
  required String languageCode,
}) async {
  final q = query.trim();
  if (q.length < 2)
    return (
      success: false,
      data: null,
      error: 'Query must be at least 2 characters'
    );
  try {
    final encoded = Uri.encodeComponent(q);
    final url = '$_apiBase/search/$encoded/$languageCode';
    final res = await http.get(Uri.parse(url));
    if (res.statusCode == 404)
      return (success: true, data: <AyahSearchMatch>[], error: null);
    if (res.statusCode < 200 || res.statusCode >= 300)
      return (success: true, data: <AyahSearchMatch>[], error: null);
    final body = jsonDecode(res.body) as Map<String, dynamic>?;
    if (body == null)
      return (success: true, data: <AyahSearchMatch>[], error: null);
    final code = body['code'] as num?;
    final data = body['data'] as Map<String, dynamic>?;
    final matches = data?['matches'] as List<dynamic>?;
    if (code != 200 || matches == null)
      return (success: true, data: <AyahSearchMatch>[], error: null);
    final list = <AyahSearchMatch>[];
    for (final m in matches) {
      final map = m as Map<String, dynamic>?;
      if (map == null) continue;
      final surahObj = map['surah'] as Map<String, dynamic>?;
      final surahNum = (surahObj?['number'] as num?)?.toInt();
      final ayahNum = (map['numberInSurah'] as num?)?.toInt();
      if (surahNum == null || ayahNum == null) continue;
      list.add(AyahSearchMatch(
        surah: surahNum,
        ayah: ayahNum,
        text: map['text'] as String? ?? '',
        translation: map['translation'] as String? ?? '',
      ));
    }
    return (success: true, data: list, error: null);
  } catch (_) {
    return (success: true, data: <AyahSearchMatch>[], error: null);
  }
}

// ========== Mushaf / Juz (RN: getMushafPageUrl, getJuzStartPage, getJuzEndPage, calculateJuzByPage) ==========
const int totalMushafPages = 605;
const String _mushafStorageUrl =
    'https://dnfskfcofunpbrbmacbv.supabase.co/storage/v1/object/public/mushaf';

/// RN: calculateJuzByPage – sayfa numarasına göre cüz (1–30).
int calculateJuzByPage(int pageNumber) {
  final page = pageNumber.clamp(1, totalMushafPages);
  if (page <= 21) return 1;
  if (page >= 582) return 30;
  return ((page - 22) / 20).floor() + 2;
}

int getJuzStartPage(int juzNumber) {
  if (juzNumber == 1) return 1;
  if (juzNumber == 30) return 582;
  return (juzNumber - 2) * 20 + 22;
}

int getJuzEndPage(int juzNumber) {
  if (juzNumber == 1) return 21;
  if (juzNumber == 30) return 604;
  return (juzNumber - 1) * 20 + 1;
}

String getMushafPageUrl(int pageNumber) {
  if (pageNumber < 1 || pageNumber > totalMushafPages) {
    throw ArgumentError(
        'Invalid page number: $pageNumber. Must be between 1 and $totalMushafPages');
  }
  final encodedPageName = Uri.encodeComponent('page ($pageNumber).png');
  return '$_mushafStorageUrl/$encodedPageName?width=ORIGINAL&quality=100&download=true&format=origin';
}

// ========== Juz → (surah, ayah) list for audio download ==========
/// End (surah, ayah) of each juz (1-based). Juz 1 ends at 2:141, etc.
const List<(int surah, int ayah)> _juzEndAyah = [
  (2, 141),
  (2, 252),
  (3, 92),
  (3, 170),
  (4, 23),
  (4, 87),
  (4, 147),
  (5, 26),
  (5, 81),
  (6, 110),
  (6, 165),
  (7, 87),
  (7, 170),
  (8, 40),
  (9, 92),
  (10, 25),
  (11, 5),
  (11, 83),
  (12, 52),
  (13, 18),
  (14, 52),
  (15, 99),
  (16, 128),
  (17, 111),
  (18, 74),
  (19, 98),
  (20, 135),
  (22, 78),
  (25, 20),
  (114, 6),
];

/// Returns all (surah, ayah) pairs in the given juz (1–30).
List<(int surah, int ayah)> getAyahsInJuz(int juzNumber) {
  if (juzNumber < 1 || juzNumber > 30) return [];
  final end = _juzEndAyah[juzNumber - 1];
  int startS = 1, startA = 1;
  if (juzNumber > 1) {
    final prev = _juzEndAyah[juzNumber - 2];
    startS = prev.$1;
    startA = prev.$2 + 1;
    if (startA > _surahVerseCount[startS]!) {
      startS++;
      startA = 1;
    }
  }
  final list = <(int, int)>[];
  for (int s = startS; s <= end.$1; s++) {
    final firstA = s == startS ? startA : 1;
    final lastA = s == end.$1 ? end.$2 : _surahVerseCount[s]!;
    for (int a = firstA; a <= lastA; a++) {
      list.add((s, a));
    }
  }
  return list;
}

/// Returns the juz number (1–30) that contains the given (surah, ayah).
int getJuzForAyah(int surah, int ayah) {
  for (int j = 0; j < 30; j++) {
    final end = _juzEndAyah[j];
    if (surah < end.$1 || (surah == end.$1 && ayah <= end.$2)) return j + 1;
  }
  return 30;
}

/// Returns all (surah, ayah) in the Quran (1:1 through 114:6).
List<(int surah, int ayah)> getAllAyahs() {
  final list = <(int, int)>[];
  for (int s = 1; s <= 114; s++) {
    final count = _surahVerseCount[s]!;
    for (int a = 1; a <= count; a++) {
      list.add((s, a));
    }
  }
  return list;
}

/// Verse count per surah (for juz iteration).
const Map<int, int> _surahVerseCount = {
  1: 7,
  2: 286,
  3: 200,
  4: 176,
  5: 120,
  6: 165,
  7: 206,
  8: 75,
  9: 129,
  10: 109,
  11: 123,
  12: 111,
  13: 43,
  14: 52,
  15: 99,
  16: 128,
  17: 111,
  18: 110,
  19: 98,
  20: 135,
  21: 112,
  22: 78,
  23: 118,
  24: 64,
  25: 77,
  26: 227,
  27: 93,
  28: 88,
  29: 69,
  30: 60,
  31: 34,
  32: 30,
  33: 73,
  34: 54,
  35: 45,
  36: 83,
  37: 182,
  38: 88,
  39: 75,
  40: 85,
  41: 54,
  42: 53,
  43: 89,
  44: 59,
  45: 37,
  46: 35,
  47: 38,
  48: 29,
  49: 18,
  50: 45,
  51: 60,
  52: 49,
  53: 62,
  54: 55,
  55: 78,
  56: 96,
  57: 29,
  58: 22,
  59: 24,
  60: 13,
  61: 14,
  62: 11,
  63: 11,
  64: 18,
  65: 12,
  66: 12,
  67: 30,
  68: 52,
  69: 52,
  70: 44,
  71: 28,
  72: 28,
  73: 20,
  74: 56,
  75: 40,
  76: 31,
  77: 50,
  78: 40,
  79: 46,
  80: 42,
  81: 29,
  82: 19,
  83: 36,
  84: 25,
  85: 22,
  86: 17,
  87: 19,
  88: 26,
  89: 30,
  90: 20,
  91: 15,
  92: 21,
  93: 11,
  94: 8,
  95: 8,
  96: 19,
  97: 5,
  98: 8,
  99: 8,
  100: 11,
  101: 11,
  102: 8,
  103: 3,
  104: 9,
  105: 5,
  106: 4,
  107: 7,
  108: 3,
  109: 6,
  110: 3,
  111: 5,
  112: 4,
  113: 5,
  114: 6,
};
