import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../contexts/location_provider.dart';
import '../contexts/navigation_bar_provider.dart';
import '../contexts/theme_provider.dart';
import '../data/prayer_steps.dart';
import '../l10n/app_localizations.dart';
import '../services/prayer_surahs_arabic_service.dart';
import '../services/prayer_times_service.dart';
import '../services/quran_playback_service.dart';
import '../services/turkey_prayer_times_service.dart';
import '../utils/scaling.dart';
import '../widgets/prayer_verse_card.dart';
import '../widgets/rn_segment_bar.dart';

/// Dil kodundan pronunciation guide JSON dilini. Tüm uygulama dilleri: en, tr, ar, pt, es, de, nl. Eşleşmeyenler en.
String _pronunciationGuideLangFromLocale(String locale) {
  final lower = locale.split('_').first.toLowerCase();
  if (lower == 'tr' ||
      lower == 'de' ||
      lower == 'es' ||
      lower == 'nl' ||
      lower == 'pt') return lower;
  if (lower == 'ar') return 'en';
  return 'en';
}

/// Flutter equivalent of RN PrayerScreen – Namaz rehberi with prayer/rakat selector, steps, and segment to Dua (Dhikr).
class PrayerScreen extends StatefulWidget {
  const PrayerScreen({super.key});

  @override
  State<PrayerScreen> createState() => _PrayerScreenState();
}

class _PrayerScreenState extends State<PrayerScreen> {
  static const List<String> _prayerKeys = [
    'fajr',
    'dhuhr',
    'asr',
    'maghrib',
    'isha',
    'vitr'
  ];
  static const Map<String, String> _prayerNameKeys = {
    'fajr': 'prayerFajr',
    'dhuhr': 'prayerDhuhr',
    'asr': 'prayerAsr',
    'maghrib': 'prayerMaghrib',
    'isha': 'prayerIsha',
    'vitr': 'prayerVitr',
  };
  static const Map<String, int> _rakats = {
    'fajr': 2,
    'dhuhr': 4,
    'asr': 4,
    'maghrib': 3,
    'isha': 4,
    'vitr': 3,
  };

  String _selectedPrayer = 'fajr';
  int _currentRakat = 1;
  String _viewMode = 'basic'; // basic | detailed
  PrayerTimesResult? _prayerTimes;
  bool _loading = true;

  /// Zammi surah config (persisted later). Null = use default.
  static const _zammiConfigKey = 'zammi_surah_config';
  Map<String, Map<int, int>>? _zammiSurahConfig;
  Map<String, dynamic>? _prayerSurahsArabic;
  Map<int, Map<int, String>>? _transliterationMap;

  /// Zammi verse-by-verse translations by locale then surah number. Loaded from zammi_verse_translations.json.
  Map<String, dynamic>? _zammiVerseTranslationsByLocale;
  String _verseTextMode = 'arabic'; // arabic | transliteration

  final ScrollController _scrollController = ScrollController();

  int? _getZammiForRakat(String prayer, int rakat) {
    final config = _zammiSurahConfig ?? defaultZammiConfig;
    return config[prayer]?[rakat];
  }

  List<PrayerStepEntry> _getCurrentSteps() {
    final all = getStepsForPrayer(_selectedPrayer, _getZammiForRakat);
    final forRakat = all.where((s) => s.rakat == _currentRakat).toList();
    if (_viewMode == 'basic') {
      return forRakat.where((s) => !s.hideInBasic).toList();
    }
    return forRakat;
  }

  void _showPrayerSelectorModal(BuildContext context) {
    String t(String key) => AppLocalizations.t(context, key);
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius:
            BorderRadius.vertical(top: Radius.circular(scaleSize(context, 20))),
      ),
      builder: (ctx) {
        return SafeArea(
          child: Padding(
            padding: EdgeInsets.all(scaleSize(context, 16)),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(t('prayer'),
                    style: GoogleFonts.plusJakartaSans(
                        fontSize: scaleFont(context, 16),
                        fontWeight: FontWeight.w600)),
                SizedBox(height: scaleSize(context, 8)),
                ..._prayerKeys.map((key) => ListTile(
                      title: Text(t(_prayerNameKeys[key] ?? 'prayer'),
                          style: GoogleFonts.plusJakartaSans(
                              fontSize: scaleFont(context, 15),
                              color: const Color(0xFF1E293B))),
                      onTap: () {
                        setState(() {
                          _selectedPrayer = key;
                          _currentRakat = 1;
                        });
                        Navigator.of(ctx).pop();
                      },
                    )),
              ],
            ),
          ),
        );
      },
    );
  }

  void _showRakatSelectorModal(BuildContext context) {
    String t(String key) => AppLocalizations.t(context, key);
    final rakats = _rakats[_selectedPrayer] ?? 2;
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius:
            BorderRadius.vertical(top: Radius.circular(scaleSize(context, 20))),
      ),
      builder: (ctx) {
        return SafeArea(
          child: Padding(
            padding: EdgeInsets.all(scaleSize(context, 16)),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(t('selectRakat'),
                    style: GoogleFonts.plusJakartaSans(
                        fontSize: scaleFont(context, 16),
                        fontWeight: FontWeight.w600)),
                SizedBox(height: scaleSize(context, 8)),
                ...List.generate(rakats, (i) {
                  final rakatNum = i + 1;
                  return ListTile(
                    title: Text('$rakatNum ${t('rakat')}',
                        style: GoogleFonts.plusJakartaSans(
                            fontSize: scaleFont(context, 15),
                            color: const Color(0xFF1E293B))),
                    onTap: () {
                      setState(() => _currentRakat = rakatNum);
                      Navigator.of(ctx).pop();
                    },
                  );
                }),
              ],
            ),
          ),
        );
      },
    );
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<NavigationBarProvider>().setVisible(true);
      _loadPrayerTimes();
      _loadPrayerSurahsArabic();
      _loadZammiConfig();
      _loadTransliterationMap();
      _loadZammiVerseTranslations();
    });
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  void _goToPreviousRakat() {
    if (_currentRakat <= 1) return;
    setState(() => _currentRakat = _currentRakat - 1);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(0, duration: const Duration(milliseconds: 300), curve: Curves.easeOut);
      }
    });
  }

  void _goToNextRakat() {
    final rakats = _rakats[_selectedPrayer] ?? 2;
    if (_currentRakat >= rakats) return;
    setState(() => _currentRakat = _currentRakat + 1);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(0, duration: const Duration(milliseconds: 300), curve: Curves.easeOut);
      }
    });
  }

  Future<void> _loadZammiVerseTranslations() async {
    try {
      final s = await rootBundle
          .loadString('assets/data/zammi_verse_translations.json');
      final j = jsonDecode(s) as Map<String, dynamic>?;
      if (j != null && mounted)
        setState(() => _zammiVerseTranslationsByLocale = j);
    } catch (_) {}
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

  /// One entry in the flat list: either a normal step or one combined surah card (Fatiha / zammi).
  List<_DisplayEntry> _buildDisplayEntries(List<PrayerStepEntry> steps) {
    final entries = <_DisplayEntry>[];
    for (var stepIndex = 0; stepIndex < steps.length; stepIndex++) {
      final step = steps[stepIndex];
      final surahNum = step.surahNumber == 1
          ? 1
          : (step.isZammiSurah
              ? _getZammiForRakat(_selectedPrayer, step.rakat)
              : null);
      final verses = (surahNum != null && _prayerSurahsArabic != null)
          ? PrayerSurahsArabicService.getVerses(_prayerSurahsArabic!, surahNum)
          : null;
      if (verses != null && verses.isNotEmpty) {
        final transliterations = <String?>[
          for (var v = 1; v <= verses.length; v++)
            _transliterationMap?[surahNum]?[v],
        ];
        entries.add(_DisplayEntry(
          step: step,
          stepIndex: stepIndex,
          isSurahCard: true,
          surahNum: surahNum,
          verses: verses,
          transliterations: transliterations,
          showBesmele: step.isZammiSurah,
        ));
      } else if (step.surahNumber == 2) {
        entries.add(_DisplayEntry(
          step: step,
          stepIndex: stepIndex,
          isTahiyyatCard: true,
        ));
      } else {
        entries.add(_DisplayEntry(step: step, stepIndex: stepIndex));
      }
    }
    return entries;
  }

  Future<void> _loadZammiConfig() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_zammiConfigKey);
      if (raw == null) return;
      final decoded = jsonDecode(raw) as Map<String, dynamic>;
      final config = <String, Map<int, int>>{};
      for (final e in decoded.entries) {
        final inner = (e.value as Map<String, dynamic>)
            .map((k, v) => MapEntry(int.parse(k), v as int));
        config[e.key] = inner;
      }
      if (mounted) setState(() => _zammiSurahConfig = config);
    } catch (_) {}
  }

  Future<void> _saveZammiConfig(Map<String, Map<int, int>> config) async {
    try {
      final encoded = config.map((p, rakatMap) =>
          MapEntry(p, rakatMap.map((k, v) => MapEntry(k.toString(), v))));
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_zammiConfigKey, jsonEncode(encoded));
      if (mounted) setState(() => _zammiSurahConfig = config);
    } catch (_) {}
  }

  static const _zammiSurahNumbers = [
    97,
    102,
    103,
    105,
    106,
    107,
    108,
    109,
    110,
    111,
    112,
    113,
    114
  ];

  void _showZammiSelectorModal(BuildContext context, String prayer, int rakat) {
    String t(String key) => AppLocalizations.t(context, key);
    showDialog<void>(
      context: context,
      barrierDismissible: true,
      barrierColor: Colors.black54,
      builder: (ctx) => GestureDetector(
        onTap: () => Navigator.of(ctx).pop(),
        behavior: HitTestBehavior.opaque,
        child: Center(
          child: GestureDetector(
            onTap: () {},
            child: Container(
              width: MediaQuery.of(context).size.width * 0.88,
              constraints: BoxConstraints(
                maxWidth: scaleSize(context, 320),
                maxHeight: MediaQuery.of(context).size.height * 0.45,
              ),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(scaleSize(context, 16)),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.2),
                    offset: Offset(0, scaleSize(context, 4)),
                    blurRadius: 12,
                  ),
                ],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Padding(
                    padding: EdgeInsets.symmetric(
                      horizontal: scaleSize(context, 14),
                      vertical: scaleSize(context, 8),
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: Text(
                            '${t('selectZammiSurah')} · ${t('rakat')} $rakat',
                            style: GoogleFonts.plusJakartaSans(
                              fontSize: scaleFont(context, 11),
                              fontWeight: FontWeight.w600,
                              color: const Color(0xFF1E293B),
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        GestureDetector(
                          onTap: () {
                            final base = _zammiSurahConfig != null
                                ? _zammiSurahConfig!.map((p, m) =>
                                    MapEntry(p, Map<int, int>.from(m)))
                                : defaultZammiConfig.map((p, m) =>
                                    MapEntry(p, Map<int, int>.from(m)));
                            base[prayer] ??= {};
                            base[prayer]![rakat] =
                                defaultZammiConfig[prayer]![rakat]!;
                            _saveZammiConfig(base);
                            Navigator.of(ctx).pop();
                          },
                          child: Container(
                            padding: EdgeInsets.symmetric(
                              horizontal: scaleSize(context, 8),
                              vertical: scaleSize(context, 4),
                            ),
                            decoration: BoxDecoration(
                              borderRadius:
                                  BorderRadius.circular(scaleSize(context, 6)),
                              border: Border.all(
                                  color: const Color(0xFF6366F1)
                                      .withValues(alpha: 0.4)),
                            ),
                            child: Text(
                              t('resetZammiToDefault'),
                              style: GoogleFonts.plusJakartaSans(
                                fontSize: scaleFont(context, 11),
                                fontWeight: FontWeight.w600,
                                color: const Color(0xFF6366F1),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  Flexible(
                    child: ListView.builder(
                      padding: EdgeInsets.symmetric(
                        horizontal: scaleSize(context, 12),
                        vertical: scaleSize(context, 8),
                      ),
                      itemCount: _zammiSurahNumbers.length,
                      itemBuilder: (_, idx) {
                        final num = _zammiSurahNumbers[idx];
                        final data = _prayerSurahsArabic != null
                            ? _prayerSurahsArabic![num.toString()]
                                as Map<String, dynamic>?
                            : null;
                        final name = t('surah$num');
                        final nameAr = data?['nameAr'] as String? ?? '';
                        return Material(
                          color: Colors.transparent,
                          child: InkWell(
                            onTap: () {
                              final base = _zammiSurahConfig != null
                                  ? _zammiSurahConfig!.map((p, m) =>
                                      MapEntry(p, Map<int, int>.from(m)))
                                  : defaultZammiConfig.map((p, m) =>
                                      MapEntry(p, Map<int, int>.from(m)));
                              base[prayer] ??= {};
                              base[prayer]![rakat] = num;
                              _saveZammiConfig(base);
                              Navigator.of(ctx).pop();
                            },
                            borderRadius:
                                BorderRadius.circular(scaleSize(context, 8)),
                            child: Container(
                              padding: EdgeInsets.symmetric(
                                vertical: scaleSize(context, 8),
                                horizontal: scaleSize(context, 8),
                              ),
                              margin: EdgeInsets.only(
                                  bottom: scaleSize(context, 3)),
                              decoration: BoxDecoration(
                                color: const Color(0xFFF8FAFC),
                                borderRadius: BorderRadius.circular(
                                    scaleSize(context, 8)),
                                border: Border.all(
                                    color: const Color(0xFF6366F1)
                                        .withValues(alpha: 0.08)),
                              ),
                              child: Row(
                                children: [
                                  Container(
                                    width: scaleSize(context, 28),
                                    height: scaleSize(context, 28),
                                    decoration: const BoxDecoration(
                                      color: Color(0xFF6366F1),
                                      shape: BoxShape.circle,
                                    ),
                                    alignment: Alignment.center,
                                    child: Text(
                                      '$num',
                                      style: GoogleFonts.plusJakartaSans(
                                        fontSize: scaleFont(context, 13),
                                        fontWeight: FontWeight.w600,
                                        color: Colors.white,
                                      ),
                                    ),
                                  ),
                                  SizedBox(width: scaleSize(context, 10)),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          name,
                                          style: GoogleFonts.plusJakartaSans(
                                            fontSize: scaleFont(context, 14),
                                            fontWeight: FontWeight.w600,
                                            color: const Color(0xFF1E293B),
                                          ),
                                        ),
                                        if (nameAr.isNotEmpty)
                                          Align(
                                            alignment: Alignment.centerRight,
                                            child: Text(
                                              nameAr,
                                            style: GoogleFonts.notoNaskhArabic(
                                              fontWeight: FontWeight.w400,
                                              fontSize: scaleFont(context, 24),
                                              color: const Color(0xFF64748B),
                                            ),
                                              textAlign: TextAlign.right,
                                              textDirection: TextDirection.rtl,
                                            ),
                                          ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  /// RN: Pronunciation Guide Modal – ortada açılır, transliteration/telaffuz rehberi.
  Future<void> _showPronunciationGuideModal(BuildContext context) async {
    String t(String key) => AppLocalizations.t(context, key);
    final locale = Localizations.localeOf(context).languageCode;
    final lang = _pronunciationGuideLangFromLocale(locale);
    Map<String, dynamic>? data;
    try {
      final raw = await rootBundle
          .loadString('assets/data/pronunciation_guide_$lang.json');
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

    // RN: width 92%, maxWidth 520, height 80%, borderRadius 20, padding 20
    showDialog<void>(
      context: context,
      barrierDismissible: true,
      barrierColor: Colors.black54,
      builder: (ctx) => Center(
        child: Material(
          color: Colors.transparent,
          child: Container(
            width: MediaQuery.of(context).size.width * 0.92,
            constraints: BoxConstraints(
              maxWidth: scaleSize(context, 520),
              maxHeight: MediaQuery.of(context).size.height * 0.80,
            ),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(20),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 20, 20, 10),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          title,
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 18,
                            fontWeight: FontWeight.w700,
                            color: const Color(0xFF0F172A),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      GestureDetector(
                        onTap: () => Navigator.pop(ctx),
                        child: const Icon(Icons.close,
                            size: 24, color: Color(0xFF64748B)),
                      ),
                    ],
                  ),
                ),
                Flexible(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          description,
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 14,
                            color: const Color(0xFF475569),
                            height: 1.43,
                          ),
                        ),
                        const SizedBox(height: 12),
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
                            padding: const EdgeInsets.only(bottom: 12),
                            child: Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: const Color(0xFFF8FAFC),
                                borderRadius: BorderRadius.circular(12),
                                border:
                                    Border.all(color: const Color(0xFFE2E8F0)),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    itemTitle,
                                    style: GoogleFonts.plusJakartaSans(
                                      fontSize: 16,
                                      fontWeight: FontWeight.w700,
                                      color: const Color(0xFF6366F1),
                                    ),
                                  ),
                                  if (symbol.isNotEmpty) ...[
                                    const SizedBox(height: 6),
                                    Text(
                                      symbol,
                                      style: GoogleFonts.plusJakartaSans(
                                        fontSize: 14,
                                        color: const Color(0xFF334155),
                                      ),
                                    ),
                                  ],
                                  if (itemDesc.isNotEmpty) ...[
                                    const SizedBox(height: 6),
                                    Text(
                                      itemDesc,
                                      style: GoogleFonts.plusJakartaSans(
                                        fontSize: 14,
                                        color: const Color(0xFF334155),
                                      ),
                                    ),
                                  ],
                                  if (exampleLabel.isNotEmpty &&
                                      examples.isNotEmpty) ...[
                                    const SizedBox(height: 6),
                                    Text(
                                      exampleLabel,
                                      style: GoogleFonts.plusJakartaSans(
                                        fontSize: 13,
                                        color: const Color(0xFF64748B),
                                      ),
                                    ),
                                    ...examples.map<Widget>((ex) => Padding(
                                          padding:
                                              const EdgeInsets.only(top: 2),
                                          child: Text(
                                            ex as String,
                                            style: GoogleFonts.plusJakartaSans(
                                              fontSize: 13,
                                              color: const Color(0xFF64748B),
                                            ),
                                          ),
                                        )),
                                  ],
                                ],
                              ),
                            ),
                          );
                        }),
                        if (notesTitle != null &&
                            notesTitle.isNotEmpty &&
                            notesItems.isNotEmpty) ...[
                          const SizedBox(height: 12),
                          Text(
                            notesTitle,
                            style: GoogleFonts.plusJakartaSans(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              color: const Color(0xFF475569),
                            ),
                          ),
                          const SizedBox(height: 4),
                          ...notesItems.map<Widget>((n) => Padding(
                                padding: const EdgeInsets.only(bottom: 4),
                                child: Text(
                                  n as String,
                                  style: GoogleFonts.plusJakartaSans(
                                    fontSize: 13,
                                    color: const Color(0xFF475569),
                                    height: 1.38,
                                  ),
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

  Future<void> _loadPrayerSurahsArabic() async {
    try {
      final data = await PrayerSurahsArabicService.load();
      if (mounted) setState(() => _prayerSurahsArabic = data);
    } catch (_) {}
  }

  Future<void> _loadPrayerTimes() async {
    final loc = context.read<LocationProvider>();
    if (!loc.hasCities) {
      if (mounted)
        setState(() {
          _loading = false;
        });
      return;
    }
    final city = loc.selectedCity;
    if (city == null) {
      if (mounted)
        setState(() {
          _loading = false;
        });
      return;
    }
    final location = city['location'] as Map<String, dynamic>?;
    if (location == null) {
      if (mounted)
        setState(() {
          _loading = false;
        });
      return;
    }
    final lat = (location['latitude'] as num?)?.toDouble();
    final lng = (location['longitude'] as num?)?.toDouble();
    if (lat == null || lng == null) {
      if (mounted)
        setState(() {
          _loading = false;
        });
      return;
    }
    final method = (city['calculationMethod'] as num?)?.toInt() ?? 2;
    final madhab = (city['madhab'] as String?) ?? 'standard';
    final admin = city['admin'] as Map<String, dynamic>?;

    try {
      PrayerTimesResult times;
      if (method == 13) {
        final province =
            admin?['state'] ?? admin?['province'] ?? admin?['city'];
        final district = admin?['district'] ?? admin?['county'];
        final trToday = await getTurkeyPrayerTimesForToday(
          province: province?.toString(),
          district: district?.toString(),
        );
        if (trToday != null) {
          String s(String key) =>
              (trToday[key] is String) ? (trToday[key] as String) : '00:00';
          times = PrayerTimesResult(
            fajr: s('fajr'),
            sunrise: s('sunrise'),
            dhuhr: s('dhuhr'),
            asr: s('asr'),
            maghrib: s('maghrib'),
            isha: s('isha'),
          );
        } else {
          times = PrayerTimesResult.fallback;
        }
      } else {
        times = await getPrayerTimes(
          latitude: lat,
          longitude: lng,
          method: method,
          madhab: madhab,
          admin: admin,
        );
      }
      if (!mounted) return;
      setState(() {
        _prayerTimes = times;
        _loading = false;
        _setDefaultPrayerFromTime(times);
      });
    } catch (_) {
      if (mounted)
        setState(() {
          _loading = false;
        });
    }
  }

  void _setDefaultPrayerFromTime(PrayerTimesResult times) {
    final now = DateTime.now();
    final nowMins = now.hour * 60 + now.minute;
    final list = [
      ('fajr', times.fajr),
      ('dhuhr', times.dhuhr),
      ('asr', times.asr),
      ('maghrib', times.maghrib),
      ('isha', times.isha),
    ];
    String last = 'fajr';
    for (final (key, time) in list) {
      final parts = time.split(':');
      if (parts.length >= 2) {
        final pMins =
            (int.tryParse(parts[0]) ?? 0) * 60 + (int.tryParse(parts[1]) ?? 0);
        if (nowMins >= pMins) last = key;
      }
    }
    if (_prayerKeys.contains(last)) _selectedPrayer = last;
  }

  String _formatTime(String timeStr) {
    if (timeStr.isEmpty) return '--:--';
    final parts = timeStr.split(' ');
    final t = parts.isNotEmpty ? parts[0] : timeStr;
    return t.length >= 5 ? t : '--:--';
  }

  @override
  Widget build(BuildContext context) {
    String t(String key) => AppLocalizations.t(context, key);
    final rakats = _rakats[_selectedPrayer] ?? 2;
    String currentPrayerTimeStr = '--:--';
    if (_prayerTimes != null && _selectedPrayer != 'vitr') {
      switch (_selectedPrayer) {
        case 'fajr':
          currentPrayerTimeStr = _formatTime(_prayerTimes!.fajr);
          break;
        case 'dhuhr':
          currentPrayerTimeStr = _formatTime(_prayerTimes!.dhuhr);
          break;
        case 'asr':
          currentPrayerTimeStr = _formatTime(_prayerTimes!.asr);
          break;
        case 'maghrib':
          currentPrayerTimeStr = _formatTime(_prayerTimes!.maghrib);
          break;
        case 'isha':
          currentPrayerTimeStr = _formatTime(_prayerTimes!.isha);
          break;
        default:
          break;
      }
    }

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      body: SafeArea(
        top: true,
        child: Column(
          children: [
            // Segments: Prayer|Dua (left) and Basic|Detailed (right) – RN style: border 24, active bg rgba(99,102,241,0.3)
            Padding(
              padding: EdgeInsets.fromLTRB(
                  scaleSize(context, 20),
                  scaleSize(context, 4),
                  scaleSize(context, 20),
                  scaleSize(context, 6)),
              child: Row(
                children: [
                  RnSegmentBar(
                    scaleContext: context,
                    labels: [t('prayer'), t('Dua')],
                    selectedIndex: 0,
                    onSelected: (i) {
                      if (i == 1) Navigator.of(context).pushNamed('/dhikr');
                    },
                  ),
                  const Spacer(),
                  RnSegmentBar(
                    scaleContext: context,
                    labels: [t('basic'), t('detailed')],
                    selectedIndex: _viewMode == 'basic' ? 0 : 1,
                    onSelected: (i) => setState(
                        () => _viewMode = i == 0 ? 'basic' : 'detailed'),
                  ),
                ],
              ),
            ),
            // Header: çok ince container – Namaz adı, rekat, sağda namaz vakti + indir
            Padding(
              padding: EdgeInsets.fromLTRB(scaleSize(context, 16), 0,
                  scaleSize(context, 16), scaleSize(context, 4)),
              child: Container(
                width: double.infinity,
                padding: EdgeInsets.symmetric(
                    horizontal: scaleSize(context, 16),
                    vertical: scaleSize(context, 8)),
                decoration: BoxDecoration(
                  color: const Color(0xCCFFFFFF),
                  borderRadius: BorderRadius.circular(scaleSize(context, 6)),
                  border: Border.all(
                      color: const Color(0xFF6366F1).withValues(alpha: 0.2),
                      width: 1),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    GestureDetector(
                      onTap: () => _showPrayerSelectorModal(context),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            t(_prayerNameKeys[_selectedPrayer] ?? 'prayer'),
                            style: GoogleFonts.plusJakartaSans(
                              fontSize: scaleFont(context, 11),
                              fontWeight: FontWeight.bold,
                              color: const Color(0xFF6366F1),
                            ),
                          ),
                          SizedBox(width: scaleSize(context, 1)),
                          Icon(Icons.keyboard_arrow_down,
                              color: const Color(0xFF6366F1),
                              size: scaleSize(context, 14)),
                        ],
                      ),
                    ),
                    GestureDetector(
                      onTap: () => _showRakatSelectorModal(context),
                      child: Padding(
                        padding: EdgeInsets.symmetric(
                            horizontal: scaleSize(context, 6)),
                        child: Text(
                          '$_currentRakat/$rakats ${t('rakat')}',
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: scaleFont(context, 11),
                            fontWeight: FontWeight.w600,
                            color: const Color(0xFF6366F1),
                          ),
                        ),
                      ),
                    ),
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.access_time,
                            size: scaleSize(context, 14),
                            color: const Color(0xFF64748B)),
                        SizedBox(width: scaleSize(context, 4)),
                        Text(
                          currentPrayerTimeStr,
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: scaleFont(context, 11),
                            fontWeight: FontWeight.w600,
                            color: const Color(0xFF475569),
                            fontFeatures: const [FontFeature.tabularFigures()],
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            // Steps list (filtered by current rakat and basic/detailed); Fatiha/zammi as verse cards
            Expanded(
              child: _loading
                  ? const Center(
                      child:
                          CircularProgressIndicator(color: Color(0xFF6366F1)))
                  : Builder(
                      builder: (ctx) {
                        final steps = _getCurrentSteps();
                        final entries = _buildDisplayEntries(steps);
                        return ListView.builder(
                          controller: _scrollController,
                          padding: EdgeInsets.fromLTRB(
                              scaleSize(context, 16),
                              scaleSize(context, 8),
                              scaleSize(context, 16),
                              scaleSize(context, 100)),
                          itemCount: entries.length + 1,
                          itemBuilder: (_, i) {
                            // Son öğe: önceki/sonraki rekat butonları (her rekatın altında)
                            if (i == entries.length) {
                              return Padding(
                                padding: EdgeInsets.fromLTRB(
                                    scaleSize(context, 20),
                                    scaleSize(context, 16),
                                    scaleSize(context, 20),
                                    scaleSize(context, 30)),
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    if (_currentRakat > 1)
                                      Material(
                                        color: Colors.transparent,
                                        child: InkWell(
                                          onTap: _goToPreviousRakat,
                                          borderRadius: BorderRadius.circular(scaleSize(context, 20)),
                                          child: Container(
                                            padding: EdgeInsets.symmetric(
                                                horizontal: scaleSize(context, 16),
                                                vertical: scaleSize(context, 8)),
                                            decoration: BoxDecoration(
                                              border: Border.all(
                                                  color: const Color(0xFF6366F1).withValues(alpha: 0.4),
                                                  width: scaleSize(context, 1.5)),
                                              borderRadius: BorderRadius.circular(scaleSize(context, 20)),
                                            ),
                                            child: Row(
                                              mainAxisSize: MainAxisSize.min,
                                              children: [
                                                Icon(Icons.chevron_left,
                                                    size: scaleSize(context, 18),
                                                    color: const Color(0xFF6366F1)),
                                                SizedBox(width: scaleSize(context, 6)),
                                                Text(
                                                  t('previousRakat'),
                                                  style: GoogleFonts.plusJakartaSans(
                                                      fontSize: scaleFont(context, 13),
                                                      fontWeight: FontWeight.w600,
                                                      color: const Color(0xFF6366F1)),
                                                ),
                                              ],
                                            ),
                                          ),
                                        ),
                                      ),
                                    if (_currentRakat > 1 && _currentRakat < rakats) SizedBox(width: scaleSize(context, 12)),
                                    if (_currentRakat < rakats)
                                      Material(
                                        color: Colors.transparent,
                                        child: InkWell(
                                          onTap: _goToNextRakat,
                                          borderRadius: BorderRadius.circular(scaleSize(context, 20)),
                                          child: Container(
                                            padding: EdgeInsets.symmetric(
                                                horizontal: scaleSize(context, 16),
                                                vertical: scaleSize(context, 8)),
                                            decoration: BoxDecoration(
                                              border: Border.all(
                                                  color: const Color(0xFF6366F1).withValues(alpha: 0.4),
                                                  width: scaleSize(context, 1.5)),
                                              borderRadius: BorderRadius.circular(scaleSize(context, 20)),
                                            ),
                                            child: Row(
                                              mainAxisSize: MainAxisSize.min,
                                              children: [
                                                Text(
                                                  t('nextRakat'),
                                                  style: GoogleFonts.plusJakartaSans(
                                                      fontSize: scaleFont(context, 13),
                                                      fontWeight: FontWeight.w600,
                                                      color: const Color(0xFF6366F1)),
                                                ),
                                                SizedBox(width: scaleSize(context, 6)),
                                                Icon(Icons.chevron_right,
                                                    size: scaleSize(context, 18),
                                                    color: const Color(0xFF6366F1)),
                                              ],
                                            ),
                                          ),
                                        ),
                                      ),
                                  ],
                                ),
                              );
                            }
                            final e = entries[i];
                            if (e.isTahiyyatCard && e.step != null) {
                              return PrayerTahiyyatCard(
                                stepNumber: e.stepIndex! + 1,
                                actionLabel: t(e.step!.actionKey),
                                verseTextMode: _verseTextMode,
                                onVerseTextMode: (mode) =>
                                    setState(() => _verseTextMode = mode),
                                onPronunciationGuideTap: () =>
                                    _showPronunciationGuideModal(context),
                                arabicText: _tahiyyatArabic,
                                transliterationText: _tahiyyatTransliteration,
                                meaningText: t(e.step!.meaningKey),
                              );
                            }
                            if (e.isSurahCard &&
                                e.surahNum != null &&
                                e.verses != null) {
                              final step = e.step!;
                              final besmeleAr = e.showBesmele
                                  ? (_prayerSurahsArabic?['besmele'] as String?)
                                  : null;
                              final besmeleTr = e.showBesmele
                                  ? (_transliterationMap?[1]?[1])
                                  : null;
                              final zammiName = step.isZammiSurah
                                  ? ((_prayerSurahsArabic?[
                                                  e.surahNum.toString()]
                                              as Map<String, dynamic>?)?['name']
                                          as String?) ??
                                      t('prayerActionZammiSure')
                                  : null;
                              final locale =
                                  context.read<ThemeProvider>().language;
                              final zammiVerseList = e.surahNum != null
                                  ? (_zammiVerseTranslationsByLocale?[locale]
                                          ?[e.surahNum.toString()]
                                      as List<dynamic>?)
                                  : null;
                              final meanings = e.surahNum == 1
                                  ? [
                                      for (var v = 1; v <= 7; v++)
                                        t('fatihaVerse$v')
                                    ]
                                  : (e.surahNum != null
                                      ? (zammiVerseList != null
                                          ? zammiVerseList
                                              .map((x) => x as String)
                                              .toList()
                                          : [
                                              t('zammi${e.surahNum}Translation')
                                            ])
                                      : null);
                              return Consumer<QuranPlaybackService>(
                                builder: (_, playback, __) => PrayerSurahCard(
                                  stepNumber: e.stepIndex! + 1,
                                  actionLabel: t(step.actionKey),
                                  surahNumber: e.surahNum!,
                                  verses: e.verses!,
                                  transliterations: e.transliterations ?? [],
                                  verseTextMode: _verseTextMode,
                                  onVerseTextMode: (mode) =>
                                      setState(() => _verseTextMode = mode),
                                  onPlayPause: () {
                                    final cur = playback.currentAyah;
                                    if (cur != null &&
                                        cur.surah == e.surahNum &&
                                        playback.isPlaying &&
                                        !playback.isPaused) {
                                      playback.pause();
                                    } else if (cur != null &&
                                        cur.surah == e.surahNum &&
                                        playback.isPaused) {
                                      playback.resume();
                                    } else if (e.surahNum == 1) {
                                      final nextZammi = _getZammiForRakat(
                                          _selectedPrayer, step.rakat);
                                      playback.playPrayerSequence(1, nextZammi);
                                    } else {
                                      playback.playAyah(
                                        e.surahNum!,
                                        1,
                                        endSurah: e.surahNum,
                                        endAyah: e.verses!.length,
                                      );
                                    }
                                  },
                                  isPlaying: playback.currentAyah?.surah ==
                                          e.surahNum &&
                                      playback.isPlaying &&
                                      !playback.isPaused,
                                  isCached: e.verses!.asMap().keys.any((v) =>
                                      playback.isCached(e.surahNum!, v + 1)),
                                  showBesmele: e.showBesmele,
                                  besmeleArabic: besmeleAr,
                                  besmeleTransliteration: besmeleTr,
                                  zammiSurahName: zammiName,
                                  onZammiTap: step.isZammiSurah
                                      ? () => _showZammiSelectorModal(
                                          context, _selectedPrayer, step.rakat)
                                      : null,
                                  currentAyahSurah: playback.currentAyah?.surah,
                                  currentAyahAyah: playback.currentAyah?.ayah,
                                  onPronunciationGuideTap: () =>
                                      _showPronunciationGuideModal(context),
                                  meanings: meanings,
                                ),
                              );
                            }
                            final step = e.step!;
                            final action = t(step.actionKey);
                            final meaning = step.meaningKey.isEmpty
                                ? ''
                                : t(step.meaningKey);
                            String? arabic = step.arabic;
                            if (_prayerSurahsArabic != null) {
                              if (step.surahNumber != null &&
                                  step.surahNumber! >= 1) {
                                arabic = PrayerSurahsArabicService.getArabic(
                                    _prayerSurahsArabic!, step.surahNumber!);
                              } else if (step.isZammiSurah) {
                                final num = _getZammiForRakat(
                                    _selectedPrayer, step.rakat);
                                if (num != null)
                                  arabic = PrayerSurahsArabicService.getArabic(
                                      _prayerSurahsArabic!, num);
                              }
                            }
                            if (arabic == null && step.arabic != null)
                              arabic = step.arabic;
                            return _StepCard(
                              stepNumber: e.stepIndex! + 1,
                              action: action,
                              meaning: meaning,
                              arabic: arabic,
                              transliteration: step.transliteration,
                              surahNumber: step.surahNumber,
                              isZammiSurah: step.isZammiSurah,
                              zammiSurahNumber: step.isZammiSurah
                                  ? _getZammiForRakat(
                                      _selectedPrayer, step.rakat)
                                  : null,
                              onZammiTap: step.isZammiSurah
                                  ? () => _showZammiSelectorModal(
                                      context, _selectedPrayer, step.rakat)
                                  : null,
                            );
                          },
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

class _DisplayEntry {
  final PrayerStepEntry? step;
  final int? stepIndex;
  final bool isSurahCard;
  final bool isTahiyyatCard;
  final int? surahNum;
  final List<String>? verses;
  final List<String?>? transliterations;
  final bool showBesmele;

  _DisplayEntry({
    this.step,
    this.stepIndex,
    this.isSurahCard = false,
    this.isTahiyyatCard = false,
    this.surahNum,
    this.verses,
    this.transliterations,
    this.showBesmele = false,
  });
}

// RN Tahiyyat – static Arapça ve transliterasyon metni.
const String _tahiyyatArabic =
    'التَّحِيَّاتُ لِلَّهِ وَالصَّلَوَاتُ وَالطَّيِّبَاتُ، السَّلَامُ عَلَيْكَ أَيُّهَا النَّبِيُّ وَرَحْمَةُ اللَّهِ وَبَرَكَاتُهُ، السَّلَامُ عَلَيْنَا وَعَلَى عِبَادِ اللَّهِ الصَّالِحِينَ، أَشْهَدُ أَنْ لَا إِلَهَ إِلَّا اللَّهُ وَأَشْهَدُ أَنَّ مُحَمَّدًا عَبْدُهُ وَرَسُولُهُ';
const String _tahiyyatTransliteration =
    'At-tahiyyātu lillāhi waṣ-ṣalawātu waṭ-ṭayyibāt, as-salāmu \'alayka ayyuhan-nabiyyu wa raḥmatullāhi wa barakātuh, as-salāmu \'alaynā wa \'alā \'ibādillāhiṣ-ṣāliḥīn, ashhadu an lā ilāha illallāhu wa ashhadu anna Muḥammadan \'abduhū wa rasūluh';

class _StepCard extends StatelessWidget {
  final int stepNumber;
  final String action;
  final String meaning;
  final String? arabic;
  final String? transliteration;
  final int? surahNumber;
  final bool isZammiSurah;
  final int? zammiSurahNumber;
  final VoidCallback? onZammiTap;

  const _StepCard({
    required this.stepNumber,
    required this.action,
    required this.meaning,
    this.arabic,
    this.transliteration,
    this.surahNumber,
    this.isZammiSurah = false,
    this.zammiSurahNumber,
    this.onZammiTap,
  });

  @override
  Widget build(BuildContext context) {
    final showArabic = (arabic != null && arabic!.isNotEmpty) ||
        surahNumber != null ||
        (isZammiSurah && zammiSurahNumber != null);
    Widget card = Container(
      margin: EdgeInsets.only(bottom: scaleSize(context, 12)),
      padding: EdgeInsets.all(scaleSize(context, 16)),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(scaleSize(context, 16)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.06),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: scaleSize(context, 28),
                height: scaleSize(context, 28),
                decoration: BoxDecoration(
                  color: const Color(0xFF6366F1).withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(scaleSize(context, 8)),
                ),
                alignment: Alignment.center,
                child: Text(
                  '$stepNumber',
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: scaleFont(context, 14),
                    fontWeight: FontWeight.w600,
                    color: const Color(0xFF6366F1),
                  ),
                ),
              ),
              SizedBox(width: scaleSize(context, 12)),
              Expanded(
                child: Text(
                  action,
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: scaleFont(context, 16),
                    fontWeight: FontWeight.w600,
                    color: const Color(0xFF1E293B),
                  ),
                ),
              ),
            ],
          ),
          if (meaning.isNotEmpty) ...[
            SizedBox(height: scaleSize(context, 8)),
            Text(
              meaning,
              style: GoogleFonts.plusJakartaSans(
                  fontSize: scaleFont(context, 14),
                  color: const Color(0xFF64748B),
                  height: 1.4),
            ),
          ],
          if (showArabic && arabic != null && arabic!.isNotEmpty) ...[
            SizedBox(height: scaleSize(context, 8)),
            Align(
              alignment: Alignment.centerRight,
              child: Text(
                arabic!,
                style: GoogleFonts.notoNaskhArabic(
                  fontWeight: FontWeight.w400,
                  fontSize: scaleFont(context, 24),
                  color: const Color(0xFF1E293B)),
                textAlign: TextAlign.right,
                textDirection: TextDirection.rtl,
              ),
            ),
          ],
          if (transliteration != null && transliteration!.isNotEmpty) ...[
            SizedBox(height: scaleSize(context, 4)),
            Text(
              transliteration!,
              style: GoogleFonts.plusJakartaSans(
                  fontSize: scaleFont(context, 13),
                  color: const Color(0xFF64748B),
                  fontStyle: FontStyle.italic),
            ),
          ],
        ],
      ),
    );
    if (onZammiTap != null && isZammiSurah) {
      card = GestureDetector(
        onTap: onZammiTap,
        child: card,
      );
    }
    return card;
  }
}
