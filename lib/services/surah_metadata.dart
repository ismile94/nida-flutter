// Port of RN services/surahMetadata.js – nuzul yeri/dönemi, tarih, tema, sure açıklaması.
// Veri: assets/data/surah_metadata.json (RN utils/locales tr/en'den çıkarıldı).

import 'dart:convert';

import 'package:flutter/services.dart';

/// Locale: tr, en, ar, pt, es, de, nl (kısa kod kullanılır).
String _normLocale(String? locale) {
  if (locale == null || locale.isEmpty) return 'en';
  final loc = locale.split('-').first.toLowerCase();
  if (loc == 'tr' || loc == 'en') return loc;
  return 'en';
}

/// Yüklü metadata: { "tr": { "surahDescriptions": {...}, "surahRevelationDates": {...}, "surahMainThemes": {...} }, "en": {...} }
Map<String, dynamic>? _loaded;

/// Asset'ten surah_metadata.json yükler. Uygulama açılışında veya Quran ekranına girildiğinde çağrılmalı.
Future<void> loadSurahMetadata() async {
  if (_loaded != null) return;
  try {
    final s = await rootBundle.loadString('assets/data/surah_metadata.json');
    final decoded = jsonDecode(s) as Map<String, dynamic>?;
    _loaded = decoded;
  } catch (_) {
    _loaded = {};
  }
}

/// Nuzul yeri adı (Meccan → Mekke / Mecca vb.)
String? getRevelationPlaceName(String? revelationType, String? locale) {
  if (revelationType == null || revelationType.isEmpty) return null;
  final loc = _normLocale(locale);
  const map = {
    'tr': {'meccan': 'Mekke', 'medinan': 'Medine'},
    'en': {'meccan': 'Mecca', 'medinan': 'Medina'},
    'ar': {'meccan': 'مكة', 'medinan': 'المدينة'},
    'pt': {'meccan': 'Meca', 'medinan': 'Medina'},
    'es': {'meccan': 'La Meca', 'medinan': 'Medina'},
    'de': {'meccan': 'Mekka', 'medinan': 'Medina'},
    'nl': {'meccan': 'Mekka', 'medinan': 'Medina'},
  };
  final key = revelationType.toLowerCase();
  return map[loc]?[key] ?? map['en']?[key] ?? revelationType;
}

/// Nuzul dönemi açıklaması (Meccan → Mekke Dönemi / Meccan Period vb.)
String? getRevelationPeriodDescription(String? revelationType, String? locale) {
  if (revelationType == null || revelationType.isEmpty) return null;
  final loc = _normLocale(locale);
  const map = {
    'tr': {'meccan': 'Mekke Dönemi', 'medinan': 'Medine Dönemi'},
    'en': {'meccan': 'Meccan Period', 'medinan': 'Medinan Period'},
    'ar': {'meccan': 'الفترة المكية', 'medinan': 'الفترة المدنية'},
    'pt': {'meccan': 'Período Meca', 'medinan': 'Período Medina'},
    'es': {'meccan': 'Período de La Meca', 'medinan': 'Período de Medina'},
    'de': {'meccan': 'Mekka-Periode', 'medinan': 'Medina-Periode'},
    'nl': {'meccan': 'Mekka-periode', 'medinan': 'Medina-periode'},
  };
  final key = revelationType.toLowerCase();
  return map[loc]?[key] ?? map['en']?[key] ?? revelationType;
}

/// Nuzul tarihi – assets/data/surah_metadata.json -> [locale].surahRevelationDates[surahNumber]
String? getSurahRevelationDate(int surahNumber, String? locale) {
  final loc = _normLocale(locale);
  final localeData = _loaded?[loc] as Map<String, dynamic>?;
  final dates = localeData?['surahRevelationDates'] as Map<String, dynamic>?;
  if (dates == null) return null;
  return dates[surahNumber.toString()] as String?;
}

/// Nuzul olayı – i18n'de varsa eklenebilir; şimdilik null.
String? getSurahRevelationEvent(int surahNumber, String? locale) {
  return null;
}

/// Ana tema – assets/data/surah_metadata.json -> [locale].surahMainThemes[surahNumber][locale]
String? getSurahMainTheme(int surahNumber, String? locale) {
  final loc = _normLocale(locale);
  final localeData = _loaded?[loc] as Map<String, dynamic>?;
  final themes = localeData?['surahMainThemes'] as Map<String, dynamic>?;
  if (themes == null) return null;
  final surahTheme = themes[surahNumber.toString()] as Map<String, dynamic>?;
  if (surahTheme == null) return null;
  return (surahTheme[loc] ?? surahTheme['en'] ?? surahTheme['tr']) as String?;
}

/// Sure açıklaması – assets/data/surah_metadata.json -> [locale].surahDescriptions[surahNumber][locale]
String? getSurahDescription(int surahNumber, String? locale) {
  final loc = _normLocale(locale);
  final localeData = _loaded?[loc] as Map<String, dynamic>?;
  final descriptions = localeData?['surahDescriptions'] as Map<String, dynamic>?;
  if (descriptions == null) return null;
  final surahDesc = descriptions[surahNumber.toString()] as Map<String, dynamic>?;
  if (surahDesc == null) return null;
  return (surahDesc[loc] ?? surahDesc['en'] ?? surahDesc['tr']) as String?;
}
