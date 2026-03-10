// RN: screens/PureQuranScreen.js – mushaf sayfa görünümü.
// Faz 1–5: Sayfa görseli, TopBar, swipe/tap, ayet overlay, modallar, ses senkronu.

import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:share_plus/share_plus.dart' show SharePlus, ShareParams;
import 'package:path_provider/path_provider.dart';

import '../contexts/back_handler_provider.dart';
import '../contexts/navigation_bar_provider.dart';
import '../contexts/quran_view_mode_provider.dart';
import '../data/page_ayah_map.dart' hide totalMushafPages;
import '../data/surah_meta.dart' show getSurahName;
import '../l10n/app_localizations.dart';
import '../services/quran_service.dart'
    show
        calculateJuzByPage,
        getJuzEndPage,
        getJuzStartPage,
        getMushafPageUrl,
        getAyahTranslation,
        totalMushafPages;
import '../services/ayah_coordination_service.dart';
import '../services/mushaf_download_service.dart';
import '../utils/scaling.dart';
import '../widgets/quran_top_bar.dart';
import '../widgets/quran_index_modal.dart';
import '../widgets/quran_sound_player.dart';
import '../services/quran_playback_service.dart';

const String _storageKeyLastPage = '@purequran_last_page';
const String _storageKeyBookmark = '@purequran_bookmark';

class PureQuranScreen extends StatefulWidget {
  final int? initialPage;
  final VoidCallback onSwitchToSurahView;

  const PureQuranScreen({
    super.key,
    this.initialPage,
    required this.onSwitchToSurahView,
  });

  @override
  State<PureQuranScreen> createState() => _PureQuranScreenState();
}

class _PureQuranScreenState extends State<PureQuranScreen> {
  int _currentPage = 1;
  bool _isInitialPageLoaded = false;
  String? _localImagePath;
  bool _soundPlayerVisible = true;
  bool _bookmark = false;
  int? _bookmarkSurah;
  int? _bookmarkAyah;
  double _dragStartX = 0;
  // Faz 5: kullanıcı sayfa değiştirdiğinde sesi durdur; otomatik sayfa değişiminde durdurma
  bool _isAutoPageChange = false;
  // Uzun basılan ayet (yeşil highlight)
  int? _longPressedSurah;
  int? _longPressedAyah;
  bool _showQuranIndex = false;
  // TopBar ve QuranIndexModal için mevcut sayfanın sure/ayet bilgisi (PN pageInfo ile aynı)
  int? _pageInfoSurah;
  int? _pageInfoAyah;
  String? _pageInfoSurahName;

  /// Secde ayetleri (surah:ayah) – Sajdah_verses.json'dan, kalıcı açık kırmızı highlight için.
  Set<String>? _sajdahVerseKeys;

  /// Mushaf sayfa indirme ilerlemesi (Surah view’deki banner ile aynı görünüm).
  ({int current, int total})? _mushafDownloadProgress;

  @override
  void initState() {
    super.initState();
    context.read<NavigationBarProvider>().setVisible(false);
    _loadPageAyahMap();
    _loadLastPageAndBookmark();
    _loadSajdahVerses();
    context.read<QuranPlaybackService>().addListener(_onPlaybackChanged);
  }

  Future<void> _loadSajdahVerses() async {
    try {
      final raw = await rootBundle.loadString('assets/data/Sajdah_verses.json');
      final map = jsonDecode(raw) as Map<String, dynamic>;
      final list = map['sajdah_verses'] as List<dynamic>?;
      if (list == null) return;
      final keys = <String>{};
      for (final e in list) {
        final m = e as Map<String, dynamic>?;
        if (m == null) continue;
        final surah = (m['surah'] as num?)?.toInt();
        final ayah = (m['ayah'] as num?)?.toInt();
        if (surah != null && ayah != null) {
          keys.add('$surah:$ayah');
        }
      }
      if (mounted) setState(() => _sajdahVerseKeys = keys);
    } catch (_) {}
  }

  @override
  void dispose() {
    // Yatayda gizlenen sistem çubuğunu ekrandan çıkarken geri getir.
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    context.read<QuranPlaybackService>().removeListener(_onPlaybackChanged);
    context.read<NavigationBarProvider>().setVisible(true);
    super.dispose();
  }

  void _onPlaybackChanged() {
    if (!mounted) return;
    final playback = context.read<QuranPlaybackService>();
    final current = playback.currentAyah;
    if (current == null || !playback.isPlaying) return;
    getPageForSurahAyah(current.surah, current.ayah).then((page) {
      if (page == null || !mounted) return;
      if (page != _currentPage) {
        _isAutoPageChange = true;
        setState(() => _currentPage = page);
        _saveLastPage();
        _checkLocalImage();
        _updatePageSurahInfo(page);
      }
    });
  }

  Future<void> _loadPageAyahMap() async {
    await getPageStartAyah(1);
    _updatePageSurahInfo(_currentPage);
  }

  /// Mevcut sayfanın ilk ayet bilgisini asenkron okuyup TopBar ve QuranIndexModal'ı günceller (PN pageInfo ile aynı).
  void _updatePageSurahInfo(int page) {
    getPageStartAyah(page).then((start) {
      if (!mounted || start == null) return;
      final surahNum = start.surah.clamp(1, 114);
      final name = getSurahName(surahNum);
      setState(() {
        _pageInfoSurah = surahNum;
        _pageInfoAyah = start.ayah;
        _pageInfoSurahName = '$surahNum. $name';
      });
    });
  }

  Future<void> _loadLastPageAndBookmark() async {
    if (widget.initialPage != null) {
      setState(() {
        _currentPage = widget.initialPage!.clamp(1, totalMushafPages);
        _isInitialPageLoaded = true;
      });
      context.read<QuranViewModeProvider>().clearPureQuranInitialPage();
      return;
    }
    try {
      final prefs = await SharedPreferences.getInstance();
      final savedPage = prefs.getString(_storageKeyLastPage);
      if (savedPage != null) {
        final pageNum = int.tryParse(savedPage);
        if (pageNum != null && pageNum >= 1 && pageNum <= totalMushafPages) {
          setState(() => _currentPage = pageNum);
        }
      }
      final bookmarkJson = prefs.getString(_storageKeyBookmark);
      if (bookmarkJson != null) {
        try {
          final map = _parseBookmark(bookmarkJson);
          if (map != null) {
            setState(() {
              _bookmark = true;
              _bookmarkSurah = map.$1;
              _bookmarkAyah = map.$2;
            });
          }
        } catch (_) {}
      }
    } catch (_) {}
    setState(() => _isInitialPageLoaded = true);
    _checkLocalImage();
    _updatePageSurahInfo(_currentPage);
  }

  (int, int)? _parseBookmark(String jsonStr) {
    try {
      final decoded = jsonDecode(jsonStr) as Map<String, dynamic>?;
      if (decoded == null) return null;
      final surah = (decoded['surah'] as num?)?.toInt();
      final ayah = (decoded['ayah'] as num?)?.toInt();
      if (surah == null || ayah == null) return null;
      return (surah, ayah);
    } catch (_) {
      return null;
    }
  }

  Future<void> _saveLastPage() async {
    if (!_isInitialPageLoaded) return;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_storageKeyLastPage, _currentPage.toString());
    } catch (_) {}
  }

  Future<void> _checkLocalImage() async {
    try {
      final dir = await getApplicationDocumentsDirectory();
      final file = File(
          '${dir.path}/mushaf/page_${_currentPage.toString().padLeft(3, '0')}.png');
      if (await file.exists()) {
        setState(() => _localImagePath = file.path);
      } else {
        setState(() => _localImagePath = null);
      }
    } catch (_) {
      setState(() => _localImagePath = null);
    }
  }

  @override
  void didUpdateWidget(covariant PureQuranScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.initialPage != null &&
        widget.initialPage != oldWidget.initialPage) {
      setState(
          () => _currentPage = widget.initialPage!.clamp(1, totalMushafPages));
    }
  }

  void _goToNextPage() {
    if (_currentPage < totalMushafPages) {
      if (!_isAutoPageChange) context.read<QuranPlaybackService>().stop();
      _isAutoPageChange = false;
      setState(() {
        _currentPage++;
        _longPressedSurah = null;
        _longPressedAyah = null;
      });
      _saveLastPage();
      _checkLocalImage();
      _updatePageSurahInfo(_currentPage);
    }
  }

  void _goToPrevPage() {
    if (_currentPage > 1) {
      if (!_isAutoPageChange) context.read<QuranPlaybackService>().stop();
      _isAutoPageChange = false;
      setState(() {
        _currentPage--;
        _longPressedSurah = null;
        _longPressedAyah = null;
      });
      _saveLastPage();
      _checkLocalImage();
      _updatePageSurahInfo(_currentPage);
    }
  }

  void _toggleSoundPlayer() {
    setState(() => _soundPlayerVisible = !_soundPlayerVisible);
  }

  String _buildPageInfoText(BuildContext context) {
    String t(String k) => AppLocalizations.t(context, k);
    final juz = calculateJuzByPage(_currentPage);
    return '${t('juz')} $juz • ${t('page')} $_currentPage';
  }

  /// TopBar ikinci satırı: "N. SureName" — state zaten hazırsa senkron döner.
  String? _buildSurahInfoLine() => _pageInfoSurahName;

  /// BoxFit.contain ile sayfa görüntüsünün ekranda kapladığı dikdörtgen.
  ({double left, double top, double width, double height})
      _getDisplayedImageRect(
    double containerWidth,
    double containerHeight,
    int imageWidth,
    int imageHeight,
  ) {
    final scale = (containerWidth / imageWidth).clamp(0.0, double.infinity);
    final scaleH = (containerHeight / imageHeight).clamp(0.0, double.infinity);
    final s = scale < scaleH ? scale : scaleH;
    final w = imageWidth * s;
    final h = imageHeight * s;
    final left = (containerWidth - w) / 2;
    const top = 0.0;
    return (left: left, top: top, width: w, height: h);
  }

  /// Highlight bölgesinin tamamı tap ve uzun basma hedefi; uzun basınca da ayet vurgulanır.
  List<Widget> _buildAyahHighlightTapTargets(
    AyahPageData data,
    int refW,
    int refH,
    double layoutW,
    double layoutH,
  ) {
    final list = <Widget>[];
    for (final box in data.boundingBoxes) {
      final regions = _getAyahHighlightRegions(
        _currentPage,
        box,
        data.boundingBoxes,
        data.imageWidth,
        data.imageHeight,
        layoutW,
        layoutH,
      );
      for (final r in regions) {
        list.add(
          Positioned(
            left: r.x,
            top: r.y,
            width: r.width,
            height: r.height,
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: _toggleSoundPlayer,
              onLongPress: () {
                setState(() {
                  _longPressedSurah = box.surahNumber;
                  _longPressedAyah = box.ayahNumber;
                });
                _showAyahActionSheet(context, box.surahNumber, box.ayahNumber);
              },
            ),
          ),
        );
      }
    }
    return list;
  }

  /// RN getAyahHighlightRegions – tüm özel kurallarla çok bölgeli highlight.
  List<({double x, double y, double width, double height})>
      _getAyahHighlightRegions(
    int currentPage,
    AyahBoundingBox currentBox,
    List<AyahBoundingBox> boxes,
    int imageWidth,
    int imageHeight,
    double layoutW,
    double layoutH,
  ) {
    final scaleX = layoutW / imageWidth;
    final scaleY = layoutH / imageHeight;
    final isFirstTwoPages = currentPage == 1 || currentPage == 2;
    final highlightPadding = isFirstTwoPages ? 35.0 : 52.0;
    final totalPadding = highlightPadding * 2;
    final rawMargin = (imageWidth * 0.023).roundToDouble();
    final leftMargin =
        isFirstTwoPages ? 24.0 : (rawMargin > 30.0 ? rawMargin : 30.0);
    final rightMargin = leftMargin;
    final effectiveImageWidth = imageWidth - rightMargin;

    final ayahNumber = currentBox.ayahNumber;
    final currentTop = currentBox.topLeftY;
    final currentBottom = currentBox.bottomLeftY;
    final currentHeight = currentBottom - currentTop;
    final currentTotalHighlightHeight = currentHeight + totalPadding;
    final currentRightX = currentBox.topRightX;

    // Özel: ek üst satır sayıları (sayfa, sure, ayet 1)
    int extraLines = 0;
    if ((currentPage == 558 && currentBox.surahNumber == 65) ||
        (currentPage == 549 && currentBox.surahNumber == 60)) {
      extraLines = 4;
    } else if ((currentPage == 77 && currentBox.surahNumber == 4) ||
        (currentPage == 106 && currentBox.surahNumber == 5) ||
        (currentPage == 177 && currentBox.surahNumber == 8) ||
        (currentPage == 282 && currentBox.surahNumber == 17) ||
        (currentPage == 434 && currentBox.surahNumber == 35)) {
      extraLines = 2;
    } else if ((currentPage == 128 && currentBox.surahNumber == 6) ||
        (currentPage == 249 && currentBox.surahNumber == 13) ||
        (currentPage == 255 && currentBox.surahNumber == 14) ||
        (currentPage == 350 && currentBox.surahNumber == 24) ||
        (currentPage == 359 && currentBox.surahNumber == 25) ||
        (currentPage == 418 && currentBox.surahNumber == 33) ||
        (currentPage == 428 && currentBox.surahNumber == 34) ||
        (currentPage == 515 && currentBox.surahNumber == 49) ||
        (currentPage == 542 && currentBox.surahNumber == 58) ||
        (currentPage == 553 && currentBox.surahNumber == 62) ||
        (currentPage == 554 && currentBox.surahNumber == 63) ||
        (currentPage == 556 && currentBox.surahNumber == 64) ||
        (currentPage == 560 && currentBox.surahNumber == 66) ||
        (currentPage == 599 && currentBox.surahNumber == 98)) {
      extraLines = 1;
    }
    final hasExtraTopPadding = extraLines > 0;
    final extraTopPadding =
        hasExtraTopPadding ? (currentTotalHighlightHeight * extraLines) : 0.0;

    AyahBoundingBox? prevBox;
    for (final b in boxes) {
      if (b.surahNumber == currentBox.surahNumber &&
          b.ayahNumber == ayahNumber - 1) {
        prevBox = b;
        break;
      }
    }

    final regions = <({double x, double y, double width, double height})>[];

    // Ekstra üst bölge (özel sure başı kuralları)
    if (hasExtraTopPadding && extraTopPadding > 0) {
      regions.add((
        x: leftMargin * scaleX,
        y: (currentTop - highlightPadding - extraTopPadding) * scaleY,
        width: (effectiveImageWidth - leftMargin) * scaleX,
        height: extraTopPadding * scaleY,
      ));
    }

    if (prevBox != null) {
      final prevTop = prevBox.topLeftY;
      final prevBottom = prevBox.bottomLeftY;
      final prevHeight = prevBottom - prevTop;
      final prevTotalHighlightHeight = prevHeight + totalPadding;
      final prevLeftX = prevBox.topLeftX;

      final isSameLine = (prevTop - currentTop).abs() < (currentHeight * 0.5);

      if (isSameLine) {
        // DURUM A: Aynı satır – aradaki boşluk
        regions.add((
          x: currentRightX * scaleX,
          y: (currentTop - highlightPadding) * scaleY,
          width: (prevLeftX - currentRightX) * scaleX,
          height: currentTotalHighlightHeight * scaleY,
        ));
      } else {
        // DURUM B: Farklı satırlar
        final sameLineBoxes = boxes.where((b) {
          if (b.ayahNumber == ayahNumber) return false;
          final boxTop = b.topLeftY;
          return (boxTop - currentTop).abs() < (currentHeight * 0.5);
        }).toList();
        double highlightWidth = (effectiveImageWidth - currentRightX) * scaleX;
        if (sameLineBoxes.isNotEmpty) {
          final leftmostX = sameLineBoxes
              .map((b) => b.topLeftX)
              .reduce((a, x) => a < x ? a : x);
          if (leftmostX < effectiveImageWidth) {
            final w = (leftmostX - currentRightX) * scaleX;
            if (w < highlightWidth) highlightWidth = w;
          }
        }
        regions.add((
          x: currentRightX * scaleX,
          y: (currentTop - highlightPadding) * scaleY,
          width: highlightWidth,
          height: currentTotalHighlightHeight * scaleY,
        ));

        // Aradaki boş satırlar
        final verticalGap = currentTop - prevBottom;
        final avgHeight =
            (currentTotalHighlightHeight + prevTotalHighlightHeight) / 2;
        int numberOfGapLines = (verticalGap / avgHeight).floor();

        if (currentPage == 411 &&
            currentBox.surahNumber == 31 &&
            ayahNumber == 4 &&
            numberOfGapLines > 1) {
          numberOfGapLines = 1;
        }
        if (currentPage == 445 &&
            currentBox.surahNumber == 36 &&
            ayahNumber == 71 &&
            numberOfGapLines > 0) {
          final gapCenter = (prevBottom + currentTop) / 2;
          final currentLineTop = currentTop - highlightPadding;
          final lastGapLineOffset =
              ((numberOfGapLines - 1) - (numberOfGapLines - 1) / 2) * avgHeight;
          final lastGapLineCenter = gapCenter + lastGapLineOffset;
          final lastGapLineBottom = lastGapLineCenter + (avgHeight / 2);
          if (lastGapLineBottom > currentLineTop) {
            int safeGapLines = 0;
            for (int i = 0; i < numberOfGapLines; i++) {
              final offset = (i - (numberOfGapLines - 1) / 2) * avgHeight;
              final lineCenter = gapCenter + offset;
              final lineBottom = lineCenter + (avgHeight / 2);
              if (lineBottom <= currentLineTop) {
                safeGapLines = i + 1;
              } else {
                break;
              }
            }
            numberOfGapLines = safeGapLines;
          }
        }

        if (numberOfGapLines > 0) {
          final gapCenter = (prevBottom + currentTop) / 2;
          for (int i = 0; i < numberOfGapLines; i++) {
            final offset = (i - (numberOfGapLines - 1) / 2) * avgHeight;
            final lineCenter = gapCenter + offset;
            regions.add((
              x: leftMargin * scaleX,
              y: (lineCenter - (avgHeight / 2)) * scaleY,
              width: (effectiveImageWidth - leftMargin) * scaleX,
              height: avgHeight * scaleY,
            ));
          }
        }

        // Üst satır: satır başından önceki gülün soluna
        final prevLineBoxes = boxes.where((b) {
          if (b.ayahNumber == prevBox!.ayahNumber || b.ayahNumber == ayahNumber)
            return false;
          final boxTop = b.topLeftY;
          if ((boxTop - prevTop).abs() >= (prevHeight * 0.5)) return false;
          return b.topLeftX > prevLeftX;
        }).toList();
        double prevLineHighlightWidth = (prevLeftX - leftMargin) * scaleX;
        if (prevLineBoxes.isNotEmpty) {
          final rightmostX = prevLineBoxes
              .map((b) => b.topLeftX)
              .reduce((a, x) => a < x ? a : x);
          if (rightmostX > leftMargin) {
            final w = (rightmostX - leftMargin) * scaleX;
            if (w < prevLineHighlightWidth) prevLineHighlightWidth = w;
          }
        }
        regions.add((
          x: leftMargin * scaleX,
          y: (prevTop - highlightPadding) * scaleY,
          width: prevLineHighlightWidth,
          height: prevTotalHighlightHeight * scaleY,
        ));
      }
    } else {
      // DURUM C: Sayfanın ilk ayeti
      final sameLineBoxes = boxes.where((b) {
        if (b.ayahNumber == ayahNumber) return false;
        final boxTop = b.topLeftY;
        return (boxTop - currentTop).abs() < (currentHeight * 0.5);
      }).toList();
      double highlightWidth = (effectiveImageWidth - currentRightX) * scaleX;
      if (sameLineBoxes.isNotEmpty) {
        final leftmostX = sameLineBoxes
            .map((b) => b.topLeftX)
            .reduce((a, x) => a < x ? a : x);
        if (leftmostX < effectiveImageWidth) {
          final w = (leftmostX - currentRightX) * scaleX;
          if (w < highlightWidth) highlightWidth = w;
        }
      }
      regions.add((
        x: currentRightX * scaleX,
        y: (currentTop - highlightPadding) * scaleY,
        width: highlightWidth,
        height: currentTotalHighlightHeight * scaleY,
      ));

      if (!hasExtraTopPadding) {
        const excludedPages = <int>{
          1,
          2,
          12,
          50,
          56,
          68,
          71,
          77,
          86,
          87,
          96,
          128,
          133,
          151,
          159,
          165,
          176,
          177,
          187,
          208,
          216,
          218,
          235,
          241,
          248,
          249,
          253,
          262,
          263,
          264,
          265,
          266,
          267,
          273,
          282,
          287,
          291,
          293,
          302,
          303,
          305,
          306,
          309,
          311,
          312,
          313,
          314,
          315,
          316,
          321,
          322,
          327,
          332,
          335,
          342,
          345,
          346,
          348,
          349,
          350,
          356,
          361,
          363,
          365,
          367,
          368,
          369,
          370,
          371,
          372,
          373,
          374,
          375,
          376,
          377,
          384,
          392,
          398,
          410,
          411,
          415,
          418,
          424,
          428,
          434,
          437,
          441,
          443,
          444,
          447,
          448,
          449,
          450,
          451,
          452,
          453,
          454,
          457,
          458,
          460,
          465,
          477,
          483,
          487,
          492,
          495,
          496,
          497,
          498,
          499,
          502,
          503,
          507,
          511,
          518,
          521,
          522,
          524,
          525,
          526,
          528,
          529,
          530,
          531,
          532,
          533,
          534,
          535,
          536,
          537,
          542,
          549,
          553,
          556,
          558,
          560,
          562,
          563,
          565,
          567,
          568,
          569,
          570,
          571,
          572,
          574,
          576,
          577,
          578,
          579,
          580,
          581,
          582,
          583,
          584,
          585,
          586,
          587,
          588,
          589,
          590,
          591,
          592,
          593,
          594,
          595,
          596,
          597,
          598,
          599,
          600,
          601,
          602,
          603,
          604,
          605,
        };
        final shouldSkipTopHighlight = (currentPage == 221 &&
                currentBox.surahNumber == 11 &&
                ayahNumber == 1) ||
            (currentPage == 385 &&
                currentBox.surahNumber == 28 &&
                ayahNumber == 1) ||
            (currentPage == 396 &&
                currentBox.surahNumber == 29 &&
                ayahNumber == 1) ||
            (currentPage == 404 &&
                currentBox.surahNumber == 30 &&
                ayahNumber == 1) ||
            (currentPage == 440 &&
                currentBox.surahNumber == 36 &&
                ayahNumber == 1) ||
            (currentPage == 446 &&
                currentBox.surahNumber == 37 &&
                ayahNumber == 1);
        if (!excludedPages.contains(currentPage) && !shouldSkipTopHighlight) {
          final topGap = currentTop - highlightPadding;
          final numberOfTopLines =
              (topGap / currentTotalHighlightHeight).floor();
          for (int i = 0; i < numberOfTopLines; i++) {
            final lineY = (currentTop - highlightPadding) -
                ((i + 1) * currentTotalHighlightHeight);
            if (lineY >= 0) {
              regions.add((
                x: leftMargin * scaleX,
                y: lineY * scaleY,
                width: (effectiveImageWidth - leftMargin) * scaleX,
                height: currentTotalHighlightHeight * scaleY,
              ));
            }
          }
        }
      }
    }

    return regions;
  }

  /// Secde ayetleri – Sajdah_verses.json'dan, açık kırmızı kalıcı highlight + "Sajdah Verse" silik yazı.
  Widget _buildSajdahHighlightOverlay(
      BuildContext context, AyahPageData data, double layoutW, double layoutH) {
    final keys = _sajdahVerseKeys;
    if (keys == null || keys.isEmpty) return const SizedBox.shrink();
    final label = AppLocalizations.t(context, 'sajdahVerse');
    final children = <Widget>[];
    for (final box in data.boundingBoxes) {
      if (!keys.contains('${box.surahNumber}:${box.ayahNumber}')) continue;
      final regions = _getAyahHighlightRegions(
        _currentPage,
        box,
        data.boundingBoxes,
        data.imageWidth,
        data.imageHeight,
        layoutW,
        layoutH,
      );
      for (final r in regions) {
        children.add(
          Positioned(
            left: r.x,
            top: r.y,
            width: r.width,
            height: r.height,
            child: Stack(
              clipBehavior: Clip.none,
              alignment: Alignment.topRight,
              children: [
                Container(
                  decoration: BoxDecoration(
                    color: const Color(0x40EF4444),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                Transform.translate(
                  offset: const Offset(0, -6),
                  child: Padding(
                    padding: const EdgeInsets.only(top: 2, right: 4),
                    child: Text(
                      label,
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 12,
                        color: Colors.white.withOpacity(0.85),
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      }
    }
    if (children.isEmpty) return const SizedBox.shrink();
    return Stack(
      clipBehavior: Clip.none,
      children: children,
    );
  }

  /// Uzun basılan ayet için yeşil highlight (RN kurallarıyla çok bölgeli).
  Widget _buildLongPressHighlightOverlay(
      AyahPageData data, double layoutW, double layoutH) {
    if (_longPressedSurah == null || _longPressedAyah == null)
      return const SizedBox.shrink();
    AyahBoundingBox? target;
    for (final box in data.boundingBoxes) {
      if (box.surahNumber == _longPressedSurah &&
          box.ayahNumber == _longPressedAyah) {
        target = box;
        break;
      }
    }
    if (target == null) return const SizedBox.shrink();
    final regions = _getAyahHighlightRegions(
      _currentPage,
      target,
      data.boundingBoxes,
      data.imageWidth,
      data.imageHeight,
      layoutW,
      layoutH,
    );
    return Stack(
      clipBehavior: Clip.none,
      children: [
        for (final r in regions)
          Positioned(
            left: r.x,
            top: r.y,
            width: r.width,
            height: r.height,
            child: Container(
              decoration: BoxDecoration(
                color: const Color(0x4022C55E),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildHighlightOverlay(
      AyahPageData data, double layoutW, double layoutH) {
    return Consumer<QuranPlaybackService>(
      builder: (context, playback, _) {
        final current = playback.currentAyah;
        if (current == null || !playback.isPlaying)
          return const SizedBox.shrink();
        AyahBoundingBox? target;
        for (final box in data.boundingBoxes) {
          if (box.surahNumber == current.surah &&
              box.ayahNumber == current.ayah) {
            target = box;
            break;
          }
        }
        if (target == null) return const SizedBox.shrink();
        final regions = _getAyahHighlightRegions(
          _currentPage,
          target,
          data.boundingBoxes,
          data.imageWidth,
          data.imageHeight,
          layoutW,
          layoutH,
        );
        return Stack(
          clipBehavior: Clip.none,
          children: [
            for (final r in regions)
              Positioned(
                left: r.x,
                top: r.y,
                width: r.width,
                height: r.height,
                child: Container(
                  decoration: BoxDecoration(
                    color: const Color(0x406366F1),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
          ],
        );
      },
    );
  }

  Future<void> _showAyahActionSheet(
      BuildContext context, int surah, int ayah) async {
    String t(String k) => AppLocalizations.t(context, k);
    final playback = context.read<QuranPlaybackService>();
    await showDialog<void>(
      context: context,
      barrierColor: Colors.black54,
      builder: (ctx) => Center(
        child: Material(
          color: Colors.transparent,
          child: Container(
            margin: EdgeInsets.symmetric(horizontal: scaleSize(context, 24)),
            constraints: const BoxConstraints(maxWidth: 320),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(14),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.12),
                  blurRadius: 16,
                  offset: const Offset(0, 6),
                ),
              ],
            ),
            padding: EdgeInsets.symmetric(
              horizontal: scaleSize(context, 14),
              vertical: scaleSize(context, 12),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  '${getSurahName(surah)} : $ayah',
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: scaleFont(context, 16),
                    fontWeight: FontWeight.w600,
                    color: const Color(0xFF1E293B),
                  ),
                ),
                SizedBox(height: scaleSize(context, 12)),
                Row(
                  children: [
                    Expanded(
                      child: _modalAction(
                        context,
                        icon: Icons.play_arrow_rounded,
                        label: t('play'),
                        onTap: () {
                          Navigator.pop(ctx);
                          playback.playAyah(surah, ayah);
                        },
                      ),
                    ),
                    SizedBox(width: scaleSize(context, 6)),
                    Expanded(
                      child: _modalAction(
                        context,
                        icon: _isBookmark(surah, ayah)
                            ? Icons.bookmark_rounded
                            : Icons.bookmark_border_rounded,
                        label: _isBookmark(surah, ayah)
                            ? t('removeBookmark')
                            : t('saveBookmark'),
                        onTap: () {
                          _toggleBookmark(surah, ayah);
                          Navigator.pop(ctx);
                        },
                      ),
                    ),
                    SizedBox(width: scaleSize(context, 6)),
                    Expanded(
                      child: _modalAction(
                        context,
                        icon: Icons.translate_rounded,
                        label: t('translation'),
                        onTap: () {
                          Navigator.pop(ctx);
                          _showTranslationSheet(context, surah, ayah);
                        },
                      ),
                    ),
                    SizedBox(width: scaleSize(context, 6)),
                    Expanded(
                      child: _modalAction(
                        context,
                        icon: Icons.text_fields_rounded,
                        label: t('transliteration'),
                        onTap: () {
                          Navigator.pop(ctx);
                          _showTransliterationSheet(context, surah, ayah);
                        },
                      ),
                    ),
                    SizedBox(width: scaleSize(context, 6)),
                    Expanded(
                      child: _modalAction(
                        context,
                        icon: Icons.share_rounded,
                        label: t('share'),
                        onTap: () {
                          Navigator.pop(ctx);
                          _shareAyah(surah, ayah);
                        },
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
    if (mounted) {
      setState(() {
        _longPressedSurah = null;
        _longPressedAyah = null;
      });
    }
  }

  bool _isBookmark(int surah, int ayah) =>
      _bookmark && _bookmarkSurah == surah && _bookmarkAyah == ayah;

  Future<void> _toggleBookmark(int surah, int ayah) async {
    if (_isBookmark(surah, ayah)) {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_storageKeyBookmark);
      setState(() {
        _bookmark = false;
        _bookmarkSurah = null;
        _bookmarkAyah = null;
      });
    } else {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(
          _storageKeyBookmark, jsonEncode({'surah': surah, 'ayah': ayah}));
      setState(() {
        _bookmark = true;
        _bookmarkSurah = surah;
        _bookmarkAyah = ayah;
      });
    }
  }

  Future<void> _shareAyah(int surah, int ayah) async {
    final locale = Localizations.localeOf(context).languageCode;
    final result = await getAyahTranslation(surah, ayah, languageCode: locale);
    final text =
        result.success && result.text != null && result.text!.isNotEmpty
            ? result.text!
            : '';
    final ref = '${getSurahName(surah)} : $ayah';
    final body = text.isEmpty ? ref : '$text\n\n$ref';
    await SharePlus.instance.share(ShareParams(text: body));
  }

  Future<void> _showTranslationSheet(
      BuildContext context, int surah, int ayah) async {
    int curSurah = surah;
    int curAyah = ayah;
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setModalState) {
          return Container(
            constraints: BoxConstraints(
                maxHeight: MediaQuery.of(context).size.height * 0.5),
            decoration: const BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
            ),
            padding: EdgeInsets.all(scaleSize(context, 20)),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    IconButton(
                      icon: const Icon(Icons.chevron_left),
                      onPressed: () {
                        final prev = getPreviousAyah(curSurah, curAyah);
                        if (prev != null) {
                          setModalState(() {
                            curSurah = prev.surah;
                            curAyah = prev.ayah;
                          });
                        }
                      },
                    ),
                    Text(
                      '${getSurahName(curSurah)} : $curAyah',
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: scaleFont(context, 16),
                        fontWeight: FontWeight.w600,
                        color: const Color(0xFF1E293B),
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.chevron_right),
                      onPressed: () async {
                        final next = await getNextAyah(curSurah, curAyah);
                        if (next != null) {
                          setModalState(() {
                            curSurah = next.surah;
                            curAyah = next.ayah;
                          });
                        }
                      },
                    ),
                  ],
                ),
                Flexible(
                  child: FutureBuilder<
                      ({bool success, String? text, String? error})>(
                    key: ValueKey('$curSurah-$curAyah'),
                    future: getAyahTranslation(curSurah, curAyah,
                        languageCode:
                            Localizations.localeOf(context).languageCode),
                    builder: (context, snapshot) {
                      if (snapshot.connectionState == ConnectionState.waiting) {
                        return const Center(child: CircularProgressIndicator());
                      }
                      if (snapshot.hasError || !snapshot.hasData) {
                        return Center(
                            child: Text(AppLocalizations.t(context, 'error'),
                                style: GoogleFonts.plusJakartaSans(
                                    fontSize: scaleFont(context, 14),
                                    color: const Color(0xFF64748B))));
                      }
                      final r = snapshot.data!;
                      if (!r.success) return Center(
                          child: Text(r.error ?? '',
                              style: GoogleFonts.plusJakartaSans(
                                  fontSize: scaleFont(context, 14),
                                  color: const Color(0xFF64748B))));
                      return SingleChildScrollView(
                          child: Text(r.text ?? '',
                              style: GoogleFonts.plusJakartaSans(
                                  fontSize: scaleFont(context, 14),
                                  height: 1.5,
                                  color: const Color(0xFF475569))));
                    },
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  /// assets/data/transliteration_pt.json → surahNumber -> verseNumber -> transliteration_pt
  static Future<Map<int, Map<int, String>>> _loadTransliterationPtMap() async {
    try {
      final s = await rootBundle.loadString('assets/data/transliteration_pt.json');
      final j = jsonDecode(s) as Map<String, dynamic>?;
      if (j == null) return {};
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
          if (verseNum != null && tr != null && tr.isNotEmpty) {
            verseMap[verseNum] = tr;
          }
        }
        map[surahNum] = verseMap;
      }
      return map;
    } catch (_) {
      return {};
    }
  }

  Future<void> _showTransliterationSheet(
      BuildContext context, int surah, int ayah) async {
    int curSurah = surah;
    int curAyah = ayah;
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => FutureBuilder<Map<int, Map<int, String>>>(
        future: _loadTransliterationPtMap(),
        builder: (context, mapSnapshot) {
          if (mapSnapshot.connectionState == ConnectionState.waiting) {
            return Container(
              constraints: BoxConstraints(
                  maxHeight: MediaQuery.of(context).size.height * 0.5),
              decoration: const BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
              ),
              child: const Center(child: CircularProgressIndicator()),
            );
          }
          final trMap = mapSnapshot.data ?? {};
          return StatefulBuilder(
            builder: (context, setModalState) {
              final text = trMap[curSurah]?[curAyah] ?? '';
              return Container(
                constraints: BoxConstraints(
                    maxHeight: MediaQuery.of(context).size.height * 0.5),
                decoration: const BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
                ),
                padding: EdgeInsets.all(scaleSize(context, 20)),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        IconButton(
                          icon: const Icon(Icons.chevron_left),
                          onPressed: () {
                            final prev = getPreviousAyah(curSurah, curAyah);
                            if (prev != null) {
                              setModalState(() {
                                curSurah = prev.surah;
                                curAyah = prev.ayah;
                              });
                            }
                          },
                        ),
                        Text(
                          '${getSurahName(curSurah)} : $curAyah',
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: scaleFont(context, 16),
                            fontWeight: FontWeight.w600,
                            color: const Color(0xFF1E293B),
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.chevron_right),
                          onPressed: () async {
                            final next = await getNextAyah(curSurah, curAyah);
                            if (next != null) {
                              setModalState(() {
                                curSurah = next.surah;
                                curAyah = next.ayah;
                              });
                            }
                          },
                        ),
                      ],
                    ),
                    Flexible(
                      child: text.isEmpty
                          ? Center(
                              child: Text('—',
                                  style: GoogleFonts.plusJakartaSans(
                                      fontSize: scaleFont(context, 15),
                                      color: const Color(0xFF94A3B8))))
                          : SingleChildScrollView(
                              child: Text(text,
                                  style: GoogleFonts.plusJakartaSans(
                                      fontSize: scaleFont(context, 15),
                                      height: 1.5)),
                            ),
                    ),
                  ],
                ),
              );
            },
          );
        },
      ),
    );
  }

  Widget _modalAction(BuildContext context,
      {required IconData icon,
      required String label,
      required VoidCallback onTap}) {
    return Material(
      color: const Color(0xFFF1F5F9),
      borderRadius: BorderRadius.circular(10),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(10),
        child: Padding(
          padding: EdgeInsets.symmetric(
            horizontal: scaleSize(context, 4),
            vertical: scaleSize(context, 8),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                icon,
                size: scaleSize(context, 18),
                color: const Color(0xFF6366F1),
              ),
              SizedBox(height: scaleSize(context, 4)),
              Text(
                label,
                style: GoogleFonts.plusJakartaSans(
                  fontSize: scaleFont(context, 11),
                  fontWeight: FontWeight.w500,
                  color: const Color(0xFF334155),
                ),
                overflow: TextOverflow.ellipsis,
                maxLines: 1,
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    context.read<BackHandlerProvider>().setBackHandler(() {
      widget.onSwitchToSurahView();
      return true;
    });

    final mq = MediaQuery.of(context);
    final isLandscape = mq.orientation == Orientation.landscape;

    // Yatayda sistem çubuğunu tamamen gizle (bildirim çekilmeden hiçbir şey görünmesin).
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      if (isLandscape) {
        SystemChrome.setEnabledSystemUIMode(
          SystemUiMode.manual,
          overlays: [SystemUiOverlay.bottom],
        );
      } else {
        SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
      }
    });

    Widget columnChild = Column(
      children: [
        Builder(builder: (ctx) {
          final ctxMq = MediaQuery.of(ctx);
          final landscape = ctxMq.orientation == Orientation.landscape;
          return QuranTopBar(
            pageInfoText: _buildPageInfoText(ctx),
            surahInfoLine: _buildSurahInfoLine(),
            isLandscape: landscape,
            statusBarTop: landscape ? 0.0 : null,
            showSearchBar: false,
            showNavigateButton: true,
            onOpenQuranIndex: () => setState(() => _showQuranIndex = true),
            onBookmarkPress: _onBookmarkPress,
            hasBookmark: _bookmark,
            onOpenDownload: _onOpenSettings,
          );
        }),
        if (_mushafDownloadProgress != null)
          _buildMushafDownloadBanner(context),
        Expanded(
          child: LayoutBuilder(
            builder: (context, constraints) {
              final cw = constraints.maxWidth;
              final ch = constraints.maxHeight;
              return GestureDetector(
                onHorizontalDragStart: (d) => _dragStartX = d.globalPosition.dx,
                onHorizontalDragEnd: (d) {
                  const threshold = 50.0;
                  final delta = d.velocity.pixelsPerSecond.dx;
                  // Sola swipe (parmak sola) -> önceki sayfa; sağa swipe -> sonraki sayfa
                  if (_dragStartX - d.globalPosition.dx > threshold ||
                      delta < -300) {
                    _goToPrevPage();
                  } else if (d.globalPosition.dx - _dragStartX > threshold ||
                      delta > 300) {
                    _goToNextPage();
                  }
                },
                onTap: _toggleSoundPlayer,
                child: isLandscape
                    ? _buildLandscapePageContent(cw, ch)
                    : _buildPortraitPageContent(cw, ch),
              );
            },
          ),
        ),
        if (_soundPlayerVisible)
          Consumer<QuranPlaybackService>(
            builder: (context, playback, _) => QuranSoundPlayer(
              visible: true,
              onClose: () => setState(() => _soundPlayerVisible = false),
              onPlayFirstAyah: _onPlayFirstAyah,
              currentAyah: playback.currentAyah != null
                  ? (
                      surah: playback.currentAyah!.surah,
                      ayah: playback.currentAyah!.ayah
                    )
                  : null,
              isPlaying: playback.isPlaying,
              isPaused: playback.isPaused,
              playbackSpeed: playback.playbackSpeed,
              selectedReciterKey: playback.selectedReciterKey,
              repeatMode: playback.repeatMode,
              onPlayPause: () async {
                if (playback.isPaused) {
                  await playback.resume();
                } else {
                  await playback.pause();
                }
              },
              onStop: playback.stop,
              onSpeedChange: playback.setSpeed,
              onReciterChange: (key) async {
                await playback.setReciter(key);
                if (!mounted) return;
                final saved = playback.currentAyah;
                if (saved != null) {
                  playback.playAyah(saved.surah, saved.ayah);
                }
              },
              onRepeatModeChange: playback.setRepeatMode,
              preloadProgress: playback.preloadProgress,
            ),
          ),
      ],
    );

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (bool didPop, dynamic result) {
        if (!didPop) widget.onSwitchToSurahView();
      },
      child: Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      body: Stack(
        children: [
          isLandscape
              ? MediaQuery.removePadding(
                  context: context,
                  removeTop: true,
                  child: Padding(
                    padding: EdgeInsets.only(
                      left: mq.padding.left > 0
                          ? mq.padding.left
                          : scaleSize(context, 24),
                      right: mq.padding.right > 0
                          ? mq.padding.right
                          : scaleSize(context, 24),
                    ),
                    child: columnChild,
                  ),
                )
              : SafeArea(child: columnChild),
          if (_showQuranIndex)
            QuranIndexModal(
              visible: true,
              onClose: () => setState(() => _showQuranIndex = false),
              currentPage: _currentPage,
              pageInfoSurah: _pageInfoSurah,
              pageInfoAyah: _pageInfoAyah,
              onPreviewPage: (page) {
                setState(() => _currentPage = page);
                _updatePageSurahInfo(page);
              },
              onCommitPage: (page) {
                setState(() {
                  _currentPage = page;
                  _showQuranIndex = false;
                });
                _saveLastPage();
                _checkLocalImage();
                _updatePageSurahInfo(page);
              },
            ),
        ],
      ),
    ),
    );
  }

  /// Portrait: sayfa contain ile ortada, overlay üstünde.
  Widget _buildPortraitPageContent(double cw, double ch) {
    return Stack(
      alignment: Alignment.topCenter,
      children: [
        _buildPageImage(),
        FutureBuilder<AyahPageData?>(
          future: getAyahCoordinatesForPage(_currentPage),
          builder: (context, snapshot) {
            if (!snapshot.hasData || snapshot.data == null)
              return const SizedBox.shrink();
            final data = snapshot.data!;
            final rect = _getDisplayedImageRect(
                cw, ch, data.imageWidth, data.imageHeight);
            return Positioned(
              left: rect.left,
              top: rect.top,
              width: rect.width,
              height: rect.height,
              child: Stack(
                clipBehavior: Clip.none,
                children: [
                  _buildSajdahHighlightOverlay(
                      context, data, rect.width, rect.height),
                  _buildLongPressHighlightOverlay(
                      data, rect.width, rect.height),
                  _buildHighlightOverlay(data, rect.width, rect.height),
                  ..._buildAyahHighlightTapTargets(
                    data,
                    data.imageWidth,
                    data.imageHeight,
                    rect.width,
                    rect.height,
                  ),
                ],
              ),
            );
          },
        ),
      ],
    );
  }

  /// Yatay: sayfa tam genişlik (sağdan sola), dikey scroll ile altta kalan görünür.
  Widget _buildLandscapePageContent(double cw, double ch) {
    return FutureBuilder<AyahPageData?>(
      future: getAyahCoordinatesForPage(_currentPage),
      builder: (context, snapshot) {
        if (!snapshot.hasData || snapshot.data == null) {
          return Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const CircularProgressIndicator(color: Color(0xFF6366F1)),
                SizedBox(height: scaleSize(context, 12)),
                Text(
                  AppLocalizations.t(context, 'loading'),
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: scaleFont(context, 14),
                    color: Color(0xFF64748B),
                  ),
                ),
              ],
            ),
          );
        }
        final data = snapshot.data!;
        final contentHeight = cw * (data.imageHeight / data.imageWidth);
        final rect = _getDisplayedImageRect(
            cw, contentHeight, data.imageWidth, data.imageHeight);
        return SingleChildScrollView(
          child: SizedBox(
            width: cw,
            height: contentHeight,
            child: Stack(
              alignment: Alignment.topCenter,
              children: [
                _buildPageImage(),
                Positioned(
                  left: rect.left,
                  top: rect.top,
                  width: rect.width,
                  height: rect.height,
                  child: Stack(
                    clipBehavior: Clip.none,
                    children: [
                      _buildSajdahHighlightOverlay(
                          context, data, rect.width, rect.height),
                      _buildLongPressHighlightOverlay(
                          data, rect.width, rect.height),
                      _buildHighlightOverlay(data, rect.width, rect.height),
                      ..._buildAyahHighlightTapTargets(
                        data,
                        data.imageWidth,
                        data.imageHeight,
                        rect.width,
                        rect.height,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildPageImage() {
    final url = getMushafPageUrl(_currentPage);
    if (_localImagePath != null) {
      return Image.file(
        File(_localImagePath!),
        fit: BoxFit.contain,
        alignment: Alignment.topCenter,
        width: double.infinity,
        height: double.infinity,
      );
    }
    return Image.network(
      url,
      fit: BoxFit.contain,
      alignment: Alignment.topCenter,
      width: double.infinity,
      height: double.infinity,
      loadingBuilder: (context, child, loadingProgress) {
        if (loadingProgress == null) return child;
        return Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              CircularProgressIndicator(
                value: loadingProgress.expectedTotalBytes != null
                    ? loadingProgress.cumulativeBytesLoaded /
                        (loadingProgress.expectedTotalBytes ?? 1)
                    : null,
                color: const Color(0xFF6366F1),
              ),
              SizedBox(height: scaleSize(context, 12)),
              Text(
                AppLocalizations.t(context, 'loading'),
                style: GoogleFonts.plusJakartaSans(
                  fontSize: scaleFont(context, 14),
                  color: const Color(0xFF64748B),
                ),
              ),
            ],
          ),
        );
      },
      errorBuilder: (_, __, ___) => Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.broken_image_outlined,
                size: scaleSize(context, 48), color: Colors.grey),
            SizedBox(height: scaleSize(context, 8)),
            Text(
              AppLocalizations.t(context, 'error'),
              style: GoogleFonts.plusJakartaSans(
                  fontSize: scaleFont(context, 14), color: Colors.grey),
            ),
          ],
        ),
      ),
    );
  }

  void _onBookmarkPress() {
    _showBookmarkSheet(context);
  }

  Future<void> _showBookmarkSheet(BuildContext context) async {
    String t(String k) => AppLocalizations.t(context, k);
    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
        ),
        padding: EdgeInsets.all(scaleSize(context, 20)),
        child: SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (_bookmark &&
                  _bookmarkSurah != null &&
                  _bookmarkAyah != null) ...[
                Text('${t('page')} $_currentPage',
                    style: GoogleFonts.plusJakartaSans(fontSize: scaleFont(context, 16))),
                SizedBox(height: scaleSize(context, 12)),
                ElevatedButton(
                  onPressed: () async {
                    final page = await getPageForSurahAyah(
                        _bookmarkSurah!, _bookmarkAyah!);
                    if (!mounted) return;
                    Navigator.pop(ctx);
                    if (page != null && mounted) {
                      setState(() => _currentPage = page);
                      _saveLastPage();
                      _checkLocalImage();
                    }
                  },
                  child: Text(t('goToBookmark'),
                      style: GoogleFonts.plusJakartaSans(
                          fontSize: scaleFont(context, 14),
                          fontWeight: FontWeight.w600,
                          color: Colors.white)),
                ),
                TextButton(
                  onPressed: () async {
                    Navigator.pop(ctx);
                    await _toggleBookmark(_bookmarkSurah!, _bookmarkAyah!);
                  },
                  child: Text(t('removeBookmark'),
                      style: GoogleFonts.plusJakartaSans(
                          fontSize: scaleFont(context, 14),
                          fontWeight: FontWeight.w500,
                          color: const Color(0xFF6366F1))),
                ),
              ] else
                Text(t('noBookmark'),
                    style: GoogleFonts.plusJakartaSans(fontSize: scaleFont(context, 14))),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildMushafDownloadBanner(BuildContext context) {
    final p = _mushafDownloadProgress!;
    final progress = p.total > 0 ? (p.current / p.total).clamp(0.0, 1.0) : 0.0;
    String t(String k) => AppLocalizations.t(context, k);
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
                            color: const Color(0xFFC7D2FE).withValues(alpha: 0.5),
                            borderRadius: BorderRadius.circular(scaleSize(context, 3)),
                          ),
                        ),
                        ClipRRect(
                          borderRadius: BorderRadius.circular(scaleSize(context, 3)),
                          child: SizedBox(
                            width: w * progress,
                            height: scaleSize(context, 6),
                            child: Container(
                              decoration: const BoxDecoration(color: Color(0xFF6366F1)),
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

  void _onOpenSettings() {
    _showViewMenuSheet(context);
  }

  Future<void> _showViewMenuSheet(BuildContext context) async {
    String t(String k) => AppLocalizations.t(context, k);
    final cachedCount = await _getCachedMushafPageCount();

    if (!mounted) return;
    await showDialog<void>(
      context: context,
      builder: (ctx) => Center(
        child: Material(
          borderRadius: BorderRadius.circular(scaleSize(context, 16)),
          color: Colors.white,
          elevation: 8,
          child: ConstrainedBox(
            constraints: BoxConstraints(maxWidth: scaleSize(context, 280)),
            child: Padding(
              padding: EdgeInsets.all(scaleSize(context, 16)),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: const Icon(Icons.download, color: Color(0xFF6366F1)),
                    title: Text(t('downloadSurahPages'),
                        style: GoogleFonts.plusJakartaSans(
                            fontSize: scaleFont(context, 15),
                            fontWeight: FontWeight.w500,
                            color: const Color(0xFF1E293B))),
                    onTap: () async {
                      Navigator.pop(ctx);
                      await _showDownloadScopeDialog(context);
                    },
                  ),
                  if (cachedCount > 0) ...[
                    ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: Icon(Icons.check_circle, color: Colors.green.shade700, size: 24),
                      title: Text('${t('downloadCompleted')} ($cachedCount ${t('page')})',
                          style: GoogleFonts.plusJakartaSans(
                              fontSize: scaleFont(context, 15),
                              fontWeight: FontWeight.w500,
                              color: const Color(0xFF1E293B))),
                    ),
                    ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: const Icon(Icons.delete_outline, color: Color(0xFF64748B)),
                      title: Text(t('clearCache'),
                          style: GoogleFonts.plusJakartaSans(
                              fontSize: scaleFont(context, 15),
                              fontWeight: FontWeight.w500,
                              color: const Color(0xFF1E293B))),
                      onTap: () async {
                        Navigator.pop(ctx);
                        await _clearMushafCache();
                      },
                    ),
                  ] else
                    ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: const Icon(Icons.delete_outline, color: Color(0xFF64748B)),
                      title: Text(t('clearCache'),
                          style: GoogleFonts.plusJakartaSans(
                              fontSize: scaleFont(context, 15),
                              fontWeight: FontWeight.w500,
                              color: const Color(0xFF1E293B))),
                      onTap: () async {
                        Navigator.pop(ctx);
                        await _clearMushafCache();
                      },
                    ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Future<int> _getCachedMushafPageCount() async {
    try {
      final dir = await getApplicationDocumentsDirectory();
      final mushafDir = Directory('${dir.path}/mushaf');
      if (!await mushafDir.exists()) return 0;
      int count = 0;
      await for (final _ in mushafDir.list()) count++;
      return count;
    } catch (_) {
      return 0;
    }
  }

  Future<void> _showDownloadScopeDialog(BuildContext context) async {
    String t(String k) => AppLocalizations.t(context, k);
    final juz = calculateJuzByPage(_currentPage);
    final scope = await showDialog<String>(
      context: context,
      builder: (ctx) => Center(
        child: Material(
          borderRadius: BorderRadius.circular(scaleSize(context, 16)),
          color: Colors.white,
          elevation: 8,
          child: ConstrainedBox(
            constraints: BoxConstraints(maxWidth: scaleSize(context, 280)),
            child: Padding(
              padding: EdgeInsets.all(scaleSize(context, 16)),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Padding(
                    padding: EdgeInsets.only(bottom: scaleSize(context, 12)),
                    child: Text(
                      t('downloadSurahPages'),
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: scaleFont(context, 16),
                        fontWeight: FontWeight.w600,
                        color: const Color(0xFF1E293B),
                      ),
                    ),
                  ),
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    title: Text('${t('page')} $_currentPage',
                        style: GoogleFonts.plusJakartaSans(
                            fontSize: scaleFont(context, 15),
                            fontWeight: FontWeight.w500,
                            color: const Color(0xFF1E293B))),
                    onTap: () => Navigator.pop(ctx, 'page'),
                  ),
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    title: Text('${t('juz')} $juz',
                        style: GoogleFonts.plusJakartaSans(
                            fontSize: scaleFont(context, 15),
                            fontWeight: FontWeight.w500,
                            color: const Color(0xFF1E293B))),
                    onTap: () => Navigator.pop(ctx, 'juz'),
                  ),
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    title: Text(t('fullQuran'),
                        style: GoogleFonts.plusJakartaSans(
                            fontSize: scaleFont(context, 15),
                            fontWeight: FontWeight.w500,
                            color: const Color(0xFF1E293B))),
                    onTap: () => Navigator.pop(ctx, 'full'),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
    if (scope == null || !mounted) return;
    List<int> pages;
    switch (scope) {
      case 'page':
        pages = [_currentPage];
        break;
      case 'juz':
        pages = List.generate(
          getJuzEndPage(juz) - getJuzStartPage(juz) + 1,
          (i) => getJuzStartPage(juz) + i,
        );
        break;
      case 'full':
        pages = List.generate(totalMushafPages, (i) => i + 1);
        break;
      default:
        return;
    }
    setState(() => _mushafDownloadProgress = (current: 0, total: pages.length));
    final result = await downloadMushafPages(
      pages,
      onProgress: (current, total) {
        if (mounted) setState(() => _mushafDownloadProgress = (current: current, total: total));
      },
    );
    if (!mounted) return;
    setState(() => _mushafDownloadProgress = null);
    if (result.success) {
      _checkLocalImage();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(t('downloadCompleted'),
            style: GoogleFonts.plusJakartaSans(
                fontSize: scaleFont(context, 14),
                color: Colors.white))),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(result.error ?? t('error'),
            style: GoogleFonts.plusJakartaSans(
                fontSize: scaleFont(context, 14),
                color: Colors.white))),
      );
    }
  }

  Future<void> _clearMushafCache() async {
    try {
      final dir = await getApplicationDocumentsDirectory();
      final mushafDir = Directory('${dir.path}/mushaf');
      if (await mushafDir.exists()) {
        await for (final f in mushafDir.list()) {
          if (f is File) await f.delete();
        }
      }
      setState(() => _localImagePath = null);
      if (mounted)
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(AppLocalizations.t(context, 'success'),
                style: GoogleFonts.plusJakartaSans(
                    fontSize: scaleFont(context, 14),
                    color: Colors.white))));
    } catch (_) {
      if (mounted)
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(AppLocalizations.t(context, 'error'),
                style: GoogleFonts.plusJakartaSans(
                    fontSize: scaleFont(context, 14),
                    color: Colors.white))));
    }
  }

  Future<void> _onPlayFirstAyah() async {
    final start = await getPageStartAyah(_currentPage);
    if (start == null || !mounted) return;
    await context
        .read<QuranPlaybackService>()
        .playAyah(start.surah, start.ayah);
    setState(() => _soundPlayerVisible = true);
  }
}
