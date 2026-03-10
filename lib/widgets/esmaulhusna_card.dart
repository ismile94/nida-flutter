import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../contexts/theme_provider.dart';
import '../l10n/app_localizations.dart';
import '../services/content_service.dart';
import '../utils/scaling.dart';
import 'content_card_base.dart';

/// Flutter equivalent of the RN EsmaulHusnaCard component.
/// Shows the Esma of the day using a two-column layout: Arabic + Latin name
/// on the left, meaning + usage on the right.
class EsmaulHusnaCard extends StatefulWidget {
  final bool isRamadan;
  final bool isKandil;

  const EsmaulHusnaCard({
    super.key,
    this.isRamadan = false,
    this.isKandil = false,
  });

  @override
  State<EsmaulHusnaCard> createState() => _EsmaulHusnaCardState();
}

class _EsmaulHusnaCardState extends State<EsmaulHusnaCard> {
  final _cardKey = GlobalKey<ContentCardState>();
  Map<String, dynamic>? _esma;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadEsma();
  }

  Future<void> _loadEsma() async {
    final locale = context.read<ThemeProvider>().language;
    final esma = await ContentService.instance.getEsmaulHusna(locale: locale);
    if (!mounted) return;
    setState(() {
      _esma = esma;
      _loading = false;
    });
    if (esma != null) {
      final isNew = await ContentService.instance.markEsmaAsSeenIfNew(esma);
      if (isNew && mounted) {
        _cardKey.currentState?.playHighlight();
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading || _esma == null) return const SizedBox.shrink();
    String t(String key) => AppLocalizations.t(context, key);
    final esma = _esma!;

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
              // Two-column layout: Arabic/Latin | Meaning/Usage
              IntrinsicHeight(
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Left column: Arabic text (centred, ~32.5% width)
                    SizedBox(
                      width: (MediaQuery.sizeOf(context).width - scaleSize(context, 40) - scaleSize(context, 10) * 2) * 0.325,
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.start,
                        children: [
                          Text(
                            esma['arabic'] as String? ?? '',
                            textAlign: TextAlign.center,
                            style: GoogleFonts.plusJakartaSans(
                              fontSize: scaleFont(context, 24),
                              color: kBodyText,
                              fontWeight: FontWeight.w300,
                              height: 1.3,
                            ),
                          ),
                          SizedBox(height: scaleSize(context, 2)),
                          Text(
                            esma['latin'] as String? ?? '',
                            textAlign: TextAlign.center,
                            style: GoogleFonts.plusJakartaSans(
                              fontSize: scaleFont(context, 14),
                              color: kExplanationText,
                              fontWeight: FontWeight.w400,
                            ),
                          ),
                        ],
                      ),
                    ),
                    SizedBox(width: scaleSize(context, 12)),
                    // Right column: Meaning + Usage
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          SizedBox(height: scaleSize(context, 6)),
                          Text(
                            esma['meaning'] as String? ?? '',
                            style: GoogleFonts.plusJakartaSans(
                              fontSize: scaleFont(context, 13),
                              color: kBodyText,
                              fontWeight: FontWeight.w400,
                            ),
                          ),
                          if (esma['usage'] != null) ...[
                            SizedBox(height: scaleSize(context, 6)),
                            Text(
                              esma['usage'] as String,
                              style: GoogleFonts.plusJakartaSans(
                                fontSize: scaleFont(context, 11),
                                color: kSourceText,
                                fontStyle: FontStyle.italic,
                                height: 16 / 11,
                                fontWeight: FontWeight.w400,
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        Positioned(
          top: scaleSize(context, 12) - scaleSize(context, 8),
          right: -scaleSize(context, 8),
          child: CardTypeLabel(
            text: t('esmaulHusnaLabel'),
            bgColor: kEsmaLabelBg,
            textColor: kEsmaLabelText,
          ),
        ),
      ],
    );
  }
}
