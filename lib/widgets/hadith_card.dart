import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../contexts/theme_provider.dart';
import '../l10n/app_localizations.dart';
import '../services/content_service.dart';
import '../utils/scaling.dart';
import 'content_card_base.dart';

/// Flutter equivalent of the RN HadisCard component.
class HadithCard extends StatefulWidget {
  final String prayerTime;
  final String? mood;
  final bool isRamadan;
  final bool isKandil;

  const HadithCard({
    super.key,
    required this.prayerTime,
    this.mood,
    this.isRamadan = false,
    this.isKandil = false,
  });

  @override
  State<HadithCard> createState() => _HadithCardState();
}

class _HadithCardState extends State<HadithCard> {
  final _cardKey = GlobalKey<ContentCardState>();
  Map<String, dynamic>? _hadith;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadHadith();
  }

  @override
  void didUpdateWidget(covariant HadithCard old) {
    super.didUpdateWidget(old);
    if (old.prayerTime != widget.prayerTime ||
        old.mood != widget.mood ||
        old.isRamadan != widget.isRamadan ||
        old.isKandil != widget.isKandil) {
      _loadHadith();
    }
  }

  Future<void> _loadHadith() async {
    final locale = context.read<ThemeProvider>().language;
    final hadith = await ContentService.instance.getHadith(
      prayerTime: widget.prayerTime,
      locale: locale,
      mood: widget.mood,
      isRamadan: widget.isRamadan,
      isKandil: widget.isKandil,
    );
    if (!mounted) return;
    setState(() {
      _hadith = hadith;
      _loading = false;
    });
    if (hadith != null) {
      final isNew = await ContentService.instance.markHadithAsSeenIfNew(hadith);
      if (isNew && mounted) {
        _cardKey.currentState?.playHighlight();
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading || _hadith == null) return const SizedBox.shrink();
    String t(String key) => AppLocalizations.t(context, key);
    final hadith = _hadith!;

    return Stack(
      clipBehavior: Clip.none,
      children: [
        ContentCard(
          key: _cardKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(height: scaleSize(context, 4)),
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
              // Hadith text
              Text(
                hadith['text'] as String? ?? '',
                style: GoogleFonts.plusJakartaSans(
                  fontSize: scaleFont(context, 14),
                  height: 22 / 14,
                  color: kBodyText,
                  fontWeight: FontWeight.w300,
                  letterSpacing: 0.4,
                ),
              ),
              if (hadith['source'] != null) ...[
                SizedBox(height: scaleSize(context, 4)),
                Text(
                  hadith['source'] as String,
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: scaleFont(context, 9),
                    color: kSourceText,
                    fontStyle: FontStyle.italic,
                    fontWeight: FontWeight.w400,
                  ),
                ),
              ],
              if (hadith['explanation'] != null) ...[
                SizedBox(height: scaleSize(context, 6)),
                Text(
                  hadith['explanation'] as String,
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: scaleFont(context, 11),
                    height: 16 / 11,
                    color: kExplanationText,
                    fontWeight: FontWeight.w400,
                  ),
                ),
              ],
            ],
          ),
        ),
        Positioned(
          top: scaleSize(context, 12) - scaleSize(context, 8),
          right: -scaleSize(context, 8),
          child: CardTypeLabel(
            text: t('hadis'),
            bgColor: kHadithLabelBg,
            textColor: kHadithLabelText,
          ),
        ),
      ],
    );
  }
}
