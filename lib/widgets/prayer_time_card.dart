import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../utils/scaling.dart';

/// Single prayer time card - same design as RN (white card, name + time, current/next highlight). Scaled.
class PrayerTimeCard extends StatelessWidget {
  final String name;
  final String time;
  final IconData icon;
  final bool isCurrent;
  final bool isNext;
  /// 'sad' | 'neutral' | 'happy' — shown as emoji badge bottom-right.
  final String? mood;

  const PrayerTimeCard({
    super.key,
    required this.name,
    required this.time,
    required this.icon,
    this.isCurrent = false,
    this.isNext = false,
    this.mood,
  });

  @override
  Widget build(BuildContext context) {
    Color bgColor = Colors.white;
    Color borderColor = Colors.transparent;
    if (isCurrent) {
      bgColor = const Color(0xFFF0FDF4);
      borderColor = const Color(0xFF10B981);
    } else if (isNext) {
      bgColor = const Color(0xFFEEF2FF);
      borderColor = const Color(0xFF6366F1);
    }

    final String? moodEmoji = switch (mood) {
      'sad'     => '😢',
      'neutral' => '😐',
      'happy'   => '😊',
      _         => null,
    };

    final card = Container(
      // width: infinity ensures the card fills available space whether it sits
      // directly in Expanded or inside a Stack (which gives loose constraints).
      width: double.infinity,
      padding: EdgeInsets.symmetric(vertical: scaleSize(context, 6), horizontal: scaleSize(context, 4)),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(scaleSize(context, 12)),
        border: Border.all(color: borderColor, width: isCurrent || isNext ? scaleSize(context, 2) : 0),
        boxShadow: [
          BoxShadow(
            color: const Color(0x0D000000),
            blurRadius: scaleSize(context, 8),
            offset: Offset(0, scaleSize(context, 2)),
          ),
        ],
      ),
      constraints: BoxConstraints(minHeight: scaleSize(context, 75)),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, size: scaleSize(context, 20), color: isNext ? const Color(0xFF6366F1) : const Color(0xFF64748B)),
          SizedBox(height: scaleSize(context, 4)),
          Text(
            name,
            style: GoogleFonts.plusJakartaSans(
              fontSize: scaleFont(context, 11),
              color: isNext ? const Color(0xFF6366F1) : const Color(0xFF64748B),
              fontWeight: isNext ? FontWeight.w600 : FontWeight.w500,
            ),
            textAlign: TextAlign.center,
          ),
          SizedBox(height: scaleSize(context, 2)),
          Text(
            time,
            style: GoogleFonts.plusJakartaSans(
              fontSize: scaleFont(context, isNext ? 12 : 11),
              color: isNext ? const Color(0xFF6366F1) : const Color(0xFF1E293B),
              fontWeight: FontWeight.w600,
              fontFeatures: const [FontFeature.tabularFigures()],
            ),
          ),
        ],
      ),
    );

    if (moodEmoji == null) return card;

    // Card keeps its original size. Badge sits half inside / half outside
    // the bottom-right corner via negative Positioned offsets.
    // Stack(clipBehavior: Clip.none) lets it overflow without affecting layout.
    return Stack(
      clipBehavior: Clip.none,
      children: [
        card,
        Positioned(
          right: -scaleSize(context, 2),
          bottom: -scaleSize(context, 10),
          child: Container(
            width: scaleSize(context, 20),
            height: scaleSize(context, 20),
            decoration: BoxDecoration(
              color: Colors.white,
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.15),
                  blurRadius: scaleSize(context, 4),
                  offset: Offset(0, scaleSize(context, 1)),
                ),
              ],
            ),
            alignment: Alignment.center,
            child: Text(moodEmoji,
                style: GoogleFonts.plusJakartaSans(fontSize: scaleFont(context, 12))),
          ),
        ),
      ],
    );
  }
}
