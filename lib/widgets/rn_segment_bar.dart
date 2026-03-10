import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../utils/scaling.dart';

/// RN-style segment bar: width 144, border radius 24, border rgba(99,102,241,0.4), active bg rgba(99,102,241,0.3).
/// Used on Prayer screen (Prayer|Dua, Basic|Detailed) and Dhikr screen (Prayer|Dua).
class RnSegmentBar extends StatelessWidget {
  final List<String> labels;
  final int selectedIndex;
  final void Function(int index) onSelected;
  final BuildContext scaleContext;

  const RnSegmentBar({
    super.key,
    required this.labels,
    required this.selectedIndex,
    required this.onSelected,
    required this.scaleContext,
  });

  @override
  Widget build(BuildContext context) {
    const double width = 144;
    final radius = scaleSize(scaleContext, 24);
    final padding = scaleSize(scaleContext, 2);
    final borderW = scaleSize(scaleContext, 1.5);
    return Container(
      width: scaleSize(scaleContext, width),
      padding: EdgeInsets.all(padding),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(radius),
        border: Border.all(color: const Color(0xFF6366F1).withValues(alpha: 0.4), width: borderW),
      ),
      child: Row(
        children: List.generate(labels.length, (i) {
          final isActive = i == selectedIndex;
          return Expanded(
            child: GestureDetector(
              onTap: () => onSelected(i),
              child: Container(
                padding: EdgeInsets.symmetric(vertical: scaleSize(scaleContext, 5)),
                decoration: BoxDecoration(
                  color: isActive ? const Color(0xFF6366F1).withValues(alpha: 0.3) : Colors.transparent,
                  borderRadius: BorderRadius.circular(radius),
                ),
                alignment: Alignment.center,
                child: Text(
                  labels[i],
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: scaleFont(scaleContext, 11),
                    fontWeight: isActive ? FontWeight.bold : FontWeight.w600,
                    color: isActive ? const Color(0xFF6366F1) : const Color(0xFF64748B),
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ),
          );
        }),
      ),
    );
  }
}
