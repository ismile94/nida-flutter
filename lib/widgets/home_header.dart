import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../utils/scaling.dart';

/// Header section: gradient background, nida.png pulse logo, alarm + calendar buttons.
/// When [cityNames] is not empty, shows a horizontal PageView (one page per city + optional "Add City" page).
class HomeHeader extends StatefulWidget {
  final PageController? pageController;
  final List<String> cityNames;
  final int selectedCityIndex;
  final String nextPrayerLabel;
  final String nextPrayerTime;
  final String hijriDate;
  final String gregorianDate;
  final void Function(int index)? onPageChanged;
  final VoidCallback? onAddCityTap;
  final void Function(int index)? onRemoveCity;
  final String? addCityLabel;
  final String? addCitySubtext;
  final String loadingText;
  final VoidCallback? onAlarmTap;
  final VoidCallback? onCalendarTap;

  const HomeHeader({
    super.key,
    this.pageController,
    required this.cityNames,
    required this.selectedCityIndex,
    required this.nextPrayerLabel,
    required this.nextPrayerTime,
    required this.hijriDate,
    required this.gregorianDate,
    this.onPageChanged,
    this.onAddCityTap,
    this.onRemoveCity,
    this.addCityLabel,
    this.addCitySubtext,
    this.loadingText = 'Loading',
    this.onAlarmTap,
    this.onCalendarTap,
  });

  @override
  State<HomeHeader> createState() => _HomeHeaderState();
}

class _HomeHeaderState extends State<HomeHeader>
    with SingleTickerProviderStateMixin {
  late final AnimationController _pulseCtrl;
  late final Animation<double> _pulseAnim;

  @override
  void initState() {
    super.initState();
    _pulseCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2800),
    )..repeat(reverse: true);
    _pulseAnim = Tween<double>(begin: 0.10, end: 0.28).animate(
      CurvedAnimation(parent: _pulseCtrl, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _pulseCtrl.dispose();
    super.dispose();
  }

  Widget _buildCityPage(
      BuildContext context, String locationName, int cityIndex) {
    final canRemove = cityIndex >= 1 &&
        widget.cityNames.length > 1 &&
        widget.onRemoveCity != null;
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: scaleSize(context, 16)),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          // ── Left: next prayer ────────────────────────────────────────────
          Expanded(
            flex: 5,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  widget.nextPrayerLabel,
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: scaleFont(context, 12.5),
                    color: const Color(0xFF6366F1),
                    fontWeight: FontWeight.w500,
                  ),
                  textAlign: TextAlign.center,
                ),
                SizedBox(height: scaleSize(context, 3)),
                Text(
                  widget.nextPrayerTime,
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: scaleFont(context, 24),
                    color: const Color(0xFF4F46E5),
                    fontWeight: FontWeight.bold,
                    letterSpacing: scaleSize(context, 1.2),
                  ),
                ),
              ],
            ),
          ),
          // ── Divider ──────────────────────────────────────────────────────
          Container(
            width: scaleSize(context, 1),
            height: scaleSize(context, 36),
            color: const Color(0xFFE2E8F0),
            margin: EdgeInsets.symmetric(horizontal: scaleSize(context, 4)),
          ),
          // ── Right: location + dates ──────────────────────────────────────
          Expanded(
            flex: 6,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Flexible(
                      child: Text(
                        locationName,
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: scaleFont(context, 16),
                          fontWeight: FontWeight.w600,
                          color: const Color(0xFF475569),
                        ),
                        textAlign: TextAlign.center,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    if (canRemove) ...[
                      SizedBox(width: scaleSize(context, 5)),
                      Material(
                        color: const Color(0xFFDC2626),
                        borderRadius:
                            BorderRadius.circular(scaleSize(context, 9)),
                        clipBehavior: Clip.antiAlias,
                        child: InkWell(
                          onTap: () => widget.onRemoveCity!(cityIndex),
                          child: SizedBox(
                            width: scaleSize(context, 18),
                            height: scaleSize(context, 18),
                            child: Icon(Icons.remove,
                                size: scaleSize(context, 12),
                                color: Colors.white),
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
                SizedBox(height: scaleSize(context, 3)),
                FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        padding: EdgeInsets.symmetric(
                            horizontal: scaleSize(context, 4),
                            vertical: scaleSize(context, 2)),
                        decoration: BoxDecoration(
                          borderRadius:
                              BorderRadius.circular(scaleSize(context, 5)),
                          border: Border.all(
                              color:
                                  const Color(0xFF10B981).withValues(alpha: 0.4),
                              width: scaleSize(context, 1)),
                        ),
                        child: Text(
                          widget.hijriDate,
                          style: GoogleFonts.plusJakartaSans(
                              fontSize: scaleFont(context, 11),
                              color: const Color(0xFF475569)),
                        ),
                      ),
                      Padding(
                        padding: EdgeInsets.symmetric(
                            horizontal: scaleSize(context, 3)),
                        child: Text('|',
                            style: GoogleFonts.plusJakartaSans(
                                fontSize: scaleFont(context, 11),
                                color: const Color(0xFF94A3B8))),
                      ),
                      Container(
                        padding: EdgeInsets.symmetric(
                            horizontal: scaleSize(context, 4),
                            vertical: scaleSize(context, 2)),
                        decoration: BoxDecoration(
                          borderRadius:
                              BorderRadius.circular(scaleSize(context, 5)),
                          border: Border.all(
                              color:
                                  const Color(0xFF6366F1).withValues(alpha: 0.4),
                              width: scaleSize(context, 1)),
                        ),
                        child: Text(
                          widget.gregorianDate,
                          style: GoogleFonts.plusJakartaSans(
                              fontSize: scaleFont(context, 11),
                              color: const Color(0xFF475569)),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAddCityPage(BuildContext context) {
    final label = widget.addCityLabel ?? 'Add City';
    final subtext = widget.addCitySubtext ?? 'Swipe to add another city';
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: widget.onAddCityTap,
        child: Padding(
          padding: EdgeInsets.symmetric(
              horizontal: scaleSize(context, 10),
              vertical: scaleSize(context, 4)),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.add_circle_outline,
                  size: scaleSize(context, 26), color: const Color(0xFF6366F1)),
              SizedBox(height: scaleSize(context, 5)),
              Text(
                label,
                style: GoogleFonts.plusJakartaSans(
                  fontSize: scaleFont(context, 12.8),
                  fontWeight: FontWeight.w600,
                  color: const Color(0xFF6366F1),
                ),
                textAlign: TextAlign.center,
              ),
              SizedBox(height: scaleSize(context, 2)),
              Text(
                subtext,
                style: GoogleFonts.plusJakartaSans(
                    fontSize: scaleFont(context, 9.6),
                    color: const Color(0xFF94A3B8)),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final pad = scaleSize(context, 40);
    final pageWidth = MediaQuery.sizeOf(context).width - pad;
    final hasCities = widget.cityNames.isNotEmpty;
    final canAddCity = hasCities && widget.cityNames.length < 3;
    final pageCount =
        hasCities ? widget.cityNames.length + (canAddCity ? 1 : 0) : 1;
    final minH = scaleSize(context, 100);

    return ClipRRect(
      borderRadius: BorderRadius.vertical(
          bottom: Radius.circular(scaleSize(context, 19.2))),
      child: Container(
        padding: EdgeInsets.only(
            left: scaleSize(context, 16),
            right: scaleSize(context, 16),
            bottom: scaleSize(context, 4)),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.vertical(
              bottom: Radius.circular(scaleSize(context, 19.2))),
        ),
        child: Container(
          constraints: BoxConstraints(minHeight: minH),
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              // ── nida.png pulsing background ──────────────────────────────
              const Positioned.fill(
                child: DecoratedBox(
                  decoration: BoxDecoration(color: Color(0xFFF8FAFC)),
                ),
              ),
              Positioned.fill(
                child: AnimatedBuilder(
                  animation: _pulseAnim,
                  builder: (_, __) => Opacity(
                    opacity: _pulseAnim.value,
                    child: Image.asset(
                      'assets/nida.png',
                      fit: BoxFit.contain,
                    ),
                  ),
                ),
              ),
              Padding(
                padding: EdgeInsets.only(top: scaleSize(context, 6)),
                child: hasCities && widget.pageController != null
                    ? Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          SizedBox(
                            height: scaleSize(context, 78),
                            child: PageView.builder(
                              controller: widget.pageController,
                              itemCount: pageCount,
                              onPageChanged: (index) {
                                if (index < widget.cityNames.length) {
                                  widget.onPageChanged?.call(index);
                                }
                              },
                              itemBuilder: (ctx, index) {
                                if (index < widget.cityNames.length) {
                                  return SizedBox(
                                    width: pageWidth,
                                    child: _buildCityPage(
                                        ctx, widget.cityNames[index], index),
                                  );
                                }
                                return SizedBox(
                                  width: pageWidth,
                                  child: _buildAddCityPage(ctx),
                                );
                              },
                            ),
                          ),
                          SizedBox(height: scaleSize(context, 3)),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            mainAxisSize: MainAxisSize.min,
                            children:
                                List.generate(widget.cityNames.length, (i) {
                              final isSelected = i == widget.selectedCityIndex;
                              return Container(
                                margin: EdgeInsets.symmetric(
                                    horizontal: scaleSize(context, 3)),
                                width: scaleSize(context, isSelected ? 16 : 5),
                                height: scaleSize(context, 5),
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(
                                      scaleSize(context, 3.2)),
                                  color: isSelected
                                      ? const Color(0xFF6366F1)
                                      : const Color(0xFFCBD5E1),
                                ),
                              );
                            }),
                          ),
                        ],
                      )
                    : Center(
                        child: Padding(
                          padding: EdgeInsets.only(top: scaleSize(context, 14)),
                          child: Text(
                            widget.loadingText,
                            style: GoogleFonts.plusJakartaSans(
                                fontSize: scaleFont(context, 16),
                                color: const Color(0xFF64748B)),
                          ),
                        ),
                      ),
              ),
              // Alarm button — above city content (scaled so it does not appear too large)
              Positioned(
                top: scaleSize(context, -4),
                left: 0,
                child: Material(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(scaleSize(context, 16)),
                  elevation: scaleSize(context, 2),
                  shadowColor: Colors.black.withValues(alpha: 0.15),
                  child: InkWell(
                    onTap: widget.onAlarmTap,
                    borderRadius: BorderRadius.circular(scaleSize(context, 16)),
                    child: Padding(
                      padding: EdgeInsets.all(scaleSize(context, 8)),
                      child: Image.asset(
                        'assets/call-to-prayer.png',
                        width: scaleSize(context, 18),
                        height: scaleSize(context, 18),
                        fit: BoxFit.contain,
                      ),
                    ),
                  ),
                ),
              ),
              // Calendar button — last child so it renders above everything
              Positioned(
                top: scaleSize(context, -4),
                right: 0,
                child: Material(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(scaleSize(context, 14)),
                  elevation: scaleSize(context, 2),
                  shadowColor: Colors.black.withValues(alpha: 0.15),
                  child: InkWell(
                    onTap: widget.onCalendarTap,
                    borderRadius: BorderRadius.circular(scaleSize(context, 14)),
                    child: Padding(
                      padding: EdgeInsets.all(scaleSize(context, 6)),
                      child: Icon(Icons.calendar_today_outlined,
                          size: scaleSize(context, 18),
                          color: const Color(0xFF6366F1)),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
