import 'dart:convert';
import 'package:http/http.dart' as http;

const _manifestUrls = [
  'https://cdn.jsdelivr.net/gh/ismile94/nidaunnur-content@main/manifest.json',
  'https://raw.githubusercontent.com/ismile94/nidaunnur-content/main/manifest.json',
];
const _cdnBase = 'https://cdn.jsdelivr.net/gh/ismile94/nidaunnur-content@main';
const _githubApiBase =
    'https://api.github.com/repos/ismile94/nidaunnur-content/contents';

class RemoteContentItem {
  final String id;

  /// Horizontal (landscape) image — shown in the card preview.
  final String imageUrl;

  /// Vertical (portrait) image — used for the share composition.
  /// Falls back to [imageUrl] when null.
  final String? shareImageUrl;

  final String? quoteText;
  final String? shareText;
  final String? type;

  const RemoteContentItem({
    required this.id,
    required this.imageUrl,
    this.shareImageUrl,
    this.quoteText,
    this.shareText,
    this.type,
  });

  /// URL to use for sharing: vertical variant if available, else horizontal.
  String get effectiveShareImageUrl => shareImageUrl ?? imageUrl;
}

// ── Internal helper ────────────────────────────────────────────────────────────

class _ImagePair {
  final String horizontal;
  final String? vertical;
  const _ImagePair(this.horizontal, this.vertical);
}

// ── Service ────────────────────────────────────────────────────────────────────

class RemoteContentService {
  RemoteContentService._();
  static final RemoteContentService instance = RemoteContentService._();

  Map<String, dynamic>? _cachedManifest;
  DateTime? _cacheTime;
  static const _cacheDuration = Duration(hours: 6);

  // folder → pairs cache
  final Map<String, List<_ImagePair>> _folderCache = {};

  // ─── Manifest ────────────────────────────────────────────────────────────────

  Future<Map<String, dynamic>?> _fetchManifest() async {
    final now = DateTime.now();
    if (_cachedManifest != null &&
        _cacheTime != null &&
        now.difference(_cacheTime!) < _cacheDuration) {
      return _cachedManifest;
    }

    for (final url in _manifestUrls) {
      try {
        final res = await http
            .get(Uri.parse(url))
            .timeout(const Duration(seconds: 10));
        if (res.statusCode == 200) {
          _cachedManifest = jsonDecode(res.body) as Map<String, dynamic>;
          _cacheTime = now;
          return _cachedManifest;
        }
      } catch (_) {
        continue;
      }
    }
    return null;
  }

  // ─── GitHub folder expansion ──────────────────────────────────────────────

  /// Fetches all images in [folderPath] and pairs each horizontal image with
  /// its `_vertical` counterpart (if present in the same folder).
  Future<List<_ImagePair>> _fetchFolderPairs(String folderPath) async {
    if (_folderCache.containsKey(folderPath)) {
      return _folderCache[folderPath]!;
    }
    try {
      final apiUrl = '$_githubApiBase/$folderPath';
      final res = await http
          .get(
            Uri.parse(apiUrl),
            headers: {'Accept': 'application/vnd.github.v3+json'},
          )
          .timeout(const Duration(seconds: 10));
      if (res.statusCode != 200) return [];

      final files = jsonDecode(res.body) as List;

      const imageExts = {'.jpg', '.jpeg', '.png', '.webp'};

      // Build two maps: stem → CDN URL for horizontal and vertical images.
      // Names like "ramazan_01.jpg" and "ramazan_01_vertical.jpg" should pair.
      final Map<String, String> verticals = {};   // lower stem → CDN URL
      final Map<String, String> horizontals = {}; // lower stem → CDN URL

      for (final f in files.whereType<Map<String, dynamic>>()) {
        final rawName = f['name'] as String? ?? '';
        final name = rawName.toLowerCase();
        final dotIdx = name.lastIndexOf('.');
        if (dotIdx == -1) continue;
        final ext = name.substring(dotIdx);
        if (!imageExts.contains(ext)) continue;

        final path = f['path'] as String? ?? '';
        final url = '$_cdnBase/$path';
        final stem = name.substring(0, dotIdx); // e.g. "ramazan_01"

        // Detect vertical by "-vertical" or "_vertical" anywhere in the stem
        final verticalPattern = RegExp(r'[-_]vertical');
        if (verticalPattern.hasMatch(stem)) {
          // Strip from the first "-vertical" / "_vertical" to get the base stem
          final baseStem = stem.replaceFirst(verticalPattern, '');
          verticals[baseStem] = url;
        } else {
          horizontals[stem] = url;
        }
      }

      // Pair each horizontal with its vertical counterpart.
      // Extra guard: skip any URL that somehow still contains a vertical suffix.
      final verticalGuard = RegExp(r'[-_]vertical', caseSensitive: false);
      final pairs = horizontals.entries
          .where((e) => !verticalGuard.hasMatch(e.value))
          .map((e) => _ImagePair(e.value, verticals[e.key]))
          .toList();

      _folderCache[folderPath] = pairs;
      return pairs;
    } catch (_) {
      return [];
    }
  }

  // ─── Locale helpers ───────────────────────────────────────────────────────────

  List<String> _localePriority(String locale) {
    return {locale.toLowerCase(), 'en', 'tr'}.toList();
  }

  String? _getLocalizedValue(
      Map<String, dynamic>? source, String locale, String field) {
    if (source == null) return null;
    for (final l in _localePriority(locale)) {
      final entry = source[l];
      if (entry is Map) {
        final val = entry[field] as String?;
        if (val != null && val.trim().isNotEmpty) return val;
      }
    }
    return null;
  }

  String? _resolveText(
    Map<String, dynamic> item,
    Map<String, dynamic>? byType,
    String locale,
    String field,
  ) {
    final itemLocales = item['locales'] as Map<String, dynamic>?;
    return _getLocalizedValue(itemLocales, locale, field) ??
        _getLocalizedValue(byType, locale, field) ??
        item[field] as String?;
  }

  // ─── Date + Locale filters ────────────────────────────────────────────────────

  bool _isActiveToday(Map<String, dynamic> item) {
    final today = DateTime.now().toIso8601String().substring(0, 10);
    final start = item['startDate'] as String?;
    final end = item['endDate'] as String?;
    if (start == null || end == null) return false;
    return start.compareTo(today) <= 0 && end.compareTo(today) >= 0;
  }

  bool _supportsLocale(
    Map<String, dynamic> item,
    String locale,
    Map<String, dynamic>? byType,
  ) {
    final priorities = _localePriority(locale);
    final itemLocales = item['locales'] as Map<String, dynamic>?;
    if (itemLocales != null) {
      if (priorities.any((l) => itemLocales.containsKey(l))) return true;
    }
    if (byType != null) {
      if (priorities.any((l) => byType.containsKey(l))) return true;
    }
    final lang = item['lang'] as String?;
    return lang == null || priorities.contains(lang.toLowerCase());
  }

  // ─── Public API ───────────────────────────────────────────────────────────────

  Future<List<RemoteContentItem>> getItems(String locale) async {
    try {
      final manifest = await _fetchManifest();
      if (manifest == null) return [];

      final rawItems = <Map<String, dynamic>>[];

      // specialDays take priority
      final specialDays = manifest['specialDays'] as List? ?? [];
      for (final day in specialDays.whereType<Map<String, dynamic>>()) {
        if (_isActiveToday(day)) rawItems.add(day);
      }

      final items = manifest['items'] as List? ?? [];
      for (final item in items.whereType<Map<String, dynamic>>()) {
        if (_isActiveToday(item)) rawItems.add(item);
      }

      if (rawItems.isEmpty) return [];

      final localizedTextByType =
          manifest['localizedTextByType'] as Map<String, dynamic>?;

      final result = <RemoteContentItem>[];

      for (final item in rawItems) {
        final itemType = item['type'] as String?;
        Map<String, dynamic>? byType;
        if (itemType != null && localizedTextByType != null) {
          byType = localizedTextByType[itemType] as Map<String, dynamic>?;
        }

        if (!_supportsLocale(item, locale, byType)) continue;

        final quoteText = _resolveText(item, byType, locale, 'quoteText');
        final shareText = _resolveText(item, byType, locale, 'shareText');

        // Items with imageFolder → expand to individual paired image items
        final imageFolder = item['imageFolder'] as String?;
        if (imageFolder != null) {
          final pairs = await _fetchFolderPairs(imageFolder);
          for (int i = 0; i < pairs.length; i++) {
            result.add(RemoteContentItem(
              id: '${item['id']}_$i',
              imageUrl: pairs[i].horizontal,
              shareImageUrl: pairs[i].vertical,
              quoteText: quoteText,
              shareText: shareText,
              type: itemType,
            ));
          }
          continue;
        }

        // Items with a direct imageUrl
        final rawImageUrl = item['imageUrl'] as String? ?? '';
        if (rawImageUrl.isEmpty) continue;
        final imageUrl = rawImageUrl.startsWith('http')
            ? rawImageUrl
            : '$_cdnBase/${rawImageUrl.replaceFirst(RegExp(r'^/?'), '')}';

        result.add(RemoteContentItem(
          id: item['id']?.toString() ?? '',
          imageUrl: imageUrl,
          shareImageUrl: null,
          quoteText: quoteText,
          shareText: shareText,
          type: itemType,
        ));
      }

      return result;
    } catch (_) {
      return [];
    }
  }

  void clearCache() {
    _cachedManifest = null;
    _cacheTime = null;
    _folderCache.clear();
  }
}
