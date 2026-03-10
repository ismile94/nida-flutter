import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../utils/scaling.dart';

/// Shared visual helpers used by all content cards (Dua / Hadith / Esmaul Husna).
/// Mirrors the common styles in RN DuaCard / hadisCard / EsmaulHusnaCard.

// ── Color constants matching RN style sheet ──────────────────────────────────
const kCardDefaultBg = Color(0xFFFFFFFF);
const kCardDefaultBorder = Color(0xFFF1F5F9);
const kCardHighlightBg = Color(0xFFFEF3C7);
const kCardHighlightBorder = Color(0xFFF59E0B);

const kDuaLabelBg = Color(0xFFEEF2FF);
const kDuaLabelText = Color(0xFF6366F1);

const kHadithLabelBg = Color(0xFFF0FDF4);
const kHadithLabelText = Color(0xFF10B981);

const kEsmaLabelBg = Color(0xFFFDF4FF);
const kEsmaLabelText = Color(0xFFA855F7);

const kRemoteLabelBg = Color(0xFFEEF2FF);
const kRemoteLabelText = Color(0xFF6366F1);

const kBodyText = Color(0xFF475569);
const kSourceText = Color(0xFF94A3B8);
const kExplanationText = Color(0xFF64748B);

/// Animated card wrapper that plays a yellow highlight when [playHighlight] is called.
class ContentCard extends StatefulWidget {
  final Widget child;
  final VoidCallback? onHighlightReady;

  const ContentCard({super.key, required this.child, this.onHighlightReady});

  @override
  State<ContentCard> createState() => ContentCardState();
}

class ContentCardState extends State<ContentCard> with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late final Animation<Color?> _bgAnim;
  late final Animation<Color?> _borderAnim;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 500));
    _bgAnim = ColorTween(begin: kCardDefaultBg, end: kCardHighlightBg).animate(_ctrl);
    _borderAnim = ColorTween(begin: kCardDefaultBorder, end: kCardHighlightBorder).animate(_ctrl);
  }

  Future<void> playHighlight() async {
    await _ctrl.forward();
    await Future.delayed(const Duration(seconds: 2));
    if (mounted) await _ctrl.reverse();
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.sizeOf(context).width;
    final cardWidth = screenWidth - scaleSize(context, 40);

    return AnimatedBuilder(
      animation: _ctrl,
      builder: (context, child) => Container(
        width: cardWidth,
        margin: EdgeInsets.only(
          top: scaleSize(context, 12),
          bottom: scaleSize(context, 8),
        ),
        padding: EdgeInsets.all(scaleSize(context, 10)),
        decoration: BoxDecoration(
          color: _bgAnim.value ?? kCardDefaultBg,
          borderRadius: BorderRadius.circular(scaleSize(context, 12)),
          border: Border.all(color: _borderAnim.value ?? kCardDefaultBorder),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.05),
              blurRadius: scaleSize(context, 8),
              offset: Offset(0, scaleSize(context, 2)),
            ),
          ],
        ),
        child: child,
      ),
      child: widget.child,
    );
  }
}

/// Small badge label positioned in the top-right corner (mirrors RN cardTypeLabel).
class CardTypeLabel extends StatelessWidget {
  final String text;
  final Color bgColor;
  final Color textColor;

  const CardTypeLabel({
    super.key,
    required this.text,
    required this.bgColor,
    required this.textColor,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: scaleSize(context, 6),
        vertical: scaleSize(context, 3),
      ),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(scaleSize(context, 6)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.1),
            blurRadius: scaleSize(context, 4),
            offset: Offset(0, scaleSize(context, 2)),
          ),
        ],
      ),
      child: Text(
        text,
        style: GoogleFonts.plusJakartaSans(
          fontSize: scaleFont(context, 11),
          fontWeight: FontWeight.w500,
          color: textColor,
        ),
      ),
    );
  }
}

/// Small tag chip (Ramazan / Kandil). Mirrors RN tag style.
class ContentTag extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color bgColor;
  final Color color;

  const ContentTag({
    super.key,
    required this.icon,
    required this.label,
    required this.bgColor,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: scaleSize(context, 6),
        vertical: scaleSize(context, 2),
      ),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(scaleSize(context, 8)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: scaleSize(context, 12), color: color),
          SizedBox(width: scaleSize(context, 3)),
          Text(
            label,
            style: GoogleFonts.plusJakartaSans(
              fontSize: scaleFont(context, 10),
              fontWeight: FontWeight.w500,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}
