import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../utils/scaling.dart';

// Arapça ayet numarası (1 -> ١, 12 -> ١٢). RN ile aynı.
String _toArabicVerseNum(int n) {
  const digits = '٠١٢٣٤٥٦٧٨٩';
  return n.toString().split('').map((d) => digits[int.parse(d)]).join('');
}

// Ayet ayracı: ۝ + Arapça numara. İnce boşluk (\u2009) ile ayet gülü ile metin arasındaki boşluk azaltıldı.
String _verseSeparator(int verseIndex1Based) => '\u2009۝${_toArabicVerseNum(verseIndex1Based)}\u2009';

/// Full surah in one card (Fatiha or zammi). Matches RN PrayerScreen card: step number, action, play, verse separators ۝١ ۝٢, highlight.
class PrayerSurahCard extends StatelessWidget {
  final int stepNumber;
  final String actionLabel;
  final int surahNumber;
  final List<String> verses;
  final List<String?> transliterations;
  final String verseTextMode;
  final ValueChanged<String> onVerseTextMode;
  final VoidCallback onPlayPause;
  final bool isPlaying;
  final bool isCached;
  final bool showBesmele;
  final String? besmeleArabic;
  final String? besmeleTransliteration;
  /// Zammi only: surah name (e.g. "An-Nas") and tap to change.
  final String? zammiSurahName;
  final VoidCallback? onZammiTap;
  /// Current playing ayah for highlight (#dcfce7). RN stepArabicHighlight / stepTransliterationHighlight.
  final int? currentAyahSurah;
  final int? currentAyahAyah;
  final VoidCallback? onPronunciationGuideTap;
  /// Verse-by-verse translation (from locale). Shown below Arabic/transliteration.
  final List<String>? meanings;

  const PrayerSurahCard({
    super.key,
    required this.stepNumber,
    required this.actionLabel,
    required this.surahNumber,
    required this.verses,
    required this.transliterations,
    required this.verseTextMode,
    required this.onVerseTextMode,
    required this.onPlayPause,
    required this.isPlaying,
    this.isCached = false,
    this.showBesmele = false,
    this.besmeleArabic,
    this.besmeleTransliteration,
    this.zammiSurahName,
    this.onZammiTap,
    this.currentAyahSurah,
    this.currentAyahAyah,
    this.onPronunciationGuideTap,
    this.meanings,
  });

  static const double _sideButtonHalfOutside = 14;
  static const double _cardRadius = 16;
  static const double _cardPadding = 16;
  static const double _cardMarginBottom = 5;
  static const Color _highlightBg = Color(0xFFDCFCE7);

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(scaleSize(context, _cardRadius)),
      child: Container(
        margin: EdgeInsets.only(bottom: scaleSize(context, _cardMarginBottom)),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(scaleSize(context, _cardRadius)),
          border: Border.all(
            color: isPlaying ? const Color(0xFF6366F1).withValues(alpha: 0.5) : const Color(0xFFE2E8F0),
            width: isPlaying ? 2.0 : 1.2,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.05),
              offset: Offset(0, scaleSize(context, 2)),
              blurRadius: scaleSize(context, 8),
            ),
          ],
        ),
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            Padding(
              padding: EdgeInsets.fromLTRB(
                scaleSize(context, 20),
                scaleSize(context, _cardPadding),
                scaleSize(context, _cardPadding),
                scaleSize(context, _cardPadding),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _buildHeader(context),
                  SizedBox(height: scaleSize(context, 12)),
                  if (verseTextMode == 'arabic') _buildArabicContent(context),
                  if (verseTextMode == 'transliteration') _buildTransliterationContent(context),
                  if (meanings != null && meanings!.isNotEmpty) _buildMeaningsContent(context),
                ],
              ),
            ),
            Positioned(
              left: -scaleSize(context, _sideButtonHalfOutside),
              top: 0,
              bottom: 0,
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  _SideModeButton(
                    label: 'ب',
                    isActive: verseTextMode == 'arabic',
                    onTap: () => onVerseTextMode('arabic'),
                  ),
                  SizedBox(height: scaleSize(context, 8)),
                  _SideModeButton(
                    label: 'Aa',
                    isActive: verseTextMode == 'transliteration',
                    onTap: () => onVerseTextMode('transliteration'),
                  ),
                  SizedBox(height: scaleSize(context, 8)),
                  _SideModeButton(
                    label: '!',
                    isActive: false,
                    onTap: onPronunciationGuideTap ?? () {},
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Container(
          width: scaleSize(context, 32),
          height: scaleSize(context, 32),
          decoration: BoxDecoration(
            color: const Color(0xFFEEF2FF),
            borderRadius: BorderRadius.circular(scaleSize(context, 16)),
          ),
          alignment: Alignment.center,
          child: Text(
            '$stepNumber',
            style: GoogleFonts.plusJakartaSans(
              fontSize: scaleFont(context, 17),
              fontWeight: FontWeight.bold,
              color: const Color(0xFF6366F1),
            ),
          ),
        ),
        SizedBox(width: scaleSize(context, 12)),
        Expanded(
          child: Text(
            actionLabel,
            style: GoogleFonts.plusJakartaSans(
              fontSize: scaleFont(context, 19),
              fontWeight: FontWeight.w600,
              color: const Color(0xFF1E293B),
            ),
          ),
        ),
        if (zammiSurahName != null && onZammiTap != null)
          GestureDetector(
            onTap: onZammiTap,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  zammiSurahName!,
                  style: GoogleFonts.plusJakartaSans(
                    color: const Color(0xFF6366F1),
                    fontSize: scaleFont(context, 11),
                    fontWeight: FontWeight.w600,
                  ),
                ),
                SizedBox(width: scaleSize(context, 4)),
                Icon(Icons.swap_horiz, size: scaleSize(context, 14), color: const Color(0xFF6366F1)),
              ],
            ),
          ),
        if (isCached) ...[
          SizedBox(width: scaleSize(context, 6)),
          Icon(Icons.offline_bolt, size: scaleSize(context, 14), color: const Color(0xFF94A3B8)),
        ],
        SizedBox(width: scaleSize(context, 8)),
        GestureDetector(
          onTap: onPlayPause,
          child: Container(
            width: scaleSize(context, 32),
            height: scaleSize(context, 32),
            decoration: BoxDecoration(
              color: const Color(0xFFEEF2FF),
              borderRadius: BorderRadius.circular(16),
            ),
            alignment: Alignment.center,
            child: Icon(
              currentAyahSurah == surahNumber && isPlaying ? Icons.pause : Icons.play_arrow,
              size: 18,
              color: const Color(0xFF6366F1),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildArabicContent(BuildContext context) {
    final baseStyle = GoogleFonts.notoNaskhArabic(
      fontWeight: FontWeight.w400,
      fontSize: scaleFont(context, 24),
      height: scaleSize(context, 38) / scaleFont(context, 24),
      color: const Color(0xFF1E293B),
    );
    bool highlightVerse(int verse1Based) =>
        currentAyahSurah == surahNumber && currentAyahAyah == verse1Based;

    if (showBesmele && (besmeleArabic ?? '').isNotEmpty) {
      final hiliteBesmele = currentAyahSurah == surahNumber && currentAyahAyah == 0;
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            padding: hiliteBesmele ? EdgeInsets.symmetric(horizontal: scaleSize(context, 4), vertical: scaleSize(context, 2)) : null,
            decoration: hiliteBesmele ? BoxDecoration(color: _highlightBg, borderRadius: BorderRadius.circular(4)) : null,
            child: Text(
              besmeleArabic!,
              style: baseStyle,
              textAlign: TextAlign.right,
              textDirection: TextDirection.rtl,
            ),
          ),
          SizedBox(height: scaleSize(context, 10)),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: RichText(
                  textDirection: TextDirection.rtl,
                  textAlign: TextAlign.justify,
                  text: TextSpan(
                    style: baseStyle,
                    children: [
                      for (var i = 0; i < verses.length; i++) ...[
                        if (i > 0) const TextSpan(text: ' '),
                        TextSpan(
                          text: '${verses[i]}${_verseSeparator(i + 1)}',
                          style: highlightVerse(i + 1) ? baseStyle.copyWith(backgroundColor: _highlightBg) : baseStyle,
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ],
          ),
        ],
      );
    }
    if (verses.isEmpty) return const SizedBox.shrink();
    if (verses.length == 1) {
      return Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Text(
              '${verses[0]}${_verseSeparator(1)}',
              style: baseStyle.copyWith(
                backgroundColor: highlightVerse(1) ? _highlightBg : null,
              ),
              textAlign: TextAlign.justify,
              textDirection: TextDirection.rtl,
            ),
          ),
        ],
      );
    }
    // Fatiha: ilk satır sadece besmele (1. ayet), sonrası tek blokta tam genişlikte sarılıyor
    final firstLine = '${verses[0]}${_verseSeparator(1)}';
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: RichText(
            textDirection: TextDirection.rtl,
            textAlign: TextAlign.justify,
            text: TextSpan(
              style: baseStyle,
              children: [
                TextSpan(
                  text: '$firstLine\n',
                  style: highlightVerse(1) ? baseStyle.copyWith(backgroundColor: _highlightBg) : baseStyle,
                ),
                ..._buildVerseSpans(verses, baseStyle, highlightVerse, 1),
              ],
            ),
          ),
        ),
      ],
    );
  }

  List<TextSpan> _buildVerseSpans(List<String> verses, TextStyle baseStyle, bool Function(int) highlightVerse, int startIndex) {
    final spans = <TextSpan>[];
    for (var i = startIndex; i < verses.length; i++) {
      if (i > startIndex) spans.add(const TextSpan(text: ' '));
      spans.add(TextSpan(
        text: '${verses[i]}${_verseSeparator(i + 1)}',
        style: highlightVerse(i + 1) ? baseStyle.copyWith(backgroundColor: _highlightBg) : baseStyle,
      ));
    }
    return spans;
  }

  Widget _buildTransliterationContent(BuildContext context) {
    final baseStyle = GoogleFonts.plusJakartaSans(
      fontSize: scaleFont(context, 15),
      height: scaleSize(context, 23) / scaleFont(context, 15),
      color: const Color(0xFF64748B),
      fontStyle: FontStyle.italic,
    );
    bool highlightVerse(int verse1Based) =>
        currentAyahSurah == surahNumber && currentAyahAyah == verse1Based;

    final spans = <TextSpan>[];
    // Besmele (verse 0) if shown
    if (showBesmele && (besmeleTransliteration ?? '').isNotEmpty) {
      final hiliteBesmele = currentAyahSurah == surahNumber && currentAyahAyah == 0;
      spans.add(TextSpan(
        text: besmeleTransliteration!,
        style: hiliteBesmele ? baseStyle.copyWith(backgroundColor: _highlightBg) : baseStyle,
      ));
      if (verses.isNotEmpty) spans.add(TextSpan(text: ' ', style: baseStyle));
    }
    // Verses: flow on same line, verse-by-verse highlight
    for (var i = 0; i < verses.length; i++) {
      final tr = i < transliterations.length ? transliterations[i] : null;
      if (tr == null || tr.isEmpty) continue;
      if (spans.isNotEmpty && spans.last.text != ' ') spans.add(TextSpan(text: ' ', style: baseStyle));
      spans.add(TextSpan(
        text: tr,
        style: highlightVerse(i + 1) ? baseStyle.copyWith(backgroundColor: _highlightBg) : baseStyle,
      ));
    }
    if (spans.isEmpty) return const SizedBox.shrink();
    return RichText(
      textAlign: TextAlign.start,
      text: TextSpan(style: baseStyle, children: spans),
    );
  }

  Widget _buildMeaningsContent(BuildContext context) {
    final style = GoogleFonts.plusJakartaSans(
      fontSize: scaleFont(context, 15),
      height: 1.5,
      color: const Color(0xFF475569),
    );
    bool highlightVerse(int verse1Based) =>
        currentAyahSurah == surahNumber && currentAyahAyah == verse1Based;
    // Flow translation: one paragraph, verse-by-verse highlight
    final spans = <TextSpan>[];
    for (var i = 0; i < meanings!.length; i++) {
      final text = meanings![i];
      if (text.isEmpty) continue;
      if (spans.isNotEmpty) spans.add(TextSpan(text: ' ', style: style));
      spans.add(TextSpan(
        text: text,
        style: highlightVerse(i + 1) ? style.copyWith(backgroundColor: _highlightBg) : style,
      ));
    }
    if (spans.isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: EdgeInsets.only(top: scaleSize(context, 12)),
      child: RichText(
        textAlign: TextAlign.start,
        text: TextSpan(style: style, children: spans),
      ),
    );
  }
}

/// Tahiyyat (Tashahhud) card – RN step.surahNumber === 2. Static Arabic/transliteration, meaning, ب/Aa/!.
class PrayerTahiyyatCard extends StatelessWidget {
  final int stepNumber;
  final String actionLabel;
  final String verseTextMode;
  final ValueChanged<String> onVerseTextMode;
  final VoidCallback? onPronunciationGuideTap;
  final String arabicText;
  final String transliterationText;
  final String meaningText;

  const PrayerTahiyyatCard({
    super.key,
    required this.stepNumber,
    required this.actionLabel,
    required this.verseTextMode,
    required this.onVerseTextMode,
    this.onPronunciationGuideTap,
    required this.arabicText,
    required this.transliterationText,
    required this.meaningText,
  });

  static const double _sideButtonHalfOutside = 14;
  static const double _cardRadius = 16;
  static const double _cardPadding = 16;
  static const double _cardMarginBottom = 5;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(scaleSize(context, _cardRadius)),
      child: Container(
        margin: EdgeInsets.only(bottom: scaleSize(context, _cardMarginBottom)),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(scaleSize(context, _cardRadius)),
          border: Border.all(color: const Color(0xFFE2E8F0), width: 1.2),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.05),
              offset: Offset(0, scaleSize(context, 2)),
              blurRadius: scaleSize(context, 8),
            ),
          ],
        ),
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            Padding(
              padding: EdgeInsets.fromLTRB(
                scaleSize(context, 20),
                scaleSize(context, _cardPadding),
                scaleSize(context, _cardPadding),
                scaleSize(context, _cardPadding),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _buildHeader(context),
                  SizedBox(height: scaleSize(context, 12)),
                  if (verseTextMode == 'arabic')
                    Align(
                      alignment: Alignment.centerRight,
                      child: Text(
                        arabicText,
                        style: GoogleFonts.notoNaskhArabic(
                          fontWeight: FontWeight.w400,
                          fontSize: scaleFont(context, 24),
                          height: 1.5,
                          color: const Color(0xFF1E293B),
                        ),
                        textAlign: TextAlign.right,
                        textDirection: TextDirection.rtl,
                      ),
                    ),
                  if (verseTextMode == 'transliteration')
                    Text(
                      transliterationText,
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: scaleFont(context, 15),
                        height: 1.5,
                        color: const Color(0xFF64748B),
                        fontStyle: FontStyle.italic,
                      ),
                    ),
                  SizedBox(height: scaleSize(context, 10)),
                  Text(
                    meaningText,
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: scaleFont(context, 15),
                      height: 1.5,
                      color: const Color(0xFF475569),
                    ),
                  ),
                ],
              ),
            ),
            Positioned(
              left: -scaleSize(context, _sideButtonHalfOutside),
              top: 0,
              bottom: 0,
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  _SideModeButton(
                    label: 'ب',
                    isActive: verseTextMode == 'arabic',
                    onTap: () => onVerseTextMode('arabic'),
                  ),
                  SizedBox(height: scaleSize(context, 8)),
                  _SideModeButton(
                    label: 'Aa',
                    isActive: verseTextMode == 'transliteration',
                    onTap: () => onVerseTextMode('transliteration'),
                  ),
                  SizedBox(height: scaleSize(context, 8)),
                  _SideModeButton(
                    label: '!',
                    isActive: false,
                    onTap: onPronunciationGuideTap ?? () {},
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    return Row(
      children: [
        Container(
          width: scaleSize(context, 32),
          height: scaleSize(context, 32),
          decoration: BoxDecoration(
            color: const Color(0xFFEEF2FF),
            borderRadius: BorderRadius.circular(scaleSize(context, 16)),
          ),
          alignment: Alignment.center,
          child: Text(
            '$stepNumber',
            style: GoogleFonts.plusJakartaSans(
              fontSize: scaleFont(context, 17),
              fontWeight: FontWeight.bold,
              color: const Color(0xFF6366F1),
            ),
          ),
        ),
        SizedBox(width: scaleSize(context, 12)),
        Expanded(
          child: Text(
            actionLabel,
            style: GoogleFonts.plusJakartaSans(
              fontSize: scaleFont(context, 19),
              fontWeight: FontWeight.w600,
              color: const Color(0xFF1E293B),
            ),
          ),
        ),
      ],
    );
  }
}

/// Single-verse card for Prayer screen (Fatiha / zammi), styled like surah view:
/// verse number, Arabic/transliteration toggle (ب, Aa), play button, text.
class PrayerVerseCard extends StatelessWidget {
  final int surahNumber;
  final int verseNumber;
  final String arabicText;
  final String? transliterationText;
  final String verseTextMode; // 'arabic' | 'transliteration'
  final ValueChanged<String> onVerseTextMode;
  final VoidCallback onPlayPause;
  final bool isCurrentAyah;
  final bool isPlaying;
  final bool isCached;

  const PrayerVerseCard({
    super.key,
    required this.surahNumber,
    required this.verseNumber,
    required this.arabicText,
    this.transliterationText,
    required this.verseTextMode,
    required this.onVerseTextMode,
    required this.onPlayPause,
    required this.isCurrentAyah,
    required this.isPlaying,
    this.isCached = false,
  });

  @override
  Widget build(BuildContext context) {
    const double sideButtonHalfOutside = 14;
    return Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(scaleSize(context, 20)),
      child: Container(
        margin: EdgeInsets.only(bottom: scaleSize(context, 12)),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(scaleSize(context, 20)),
          border: Border.all(
            color: isCurrentAyah
                ? const Color(0xFF6366F1).withValues(alpha: 0.5)
                : const Color(0xFFE2E8F0),
            width: isCurrentAyah ? 2.0 : 1.2,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.06),
              offset: Offset(0, scaleSize(context, 2)),
              blurRadius: scaleSize(context, 8),
            ),
            BoxShadow(
              color: const Color(0xFF6366F1).withValues(alpha: 0.04),
              offset: Offset(0, scaleSize(context, 4)),
              blurRadius: scaleSize(context, 12),
            ),
          ],
        ),
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            Padding(
              padding: EdgeInsets.fromLTRB(
                scaleSize(context, 12),
                scaleSize(context, 12),
                scaleSize(context, 12),
                scaleSize(context, 12),
              ),
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
                            width: scaleSize(context, 2),
                          ),
                        ),
                        alignment: Alignment.center,
                        child: Text(
                          '$verseNumber',
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: scaleFont(context, 14),
                            fontWeight: FontWeight.bold,
                            color: const Color(0xFF6366F1),
                          ),
                        ),
                      ),
                      if (isCached) ...[
                        SizedBox(width: scaleSize(context, 6)),
                        Icon(
                          Icons.offline_bolt,
                          size: scaleSize(context, 14),
                          color: const Color(0xFF94A3B8),
                        ),
                      ],
                      const Spacer(),
                      IconButton(
                        icon: Icon(
                          isCurrentAyah && isPlaying
                              ? Icons.pause_circle
                              : Icons.play_circle,
                          size: scaleSize(context, 28),
                          color: const Color(0xFF6366F1),
                        ),
                        onPressed: onPlayPause,
                        padding: EdgeInsets.zero,
                        constraints: BoxConstraints(
                          minWidth: scaleSize(context, 34),
                          minHeight: scaleSize(context, 34),
                        ),
                        style: IconButton.styleFrom(
                          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        ),
                      ),
                    ],
                  ),
                  SizedBox(height: scaleSize(context, 12)),
                  if (verseTextMode == 'arabic' && arabicText.isNotEmpty)
                    Container(
                      padding: isCurrentAyah
                          ? EdgeInsets.symmetric(
                              horizontal: scaleSize(context, 4),
                              vertical: scaleSize(context, 4),
                            )
                          : null,
                      decoration: isCurrentAyah
                          ? BoxDecoration(
                              color: const Color(0xFF15803D).withValues(alpha: 0.22),
                              borderRadius: BorderRadius.circular(scaleSize(context, 8)),
                            )
                          : null,
                      child: Text(
                        arabicText,
                        style: GoogleFonts.notoNaskhArabic(
                          fontWeight: FontWeight.w400,
                          fontSize: scaleFont(context, 24),
                          height: 1.75,
                          color: const Color(0xFF1E293B),
                        ),
                        textAlign: TextAlign.justify,
                        textDirection: TextDirection.rtl,
                      ),
                    ),
                  if (verseTextMode == 'transliteration' &&
                      (transliterationText ?? '').isNotEmpty)
                    Container(
                      padding: isCurrentAyah
                          ? EdgeInsets.symmetric(
                              horizontal: scaleSize(context, 8),
                              vertical: scaleSize(context, 6),
                            )
                          : null,
                      decoration: isCurrentAyah
                          ? BoxDecoration(
                              color: const Color(0xFF15803D).withValues(alpha: 0.22),
                              borderRadius: BorderRadius.circular(scaleSize(context, 8)),
                            )
                          : null,
                      child: Text(
                        transliterationText!,
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: scaleFont(context, 14),
                          height: 1.6,
                          color: const Color(0xFF475569),
                          fontStyle: FontStyle.italic,
                        ),
                      ),
                    ),
                ],
              ),
            ),
            Positioned(
              left: -scaleSize(context, sideButtonHalfOutside),
              top: 0,
              bottom: 0,
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  _SideModeButton(
                    label: 'ب',
                    isActive: verseTextMode == 'arabic',
                    onTap: () => onVerseTextMode('arabic'),
                  ),
                  SizedBox(height: scaleSize(context, 8)),
                  _SideModeButton(
                    label: 'Aa',
                    isActive: verseTextMode == 'transliteration',
                    onTap: () => onVerseTextMode('transliteration'),
                  ),
                ],
              ),
            ),
          ],
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
      color: Colors.white,
      borderRadius: BorderRadius.circular(scaleSize(context, 14)),
      elevation: 1,
      shadowColor: Colors.black,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(scaleSize(context, 14)),
        child: Container(
          width: scaleSize(context, 28),
          height: scaleSize(context, 28),
          alignment: Alignment.center,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(scaleSize(context, 14)),
            color: isActive ? const Color(0xFF6366F1) : Colors.white,
            border: Border.all(
              color: isActive ? const Color(0xFF6366F1) : const Color(0xFFE2E8F0),
            ),
          ),
          child: Text(
            label,
            style: GoogleFonts.plusJakartaSans(
              fontSize: scaleFont(context, 12),
              fontWeight: FontWeight.w600,
              color: isActive ? Colors.white : const Color(0xFF64748B),
            ),
          ),
        ),
      ),
    );
  }
}
