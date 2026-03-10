import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../contexts/theme_provider.dart';
import '../l10n/app_localizations.dart';
import '../services/content_service.dart';
import '../utils/scaling.dart';
import 'content_card_base.dart';

/// Flutter equivalent of the RN DuaCard component.
/// Shows a dua selected based on prayer time, mood and special occasions.
class DuaCard extends StatefulWidget {
  final String prayerTime;
  final String? mood;
  final bool isRamadan;
  final bool isKandil;

  const DuaCard({
    super.key,
    required this.prayerTime,
    this.mood,
    this.isRamadan = false,
    this.isKandil = false,
  });

  @override
  State<DuaCard> createState() => _DuaCardState();
}

class _DuaCardState extends State<DuaCard> {
  final _cardKey = GlobalKey<ContentCardState>();
  Map<String, dynamic>? _dua;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadDua();
  }

  @override
  void didUpdateWidget(covariant DuaCard old) {
    super.didUpdateWidget(old);
    if (old.prayerTime != widget.prayerTime ||
        old.mood != widget.mood ||
        old.isRamadan != widget.isRamadan ||
        old.isKandil != widget.isKandil) {
      _loadDua();
    }
  }

  Future<void> _loadDua() async {
    final locale = context.read<ThemeProvider>().language;
    final dua = await ContentService.instance.getDua(
      prayerTime: widget.prayerTime,
      locale: locale,
      mood: widget.mood,
      isRamadan: widget.isRamadan,
      isKandil: widget.isKandil,
    );
    if (!mounted) return;
    setState(() {
      _dua = dua;
      _loading = false;
    });
    if (dua != null) {
      final isNew = await ContentService.instance.markDuaAsSeenIfNew(dua);
      if (isNew && mounted) {
        _cardKey.currentState?.playHighlight();
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading || _dua == null) return const SizedBox.shrink();
    String t(String key) => AppLocalizations.t(context, key);
    final dua = _dua!;

    return Stack(
      clipBehavior: Clip.none,
      children: [
        ContentCard(
          key: _cardKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Top padding to clear the absolute label
              SizedBox(height: scaleSize(context, 4)),
              // Ramazan / Kandil tags
              if (widget.isRamadan || widget.isKandil)
                Padding(
                  padding: EdgeInsets.only(bottom: scaleSize(context, 4)),
                  child: Wrap(
                    spacing: scaleSize(context, 4),
                    children: [
                      if (widget.isRamadan)
                        ContentTag(
                          icon: Icons.nightlight_round,
                          label: t('ramadan'),
                          bgColor: const Color(0xFFEEF2FF),
                          color: const Color(0xFF6366F1),
                        ),
                      if (widget.isKandil)
                        ContentTag(
                          icon: Icons.star_border,
                          label: t('kandilNight'),
                          bgColor: const Color(0xFFFEF3C7),
                          color: const Color(0xFFF59E0B),
                        ),
                    ],
                  ),
                ),
              // Dua text
              Text(
                dua['text'] as String? ?? '',
                style: GoogleFonts.plusJakartaSans(
                  fontSize: scaleFont(context, 14),
                  height: 22 / 14,
                  color: kBodyText,
                  fontWeight: FontWeight.w300,
                  letterSpacing: 0.4,
                ),
              ),
              // Source
              if (dua['source'] != null) ...[
                SizedBox(height: scaleSize(context, 4)),
                Text(
                  dua['source'] as String,
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: scaleFont(context, 9),
                    color: kSourceText,
                    fontStyle: FontStyle.italic,
                    fontWeight: FontWeight.w400,
                  ),
                ),
              ],
            ],
          ),
        ),
        // Absolute badge (top-right, outside card bounds)
        Positioned(
          top: scaleSize(context, 12) - scaleSize(context, 8),
          right: -scaleSize(context, 8),
          child: CardTypeLabel(
            text: t('dua'),
            bgColor: kDuaLabelBg,
            textColor: kDuaLabelText,
          ),
        ),
      ],
    );
  }
}
