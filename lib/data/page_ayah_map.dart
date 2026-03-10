// RN: contexts/PAGE_AYAH_MAP.js – sayfa ↔ surah/ayah eşlemesi.
// Veri: assets/data/page_ayah_map.json

import 'dart:convert';
import 'package:flutter/services.dart';

const int totalMushafPages = 605;

/// Bir sayfanın başlangıç ve bitiş ayeti.
class PageAyahRange {
  final int startSurah;
  final int startAyah;
  final int endSurah;
  final int endAyah;

  const PageAyahRange({
    required this.startSurah,
    required this.startAyah,
    required this.endSurah,
    required this.endAyah,
  });

  ({int surah, int ayah}) get start => (surah: startSurah, ayah: startAyah);
  ({int surah, int ayah}) get end => (surah: endSurah, ayah: endAyah);
}

Map<int, PageAyahRange>? _pageAyahMapCache;

Future<Map<int, PageAyahRange>> _loadPageAyahMap() async {
  if (_pageAyahMapCache != null) return _pageAyahMapCache!;
  final raw = await rootBundle.loadString('assets/data/page_ayah_map.json');
  final map = jsonDecode(raw) as Map<String, dynamic>;
  _pageAyahMapCache = {};
  for (final entry in map.entries) {
    final page = int.tryParse(entry.key);
    if (page == null) continue;
    final v = entry.value as Map<String, dynamic>?;
    if (v == null) continue;
    final start = v['start'] as Map<String, dynamic>?;
    final end = v['end'] as Map<String, dynamic>?;
    if (start == null || end == null) continue;
    _pageAyahMapCache![page] = PageAyahRange(
      startSurah: (start['surah'] as num?)?.toInt() ?? 0,
      startAyah: (start['ayah'] as num?)?.toInt() ?? 0,
      endSurah: (end['surah'] as num?)?.toInt() ?? 0,
      endAyah: (end['ayah'] as num?)?.toInt() ?? 0,
    );
  }
  return _pageAyahMapCache!;
}

/// Verilen (surah, ayah) ayetinin bulunduğu sayfa numarası; yoksa null.
Future<int?> getPageForSurahAyah(int surah, int ayah) async {
  final map = await _loadPageAyahMap();
  for (int page = 1; page <= totalMushafPages; page++) {
    final r = map[page];
    if (r == null) continue;
    if (r.startSurah == surah && r.endSurah == surah) {
      if (ayah >= r.startAyah && ayah <= r.endAyah) return page;
    } else if (r.startSurah <= surah && surah <= r.endSurah) {
      if (surah == r.startSurah && ayah >= r.startAyah) return page;
      if (surah == r.endSurah && ayah <= r.endAyah) return page;
      if (r.startSurah < surah && surah < r.endSurah) return page;
    }
  }
  return null;
}

/// Sayfanın ilk ayeti.
Future<({int surah, int ayah})?> getPageStartAyah(int page) async {
  final map = await _loadPageAyahMap();
  final r = map[page];
  return r?.start;
}

/// Sayfanın son ayeti.
Future<({int surah, int ayah})?> getPageEndAyah(int page) async {
  final map = await _loadPageAyahMap();
  final r = map[page];
  return r?.end;
}

/// Kuran sırasına göre sonraki ayet; 114:6 sonrası null.
/// Sure sonundayken her zaman sonraki surenin 1. ayetine gider (sayfa haritasından bağımsız).
Future<({int surah, int ayah})?> getNextAyah(int surah, int ayah) async {
  if (surah == 114 && ayah == 6) return null;
  final maxAyah = _surahAyahCounts[surah] ?? 0;
  if (maxAyah > 0 && ayah >= maxAyah) {
    if (surah < 114) return (surah: surah + 1, ayah: 1);
    return null;
  }
  final map = await _loadPageAyahMap();
  final currentPage = await getPageForSurahAyah(surah, ayah);
  if (currentPage == null) return null;
  final r = map[currentPage];
  if (r == null) return null;
  if (r.startSurah == surah && r.endSurah == surah) {
    if (ayah < r.endAyah) return (surah: surah, ayah: ayah + 1);
    if (surah < 114) return (surah: surah + 1, ayah: 1);
    return null;
  }
  if (surah == r.endSurah && ayah < r.endAyah)
    return (surah: surah, ayah: ayah + 1);
  if (surah == r.endSurah && ayah == r.endAyah) {
    if (surah < 114) return (surah: surah + 1, ayah: 1);
    return null;
  }
  for (int p = currentPage + 1; p <= totalMushafPages; p++) {
    final next = map[p];
    if (next == null) continue;
    if (next.startSurah > surah)
      return (surah: next.startSurah, ayah: next.startAyah);
    if (next.startSurah == surah && next.startAyah > ayah)
      return (surah: next.startSurah, ayah: next.startAyah);
  }
  return null;
}

/// Sure başına ayet sayısı (1..114).
const Map<int, int> _surahAyahCounts = {
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

/// Kuran sırasına göre önceki ayet; 1:1 öncesi null.
({int surah, int ayah})? getPreviousAyah(int surah, int ayah) {
  if (surah == 1 && ayah == 1) return null;
  if (ayah > 1) return (surah: surah, ayah: ayah - 1);
  if (surah > 1) {
    final prevSurah = surah - 1;
    final maxAyah = _surahAyahCounts[prevSurah] ?? 0;
    return (surah: prevSurah, ayah: maxAyah);
  }
  return null;
}

/// Senkron: sayfa aralığını döndür (map yüklüyse). Önceden load için _loadPageAyahMap() çağrılmalı.
PageAyahRange? getPageRangeSync(int page) => _pageAyahMapCache?[page];
