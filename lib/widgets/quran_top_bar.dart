// RN: components/QuranTopBar.js ile birebir aynı düzen ve fonksiyonlar.
// Portrait: Sol = toggle + 2 satır (Cüz/Sayfa | Sure adı), Sağ = arama, bookmark, index, 3nokta.
// Landscape : Sol = toggle + tek satır (Cüz • Sayfa • Sure), Sağ aynı (daha küçük ikonlar).

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../l10n/app_localizations.dart';
import '../contexts/quran_view_mode_provider.dart';
import '../utils/scaling.dart';

class QuranTopBar extends StatelessWidget {
  /// Birinci satır metni: "Cüz 1 • Sayfa 1"
  final String? pageInfoText;

  /// İkinci satır metni (portrait) / tek satır eki (landscape): "1. Al-Fatihah"
  /// Null ise ikinci satır gösterilmez.
  final String? surahInfoLine;

  /// SurahView modunda sure başlığı (pageInfoText'in yerini alır).
  final String? surahInfoText;

  final bool showSearchBar;
  final String searchQuery;
  final ValueChanged<String>? onSearchQueryChange;
  final bool searchExpanded;
  final VoidCallback? onSearchExpandedToggle;

  final VoidCallback? onBookmarkPress;
  final bool hasBookmark;

  final VoidCallback? onOpenQuranIndex;
  final bool showNavigateButton;

  final VoidCallback? onOpenDownload;
  final TextEditingController? searchController;

  /// Landscape modunu dışarıdan alır (MediaQuery.of(context).orientation ile hesaplanır).
  final bool isLandscape;

  /// Yatay modda bar sistem çubuğunun üzerinde durur; içerik bu kadar üstten boşluk alır.
  final double? statusBarTop;

  const QuranTopBar({
    super.key,
    this.pageInfoText,
    this.surahInfoLine,
    this.surahInfoText,
    this.showSearchBar = true,
    this.searchQuery = '',
    this.onSearchQueryChange,
    this.searchExpanded = false,
    this.onSearchExpandedToggle,
    this.onBookmarkPress,
    this.hasBookmark = false,
    this.onOpenQuranIndex,
    this.showNavigateButton = false,
    this.onOpenDownload,
    this.searchController,
    this.isLandscape = false,
    this.statusBarTop,
  });

  @override
  Widget build(BuildContext context) {
    String t(String k) => AppLocalizations.t(context, k);
    return Consumer<QuranViewModeProvider>(
      builder: (context, quranMode, _) =>
          _buildContent(context, quranMode, t),
    );
  }

  Widget _buildContent(
    BuildContext context,
    QuranViewModeProvider quranMode,
    String Function(String) t,
  ) {
    // En dış container mümkün olduğunca ince; yazı boyutları aynı kalır.
    final vPad = isLandscape ? scaleSize(context, 1) : scaleSize(context, 2);

    final content = Row(
        children: [
          // ── Sol bölüm: toggle + metin ──────────────────────────────────
          Expanded(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                // View-mode toggle (swap_vert ikonu, mavi arka plan)
                Padding(
                  padding: EdgeInsets.only(right: scaleSize(context, 6)),
                  child: GestureDetector(
                    onTap: () {
                      final nextMode = quranMode.isSurahBySurah
                          ? kQuranViewModePureQuran
                          : kQuranViewModeSurahBySurah;
                      quranMode.setViewMode(nextMode);
                    },
                    child: Container(
                      padding: EdgeInsets.symmetric(
                        horizontal:
                            scaleSize(context, isLandscape ? 4 : 6),
                        vertical: scaleSize(context, isLandscape ? 1 : 2),
                      ),
                      decoration: BoxDecoration(
                        color: const Color(0xFFEEF2FF),
                        borderRadius: BorderRadius.circular(
                            scaleSize(context, 8)),
                        border: Border.all(
                          color: const Color(0xFFE0E7FF),
                          width: scaleSize(context, 1.5),
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: const Color(0xFF6366F1)
                                .withValues(alpha: 0.1),
                            offset: Offset(0, scaleSize(context, 2)),
                            blurRadius: scaleSize(context, 4),
                          ),
                        ],
                      ),
                      child: Icon(
                        Icons.swap_vert,
                        size: scaleSize(context, isLandscape ? 12 : 16),
                        color: const Color(0xFF6366F1),
                      ),
                    ),
                  ),
                ),

                // Metin alanı
                Expanded(child: _buildInfoText(context)),
              ],
            ),
          ),

          // ── Sağ bölüm: arama, bookmark, index, 3 nokta ────────────────
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Arama (yalnızca showSearchBar=true ise)
              if (showSearchBar) ...[
                if (searchExpanded)
                  Padding(
                    padding:
                        EdgeInsets.only(right: scaleSize(context, 8)),
                    child: SizedBox(
                      width: scaleSize(context, 140),
                      child: TextField(
                        controller: searchController,
                        onChanged: onSearchQueryChange,
                        decoration: InputDecoration(
                          hintText: t('searchSurahs'),
                          isDense: true,
                          contentPadding: EdgeInsets.symmetric(
                            horizontal: scaleSize(context, 12),
                            vertical: scaleSize(context, 6),
                          ),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(
                                scaleSize(context, 20)),
                          ),
                          filled: true,
                          fillColor: const Color(0xFFF8FAFC),
                        ),
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: scaleFont(context, 14),
                          color: const Color(0xFF1E293B),
                        ),
                        autofocus: true,
                      ),
                    ),
                  ),
                IconButton(
                  onPressed: onSearchExpandedToggle,
                  icon: Icon(
                    searchExpanded ? Icons.close : Icons.search,
                    size: scaleSize(context, isLandscape ? 15 : 20),
                    color: searchExpanded
                        ? const Color(0xFF64748B)
                        : const Color(0xFF1E293B),
                  ),
                  style: IconButton.styleFrom(
                    minimumSize: Size(
                        scaleSize(context, isLandscape ? 24 : 28),
                        scaleSize(context, isLandscape ? 24 : 28)),
                    padding: EdgeInsets.zero,
                  ),
                ),
              ],

              // Bookmark
              IconButton(
                onPressed: onBookmarkPress ?? () {},
                icon: Icon(
                  hasBookmark ? Icons.bookmark : Icons.bookmark_border,
                  size: scaleSize(context, isLandscape ? 18 : 22),
                  color: hasBookmark
                      ? const Color(0xFFF59E0B)
                      : const Color(0xFF1E293B),
                ),
                style: IconButton.styleFrom(
                  minimumSize: Size(
                      scaleSize(context, isLandscape ? 24 : 28),
                      scaleSize(context, isLandscape ? 24 : 28)),
                  padding: EdgeInsets.zero,
                ),
              ),

              // Quran Index (sayfa/cüz atlama) – PN QuranTopBar ile aynı: search-circle-outline
              if (showNavigateButton && onOpenQuranIndex != null)
                IconButton(
                  onPressed: onOpenQuranIndex,
                  icon: Icon(
                    Icons.search,
                    size: scaleSize(context, isLandscape ? 20 : 24),
                    color: const Color(0xFF1E293B),
                  ),
                  style: IconButton.styleFrom(
                    minimumSize: Size(
                        scaleSize(context, isLandscape ? 24 : 28),
                        scaleSize(context, isLandscape ? 24 : 28)),
                    padding: EdgeInsets.zero,
                  ),
                ),

              // 3 nokta / ayarlar
              if (onOpenDownload != null)
                IconButton(
                  onPressed: onOpenDownload,
                  icon: Icon(
                    Icons.more_horiz,
                    size: scaleSize(context, isLandscape ? 18 : 22),
                    color: const Color(0xFF1E293B),
                  ),
                  style: IconButton.styleFrom(
                    minimumSize: Size(
                        scaleSize(context, isLandscape ? 24 : 28),
                        scaleSize(context, isLandscape ? 24 : 28)),
                    padding: EdgeInsets.zero,
                  ),
                ),
            ],
          ),
        ],
      );

    final topPad = (statusBarTop ?? 0) + vPad;
    return Container(
      padding: EdgeInsets.only(
        top: topPad,
        bottom: vPad,
        left: scaleSize(context, 16),
        right: scaleSize(context, 16),
      ),
      decoration: BoxDecoration(
        color: const Color(0xFFFFFFFF),
        border: Border(
          bottom: BorderSide(
            color: const Color(0xFFE2E8F0),
            width: scaleSize(context, 1),
          ),
        ),
      ),
      child: content,
    );
  }

  /// Sol taraftaki metin: SurahView → tek satır sure adı.
  /// PureQuran portrait → 2 satır (Cüz/Sayfa + Sure adı).
  /// PureQuran landscape → tek satır (Cüz • Sayfa • Sure adı).
  Widget _buildInfoText(BuildContext context) {
    // SurahView modunda tek satır sure adı
    if (surahInfoText != null) {
      return Text(
        surahInfoText!,
        style: GoogleFonts.plusJakartaSans(
          fontSize: scaleFont(context, isLandscape ? 12 : 14),
          fontWeight: FontWeight.w600,
          color: const Color(0xFF1E293B),
        ),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      );
    }

    final line1 = pageInfoText ?? '';
    final line2 = surahInfoLine;

    // Landscape: tek satırda birleştir
    if (isLandscape) {
      final combined = line2 != null && line2.isNotEmpty
          ? '$line1 • $line2'
          : line1;
      return Text(
        combined,
        style: GoogleFonts.plusJakartaSans(
          fontSize: scaleFont(context, 12),
          fontWeight: FontWeight.w600,
          color: const Color(0xFF1E293B),
        ),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      );
    }

    // Portrait: 2 satır
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          line1,
          style: GoogleFonts.plusJakartaSans(
            fontSize: scaleFont(context, 14),
            fontWeight: FontWeight.w600,
            color: const Color(0xFF1E293B),
          ),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        if (line2 != null && line2.isNotEmpty)
          Text(
            line2,
            style: GoogleFonts.plusJakartaSans(
              fontSize: scaleFont(context, 13),
              fontWeight: FontWeight.w500,
              color: const Color(0xFF475569),
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
      ],
    );
  }
}
