import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../l10n/app_localizations.dart';
import '../contexts/quran_view_mode_provider.dart';
import '../utils/scaling.dart';

/// Header: Sol = değişim ikonu + "Quran" yazısı; Sağ = arama ikonu, label (yer imi) ikonu, 3 nokta.
/// RN: QuranTopBar.js ile aynı düzen ve fonksiyonlar.
class QuranTopBar extends StatelessWidget {
  /// Sol tarafta gösterilecek metin (örn. "Quran" veya seçili sure bilgisi).
  final String? surahInfoText;
  final String? pageInfoText;
  /// Sağda arama ikonu gösterilsin mi (sure listesindeyken true).
  final bool showSearchBar;
  final String searchQuery;
  final ValueChanged<String>? onSearchQueryChange;
  final bool searchExpanded;
  final VoidCallback? onSearchExpandedToggle;
  /// Label/yer imi ikonu tıklanınca (bookmark’a git veya aç).
  final VoidCallback? onBookmarkPress;
  final bool hasBookmark;
  /// 3 nokta menüsü (ayarlar / indirme vb.). [onOpenDownload] öncelikli; yoksa [onOpenSettings].
  final VoidCallback? onOpenSettings;
  /// İndirme/ayarlar modalını açar (RN ile uyum için öncelikli).
  final VoidCallback? onOpenDownload;
  /// Arama alanı için controller (searchExpanded true iken TextField bağlanır).
  final TextEditingController? searchController;

  const QuranTopBar({
    super.key,
    this.surahInfoText,
    this.pageInfoText,
    this.showSearchBar = true,
    this.searchQuery = '',
    this.onSearchQueryChange,
    this.searchExpanded = false,
    this.onSearchExpandedToggle,
    this.onBookmarkPress,
    this.hasBookmark = false,
    this.onOpenSettings,
    this.onOpenDownload,
    this.searchController,
  });

  @override
  Widget build(BuildContext context) {
    final t = (String k) => AppLocalizations.t(context, k);

    return Consumer<QuranViewModeProvider>(
      builder: (context, quranMode, _) => _buildContent(context, quranMode, t),
    );
  }

  Widget _buildContent(BuildContext context, QuranViewModeProvider quranMode, String Function(String) t) {
    final leftTitle = surahInfoText ?? pageInfoText ?? t('quran');

    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: scaleSize(context, 16),
        vertical: scaleSize(context, 12),
      ),
      decoration: BoxDecoration(
        color: const Color(0xFFFFFFFF),
        border: Border(
            bottom: BorderSide(
                color: const Color(0xFFE2E8F0),
                width: scaleSize(context, 1))),
      ),
      child: Row(
        children: [
          // Sol: Değişim ikonu + Quran (veya sure bilgisi)
          Expanded(
            child: Row(
              children: [
                // View mode toggle: SurahView ↔ PureQuran (değişim ikonu)
                Padding(
                  padding: EdgeInsets.only(right: scaleSize(context, 8)),
                  child: GestureDetector(
                    onTap: () {
                      final nextMode = quranMode.isSurahBySurah
                          ? kQuranViewModePureQuran
                          : kQuranViewModeSurahBySurah;
                      quranMode.setViewMode(nextMode);
                    },
                    child: Container(
                      padding: EdgeInsets.symmetric(
                        horizontal: scaleSize(context, 10),
                        vertical: scaleSize(context, 8),
                      ),
                      decoration: BoxDecoration(
                        color: const Color(0xFFEEF2FF),
                        borderRadius: BorderRadius.circular(scaleSize(context, 8)),
                        border: Border.all(
                            color: const Color(0xFFE0E7FF),
                            width: scaleSize(context, 1.5)),
                        boxShadow: [
                          BoxShadow(
                            color: const Color(0xFF6366F1).withValues(alpha: 0.1),
                            offset: Offset(0, scaleSize(context, 2)),
                            blurRadius: scaleSize(context, 4),
                          ),
                        ],
                      ),
                      child: Icon(
                        Icons.swap_vert,
                        size: scaleSize(context, 20),
                        color: const Color(0xFF6366F1),
                      ),
                    ),
                  ),
                ),
                Expanded(
                  child: Text(
                    leftTitle,
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: scaleFont(context, 14),
                      fontWeight: FontWeight.w600,
                      color: const Color(0xFF1E293B),
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ),
          // Sağ: Arama ikonu, label (yer imi) ikonu, 3 nokta
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Arama ikonu (tap → arama aç/kapa)
              if (showSearchBar) ...[
                if (searchExpanded)
                  Padding(
                    padding: EdgeInsets.only(right: scaleSize(context, 8)),
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
                            borderRadius: BorderRadius.circular(scaleSize(context, 20)),
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
                    size: scaleSize(context, 24),
                    color: searchExpanded ? const Color(0xFF64748B) : const Color(0xFF1E293B),
                  ),
                  style: IconButton.styleFrom(
                    minimumSize: Size(scaleSize(context, 40), scaleSize(context, 40)),
                    padding: EdgeInsets.zero,
                  ),
                ),
              ],
              // Yer imi ikonu (bookmark) – her zaman göster; RN: tıklanınca bookmark’a git
              IconButton(
                onPressed: onBookmarkPress ?? () {},
                icon: Icon(
                  hasBookmark ? Icons.bookmark : Icons.bookmark_border,
                  size: scaleSize(context, 24),
                  color: hasBookmark ? const Color(0xFFF59E0B) : const Color(0xFF1E293B),
                ),
                style: IconButton.styleFrom(
                  minimumSize: Size(scaleSize(context, 40), scaleSize(context, 40)),
                  padding: EdgeInsets.zero,
                ),
              ),
              // 3 nokta menü (ayarlar / indirme)
              if ((onOpenDownload ?? onOpenSettings) != null)
                IconButton(
                  onPressed: onOpenDownload ?? onOpenSettings,
                  icon: Icon(
                    Icons.more_horiz,
                    size: scaleSize(context, 24),
                    color: const Color(0xFF1E293B),
                  ),
                  style: IconButton.styleFrom(
                    minimumSize: Size(scaleSize(context, 40), scaleSize(context, 40)),
                    padding: EdgeInsets.zero,
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }
}
