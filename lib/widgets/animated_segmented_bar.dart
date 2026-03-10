import 'package:flutter/material.dart';
import '../utils/scaling.dart';

/// Connected segmented bar with animated sliding selection indicator.
/// Used on Prayer and Dua (Dhikr) screens for Prayer | Dua segment.
class AnimatedSegmentedBar<T> extends StatelessWidget {
  final List<T> items;
  final int selectedIndex;
  final void Function(T item, int index) onSelected;
  final BuildContext scaleContext;
  final bool compact;

  const AnimatedSegmentedBar({
    super.key,
    required this.items,
    required this.selectedIndex,
    required this.onSelected,
    required this.scaleContext,
    this.compact = false,
  });

  @override
  Widget build(BuildContext context) {
    final radius = scaleSize(scaleContext, compact ? 11 : 13);
    final paddingV = scaleSize(scaleContext, compact ? 9 : 8);
    final fontSize = scaleFont(scaleContext, compact ? 11 : 12);
    final inset = compact ? 2.0 : 2.0;
    return LayoutBuilder(
      builder: (ctx, constraints) {
        final segmentWidth = constraints.maxWidth / items.length;
        return Container(
          height: paddingV * 2 + fontSize * 1.4,
          decoration: BoxDecoration(
            color: const Color(0xFFE2E8F0),
            borderRadius: BorderRadius.circular(radius),
            border: Border.all(color: const Color(0xFFCBD5E1), width: 0.5),
          ),
          clipBehavior: Clip.antiAlias,
          child: Stack(
            children: [
              AnimatedPositioned(
                duration: const Duration(milliseconds: 220),
                curve: Curves.easeInOutCubic,
                left: segmentWidth * selectedIndex + inset,
                top: inset,
                bottom: inset,
                width: segmentWidth - inset * 2,
                child: Container(
                  decoration: BoxDecoration(
                    color: const Color(0xFF6366F1),
                    borderRadius: BorderRadius.circular(radius - inset),
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFF6366F1).withValues(alpha: 0.25),
                        blurRadius: 4,
                        offset: const Offset(0, 1),
                      ),
                    ],
                  ),
                ),
              ),
              Row(
                children: List.generate(items.length, (i) {
                  final isSelected = i == selectedIndex;
                  return Expanded(
                    child: Material(
                      color: Colors.transparent,
                      child: InkWell(
                        onTap: () => onSelected(items[i], i),
                        splashColor: const Color(0xFF6366F1).withValues(alpha: 0.2),
                        highlightColor: const Color(0xFF6366F1).withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(radius - inset),
                        child: Center(
                          child: Text(
                            items[i].toString(),
                            style: TextStyle(
                              fontSize: fontSize,
                              fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                              color: isSelected ? Colors.white : const Color(0xFF64748B),
                            ),
                          ),
                        ),
                      ),
                    ),
                  );
                }),
              ),
            ],
          ),
        );
      },
    );
  }
}
