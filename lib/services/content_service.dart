import 'dart:convert';
import 'dart:math';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Loads duas, hadiths and esmaulhusna from bundled JSON assets and selects
/// content based on prayer time, mood, special occasions and the app locale.
///
/// JSON files are structured as  { "tr": {...}, "en": {...}, ... }  so one
/// file covers all 7 supported languages. The locale fallback chain is:
/// requested → "en" → "tr".
class ContentService {
  ContentService._();
  static final ContentService instance = ContentService._();

  /// These hold the full multi-language JSON objects (loaded once from assets).
  Map<String, dynamic>? _duas;
  Map<String, dynamic>? _hadiths;
  Map<String, dynamic>? _esmaulHusna;

  static const _fallbackLocales = ['en', 'tr'];

  Future<Map<String, dynamic>> _loadDuas() async {
    if (_duas != null) return _duas!;
    final raw = await rootBundle.loadString('assets/data/duas.json');
    _duas = jsonDecode(raw) as Map<String, dynamic>;
    return _duas!;
  }

  Future<Map<String, dynamic>> _loadHadiths() async {
    if (_hadiths != null) return _hadiths!;
    final raw = await rootBundle.loadString('assets/data/hadiths.json');
    _hadiths = jsonDecode(raw) as Map<String, dynamic>;
    return _hadiths!;
  }

  Future<Map<String, dynamic>> _loadEsmaulHusna() async {
    if (_esmaulHusna != null) return _esmaulHusna!;
    final raw = await rootBundle.loadString('assets/data/esmaulhusna.json');
    _esmaulHusna = jsonDecode(raw) as Map<String, dynamic>;
    return _esmaulHusna!;
  }

  /// Returns the locale-specific content map (duas / hadiths / esma structure).
  /// Falls back through [_fallbackLocales] when the requested locale is missing.
  Map<String, dynamic> _pickLocale(Map<String, dynamic> root, String locale) {
    final candidates = [locale, ..._fallbackLocales];
    for (final l in candidates) {
      final v = root[l];
      if (v is Map<String, dynamic>) return v;
    }
    // Last resort: return first available
    for (final v in root.values) {
      if (v is Map<String, dynamic>) return v;
    }
    return {};
  }

  List<dynamic> _buildPool(
    Map<String, dynamic> data,
    String prayerTime,
    String? mood,
    bool isRamadan,
    bool isKandil,
  ) {
    final List<dynamic> pool = [];

    // 1) Special occasions have highest priority
    if (isKandil) {
      final kandil = data['special']?['kandil'] as List?;
      if (kandil != null) pool.addAll(kandil);
    } else if (isRamadan) {
      final ramadan = data['special']?['ramadan'] as List?;
      if (ramadan != null) pool.addAll(ramadan);
    }

    // 2) Mood-based
    if (mood != null) {
      final byMood = data['byMood']?[mood] as List?;
      if (byMood != null) pool.addAll(byMood);
    }

    // 3) Prayer-time-based
    final byPrayer = data['byPrayer']?[prayerTime] as List?;
    if (byPrayer != null) pool.addAll(byPrayer);

    // 4) Fallback to general
    if (pool.isEmpty) {
      final general = data['general'] as List?;
      if (general != null) pool.addAll(general);
    }

    return pool;
  }

  Future<Map<String, dynamic>?> getDua({
    required String prayerTime,
    required String locale,
    String? mood,
    bool isRamadan = false,
    bool isKandil = false,
  }) async {
    try {
      final root = await _loadDuas();
      final data = _pickLocale(root, locale);
      final pool = _buildPool(data, prayerTime, mood, isRamadan, isKandil);
      if (pool.isEmpty) return null;
      return pool[Random().nextInt(pool.length)] as Map<String, dynamic>;
    } catch (_) {
      return null;
    }
  }

  Future<Map<String, dynamic>?> getHadith({
    required String prayerTime,
    required String locale,
    String? mood,
    bool isRamadan = false,
    bool isKandil = false,
  }) async {
    try {
      final root = await _loadHadiths();
      final data = _pickLocale(root, locale);
      final pool = _buildPool(data, prayerTime, mood, isRamadan, isKandil);
      if (pool.isEmpty) return null;
      return pool[Random().nextInt(pool.length)] as Map<String, dynamic>;
    } catch (_) {
      return null;
    }
  }

  /// Returns the Esma for today (index = dayOfYear % 99) – same logic as RN.
  Future<Map<String, dynamic>?> getEsmaulHusna({required String locale}) async {
    try {
      final root = await _loadEsmaulHusna();
      final data = _pickLocale(root, locale);
      final general = data['general'] as List?;
      if (general == null || general.isEmpty) return null;
      final now = DateTime.now();
      final startOfYear = DateTime(now.year, 1, 1);
      final dayOfYear = now.difference(startOfYear).inDays + 1;
      final index = dayOfYear % general.length;
      return general[index] as Map<String, dynamic>;
    } catch (_) {
      return null;
    }
  }

  // ── "First seen" highlight helpers (SharedPreferences) ──────────────────

  Future<bool> markDuaAsSeenIfNew(Map<String, dynamic> dua) async {
    return _markSeenIfNew('@seen_duas', _itemKey(dua));
  }

  Future<bool> markHadithAsSeenIfNew(Map<String, dynamic> hadith) async {
    return _markSeenIfNew('@seen_hadiths', _itemKey(hadith));
  }

  Future<bool> markEsmaAsSeenIfNew(Map<String, dynamic> esma) async {
    final key = '${esma['arabic']}_${esma['latin']}';
    return _markSeenIfNew('@seen_esma_names', key);
  }

  String _itemKey(Map<String, dynamic> item) {
    final id = item['id'] as String?;
    if (id != null) return id;
    final text = (item['text'] as String?) ?? '';
    return text.length > 20 ? text.substring(0, 20) : text;
  }

  Future<bool> _markSeenIfNew(String storageKey, String itemKey) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final seenJson = prefs.getString(storageKey) ?? '{}';
      final seen = jsonDecode(seenJson) as Map<String, dynamic>;
      if (seen[itemKey] == true) return false;
      seen[itemKey] = true;
      await prefs.setString(storageKey, jsonEncode(seen));
      return true;
    } catch (_) {
      return false;
    }
  }
}
