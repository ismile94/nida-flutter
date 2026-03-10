// Port of RN screens/SurahViewScreen.js – same layout, design, and behavior.

import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../contexts/back_handler_provider.dart';
import '../contexts/bottom_nav_index_provider.dart';
import '../contexts/navigation_bar_provider.dart';
import '../contexts/theme_provider.dart';
import '../l10n/app_localizations.dart';
import '../services/audio_download_service.dart';
import '../services/quran_playback_service.dart';
import '../services/quran_service.dart';
import '../services/surah_metadata.dart';
import '../utils/scaling.dart';
import 'package:scrollable_positioned_list/scrollable_positioned_list.dart';
import 'package:share_plus/share_plus.dart';
import '../widgets/quran_top_bar.dart';
import '../widgets/quran_sound_player.dart';

const String _keySelectedSurah = '@quran_selected_surah';
const String _keyBookmark = '@quran_bookmark';
const String _keyNotes = '@quran_notes';
const String _keyReadAyahs = '@quran_read_ayahs';

/// İndirme checklist pref anahtarları okuyucu bazlı (yeni okuyucu seçilince kendi checklist’i görünsün).
String _prefKeyDlSurah(String reciterKey, int surah) =>
    '@audio_dl_${reciterKey}_surah_$surah';
String _prefKeyDlJuz(String reciterKey, int juz) =>
    '@audio_dl_${reciterKey}_juz_$juz';
String _prefKeyDlFull(String reciterKey) => '@audio_dl_${reciterKey}_full';

/// 1. ve 9. sure hariç besmele satırı gösterilir.
bool _showBismillahRow(int surahNumber) => surahNumber != 1 && surahNumber != 9;

const String _bismillahArabic = 'بِسْمِ ٱللَّهِ ٱلرَّحْمَٰنِ ٱلرَّحِيمِ';

/// Besmele sonu (API/Unicode farklılıkları için birkaç varyant).
const List<String> _bismillahEndMarkers = [
  'ٱلرَّحِيمِ',
  'الرَّحِيمِ',
  'رَّحِيمِ',
  'رحيم', // harekesiz
];

/// İlk ayet asıl içeriği (besmele sonrası) – bazı surelerde farklı başlangıçlar.
const List<String> _verse1ContentStarts = [
  'الٓمٓ', // 2:1
  'الم ', // alternatif
  'المّ', // alternatif
];

/// 1. ve 9. sure hariç ilk ayet metninin başındaki besmeleyi kaldırır (gösterim için).
/// API/cache farklı Unicode ile gelebilir; besmele sonu veya ayet içeriği başı aranır.
String _verseDisplayText(int surahNumber, VerseItem verse) {
  if (surahNumber == 1 || surahNumber == 9 || verse.numberInSurah != 1) {
    return verse.text;
  }
  final t = verse.text.trimLeft();
  if (!t.startsWith('بِسْمِ')) return verse.text;
  for (final endMarker in _bismillahEndMarkers) {
    final idx = t.indexOf(endMarker);
    if (idx != -1) {
      final after = t.substring(idx + endMarker.length).trim();
      if (after.isNotEmpty) return after;
    }
  }
  for (final start in _verse1ContentStarts) {
    final idx = t.indexOf(start);
    if (idx > 0) {
      final after = t.substring(idx).trim();
      if (after.isNotEmpty) return after;
    }
  }
  return verse.text;
}

/// Dil kodundan pronunciation guide JSON dilini (en, tr, de, es, nl, pt) döndürür; yoksa en.
String _pronunciationGuideLangFromLocale(String locale) {
  final lower = locale.split('_').first.toLowerCase();
  if (lower == 'tr' ||
      lower == 'de' ||
      lower == 'es' ||
      lower == 'nl' ||
      lower == 'pt') return lower;
  return 'en';
}

/// Her surenin ayet sayısı (slash'ın sağında gösterilir). API 0 dönerse bu kullanılır.
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

class SurahViewScreen extends StatefulWidget {
  const SurahViewScreen({super.key});

  @override
  State<SurahViewScreen> createState() => _SurahViewScreenState();
}

class _SurahViewScreenState extends State<SurahViewScreen> {
  final TextEditingController _searchController = TextEditingController();
  final ItemScrollController _verseItemScrollController = ItemScrollController();

  /// Vurgu için (scroll artık indeks ile yapılıyor).
  final GlobalKey _verseScrollTargetKey = GlobalKey();
  final GlobalKey _bismillahScrollTargetKey = GlobalKey();
  (int surah, int ayah)? _scrollTargetVerse;

  List<SurahListItem> _surahs = [];
  SurahData? _selectedSurah;
  String _searchQuery = '';
  bool _searchExpanded = false;
  bool _surahListLoading = true;
  bool _loading = false;
  bool _soundPlayerVisible = true;
  /// Floating play button drag position (null = default: sağ alt, çok altta).
  double? _floatingButtonLeft;
  double? _floatingButtonBottom;
  final GlobalKey _floatingStackKey = GlobalKey();
  /// Ekran boyutu değişince (dikey↔yatay) toggle konumunu sıfırlamak için.
  Size? _prevMediaSize;
  bool _headerExpanded = false;
  String _verseTextMode = 'arabic'; // arabic | translation | transliteration

  Map<String, String> _notes = {};
  Map<String, bool> _readAyahs = {};
  ({int surah, int ayah})? _bookmark;

  /// Yer imine tıklanınca açılan surede bu ayete scroll yapılacak (RN: scrollToBookmarkedAyahRef).
  int? _scrollToAyahAfterLoad;

  /// assets/data/transliteration_pt.json → surahNumber -> verseNumber -> transliteration_pt
  Map<int, Map<int, String>>? _transliterationMap;

  /// RN: dil değişince sure listesi ve seçili sure yenilensin
  String? _lastLanguageCode;

  /// Çalınan ayete scroll için son scroll edilen (surah:ayah) – tekrar scroll etmemek için
  (int, int)? _lastScrolledToAyah;

  /// RN: ayet araması sonuçları (searchInQuran)
  List<AyahSearchMatch> _ayahSearchResults = [];
  bool _ayahSearchLoading = false;
  Timer? _searchDebounce;

  /// RN: "2:23" / "Bakara 23" parse → go to ayah satırı
  ({SurahListItem surah, int ayahNumber})? _surahAyahJump;

  /// Ayet aramasından veya yer iminden açılan ayete scroll sonrası vurgu (birkaç saniye sonra kalkar).
  (int surahNumber, int ayah)? _highlightedAyah;

  /// Top bar altında indirme banner göstermek için (null = gösterme).
  ({int current, int total})? _downloadProgress;

  /// Okuyucu değişince mevcut indirmeyi durdurmak için (indirilenler silinmez).
  bool _cancelDownloadRequested = false;

  @override
  void initState() {
    super.initState();
    _lastLanguageCode = _languageCode;
    context.read<ThemeProvider>().addListener(_onThemeOrLanguageChanged);
    context.read<QuranPlaybackService>().addListener(_onPlaybackChanged);
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      context.read<NavigationBarProvider>().setVisible(false);
      _loadBookmark();
      _loadNotes();
      _loadReadAyahs();
      await loadSurahMetadata();
      await _loadTransliterationMap();
      await _loadSurahs();
      if (!mounted) return;
      await _loadLastSelectedSurah();
      if (!mounted) return;
      setState(() {});
    });
  }

  void _onThemeOrLanguageChanged() {
    if (!mounted) return;
    final current = _languageCode;
    if (current == _lastLanguageCode) return;
    _lastLanguageCode = current;
    _loadSurahs(forceRefresh: true).then((_) async {
      if (!mounted || _selectedSurah == null) return;
      final r = await getSurah(_selectedSurah!.number, languageCode: current);
      if (!mounted) return;
      setState(() {
        if (r.success && r.data != null) _selectedSurah = r.data;
      });
    });
  }

  /// Çalınan ayeti (veya besmele satırını) indekse göre tam konuma scroll eder.
  /// scrollable_positioned_list ile değişken yükseklikteki öğelere %100 doğru scroll.
  void _scrollToPlayingAyah(CurrentAyah? currentAyah) {
    if (currentAyah == null ||
        _selectedSurah == null ||
        _selectedSurah!.number != currentAyah.surah) return;
    final basmalaCount =
        _showBismillahRow(_selectedSurah!.number) ? 1 : 0;
    final itemIndex = currentAyah.ayah == 0
        ? 0
        : (basmalaCount + currentAyah.ayah - 1);
    setState(() => _scrollTargetVerse = (currentAyah.surah, currentAyah.ayah));
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _verseItemScrollController.scrollTo(
        index: itemIndex,
        duration: const Duration(milliseconds: 350),
        curve: Curves.easeOut,
        alignment: 0.0,
      );
      if (mounted) setState(() => _scrollTargetVerse = null);
    });
  }

  Future<void> _loadTransliterationMap() async {
    try {
      final s =
          await rootBundle.loadString('assets/data/transliteration_pt.json');
      final j = jsonDecode(s) as Map<String, dynamic>?;
      if (j == null) return;
      final map = <int, Map<int, String>>{};
      for (final e in j.entries) {
        if (e.key == 'guia_de_pronuncia') continue;
        final surahNum = int.tryParse(e.key);
        if (surahNum == null) continue;
        final data = e.value as Map<String, dynamic>?;
        final verses = data?['verses'] as List<dynamic>?;
        if (verses == null) continue;
        final verseMap = <int, String>{};
        for (final v in verses) {
          final m = v as Map<String, dynamic>?;
          if (m == null) continue;
          final verseNum = (m['verse_number'] as num?)?.toInt();
          final tr = m['transliteration_pt'] as String?;
          if (verseNum != null && tr != null && tr.isNotEmpty)
            verseMap[verseNum] = tr;
        }
        map[surahNum] = verseMap;
      }
      if (mounted) setState(() => _transliterationMap = map);
    } catch (_) {}
  }

  void _onPlaybackChanged() {
    if (!mounted) return;
    final current = context.read<QuranPlaybackService>().currentAyah;
    if (current == null) return;
    if (_selectedSurah == null || _selectedSurah!.number != current.surah) {
      _loadAndSwitchToSurahForPlayback(current.surah, current.ayah);
      return;
    }
    if (_lastScrolledToAyah == (current.surah, current.ayah)) return;
    _lastScrolledToAyah = (current.surah, current.ayah);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _scrollToPlayingAyah(current);
    });
  }

  /// Ses sonraki sureye geçtiğinde surah view’ı da o sureye geçirir ve çalınan ayete scroll eder.
  Future<void> _loadAndSwitchToSurahForPlayback(
      int surahNumber, int ayahNumber) async {
    if (!mounted) return;
    if (_selectedSurah != null && _selectedSurah!.number == surahNumber) {
      _lastScrolledToAyah = (surahNumber, ayahNumber);
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _scrollToPlayingAyah(CurrentAyah(surahNumber, ayahNumber));
      });
      return;
    }
    setState(() => _loading = true);
    final r = await getSurah(surahNumber, languageCode: _languageCode);
    if (!mounted) return;
    setState(() {
      _loading = false;
      if (r.success && r.data != null) {
        _selectedSurah = r.data;
        SharedPreferences.getInstance().then((prefs) =>
            prefs.setString(_keySelectedSurah, surahNumber.toString()));
      }
    });
    if (mounted && r.success && r.data != null) {
      _lastScrolledToAyah = (surahNumber, ayahNumber);
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _scrollToPlayingAyah(CurrentAyah(surahNumber, ayahNumber));
      });
    }
  }

  @override
  void dispose() {
    _searchDebounce?.cancel();
    context.read<ThemeProvider>().removeListener(_onThemeOrLanguageChanged);
    context.read<QuranPlaybackService>().removeListener(_onPlaybackChanged);
    _searchController.dispose();
    context.read<NavigationBarProvider>().setVisible(true);
    super.dispose();
  }

  /// RN: searchQuery değişince debounce ile ayet araması ve surah:ayah parse
  void _scheduleAyahSearch() {
    _searchDebounce?.cancel();
    final q = _searchQuery.trim();
    if (q.isEmpty || q.length < 2) {
      setState(() {
        _ayahSearchResults = [];
        _ayahSearchLoading = false;
        _surahAyahJump = null;
      });
      return;
    }
    _searchDebounce = Timer(const Duration(milliseconds: 500), () async {
      if (!mounted) return;
      final query = _searchQuery.trim();
      if (query.isEmpty) return;
      final hasArabic = RegExp(r'[\u0600-\u06FF]').hasMatch(query);
      final wordCount =
          query.split(RegExp(r'\s+')).where((w) => w.isNotEmpty).length;
      final isLongQuery = wordCount >= 3 || query.length >= 10;
      final shouldSearchAyahs = hasArabic || isLongQuery;
      if (shouldSearchAyahs) {
        setState(() => _ayahSearchLoading = true);
        final r = await searchInQuran(query, languageCode: _languageCode);
        if (!mounted) return;
        setState(() {
          _ayahSearchLoading = false;
          _ayahSearchResults = r.success && r.data != null ? r.data! : [];
        });
      } else {
        setState(() {
          _ayahSearchResults = [];
          _ayahSearchLoading = false;
        });
      }
      final jump = _parseSurahAyahQuery(query);
      if (mounted) setState(() => _surahAyahJump = jump);
    });
  }

  /// "2 23", "2:23", "Bakara 23" → surah + ayah veya null
  ({SurahListItem surah, int ayahNumber})? _parseSurahAyahQuery(String query) {
    final parts =
        query.split(RegExp(r'[\s:;,]+')).where((e) => e.isNotEmpty).toList();
    if (parts.length < 2) return null;
    final ayahPart = parts.last;
    if (!RegExp(r'^\d+$').hasMatch(ayahPart)) return null;
    final ayahNumber = int.tryParse(ayahPart);
    if (ayahNumber == null || ayahNumber < 1) return null;
    final surahPart = parts.length == 2
        ? parts[0]
        : parts.sublist(0, parts.length - 1).join(' ');
    SurahListItem? surah;
    if (RegExp(r'^\d+$').hasMatch(surahPart)) {
      final num = int.tryParse(surahPart);
      if (num != null && num >= 1 && num <= 114) {
        for (final s in _surahs) {
          if (s.number == num) {
            surah = s;
            break;
          }
        }
      }
    }
    if (surah == null) {
      final norm = surahPart
          .toLowerCase()
          .replaceAll(RegExp(r"^al-|^an-|[\s-']"), '')
          .trim();
      if (norm.isEmpty) return null;
      for (final s in _surahs) {
        final name = (s.name).toLowerCase().replaceAll(RegExp(r"[\s-']"), '');
        final trans = (s.nameTransliterated ?? '')
            .toLowerCase()
            .replaceAll(RegExp(r"[\s-']"), '');
        if (name.contains(norm) ||
            trans.contains(norm) ||
            norm.contains(name) ||
            norm.contains(trans)) {
          surah = s;
          break;
        }
      }
    }
    if (surah == null) return null;
    final maxAyah = surah.numberOfAyahs > 0
        ? surah.numberOfAyahs
        : (_surahVerseCount[surah.number] ?? 0);
    if (maxAyah > 0 && ayahNumber > maxAyah) return null;
    return (surah: surah, ayahNumber: ayahNumber);
  }

  String get _languageCode => getTranslationLanguageFromLocale(
        context.read<ThemeProvider>().language,
      );

  Future<void> _loadSurahs({bool forceRefresh = false}) async {
    setState(() => _surahListLoading = true);
    final r = await getAllSurahs(
        languageCode: _languageCode, forceRefresh: forceRefresh);
    if (!mounted) return;
    setState(() {
      _surahListLoading = false;
      if (r.success && r.data != null) _surahs = r.data!;
    });
  }

  Future<void> _loadBookmark() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final s = prefs.getString(_keyBookmark);
      if (s == null) return;
      final j = Map<String, dynamic>.from(
        (_decodeJson(s)) as Map? ?? {},
      );
      final surah = (j['surah'] as num?)?.toInt();
      final ayah = (j['ayah'] as num?)?.toInt();
      if (surah != null && ayah != null && mounted) {
        setState(() => _bookmark = (surah: surah, ayah: ayah));
      }
    } catch (_) {}
  }

  Future<void> _loadNotes() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final s = prefs.getString(_keyNotes);
      if (s == null) return;
      final j = _decodeJson(s) as Map?;
      if (j != null && mounted) {
        setState(() {
          _notes = Map.fromEntries(
            (j.entries
                .map((e) => MapEntry(e.key.toString(), e.value.toString()))),
          );
        });
      }
    } catch (_) {}
  }

  Future<void> _loadReadAyahs() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final s = prefs.getString(_keyReadAyahs);
      if (s == null) return;
      final j = _decodeJson(s) as Map?;
      if (j != null && mounted) {
        setState(() {
          _readAyahs = Map.fromEntries(
            j.entries.map((e) => MapEntry(e.key.toString(), e.value == true)),
          );
        });
      }
    } catch (_) {}
  }

  dynamic _decodeJson(String s) {
    try {
      return jsonDecode(s);
    } catch (_) {
      return null;
    }
  }

  Future<void> _loadLastSelectedSurah() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final n = int.tryParse(prefs.getString(_keySelectedSurah) ?? '');
      if (n == null || n < 1 || n > 114 || _surahs.isEmpty) return;
      SurahListItem? found;
      for (final s in _surahs) {
        if (s.number == n) {
          found = s;
          break;
        }
      }
      if (found != null) await _onSurahSelect(found);
    } catch (_) {}
  }

  Future<void> _onSurahSelect(SurahListItem surah) async {
    if (_selectedSurah != null && _selectedSurah!.number == surah.number)
      return;
    setState(() => _loading = true);
    final r = await getSurah(surah.number, languageCode: _languageCode);
    if (!mounted) return;
    setState(() {
      _loading = false;
      if (r.success && r.data != null) {
        _selectedSurah = r.data;
        SharedPreferences.getInstance().then((prefs) =>
            prefs.setString(_keySelectedSurah, surah.number.toString()));
      }
    });
    if (r.success && r.data != null && _scrollToAyahAfterLoad != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        Future.delayed(const Duration(milliseconds: 450), () {
          if (mounted) _scrollToBookmarkedAyah();
        });
      });
    }
  }

  void _onBack() {
    setState(() {
      _selectedSurah = null;
      SharedPreferences.getInstance()
          .then((prefs) => prefs.remove(_keySelectedSurah));
    });
  }

  void _saveBookmark(int surah, int ayah) {
    _bookmark = (surah: surah, ayah: ayah);
    SharedPreferences.getInstance().then((prefs) => prefs.setString(
        _keyBookmark, jsonEncode({'surah': surah, 'ayah': ayah})));
    setState(() {});
  }

  void _removeBookmark() {
    _bookmark = null;
    SharedPreferences.getInstance().then((prefs) => prefs.remove(_keyBookmark));
    setState(() {});
  }

  void _saveNotes() {
    SharedPreferences.getInstance()
        .then((prefs) => prefs.setString(_keyNotes, jsonEncode(_notes)));
  }

  void _saveReadAyahs() {
    SharedPreferences.getInstance().then(
        (prefs) => prefs.setString(_keyReadAyahs, jsonEncode(_readAyahs)));
  }

  String _noteKey(int surah, int ayah) => '$surah:$ayah';

  /// RN: getSurahNoteKey – sure seviyesi not için key (ayah yok).
  String _surahNoteKey(int surahNumber) => '$surahNumber:0';
  bool _hasNote(int surah, int ayah) =>
      _notes[_noteKey(surah, ayah)]?.isNotEmpty ?? false;
  bool _hasSurahNote(int surahNumber) =>
      _notes[_surahNoteKey(surahNumber)]?.isNotEmpty ?? false;
  bool _isRead(int surah, int ayah) =>
      _readAyahs[_noteKey(surah, ayah)] ?? false;
  bool _isBookmarked(int surah, int ayah) =>
      _bookmark != null && _bookmark!.surah == surah && _bookmark!.ayah == ayah;

  /// RN: handleBookmarkPress – yer imi varsa o sureyi açıp ayete scroll eder, yoksa uyarı.
  Future<void> _handleBookmarkPress() async {
    if (_bookmark == null) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(AppLocalizations.t(context, 'noBookmark'))),
      );
      return;
    }
    setState(() => _loading = true);
    final r = await getSurah(_bookmark!.surah, languageCode: _languageCode);
    if (!mounted) return;
    setState(() {
      _loading = false;
      if (r.success && r.data != null) {
        _selectedSurah = r.data;
        _scrollToAyahAfterLoad = _bookmark!.ayah;
      }
    });
    if (r.success && r.data != null && _bookmark != null) {
      SharedPreferences.getInstance().then((prefs) =>
          prefs.setString(_keySelectedSurah, _bookmark!.surah.toString()));
      WidgetsBinding.instance.addPostFrameCallback((_) {
        Future.delayed(const Duration(milliseconds: 400), () {
          if (mounted) _scrollToBookmarkedAyah();
        });
      });
    } else if (!r.success && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
            content: Text(AppLocalizations.t(context, 'bookmarkLoadFailed'))),
      );
    }
  }

  void _scrollToBookmarkedAyah() {
    if (_scrollToAyahAfterLoad == null || _selectedSurah == null) return;
    final ayah = _scrollToAyahAfterLoad!;
    _scrollToAyahAfterLoad = null;
    final basmalaCount =
        _showBismillahRow(_selectedSurah!.number) ? 1 : 0;
    final itemIndex = basmalaCount + ayah - 1;
    setState(() {
      _highlightedAyah = (_selectedSurah!.number, ayah);
      _scrollTargetVerse = (_selectedSurah!.number, ayah);
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _verseItemScrollController.scrollTo(
        index: itemIndex,
        duration: const Duration(milliseconds: 400),
        curve: Curves.easeOut,
        alignment: 0.0,
      );
      if (mounted) setState(() => _scrollTargetVerse = null);
    });
    Future.delayed(const Duration(seconds: 3), () {
      if (mounted && _highlightedAyah == (_selectedSurah?.number, ayah)) {
        setState(() => _highlightedAyah = null);
      }
    });
  }

  Widget _buildSurahNavigationFooter(
      BuildContext context, SurahData surah, String Function(String) t) {
    final currentNum = surah.number;
    final hasPrev = currentNum > 1;
    final hasNext = currentNum < 114;
    if (!hasPrev && !hasNext) return const SizedBox.shrink();

    SurahListItem? prevSurah;
    SurahListItem? nextSurah;
    for (final s in _surahs) {
      if (s.number == currentNum - 1) prevSurah = s;
      if (s.number == currentNum + 1) nextSurah = s;
    }

    return Padding(
      padding: EdgeInsets.only(
        top: scaleSize(context, 16),
        bottom: scaleSize(context, 24),
      ),
      child: Row(
        children: [
          if (hasPrev && prevSurah != null)
            Expanded(
              child: Material(
                color: Colors.white,
                borderRadius: BorderRadius.circular(scaleSize(context, 12)),
                elevation: scaleSize(context, 1).clamp(0.0, 24.0),
                child: InkWell(
                  onTap: () => _onSurahSelect(prevSurah!),
                  borderRadius: BorderRadius.circular(scaleSize(context, 12)),
                  child: Padding(
                    padding: EdgeInsets.all(scaleSize(context, 12)),
                    child: Row(
                      children: [
                        Icon(Icons.chevron_left,
                            size: scaleSize(context, 20),
                            color: const Color(0xFF6366F1)),
                        SizedBox(width: scaleSize(context, 8)),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                t('previousSurah'),
                                style: GoogleFonts.plusJakartaSans(
                                    fontSize: scaleFont(context, 12),
                                    color: const Color(0xFF64748B)),
                              ),
                              Text(
                                prevSurah.name,
                                style: GoogleFonts.plusJakartaSans(
                                    fontSize: scaleFont(context, 14),
                                    fontWeight: FontWeight.w600,
                                    color: const Color(0xFF1E293B)),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          if (hasPrev && hasNext) SizedBox(width: scaleSize(context, 12)),
          if (hasNext && nextSurah != null)
            Expanded(
              child: Material(
                color: Colors.white,
                borderRadius: BorderRadius.circular(scaleSize(context, 12)),
                elevation: scaleSize(context, 1).clamp(0.0, 24.0),
                child: InkWell(
                  onTap: () => _onSurahSelect(nextSurah!),
                  borderRadius: BorderRadius.circular(scaleSize(context, 12)),
                  child: Padding(
                    padding: EdgeInsets.all(scaleSize(context, 12)),
                    child: Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.end,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                t('nextSurah'),
                                style: GoogleFonts.plusJakartaSans(
                                    fontSize: scaleFont(context, 12),
                                    color: const Color(0xFF64748B)),
                              ),
                              Text(
                                nextSurah.name,
                                style: GoogleFonts.plusJakartaSans(
                                    fontSize: scaleFont(context, 14),
                                    fontWeight: FontWeight.w600,
                                    color: const Color(0xFF1E293B)),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ],
                          ),
                        ),
                        SizedBox(width: scaleSize(context, 8)),
                        Icon(Icons.chevron_right,
                            size: scaleSize(context, 20),
                            color: const Color(0xFF6366F1)),
                      ],
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildHeaderMetadata(
      BuildContext context, SurahData surah, String Function(String) t) {
    final locale = context.read<ThemeProvider>().language;
    final revType = surah.revelationType;
    final place =
        revType != null ? getRevelationPlaceName(revType, locale) : null;
    final period = revType != null
        ? getRevelationPeriodDescription(revType, locale)
        : null;
    final date = getSurahRevelationDate(surah.number, locale);
    final event = getSurahRevelationEvent(surah.number, locale);
    final theme = getSurahMainTheme(surah.number, locale);
    final description = getSurahDescription(surah.number, locale);

    final styleLabel = GoogleFonts.plusJakartaSans(
      fontSize: scaleFont(context, 11),
      color: const Color(0xFF64748B),
      fontWeight: FontWeight.w400,
    );
    final styleValue = GoogleFonts.plusJakartaSans(
      fontSize: scaleFont(context, 11),
      color: const Color(0xFF475569),
      fontWeight: FontWeight.w400,
    );
    const borderStyle = BorderSide(color: Color(0xFFE2E8F0), width: 1);

    return Padding(
      padding: EdgeInsets.fromLTRB(
        scaleSize(context, 12),
        0,
        scaleSize(context, 12),
        scaleSize(context, 10),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (place != null || period != null) ...[
            Padding(
              padding: EdgeInsets.only(bottom: scaleSize(context, 6)),
              child: Wrap(
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  Text('${t('revelationPlaceAndPeriod')}: ', style: styleLabel),
                  Text(
                    [place, period].whereType<String>().join(' '),
                    style: styleValue,
                  ),
                ],
              ),
            ),
          ],
          if (date != null && date.isNotEmpty)
            Padding(
              padding: EdgeInsets.only(bottom: scaleSize(context, 6)),
              child: Wrap(
                children: [
                  Text('${t('revelationDate')}: ', style: styleLabel),
                  Text(date, style: styleValue),
                ],
              ),
            ),
          if (event != null && event.isNotEmpty) ...[
            Container(
              padding: EdgeInsets.only(top: scaleSize(context, 6)),
              decoration: const BoxDecoration(
                border: Border(top: borderStyle),
              ),
              child: Padding(
                padding: EdgeInsets.only(bottom: scaleSize(context, 6)),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(t('revelationEvent'), style: styleLabel),
                    SizedBox(height: scaleSize(context, 2)),
                    Text(event, style: styleValue),
                  ],
                ),
              ),
            ),
          ],
          if (theme != null && theme.isNotEmpty) ...[
            Container(
              padding: EdgeInsets.only(top: scaleSize(context, 6)),
              decoration: const BoxDecoration(
                border: Border(top: borderStyle),
              ),
              child: Padding(
                padding: EdgeInsets.only(bottom: scaleSize(context, 6)),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(t('mainTheme'), style: styleLabel),
                    SizedBox(height: scaleSize(context, 2)),
                    Text(theme, style: styleValue),
                  ],
                ),
              ),
            ),
          ],
          if (description != null && description.isNotEmpty)
            Container(
              padding: EdgeInsets.only(top: scaleSize(context, 6)),
              decoration: const BoxDecoration(
                border: Border(top: borderStyle),
              ),
              child: Padding(
                padding: EdgeInsets.only(top: scaleSize(context, 6)),
                child: Text(description, style: styleValue),
              ),
            ),
        ],
      ),
    );
  }

  List<SurahListItem> get _filteredSurahs {
    if (_ayahSearchResults.isNotEmpty) {
      final surahNumbers = _ayahSearchResults.map((a) => a.surah).toSet();
      return _surahs.where((s) => surahNumbers.contains(s.number)).toList()
        ..sort((a, b) => a.number.compareTo(b.number));
    }
    final q = _searchQuery.trim().toLowerCase();
    if (q.isEmpty) return _surahs;
    return _surahs.where((s) {
      if (s.number.toString() == q) return true;
      if ((s.name).toLowerCase().contains(q)) return true;
      if ((s.nameTransliterated ?? '').toLowerCase().contains(q)) return true;
      if ((s.nameArabic ?? '').contains(_searchQuery.trim())) return true;
      return false;
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    context.read<BackHandlerProvider>().setBackHandler(() {
      if (_selectedSurah != null) {
        _onBack();
        return true;
      }
      return false;
    });

    final t = (String k) => AppLocalizations.t(context, k);
    final playback = context.watch<QuranPlaybackService>();
    final currentAyah = playback.currentAyah;

    final mediaSize = MediaQuery.sizeOf(context);
    if (_prevMediaSize != null &&
        (_prevMediaSize!.width != mediaSize.width ||
            _prevMediaSize!.height != mediaSize.height)) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          setState(() {
            _floatingButtonLeft = null;
            _floatingButtonBottom = null;
          });
        }
      });
    }
    _prevMediaSize = mediaSize;

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (bool didPop, dynamic result) {
        if (didPop) return;
        if (_selectedSurah != null) {
          _onBack();
        } else {
          context.read<BottomNavIndexProvider>().goToHome();
        }
      },
      child: Scaffold(
        backgroundColor: const Color(0xFFF8FAFC),
        body: SafeArea(
          top: true,
          child: Stack(
            key: _floatingStackKey,
            fit: StackFit.expand,
            children: [
              Column(
                children: [
                  QuranTopBar(
                    surahInfoText: _selectedSurah != null
                        ? '${_selectedSurah!.name}${_selectedSurah!.nameTransliterated != null ? ' (${_selectedSurah!.nameTransliterated})' : ''} • ${_selectedSurah!.numberOfAyahs} ${t('verses')}'
                        : t('quran'),
                    showSearchBar: _selectedSurah == null,
                    searchQuery: _searchQuery,
                    searchController: _searchController,
                    onSearchQueryChange: (v) {
                      setState(() => _searchQuery = v);
                      _scheduleAyahSearch();
                    },
                    searchExpanded: _searchExpanded,
                    onSearchExpandedToggle: () => setState(() {
                      _searchExpanded = !_searchExpanded;
                      if (!_searchExpanded) {
                        _searchQuery = '';
                        _searchController.clear();
                      }
                    }),
                    onBookmarkPress: _handleBookmarkPress,
                    hasBookmark: _bookmark != null,
                    onOpenDownload: () =>
                        _showReciterAudioDownloadSheet(context, t),
                  ),
                  if (_downloadProgress != null)
                    _buildDownloadBanner(context, t),
                  Expanded(
                    child: _selectedSurah == null
                        ? _buildSurahList(context, t)
                        : _buildSurahContent(context, t, playback),
                  ),
                  QuranSoundPlayer(
                    visible: _soundPlayerVisible,
                    currentAyah: currentAyah != null
                        ? (surah: currentAyah.surah, ayah: currentAyah.ayah)
                        : null,
                    isPlaying: playback.isPlaying,
                    isPaused: playback.isPaused,
                    playbackSpeed: playback.playbackSpeed,
                    selectedReciterKey: playback.selectedReciterKey,
                    repeatMode: playback.repeatMode,
                    onPlayFirstAyah: () {
                      if (_selectedSurah != null) {
                        _playAyahIfDownloadedOrShowSheet(
                            context, t, _selectedSurah!.number, 1);
                      }
                    },
                    onPlayPause: () async {
                      if (playback.isPaused) {
                        await playback.resume();
                      } else {
                        await playback.pause();
                      }
                    },
                    onStop: () => playback.stop(),
                    onPrevious: () => playback.previousAyah(),
                    onNext: () => playback.nextAyah(),
                    onSpeedChange: (speed) => playback.setSpeed(speed),
                    onReciterChange: (key) async {
                      if (_downloadProgress != null) {
                        setState(() => _cancelDownloadRequested = true);
                      }
                      await playback.setReciter(key);
                      if (!mounted) return;
                      final saved = playback.currentAyah;
                      if (saved != null) {
                        final downloaded = await isAyahAudioDownloaded(
                            key, saved.surah, saved.ayah);
                        if (!mounted) return;
                        if (downloaded) {
                          playback.playAyah(saved.surah, saved.ayah);
                        } else {
                          await _showReciterAudioDownloadSheet(context, t,
                              startPlaybackFromSurah: saved.surah,
                              startPlaybackFromAyah: saved.ayah);
                        }
                      } else {
                        await _showReciterAudioDownloadSheet(context, t);
                      }
                    },
                    onRepeatModeChange: (mode) => playback.setRepeatMode(mode),
                    preloadProgress: playback.preloadProgress,
                  ),
                ],
              ),
              // RN: Floating play button – sağ altta, çok altta; sürüklenebilir.
              if (!_soundPlayerVisible &&
                  (playback.isPlaying || playback.isPaused) &&
                  currentAyah != null)
                Positioned(
                  left: _floatingButtonLeft,
                  right: _floatingButtonLeft == null
                      ? scaleSize(context, 20)
                      : null,
                  bottom: _floatingButtonBottom ??
                      (MediaQuery.paddingOf(context).bottom +
                          scaleSize(context, 12)),
                  child: GestureDetector(
                    onPanUpdate: (DragUpdateDetails details) {
                      final box = _floatingStackKey.currentContext
                          ?.findRenderObject() as RenderBox?;
                      if (box == null || !box.hasSize) return;
                      final local = box.globalToLocal(details.globalPosition);
                      const btnWidth = 88.0;
                      const btnHeight = 36.0;
                      double left = local.dx - btnWidth / 2;
                      double bottom = box.size.height - local.dy - btnHeight / 2;
                      left = left.clamp(0.0, box.size.width - btnWidth);
                      bottom = bottom.clamp(0.0, box.size.height - btnHeight);
                      setState(() {
                        _floatingButtonLeft = left;
                        _floatingButtonBottom = bottom;
                      });
                    },
                    child: Material(
                      elevation: 4,
                      shadowColor: Colors.black26,
                      borderRadius:
                          BorderRadius.circular(scaleSize(context, 18)),
                      color: const Color(0xFF6366F1),
                      child: InkWell(
                        onTap: () =>
                            setState(() => _soundPlayerVisible = true),
                        borderRadius:
                            BorderRadius.circular(scaleSize(context, 18)),
                        child: Padding(
                          padding: EdgeInsets.symmetric(
                            horizontal: scaleSize(context, 10),
                            vertical: scaleSize(context, 6),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                playback.isPlaying && !playback.isPaused
                                    ? Icons.pause_circle
                                    : Icons.play_circle,
                                size: scaleSize(context, 24),
                                color: Colors.white,
                              ),
                              SizedBox(width: scaleSize(context, 6)),
                              Text(
                                '${currentAyah.surah}:${currentAyah.ayah}',
                                style: GoogleFonts.plusJakartaSans(
                                  fontSize: scaleFont(context, 12),
                                  color: Colors.white,
                                  fontWeight: FontWeight.w600,
                                ),
                                overflow: TextOverflow.ellipsis,
                                maxLines: 1,
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSurahList(BuildContext context, String Function(String) t) {
    if (_surahListLoading && _surahs.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const CircularProgressIndicator(color: Color(0xFF6366F1)),
            SizedBox(height: scaleSize(context, 12)),
            Text(t('loading'),
                style: GoogleFonts.plusJakartaSans(
                    fontSize: scaleFont(context, 16),
                    color: const Color(0xFF64748B))),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: () => _loadSurahs(forceRefresh: true),
      child: CustomScrollView(
        slivers: [
          if (_surahAyahJump != null)
            SliverToBoxAdapter(
              child: Padding(
                padding: EdgeInsets.fromLTRB(
                    scaleSize(context, 20),
                    scaleSize(context, 8),
                    scaleSize(context, 20),
                    scaleSize(context, 8)),
                child: Material(
                  color: const Color(0xFFEEF2FF),
                  borderRadius: BorderRadius.circular(scaleSize(context, 12)),
                  child: InkWell(
                    onTap: () {
                      _scrollToAyahAfterLoad = _surahAyahJump!.ayahNumber;
                      _onSurahSelect(_surahAyahJump!.surah);
                    },
                    borderRadius: BorderRadius.circular(scaleSize(context, 12)),
                    child: Padding(
                      padding: EdgeInsets.symmetric(
                          horizontal: scaleSize(context, 14),
                          vertical: scaleSize(context, 12)),
                      child: Row(
                        children: [
                          Icon(Icons.menu_book,
                              size: scaleSize(context, 20),
                              color: const Color(0xFF6366F1)),
                          SizedBox(width: scaleSize(context, 10)),
                          Expanded(
                            child: Text(
                              '${t('goToAyah')} ${_surahAyahJump!.surah.name} ${_surahAyahJump!.surah.number}:${_surahAyahJump!.ayahNumber}',
                              style: GoogleFonts.plusJakartaSans(
                                  fontSize: scaleFont(context, 14),
                                  fontWeight: FontWeight.w600,
                                  color: const Color(0xFF1E293B)),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          Icon(Icons.chevron_right,
                              size: scaleSize(context, 20),
                              color: const Color(0xFF94A3B8)),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          if (_ayahSearchLoading)
            SliverToBoxAdapter(
              child: Padding(
                padding: EdgeInsets.symmetric(vertical: scaleSize(context, 12)),
                child: Center(
                    child: SizedBox(
                        width: scaleSize(context, 24),
                        height: scaleSize(context, 24),
                        child: CircularProgressIndicator(
                            strokeWidth: scaleSize(context, 2),
                            color: const Color(0xFF6366F1)))),
              ),
            ),
          SliverPadding(
            padding: EdgeInsets.fromLTRB(
              scaleSize(context, 20),
              scaleSize(context, 10),
              scaleSize(context, 20),
              scaleSize(context, 20) +
                  MediaQuery.paddingOf(context).bottom +
                  scaleSize(context, 80),
            ),
            sliver: SliverList(
              delegate: SliverChildBuilderDelegate(
                (_, i) {
                  final surah = _filteredSurahs[i];
                  final totalAyahs = surah.numberOfAyahs > 0
                      ? surah.numberOfAyahs
                      : (_surahVerseCount[surah.number] ?? 0);
                  final readCount = _readAyahs.entries.where((e) {
                    if (!e.value || !e.key.startsWith('${surah.number}:'))
                      return false;
                    final p = e.key.split(':');
                    return p.length == 2 && int.tryParse(p[1]) != null;
                  }).length;
                  final hasSurahNote = _hasSurahNote(surah.number);

                  final isAllRead = totalAyahs > 0 && readCount == totalAyahs;
                  final surahAyahResults = _ayahSearchResults
                      .where((a) => a.surah == surah.number)
                      .toList();
                  return Padding(
                    padding: EdgeInsets.only(bottom: scaleSize(context, 12)),
                    child: Material(
                      color: Colors.white,
                      borderRadius:
                          BorderRadius.circular(scaleSize(context, 16)),
                      elevation: scaleSize(context, 2).clamp(0.0, 24.0),
                      shadowColor: Colors.black.withValues(alpha: 0.05),
                      child: InkWell(
                        onTap: () => _onSurahSelect(surah),
                        onLongPress: () => _showResetReadStatusDialog(
                            context, surah, totalAyahs, readCount, t),
                        borderRadius:
                            BorderRadius.circular(scaleSize(context, 16)),
                        child: Padding(
                          padding: EdgeInsets.all(scaleSize(context, 16)),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Row(
                                children: [
                                  Container(
                                    width: scaleSize(context, 38),
                                    height: scaleSize(context, 38),
                                    decoration: BoxDecoration(
                                      color: const Color(0xFFEEF2FF),
                                      shape: BoxShape.circle,
                                      border: Border.all(
                                          color: const Color(0xFF6366F1),
                                          width: scaleSize(context, 2)),
                                    ),
                                    alignment: Alignment.center,
                                    child: Text(
                                      '${surah.number}',
                                      style: GoogleFonts.plusJakartaSans(
                                        fontSize: scaleFont(context, 14),
                                        fontWeight: FontWeight.bold,
                                        color: const Color(0xFF6366F1),
                                      ),
                                    ),
                                  ),
                                  SizedBox(width: scaleSize(context, 12)),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          '${surah.name}${surah.nameTransliterated != null ? ' (${surah.nameTransliterated})' : ''}',
                                          style: GoogleFonts.plusJakartaSans(
                                            fontSize: scaleFont(context, 14),
                                            fontWeight: FontWeight.w700,
                                            color: const Color(0xFF1E293B),
                                          ),
                                          maxLines: 2,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                        SizedBox(height: scaleSize(context, 4)),
                                        Text(
                                          '$readCount / $totalAyahs ${t('verses')}',
                                          style: GoogleFonts.plusJakartaSans(
                                            fontSize: scaleFont(context, 12),
                                            color: const Color(0xFF64748B),
                                            fontWeight: FontWeight.w500,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  if (isAllRead)
                                    Padding(
                                      padding: EdgeInsets.only(
                                          right: scaleSize(context, 4)),
                                      child: Icon(Icons.check_circle,
                                          size: scaleSize(context, 20),
                                          color: const Color(0xFFF59E0B)),
                                    ),
                                  InkWell(
                                    onTap: () {
                                      _openSurahNoteModal(context, surah, t);
                                    },
                                    borderRadius: BorderRadius.circular(
                                        scaleSize(context, 8)),
                                    child: Padding(
                                      padding:
                                          EdgeInsets.all(scaleSize(context, 6)),
                                      child: Icon(
                                        hasSurahNote
                                            ? Icons.note
                                            : Icons.note_add_outlined,
                                        size: scaleSize(context, 20),
                                        color: hasSurahNote
                                            ? const Color(0xFF10B981)
                                            : const Color(0xFF64748B),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              if (surahAyahResults.isNotEmpty &&
                                  _searchQuery.trim().length >= 2) ...[
                                SizedBox(height: scaleSize(context, 10)),
                                ...surahAyahResults.take(3).map((ayah) =>
                                    Padding(
                                      padding: EdgeInsets.only(
                                          bottom: scaleSize(context, 6)),
                                      child: InkWell(
                                        onTap: () {
                                          _scrollToAyahAfterLoad = ayah.ayah;
                                          _onSurahSelect(surah);
                                        },
                                        borderRadius: BorderRadius.circular(
                                            scaleSize(context, 8)),
                                        child: Padding(
                                          padding: EdgeInsets.symmetric(
                                              vertical: scaleSize(context, 4),
                                              horizontal:
                                                  scaleSize(context, 4)),
                                          child: Row(
                                            crossAxisAlignment:
                                                CrossAxisAlignment.start,
                                            children: [
                                              Text('${ayah.ayah}.',
                                                  style: GoogleFonts.plusJakartaSans(
                                                      fontSize: scaleFont(
                                                          context, 12),
                                                      fontWeight:
                                                          FontWeight.w600,
                                                      color: const Color(
                                                          0xFF6366F1))),
                                              SizedBox(
                                                  width: scaleSize(context, 6)),
                                              Expanded(
                                                child: Text(
                                                  ayah.translation.isNotEmpty
                                                      ? ayah.translation
                                                      : ayah.text,
                                                  style: GoogleFonts.plusJakartaSans(
                                                      fontSize: scaleFont(
                                                          context, 12),
                                                      color: const Color(
                                                          0xFF475569)),
                                                  maxLines: 2,
                                                  overflow:
                                                      TextOverflow.ellipsis,
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                      ),
                                    )),
                                if (surahAyahResults.length > 3)
                                  Padding(
                                    padding: EdgeInsets.only(
                                        top: scaleSize(context, 2)),
                                    child: Text(
                                        '+ ${surahAyahResults.length - 3} ${t('moreAyahs')}',
                                        style: GoogleFonts.plusJakartaSans(
                                            fontSize: scaleFont(context, 11),
                                            color: const Color(0xFF94A3B8))),
                                  ),
                              ],
                            ],
                          ),
                        ),
                      ),
                    ),
                  );
                },
                childCount: _filteredSurahs.length,
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// RN: handleResetSurahReadStatus – sure kartında long press ile okundu işaretlerini sıfırla
  void _showResetReadStatusDialog(BuildContext context, SurahListItem surah,
      int totalAyahs, int readCount, String Function(String) t) {
    if (readCount == 0) return;
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(t('resetReadStatus')),
        content: Text(
          t('resetReadStatusConfirm')
              .replaceAll('{surah}', surah.nameTransliterated ?? surah.name)
              .replaceAll('{count}', '$readCount'),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx), child: Text(t('cancel'))),
          TextButton(
            onPressed: () {
              Navigator.pop(ctx);
              final updated = Map<String, bool>.from(_readAyahs);
              for (int ayah = 1; ayah <= totalAyahs; ayah++) {
                updated.remove(_noteKey(surah.number, ayah));
              }
              setState(() => _readAyahs = updated);
              _saveReadAyahs();
            },
            child: Text(t('reset'),
                style: GoogleFonts.plusJakartaSans(color: const Color(0xFFEF4444))),
          ),
        ],
      ),
    );
  }

  Widget _buildSurahContent(BuildContext context, String Function(String) t,
      QuranPlaybackService playback) {
    final surah = _selectedSurah!;
    if (_loading) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const CircularProgressIndicator(color: Color(0xFF6366F1)),
            SizedBox(height: scaleSize(context, 12)),
            Text(t('loading'),
                style: GoogleFonts.plusJakartaSans(
                    fontSize: scaleFont(context, 16),
                    color: const Color(0xFF64748B))),
          ],
        ),
      );
    }

    // RN: Pressable contentContainer onPress={toggleSoundPlayer} – tap to hide/show bottom player
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () => setState(() => _soundPlayerVisible = !_soundPlayerVisible),
      child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Collapsible header – RN: surahHeader + revelation/date/event/theme/description
        Padding(
          padding: EdgeInsets.symmetric(horizontal: scaleSize(context, 20)),
          child: Material(
            color: const Color(0xFFF1F5F9),
            borderRadius: BorderRadius.circular(scaleSize(context, 12)),
            clipBehavior: Clip.antiAlias,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                InkWell(
                  onTap: () =>
                      setState(() => _headerExpanded = !_headerExpanded),
                  child: Padding(
                    padding: EdgeInsets.symmetric(
                        horizontal: scaleSize(context, 12),
                        vertical: scaleSize(context, 6)),
                    child: Row(
                      children: [
                        Text(
                          t('surahDescription'),
                          style: GoogleFonts.plusJakartaSans(
                              fontSize: scaleFont(context, 13),
                              color: const Color(0xFF64748B),
                              fontWeight: FontWeight.w500),
                        ),
                        const Spacer(),
                        Icon(
                          _headerExpanded
                              ? Icons.expand_less
                              : Icons.expand_more,
                          color: const Color(0xFF64748B),
                          size: scaleSize(context, 22),
                        ),
                      ],
                    ),
                  ),
                ),
                AnimatedCrossFade(
                  firstChild: const SizedBox.shrink(),
                  secondChild: _buildHeaderMetadata(context, surah, t),
                  crossFadeState: _headerExpanded
                      ? CrossFadeState.showSecond
                      : CrossFadeState.showFirst,
                  duration: const Duration(milliseconds: 200),
                ),
              ],
            ),
          ),
        ),
        SizedBox(height: scaleSize(context, 8)),
        // Verses list – ScrollablePositionedList ile indekse tam scroll
        Expanded(
          child: ScrollablePositionedList.builder(
            itemScrollController: _verseItemScrollController,
            padding: EdgeInsets.fromLTRB(
              scaleSize(context, 20),
              0,
              scaleSize(context, 20),
              scaleSize(context, 20) +
                  MediaQuery.paddingOf(context).bottom +
                  scaleSize(context, 100),
            ),
            itemCount: (_showBismillahRow(surah.number) ? 1 : 0) +
                surah.verses.length +
                1,
            itemBuilder: (_, index) {
              final basmalaCount = _showBismillahRow(surah.number) ? 1 : 0;
              if (index == basmalaCount + surah.verses.length) {
                return _buildSurahNavigationFooter(context, surah, t);
              }
              if (basmalaCount > 0 && index == 0) {
                final isBismillahPlaying = playback.currentAyah != null &&
                    playback.currentAyah!.surah == surah.number &&
                    playback.currentAyah!.ayah == 0;
                final isScrollTarget = _scrollTargetVerse == (surah.number, 0);
                Widget bismillahContent = Container(
                  width: double.infinity,
                  padding: EdgeInsets.symmetric(
                      vertical: scaleSize(context, 8),
                      horizontal: scaleSize(context, 20)),
                  decoration: BoxDecoration(
                    color: isBismillahPlaying
                        ? const Color(0xFF15803D).withValues(alpha: 0.22)
                        : const Color(0xFFF8FAFC),
                    borderRadius: BorderRadius.circular(scaleSize(context, 16)),
                    border: Border.all(
                        color: isBismillahPlaying
                            ? const Color(0xFF15803D).withValues(alpha: 0.5)
                            : const Color(0xFFE2E8F0)),
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFF6366F1).withValues(alpha: 0.06),
                        offset: Offset(0, scaleSize(context, 1)),
                        blurRadius: scaleSize(context, 6),
                      ),
                    ],
                  ),
                  child: Text(
                    surah.basmalaText ?? _bismillahArabic,
                    style: TextStyle(
                      fontFamily: 'KuranKerimFontLatif',
                      fontSize: scaleFont(context, 28),
                      height: 1.7,
                      color: const Color(0xFF0F172A),
                      fontWeight: FontWeight.w400,
                    ),
                    textAlign: TextAlign.center,
                  ),
                );
                return GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: () =>
                      setState(() => _soundPlayerVisible = !_soundPlayerVisible),
                  child: Padding(
                    padding: EdgeInsets.only(bottom: scaleSize(context, 12)),
                    child: isScrollTarget
                        ? KeyedSubtree(
                            key: _bismillahScrollTargetKey,
                            child: bismillahContent)
                        : bismillahContent,
                  ),
                );
              }
              final verseIndex = basmalaCount > 0 ? index - 1 : index;
              final verse = surah.verses[verseIndex];
              final isBookmarked =
                  _isBookmarked(surah.number, verse.numberInSurah);
              final hasNote = _hasNote(surah.number, verse.numberInSurah);
              final isRead = _isRead(surah.number, verse.numberInSurah);
              final isScrollTarget =
                  _scrollTargetVerse == (surah.number, verse.numberInSurah);

              final card = Padding(
                padding: EdgeInsets.only(bottom: scaleSize(context, 12)),
                child: _VerseCard(
                  verse: verse,
                  surahNumber: surah.number,
                  verseTextMode: _verseTextMode,
                  verseDisplayText: _verseDisplayText(surah.number, verse),
                  transliterationText: _transliterationMap?[surah.number]
                      ?[verse.numberInSurah],
                  isBookmarked: isBookmarked,
                  hasNote: hasNote,
                  isRead: isRead,
                  onVerseTextMode: (mode) =>
                      setState(() => _verseTextMode = mode),
                  onPronunciationGuide: () =>
                      _showPronunciationGuide(context, t),
                  onTap: () =>
                      setState(() => _soundPlayerVisible = !_soundPlayerVisible),
                  onLongPress: () =>
                      _showVerseLongPress(context, surah, verse, t),
                  onPlayPause: () {
                    final current = playback.currentAyah;
                    final isThisVerse = current != null &&
                        current.surah == surah.number &&
                        current.ayah == verse.numberInSurah;
                    if (isThisVerse) {
                      if (playback.isPaused) {
                        playback.resume();
                      } else {
                        playback.pause();
                      }
                    } else {
                      _playAyahIfDownloadedOrShowSheet(
                          context, t, surah.number, verse.numberInSurah);
                    }
                  },
                  isCurrentAyah: playback.currentAyah != null &&
                      playback.currentAyah!.surah == surah.number &&
                      playback.currentAyah!.ayah == verse.numberInSurah,
                  isPlaying: playback.isPlaying && !playback.isPaused,
                  isCached:
                      playback.isCached(surah.number, verse.numberInSurah),
                  isHighlighted:
                      _highlightedAyah == (surah.number, verse.numberInSurah),
                  onNote: () => _openNoteModal(
                      context, surah.number, verse.numberInSurah, t),
                  onToggleRead: () {
                    final k = _noteKey(surah.number, verse.numberInSurah);
                    setState(() {
                      _readAyahs[k] = !(_readAyahs[k] ?? false);
                      _saveReadAyahs();
                    });
                  },
                  onShare: () => _shareAyah(surah.number, verse, t),
                  pageLabel: t('page'),
                ),
              );
              return GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: () =>
                    setState(() => _soundPlayerVisible = !_soundPlayerVisible),
                child: isScrollTarget
                    ? KeyedSubtree(key: _verseScrollTargetKey, child: card)
                    : card,
              );
            },
          ),
        ),
      ],
    ),
    );
  }

  /// RN: QuranIndexModal – cüz listesi; seçilince Pure Quran’a o cüzün ilk sayfasıyla geç
  /// RN: transliterationGuide from utils/locales/<locale>.json – full structure (title, description, items, notes)
  Future<void> _showPronunciationGuide(
      BuildContext context, String Function(String) t) async {
    final locale = context.read<ThemeProvider>().language;
    final lang = _pronunciationGuideLangFromLocale(locale);
    Map<String, dynamic>? data;
    try {
      final raw = await rootBundle.loadString(
        'assets/data/pronunciation_guide_$lang.json',
      );
      data = jsonDecode(raw) as Map<String, dynamic>?;
    } catch (_) {
      data = null;
    }

    if (!context.mounted) return;
    final title = data?['title'] as String? ?? t('pronunciationGuide');
    final description =
        data?['description'] as String? ?? t('pronunciationGuideText');
    final items = data?['items'] as List<dynamic>? ?? const [];
    final notesMap = data?['notes'] as Map<String, dynamic>?;
    final notesTitle = notesMap?['title'] as String?;
    final notesItems = notesMap?['items'] as List<dynamic>? ?? const [];

    showDialog<void>(
      context: context,
      barrierDismissible: true,
      builder: (ctx) => Center(
        child: Material(
          color: Colors.transparent,
          child: Container(
            margin: EdgeInsets.symmetric(horizontal: scaleSize(context, 24)),
            constraints: BoxConstraints(
              maxWidth: scaleSize(context, 420),
              maxHeight: MediaQuery.of(context).size.height * 0.7,
            ),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(scaleSize(context, 16)),
              boxShadow: [
                BoxShadow(
                    color: Colors.black26,
                    blurRadius: scaleSize(context, 16),
                    spreadRadius: 0),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Padding(
                  padding: EdgeInsets.fromLTRB(
                      scaleSize(context, 20),
                      scaleSize(context, 16),
                      scaleSize(context, 8),
                      scaleSize(context, 8)),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Text(
                          title,
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: scaleFont(context, 18),
                            fontWeight: FontWeight.bold,
                            color: const Color(0xFF1E293B),
                          ),
                        ),
                      ),
                      IconButton(
                        onPressed: () => Navigator.pop(ctx),
                        icon: const Icon(Icons.close, color: Color(0xFF64748B)),
                      ),
                    ],
                  ),
                ),
                Flexible(
                  child: SingleChildScrollView(
                    padding: EdgeInsets.fromLTRB(
                      scaleSize(context, 20),
                      0,
                      scaleSize(context, 20),
                      scaleSize(context, 20),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          description,
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: scaleFont(context, 15),
                            color: const Color(0xFF475569),
                            height: 1.6,
                          ),
                        ),
                        SizedBox(height: scaleSize(context, 16)),
                        ...items.map<Widget>((e) {
                          final item = e as Map<String, dynamic>;
                          final itemTitle = item['title'] as String? ?? '';
                          final symbol = item['symbol'] as String? ?? '';
                          final itemDesc = item['description'] as String? ?? '';
                          final exampleLabel =
                              item['exampleLabel'] as String? ?? '';
                          final examples =
                              item['examples'] as List<dynamic>? ?? [];
                          return Padding(
                            padding:
                                EdgeInsets.only(bottom: scaleSize(context, 16)),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  itemTitle,
                                  style: GoogleFonts.plusJakartaSans(
                                    fontSize: scaleFont(context, 16),
                                    fontWeight: FontWeight.w600,
                                    color: const Color(0xFF1E293B),
                                  ),
                                ),
                                if (symbol.isNotEmpty) ...[
                                  SizedBox(height: scaleSize(context, 4)),
                                  Text(
                                    symbol,
                                    style: TextStyle(
                                      fontSize: scaleFont(context, 14),
                                      color: const Color(0xFF6366F1),
                                      fontFamily: 'monospace',
                                    ),
                                  ),
                                ],
                                if (itemDesc.isNotEmpty) ...[
                                  SizedBox(height: scaleSize(context, 4)),
                                  Text(
                                    itemDesc,
                                    style: GoogleFonts.plusJakartaSans(
                                      fontSize: scaleFont(context, 14),
                                      color: const Color(0xFF475569),
                                      height: 1.5,
                                    ),
                                  ),
                                ],
                                if (exampleLabel.isNotEmpty &&
                                    examples.isNotEmpty) ...[
                                  SizedBox(height: scaleSize(context, 6)),
                                  Text(
                                    exampleLabel,
                                    style: GoogleFonts.plusJakartaSans(
                                      fontSize: scaleFont(context, 13),
                                      fontWeight: FontWeight.w500,
                                      color: const Color(0xFF64748B),
                                    ),
                                  ),
                                  ...examples.map<Widget>((ex) => Padding(
                                        padding: EdgeInsets.only(
                                            left: scaleSize(context, 12),
                                            top: scaleSize(context, 2)),
                                        child: Text(
                                          ex as String,
                                          style: GoogleFonts.plusJakartaSans(
                                            fontSize: scaleFont(context, 13),
                                            color: const Color(0xFF475569),
                                            height: 1.4,
                                          ),
                                        ),
                                      )),
                                ],
                              ],
                            ),
                          );
                        }),
                        if (notesTitle != null &&
                            notesTitle.isNotEmpty &&
                            notesItems.isNotEmpty) ...[
                          SizedBox(height: scaleSize(context, 12)),
                          Text(
                            notesTitle,
                            style: GoogleFonts.plusJakartaSans(
                              fontSize: scaleFont(context, 16),
                              fontWeight: FontWeight.w600,
                              color: const Color(0xFF1E293B),
                            ),
                          ),
                          SizedBox(height: scaleSize(context, 8)),
                          ...notesItems.map<Widget>((n) => Padding(
                                padding: EdgeInsets.only(
                                    bottom: scaleSize(context, 6)),
                                child: Row(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Padding(
                                      padding: EdgeInsets.only(
                                          top: scaleSize(context, 6),
                                          right: scaleSize(context, 8)),
                                      child: Container(
                                        width: scaleSize(context, 5),
                                        height: scaleSize(context, 5),
                                        decoration: const BoxDecoration(
                                          color: Color(0xFF6366F1),
                                          shape: BoxShape.circle,
                                        ),
                                      ),
                                    ),
                                    Expanded(
                                      child: Text(
                                        n as String,
                                        style: GoogleFonts.plusJakartaSans(
                                          fontSize: scaleFont(context, 13),
                                          color: const Color(0xFF475569),
                                          height: 1.5,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              )),
                        ],
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _shareAyah(
      int surahNumber, VerseItem verse, String Function(String) t) async {
    final text = verse.text;
    final translation = verse.translation ?? '';
    await Share.share(
      translation.isEmpty ? text : '$text\n\n$translation',
      subject: '$surahNumber:${verse.numberInSurah}',
    );
  }

  void _showVerseLongPress(BuildContext context, SurahData surah,
      VerseItem verse, String Function(String) t) {
    final isBookmarked = _isBookmarked(surah.number, verse.numberInSurah);
    showModalBottomSheet<void>(
      context: context,
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: EdgeInsets.all(scaleSize(context, 20)),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (isBookmarked)
                ListTile(
                  leading: const Icon(Icons.bookmark_remove,
                      color: Color(0xFFEF4444)),
                  title: Text(t('removeBookmark')),
                  onTap: () {
                    _removeBookmark();
                    Navigator.pop(ctx);
                    ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text(t('bookmarkRemoved'))));
                  },
                )
              else
                ListTile(
                  leading:
                      const Icon(Icons.bookmark_add, color: Color(0xFF6366F1)),
                  title: Text(t('saveBookmark')),
                  onTap: () {
                    _saveBookmark(surah.number, verse.numberInSurah);
                    Navigator.pop(ctx);
                    ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text(t('bookmarkSaved'))));
                  },
                ),
              ListTile(
                leading: const Icon(Icons.note_add_outlined,
                    color: Color(0xFF6366F1)),
                title: Text(t('addNote')),
                onTap: () {
                  Navigator.pop(ctx);
                  _openNoteModal(context, surah.number, verse.numberInSurah, t);
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _openNoteModal(
      BuildContext context, int surah, int ayah, String Function(String) t) {
    final key = _noteKey(surah, ayah);
    final controller = TextEditingController(text: _notes[key] ?? '');
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (ctx) => Padding(
        padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(ctx).bottom),
        child: SafeArea(
          child: Padding(
            padding: EdgeInsets.all(scaleSize(context, 20)),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(t('addNote'),
                    style: GoogleFonts.plusJakartaSans(
                        fontSize: scaleFont(context, 18),
                        fontWeight: FontWeight.bold)),
                SizedBox(height: scaleSize(context, 12)),
                TextField(
                  controller: controller,
                  maxLines: 4,
                  decoration: InputDecoration(
                    hintText: t('note'),
                    border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(scaleSize(context, 12))),
                  ),
                ),
                SizedBox(height: scaleSize(context, 16)),
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    TextButton(
                        onPressed: () => Navigator.pop(ctx),
                        child: Text(t('cancel'))),
                    SizedBox(width: scaleSize(context, 8)),
                    FilledButton(
                      onPressed: () {
                        setState(() {
                          final text = controller.text.trim();
                          if (text.isNotEmpty)
                            _notes[key] = text;
                          else
                            _notes.remove(key);
                          _saveNotes();
                        });
                        Navigator.pop(ctx);
                      },
                      child: Text(t('save')),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// RN: handleAddSurahNote – sure listesindeki not butonu; sure seviyesi not açar.
  void _openSurahNoteModal(
      BuildContext context, SurahListItem surah, String Function(String) t) {
    final key = _surahNoteKey(surah.number);
    final controller = TextEditingController(text: _notes[key] ?? '');
    final surahName =
        '${surah.name}${surah.nameTransliterated != null ? ' (${surah.nameTransliterated})' : ''}';
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (ctx) => Padding(
        padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(ctx).bottom),
        child: SafeArea(
          child: Padding(
            padding: EdgeInsets.all(scaleSize(context, 20)),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  (t('noteForSurah').replaceAll('{surah}', surahName)),
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: scaleFont(context, 18),
                    fontWeight: FontWeight.bold,
                    color: const Color(0xFF1E293B),
                  ),
                ),
                SizedBox(height: scaleSize(context, 12)),
                TextField(
                  controller: controller,
                  maxLines: 4,
                  decoration: InputDecoration(
                    hintText: t('enterNote'),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(scaleSize(context, 12)),
                    ),
                  ),
                ),
                SizedBox(height: scaleSize(context, 16)),
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    if (controller.text.trim().isNotEmpty)
                      TextButton.icon(
                        onPressed: () {
                          setState(() {
                            _notes.remove(key);
                            _saveNotes();
                          });
                          Navigator.pop(ctx);
                        },
                        icon: Icon(Icons.delete_outline,
                            size: scaleSize(context, 18),
                            color: const Color(0xFFEF4444)),
                        label: Text(t('delete'),
                            style: GoogleFonts.plusJakartaSans(color: const Color(0xFFEF4444))),
                      ),
                    if (controller.text.trim().isNotEmpty)
                      SizedBox(width: scaleSize(context, 8)),
                    TextButton(
                        onPressed: () => Navigator.pop(ctx),
                        child: Text(t('cancel'))),
                    SizedBox(width: scaleSize(context, 8)),
                    FilledButton(
                      onPressed: () {
                        setState(() {
                          final text = controller.text.trim();
                          if (text.isNotEmpty)
                            _notes[key] = text;
                          else
                            _notes.remove(key);
                          _saveNotes();
                        });
                        Navigator.pop(ctx);
                      },
                      child: Text(t('save')),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildDownloadBanner(BuildContext context, String Function(String) t) {
    final p = _downloadProgress!;
    final progress = p.total > 0 ? (p.current / p.total).clamp(0.0, 1.0) : 0.0;
    return Material(
      elevation: scaleSize(context, 1).clamp(0.0, 24.0),
      color: const Color(0xFFEEF2FF),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: EdgeInsets.symmetric(
            horizontal: scaleSize(context, 12),
            vertical: scaleSize(context, 4),
          ),
          child: Row(
            children: [
              Expanded(
                child: LayoutBuilder(
                  builder: (_, constraints) {
                    final w = constraints.maxWidth;
                    return Stack(
                      children: [
                        Container(
                          height: scaleSize(context, 6),
                          decoration: BoxDecoration(
                            color:
                                const Color(0xFFC7D2FE).withValues(alpha: 0.5),
                            borderRadius:
                                BorderRadius.circular(scaleSize(context, 3)),
                          ),
                        ),
                        ClipRRect(
                          borderRadius:
                              BorderRadius.circular(scaleSize(context, 3)),
                          child: SizedBox(
                            width: w * progress,
                            height: scaleSize(context, 6),
                            child: Container(
                              decoration: const BoxDecoration(
                                color: Color(0xFF6366F1),
                              ),
                            ),
                          ),
                        ),
                      ],
                    );
                  },
                ),
              ),
              SizedBox(width: scaleSize(context, 10)),
              Text(
                t('downloading'),
                style: GoogleFonts.plusJakartaSans(
                  fontSize: scaleFont(context, 12),
                  fontWeight: FontWeight.w600,
                  color: const Color(0xFF1E293B),
                ),
              ),
              SizedBox(width: scaleSize(context, 6)),
              Text(
                '${p.current} / ${p.total}',
                style: GoogleFonts.plusJakartaSans(
                  fontSize: scaleFont(context, 11),
                  color: const Color(0xFF64748B),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// Play’e basıldığında: ayet seçili okuyucu için indirilmemişse indirme seçenekleri modalını aç; indirilmişse oynat.
  Future<void> _playAyahIfDownloadedOrShowSheet(BuildContext context,
      String Function(String) t, int surah, int ayah) async {
    final playback = context.read<QuranPlaybackService>();
    final downloaded =
        await isAyahAudioDownloaded(playback.selectedReciterKey, surah, ayah);
    if (!mounted) return;
    if (downloaded) {
      playback.playAyah(surah, ayah);
    } else {
      await _showReciterAudioDownloadSheet(context, t,
          startPlaybackFromSurah: surah, startPlaybackFromAyah: ayah);
    }
  }

  /// [startPlaybackFromSurah] / [startPlaybackFromAyah]: Seçim yapıldığında indirme başlarken bu ayetten oynatmayı da başlat.
  Future<void> _showReciterAudioDownloadSheet(
      BuildContext context, String Function(String) t,
      {int? startPlaybackFromSurah, int? startPlaybackFromAyah}) async {
    final prefs = await SharedPreferences.getInstance();
    if (!context.mounted) return;
    await showDialog<void>(
      context: context,
      barrierDismissible: true,
      builder: (ctx) => Center(
        child: Material(
          color: Colors.transparent,
          child: Consumer<QuranPlaybackService>(
            builder: (_, playback, __) {
              final reciterKey = playback.selectedReciterKey;
              final currentSurahDownloaded = _selectedSurah != null &&
                  (prefs.getBool(_prefKeyDlSurah(
                          reciterKey, _selectedSurah!.number)) ??
                      false);
              final fullDownloaded =
                  prefs.getBool(_prefKeyDlFull(reciterKey)) ?? false;
              return Container(
                margin:
                    EdgeInsets.symmetric(horizontal: scaleSize(context, 24)),
                constraints: BoxConstraints(
                    maxWidth: scaleSize(context, 400),
                    maxHeight: MediaQuery.of(context).size.height * 0.6),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(scaleSize(context, 16)),
                  boxShadow: [
                    BoxShadow(
                        color: Colors.black26,
                        blurRadius: scaleSize(context, 16),
                        spreadRadius: 0)
                  ],
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Flexible(
                      child: ListView(
                        shrinkWrap: true,
                        padding: EdgeInsets.symmetric(
                          horizontal: scaleSize(context, 16),
                          vertical: scaleSize(context, 8),
                        ),
                        children: [
                          if (_selectedSurah != null)
                            ListTile(
                              contentPadding: EdgeInsets.symmetric(
                                horizontal: scaleSize(context, 8),
                                vertical: 0,
                              ),
                              visualDensity: const VisualDensity(horizontal: 0, vertical: -4),
                              leading: const Icon(Icons.menu_book,
                                  color: Color(0xFF6366F1)),
                              title: Text(
                                t('currentSurah'),
                                style: GoogleFonts.plusJakartaSans(
                                  fontSize: scaleFont(ctx, 15),
                                ),
                              ),
                              subtitle: Text(
                                _selectedSurah!.name,
                                style: GoogleFonts.plusJakartaSans(
                                  fontSize: scaleFont(ctx, 13),
                                ),
                              ),
                              trailing: currentSurahDownloaded
                                  ? Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Icon(Icons.check_circle,
                                            color: const Color(0xFF16A34A),
                                            size: scaleSize(ctx, 22)),
                                        IconButton(
                                          icon: Icon(Icons.delete_outline,
                                              color: const Color(0xFFEF4444),
                                              size: scaleSize(ctx, 22)),
                                          onPressed: () async {
                                            Navigator.pop(ctx);
                                            final ayahs = List.generate(
                                                _selectedSurah!.verses.length,
                                                (i) => (
                                                      _selectedSurah!.number,
                                                      i + 1
                                                    ));
                                            await deleteAyahRange(
                                                ayahs, reciterKey);
                                            final p = await SharedPreferences
                                                .getInstance();
                                            await p.remove(_prefKeyDlSurah(
                                                reciterKey,
                                                _selectedSurah!.number));
                                            if (context.mounted) {
                                              ScaffoldMessenger.of(context)
                                                  .showSnackBar(SnackBar(
                                                      content: Text(
                                                          t('cacheCleared'))));
                                            }
                                          },
                                          padding: EdgeInsets.zero,
                                          constraints: BoxConstraints(
                                              minWidth: scaleSize(ctx, 36),
                                              minHeight: scaleSize(ctx, 36)),
                                        ),
                                      ],
                                    )
                                  : null,
                              onTap: () {
                                Navigator.pop(ctx);
                                if (startPlaybackFromSurah != null &&
                                    startPlaybackFromAyah != null) {
                                  playback.playAyah(startPlaybackFromSurah,
                                      startPlaybackFromAyah);
                                }
                                final ayahs = List.generate(
                                    _selectedSurah!.verses.length,
                                    (i) => (_selectedSurah!.number, i + 1));
                                _runReciterAudioDownload(
                                    context, ayahs, reciterKey, t,
                                    scopeSurah: _selectedSurah!.number);
                              },
                            ),
                          if (_selectedSurah != null) ...[
                            Builder(
                              builder: (ctx) {
                                final juz = _selectedSurah!.verses.isNotEmpty &&
                                        _selectedSurah!.verses.first.juz != null
                                    ? _selectedSurah!.verses.first.juz!
                                    : getJuzForAyah(_selectedSurah!.number, 1);
                                final juzDownloaded = prefs.getBool(
                                        _prefKeyDlJuz(reciterKey, juz)) ??
                                    false;
                                    return ListTile(
                                  contentPadding: EdgeInsets.symmetric(
                                    horizontal: scaleSize(ctx, 8),
                                    vertical: 0,
                                  ),
                                  visualDensity: const VisualDensity(horizontal: 0, vertical: -4),
                                  leading: Icon(Icons.book_outlined,
                                      color: const Color(0xFF6366F1),
                                      size: scaleSize(ctx, 24)),
                                  title: Text(
                                    t('currentJuzz'),
                                    style: GoogleFonts.plusJakartaSans(
                                      fontSize: scaleFont(ctx, 15),
                                    ),
                                  ),
                                  subtitle: Text(
                                    '${t('juz')} $juz',
                                    style: GoogleFonts.plusJakartaSans(
                                      fontSize: scaleFont(ctx, 13),
                                    ),
                                  ),
                                  trailing: juzDownloaded
                                      ? Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            Icon(Icons.check_circle,
                                                color: const Color(0xFF16A34A),
                                                size: scaleSize(ctx, 22)),
                                            IconButton(
                                              icon: Icon(
                                                  Icons.delete_outline,
                                                  color: const Color(0xFFEF4444),
                                                  size: scaleSize(ctx, 22)),
                                              onPressed: () async {
                                                Navigator.pop(ctx);
                                                final ayahs =
                                                    getAyahsInJuz(juz);
                                                await deleteAyahRange(
                                                    ayahs, reciterKey);
                                                final p =
                                                    await SharedPreferences
                                                        .getInstance();
                                                await p.remove(_prefKeyDlJuz(
                                                    reciterKey, juz));
                                                if (context.mounted) {
                                                  ScaffoldMessenger.of(context)
                                                      .showSnackBar(SnackBar(
                                                          content: Text(t(
                                                              'cacheCleared'))));
                                                }
                                              },
                                              padding: EdgeInsets.zero,
                                              constraints: BoxConstraints(
                                                  minWidth: scaleSize(ctx, 36),
                                                  minHeight: scaleSize(ctx, 36)),
                                            ),
                                          ],
                                        )
                                      : null,
                                  onTap: () {
                                    Navigator.pop(ctx);
                                    if (startPlaybackFromSurah != null &&
                                        startPlaybackFromAyah != null) {
                                      playback.playAyah(startPlaybackFromSurah,
                                          startPlaybackFromAyah);
                                    }
                                    final ayahs = getAyahsInJuz(juz);
                                    _runReciterAudioDownload(
                                        context, ayahs, reciterKey, t,
                                        scopeJuz: juz);
                                  },
                                );
                              },
                            ),
                          ],
                          ListTile(
                            contentPadding: EdgeInsets.symmetric(
                              horizontal: scaleSize(context, 8),
                              vertical: 0,
                            ),
                            visualDensity: const VisualDensity(horizontal: 0, vertical: -4),
                            leading: Icon(Icons.library_books_outlined,
                                color: const Color(0xFF6366F1),
                                size: scaleSize(context, 24)),
                            title: Text(
                              t('fullQuran'),
                              style: GoogleFonts.plusJakartaSans(
                                fontSize: scaleFont(context, 15),
                              ),
                            ),
                            trailing: fullDownloaded
                                ? Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(Icons.check_circle,
                                          color: const Color(0xFF16A34A),
                                          size: scaleSize(context, 22)),
                                      IconButton(
                                        icon: Icon(Icons.delete_outline,
                                            color: const Color(0xFFEF4444),
                                            size: scaleSize(context, 22)),
                                        onPressed: () async {
                                          Navigator.pop(ctx);
                                          await deleteAyahRange(
                                              getAllAyahs(), reciterKey);
                                          final p = await SharedPreferences
                                              .getInstance();
                                          await p.remove(
                                              _prefKeyDlFull(reciterKey));
                                          if (context.mounted) {
                                            ScaffoldMessenger.of(context)
                                                .showSnackBar(SnackBar(
                                                    content: Text(
                                                        t('cacheCleared'))));
                                          }
                                        },
                                        padding: EdgeInsets.zero,
                                        constraints: BoxConstraints(
                                            minWidth: scaleSize(context, 36),
                                            minHeight: scaleSize(context, 36)),
                                      ),
                                    ],
                                  )
                                : null,
                            onTap: () {
                              Navigator.pop(ctx);
                              if (startPlaybackFromSurah != null &&
                                  startPlaybackFromAyah != null) {
                                playback.playAyah(startPlaybackFromSurah,
                                    startPlaybackFromAyah);
                              }
                              _runReciterAudioDownload(
                                  context, getAllAyahs(), reciterKey, t,
                                  scopeFull: true);
                            },
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
        ),
      ),
    );
  }

  Future<void> _runReciterAudioDownload(
    BuildContext context,
    List<(int surah, int ayah)> ayahs,
    String reciterKey,
    String Function(String) t, {
    int? scopeSurah,
    int? scopeJuz,
    bool scopeFull = false,
  }) async {
    final total = ayahs.length;
    if (total == 0) return;
    if (!mounted) return;
    setState(() {
      _downloadProgress = (current: 0, total: total);
      _cancelDownloadRequested = false;
    });
    final result = await downloadAyahRange(
      ayahs,
      reciterKey,
      onProgress: (current, tot) {
        if (mounted)
          setState(() => _downloadProgress = (current: current, total: tot));
      },
      isCancelled: () => _cancelDownloadRequested,
    );
    if (!mounted) return;
    setState(() => _downloadProgress = null);
    if (result.success &&
        (scopeSurah != null || scopeJuz != null || scopeFull)) {
      final prefs = await SharedPreferences.getInstance();
      if (scopeSurah != null)
        await prefs.setBool(_prefKeyDlSurah(reciterKey, scopeSurah), true);
      if (scopeJuz != null)
        await prefs.setBool(_prefKeyDlJuz(reciterKey, scopeJuz), true);
      if (scopeFull) await prefs.setBool(_prefKeyDlFull(reciterKey), true);
    }
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(result.success
            ? t('downloadCompleted')
            : (result.error ?? t('error'))),
      ));
    }
  }
}

class _VerseCard extends StatelessWidget {
  final VerseItem verse;
  final int surahNumber;
  final String verseTextMode;

  /// Besmele ilk ayetten cikarildiysa gosterim metni (1. ve 9. haric sure 1. ayet).
  final String? verseDisplayText;

  /// Transliteration from assets/data/transliteration_pt.json (used when verse.transliteration is null)
  final String? transliterationText;
  final bool isBookmarked;
  final bool hasNote;
  final bool isRead;
  final ValueChanged<String>? onVerseTextMode;
  final VoidCallback? onPronunciationGuide;
  final VoidCallback? onTap;
  final VoidCallback onLongPress;

  /// Play/pause: if this verse is current and playing -> pause; if current and paused -> resume; else -> play this verse.
  final VoidCallback onPlayPause;

  /// This verse is the one currently in playback.
  final bool isCurrentAyah;

  /// Playback is playing (not paused).
  final bool isPlaying;

  /// RN: cache indicator – bu ayet çalındı/preload edildi (⚡/💾)
  final bool isCached;

  /// Ayet araması / yer imi ile açılan ayete kısa süreli vurgu
  final bool isHighlighted;
  final VoidCallback onNote;
  final VoidCallback onToggleRead;
  final VoidCallback onShare;
  final String pageLabel;

  const _VerseCard({
    required this.verse,
    required this.surahNumber,
    required this.verseTextMode,
    this.verseDisplayText,
    this.transliterationText,
    required this.isBookmarked,
    required this.hasNote,
    required this.isRead,
    this.onVerseTextMode,
    this.onPronunciationGuide,
    this.onTap,
    required this.onLongPress,
    required this.onPlayPause,
    required this.isCurrentAyah,
    required this.isPlaying,
    this.isCached = false,
    this.isHighlighted = false,
    required this.onNote,
    required this.onToggleRead,
    required this.onShare,
    required this.pageLabel,
  });

  @override
  Widget build(BuildContext context) {
    // RN: verseCardSideButtons left: -14 → butonların yarısı kart dışında, yarısı kartın üzerinde
    const double sideButtonHalfOutside =
        14; // left: -14 in RN, buton genişliği 28
    const double contentLeftPadding =
        12; // daha az yatay padding → ayet metni satırı daha iyi doldurur
    final bool isBookmarkedOrRead = isBookmarked || isRead;
    return Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(scaleSize(context, 20)),
      elevation: 0.0,
      shadowColor: Colors.transparent,
      child: Container(
        decoration: BoxDecoration(
          color: isHighlighted
              ? const Color(0xFFC7D2FE).withValues(alpha: 0.45)
              : (isBookmarked
                  ? const Color(0xFFEEF2FF).withValues(alpha: 0.5)
                  : (isRead
                      ? const Color(0xFFFEF3C7).withValues(alpha: 0.35)
                      : Colors.white)),
          borderRadius: BorderRadius.circular(scaleSize(context, 20)),
          border: Border.all(
            color: isHighlighted
                ? const Color(0xFF6366F1).withValues(alpha: 0.6)
                : (isBookmarkedOrRead
                    ? const Color(0xFF6366F1).withValues(alpha: 0.35)
                    : const Color(0xFFE2E8F0)),
            width: isHighlighted ? 2.0 : 1.2,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.06),
              offset: Offset(0, scaleSize(context, 2)),
              blurRadius: scaleSize(context, 8),
              spreadRadius: 0,
            ),
            BoxShadow(
              color: const Color(0xFF6366F1).withValues(alpha: 0.04),
              offset: Offset(0, scaleSize(context, 4)),
              blurRadius: scaleSize(context, 12),
              spreadRadius: 0,
            ),
          ],
        ),
        child: InkWell(
          onTap: onTap,
          onLongPress: onLongPress,
          borderRadius: BorderRadius.circular(scaleSize(context, 20)),
          child: Stack(
            clipBehavior:
                Clip.none, // butonlar sol tarafa taşabilsin (RN: left: -14)
            children: [
              Padding(
                padding: EdgeInsets.fromLTRB(
                    scaleSize(context, contentLeftPadding),
                    scaleSize(context, 12),
                    scaleSize(context, 12),
                    scaleSize(context, 12)),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Row(
                      children: [
                        Container(
                          width: scaleSize(context, 36),
                          height: scaleSize(context, 36),
                          decoration: BoxDecoration(
                            color: const Color(0xFFEEF2FF),
                            shape: BoxShape.circle,
                            border: Border.all(
                                color: const Color(0xFF6366F1),
                                width: scaleSize(context, 2)),
                          ),
                          alignment: Alignment.center,
                          child: Text(
                            '${verse.numberInSurah}',
                            style: GoogleFonts.plusJakartaSans(
                                fontSize: scaleFont(context, 14),
                                fontWeight: FontWeight.bold,
                                color: const Color(0xFF6366F1)),
                          ),
                        ),
                        if (isBookmarked)
                          Padding(
                            padding:
                                EdgeInsets.only(left: scaleSize(context, 6)),
                            child: Icon(Icons.bookmark,
                                size: scaleSize(context, 14),
                                color: const Color(0xFF6366F1)),
                          ),
                        if (isCached)
                          Padding(
                            padding:
                                EdgeInsets.only(left: scaleSize(context, 4)),
                            child: Icon(Icons.offline_bolt,
                                size: scaleSize(context, 14),
                                color: const Color(0xFF94A3B8)),
                          ),
                        if (verse.page != null) ...[
                          SizedBox(width: scaleSize(context, 6)),
                          Container(
                            padding: EdgeInsets.symmetric(
                                horizontal: scaleSize(context, 8),
                                vertical: scaleSize(context, 5)),
                            decoration: BoxDecoration(
                              color: const Color(0xFFEEF2FF),
                              borderRadius:
                                  BorderRadius.circular(scaleSize(context, 8)),
                              border:
                                  Border.all(color: const Color(0xFFE0E7FF)),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.menu_book_outlined,
                                    size: scaleSize(context, 11),
                                    color: const Color(0xFF6366F1)),
                                SizedBox(width: scaleSize(context, 4)),
                                Text(
                                  '$pageLabel ${verse.page}',
                                  style: GoogleFonts.plusJakartaSans(
                                      fontSize: scaleFont(context, 11),
                                      color: const Color(0xFF6366F1),
                                      fontWeight: FontWeight.w600),
                                  overflow: TextOverflow.ellipsis,
                                  maxLines: 1,
                                ),
                              ],
                            ),
                          ),
                        ],
                        const Spacer(),
                        IconButton(
                          icon: Icon(
                              hasNote ? Icons.note : Icons.note_add_outlined,
                              size: scaleSize(context, 18),
                              color: hasNote
                                  ? const Color(0xFF10B981)
                                  : const Color(0xFF64748B)),
                          onPressed: onNote,
                          padding: EdgeInsets.zero,
                          constraints: BoxConstraints(
                              minWidth: scaleSize(context, 32),
                              minHeight: scaleSize(context, 32)),
                          style: IconButton.styleFrom(
                              tapTargetSize: MaterialTapTargetSize.shrinkWrap),
                        ),
                        IconButton(
                          icon: Icon(
                              isRead
                                  ? Icons.check_circle
                                  : Icons.check_circle_outline,
                              size: scaleSize(context, 18),
                              color: isRead
                                  ? const Color(0xFFF59E0B)
                                  : const Color(0xFF64748B)),
                          onPressed: onToggleRead,
                          padding: EdgeInsets.zero,
                          constraints: BoxConstraints(
                              minWidth: scaleSize(context, 32),
                              minHeight: scaleSize(context, 32)),
                          style: IconButton.styleFrom(
                              tapTargetSize: MaterialTapTargetSize.shrinkWrap),
                        ),
                        IconButton(
                          icon: Icon(Icons.share_outlined,
                              size: scaleSize(context, 18),
                              color: const Color(0xFF6366F1)),
                          onPressed: onShare,
                          padding: EdgeInsets.zero,
                          constraints: BoxConstraints(
                              minWidth: scaleSize(context, 32),
                              minHeight: scaleSize(context, 32)),
                          style: IconButton.styleFrom(
                              tapTargetSize: MaterialTapTargetSize.shrinkWrap),
                        ),
                        IconButton(
                          icon: Icon(
                              isCurrentAyah && isPlaying
                                  ? Icons.pause_circle
                                  : Icons.play_circle,
                              size: scaleSize(context, 28),
                              color: const Color(0xFF6366F1)),
                          onPressed: onPlayPause,
                          padding: EdgeInsets.zero,
                          constraints: BoxConstraints(
                              minWidth: scaleSize(context, 34),
                              minHeight: scaleSize(context, 34)),
                          style: IconButton.styleFrom(
                              tapTargetSize: MaterialTapTargetSize.shrinkWrap),
                        ),
                      ],
                    ),
                    SizedBox(height: scaleSize(context, 12)),
                    if (verseTextMode == 'arabic' &&
                        (verseDisplayText ?? verse.text).isNotEmpty)
                      Container(
                        padding: isCurrentAyah
                            ? EdgeInsets.symmetric(
                                horizontal: scaleSize(context, 4),
                                vertical: scaleSize(context, 4))
                            : null,
                        decoration: isCurrentAyah
                            ? BoxDecoration(
                                color: const Color(0xFF15803D)
                                    .withValues(alpha: 0.22),
                                borderRadius: BorderRadius.circular(
                                    scaleSize(context, 8)),
                              )
                            : null,
                        child: Text(
                          verseDisplayText ?? verse.text,
                          style: TextStyle(
                            fontFamily: 'KuranKerimFontLatif',
                            fontSize: scaleFont(context, 30),
                            height: 1.75,
                            color: const Color(0xFF1E293B),
                          ),
                          textAlign: TextAlign.justify,
                          textDirection: TextDirection.rtl,
                        ),
                      ),
                    if (verseTextMode == 'transliteration') ...[
                      Builder(
                        builder: (context) {
                          final text = verse.transliteration?.isNotEmpty == true
                              ? verse.transliteration!
                              : (transliterationText ?? '');
                          if (text.isEmpty) return const SizedBox.shrink();
                          return Container(
                            padding: isCurrentAyah
                                ? EdgeInsets.symmetric(
                                    horizontal: scaleSize(context, 8),
                                    vertical: scaleSize(context, 6))
                                : null,
                            decoration: isCurrentAyah
                                ? BoxDecoration(
                                    color: const Color(0xFF15803D)
                                        .withValues(alpha: 0.22),
                                    borderRadius: BorderRadius.circular(
                                        scaleSize(context, 8)),
                                  )
                                : null,
                            child: Text(
                              text,
                              style: GoogleFonts.plusJakartaSans(
                                fontSize: scaleFont(context, 16),
                                height: 1.6,
                                color: const Color(0xFF475569),
                                fontStyle: FontStyle.italic,
                              ),
                            ),
                          );
                        },
                      ),
                    ],
                    if (verse.translation != null &&
                        verse.translation!.isNotEmpty)
                      Padding(
                        padding: EdgeInsets.only(top: scaleSize(context, 10)),
                        child: Text(
                          verse.translation!,
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: scaleFont(context, 15),
                            height: 1.5,
                            color: const Color(0xFF475569),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
              if (onVerseTextMode != null || onPronunciationGuide != null)
                Positioned(
                  left: -scaleSize(context, sideButtonHalfOutside),
                  top: 0,
                  bottom: 0,
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      if (onVerseTextMode != null) ...[
                        _SideModeButton(
                          label: 'ب',
                          isActive: verseTextMode == 'arabic',
                          onTap: () => onVerseTextMode!('arabic'),
                        ),
                        SizedBox(height: scaleSize(context, 8)),
                        _SideModeButton(
                          label: 'Aa',
                          isActive: verseTextMode == 'transliteration',
                          onTap: () => onVerseTextMode!('transliteration'),
                        ),
                        SizedBox(height: scaleSize(context, 8)),
                      ],
                      if (onPronunciationGuide != null)
                        _SideModeButton(
                          label: '!',
                          isActive: false,
                          onTap: onPronunciationGuide!,
                        ),
                    ],
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SideModeButton extends StatelessWidget {
  final String label;
  final bool isActive;
  final VoidCallback onTap;

  const _SideModeButton({
    required this.label,
    required this.isActive,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: isActive ? const Color(0xFFEEF2FF) : Colors.white,
      borderRadius: BorderRadius.circular(scaleSize(context, 14)),
      elevation: scaleSize(context, 1).clamp(0.0, 24.0),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(scaleSize(context, 14)),
        child: Container(
          width: scaleSize(context, 28),
          height: scaleSize(context, 28),
          alignment: Alignment.center,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(scaleSize(context, 14)),
            border: Border.all(
              color:
                  isActive ? const Color(0xFF6366F1) : const Color(0xFFE2E8F0),
            ),
          ),
          child: Text(
            label,
            style: GoogleFonts.plusJakartaSans(
              fontSize: scaleFont(context, 12),
              fontWeight: FontWeight.w700,
              color: const Color(0xFF334155),
            ),
          ),
        ),
      ),
    );
  }
}
