import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../l10n/app_localizations.dart';
import '../services/calendar_service.dart';
import '../utils/scaling.dart';

class PrayerCalendarModal extends StatefulWidget {
  final double? latitude;
  final double? longitude;
  final int method;
  final String madhab;
  final Map<String, dynamic>? admin;
  final VoidCallback onClose;

  const PrayerCalendarModal({
    super.key,
    this.latitude,
    this.longitude,
    this.method = 2,
    this.madhab = 'standard',
    this.admin,
    required this.onClose,
  });

  @override
  State<PrayerCalendarModal> createState() => _PrayerCalendarModalState();
}

class _PrayerCalendarModalState extends State<PrayerCalendarModal>
    with SingleTickerProviderStateMixin {
  late AnimationController _animCtrl;
  late Animation<double> _slideAnim;
  late Animation<double> _fadeAnim;

  late DateTime _selectedMonth;
  DateTime? _selectedDate;
  List<CalendarDayData> _calendarData = [];
  bool _loading = false;

  static const _accent = Color(0xFF6366F1);
  static const _surface = Color(0xFFF8FAFC);
  static const _card = Colors.white;
  static const _textPrimary = Color(0xFF1E293B);
  static const _textSecondary = Color(0xFF64748B);
  static const _textTertiary = Color(0xFF94A3B8);
  static const _border = Color(0xFFE2E8F0);
  static const _friday = Color(0xFF10B981);

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _selectedMonth = DateTime(now.year, now.month, 1);
    _selectedDate = now;

    _animCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 380),
    );
    _slideAnim = Tween<double>(begin: 1.0, end: 0.0).animate(
      CurvedAnimation(parent: _animCtrl, curve: Curves.easeOutCubic),
    );
    _fadeAnim = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _animCtrl, curve: Curves.easeOut),
    );
    _animCtrl.forward();
    _loadData();
  }

  @override
  void dispose() {
    _animCtrl.dispose();
    super.dispose();
  }

  Future<void> _close() async {
    await _animCtrl.reverse();
    widget.onClose();
  }

  Future<void> _loadData() async {
    if (widget.latitude == null || widget.longitude == null) return;
    setState(() => _loading = true);
    try {
      final data = await getCalendarMonthData(
        latitude: widget.latitude!,
        longitude: widget.longitude!,
        method: widget.method,
        year: _selectedMonth.year,
        month: _selectedMonth.month,
        madhab: widget.madhab,
        admin: widget.admin,
      );
      if (!mounted) return;
      setState(() => _calendarData = data);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _navigateMonth(int direction) {
    final next = DateTime(
      _selectedMonth.year,
      _selectedMonth.month + direction,
      1,
    );
    final now = DateTime.now();
    final isCurrentMonth =
        next.year == now.year && next.month == now.month;
    setState(() {
      _selectedMonth = next;
      _calendarData = [];
      _selectedDate = isCurrentMonth ? now : null;
    });
    _loadData();
  }

  int _firstWeekdayOffset() {
    // Monday = 0 … Sunday = 6
    final wd = DateTime(_selectedMonth.year, _selectedMonth.month, 1).weekday;
    return wd - 1; // weekday 1=Mon…7=Sun → offset 0…6
  }

  bool _isToday(int day) {
    final now = DateTime.now();
    return day == now.day &&
        _selectedMonth.month == now.month &&
        _selectedMonth.year == now.year;
  }

  bool _isSelected(int day) {
    if (_selectedDate == null) return false;
    return day == _selectedDate!.day &&
        _selectedMonth.month == _selectedDate!.month &&
        _selectedMonth.year == _selectedDate!.year;
  }

  CalendarDayData? get _selectedDayData {
    if (_selectedDate == null) return null;
    try {
      return _calendarData.firstWhere((d) => d.day == _selectedDate!.day);
    } catch (_) {
      return null;
    }
  }

  // ── UI helpers ─────────────────────────────────────────────────────────────

  List<String> _monthNames(BuildContext ctx) =>
      AppLocalizations.t(ctx, 'calendarMonths').split(';');

  List<String> _dayNames(BuildContext ctx) =>
      AppLocalizations.t(ctx, 'calendarDays').split(';');

  List<String> _hijriMonthNames(BuildContext ctx) =>
      AppLocalizations.t(ctx, 'hijriMonths').split(';');

  @override
  Widget build(BuildContext context) {
    final mq = MediaQuery.sizeOf(context);
    // Include system safe area + custom nav bar height so nothing is hidden
    final bottom = MediaQuery.paddingOf(context).bottom + scaleSize(context, 80);
    String t(String k) => AppLocalizations.t(context, k);

    return AnimatedBuilder(
      animation: _animCtrl,
      builder: (_, child) => Stack(
        children: [
          // ── Backdrop ──────────────────────────────────────────────────────
          GestureDetector(
            onTap: _close,
            child: FadeTransition(
              opacity: _fadeAnim,
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 6, sigmaY: 6),
                child: Container(color: Colors.black.withValues(alpha: 0.28)),
              ),
            ),
          ),
          // ── Sheet ─────────────────────────────────────────────────────────
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: Transform.translate(
              offset: Offset(0, _slideAnim.value * mq.height * 0.75),
              child: child!,
            ),
          ),
        ],
      ),
      child: _buildSheet(context, bottom, t),
    );
  }

  Widget _buildSheet(
      BuildContext ctx, double bottomPad, String Function(String) t) {
    final monthNames = _monthNames(ctx);
    final dayNames = _dayNames(ctx);
    final safeName = _selectedMonth.month - 1 < monthNames.length
        ? monthNames[_selectedMonth.month - 1]
        : '';

    return ClipRRect(
      borderRadius: BorderRadius.vertical(top: Radius.circular(scaleSize(ctx, 28))),
      child: Container(
        constraints: BoxConstraints(
            maxHeight: MediaQuery.sizeOf(ctx).height * 0.88),
        decoration: BoxDecoration(
          color: _surface,
          borderRadius: BorderRadius.vertical(top: Radius.circular(scaleSize(ctx, 28))),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // ── Drag handle ───────────────────────────────────────────────
            Padding(
              padding: EdgeInsets.only(top: scaleSize(ctx, 10)),
              child: Container(
                width: scaleSize(ctx, 40),
                height: scaleSize(ctx, 4),
                decoration: BoxDecoration(
                  color: _border,
                  borderRadius: BorderRadius.circular(scaleSize(ctx, 2)),
                ),
              ),
            ),
            // ── Header row ────────────────────────────────────────────────
            Padding(
              padding: EdgeInsets.symmetric(
                horizontal: scaleSize(ctx, 20),
                vertical: scaleSize(ctx, 14),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          t('prayerCalendar'),
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: scaleFont(ctx, 18),
                            fontWeight: FontWeight.w700,
                            color: _textPrimary,
                            letterSpacing: -0.3,
                          ),
                        ),
                        SizedBox(height: scaleSize(ctx, 2)),
                        Text(
                          '$safeName ${_selectedMonth.year}',
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: scaleFont(ctx, 13),
                            color: _accent,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                  // month nav
                  _NavButton(
                    icon: Icons.chevron_left_rounded,
                    onTap: () => _navigateMonth(-1),
                  ),
                  SizedBox(width: scaleSize(ctx, 6)),
                  _NavButton(
                    icon: Icons.chevron_right_rounded,
                    onTap: () => _navigateMonth(1),
                  ),
                  SizedBox(width: scaleSize(ctx, 10)),
                  // close
                  GestureDetector(
                    onTap: _close,
                    child: Container(
                      width: scaleSize(ctx, 32),
                      height: scaleSize(ctx, 32),
                      decoration: const BoxDecoration(
                        color: _border,
                        shape: BoxShape.circle,
                      ),
                      child: Icon(Icons.close_rounded,
                          size: scaleSize(ctx, 16), color: _textSecondary),
                    ),
                  ),
                ],
              ),
            ),
            // ── Scrollable body ───────────────────────────────────────────
            Flexible(
              child: SingleChildScrollView(
                padding: EdgeInsets.only(
                  left: scaleSize(ctx, 16),
                  right: scaleSize(ctx, 16),
                  bottom: bottomPad + scaleSize(ctx, 24),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _buildCalendarGrid(ctx, dayNames),
                    SizedBox(height: scaleSize(ctx, 20)),
                    if (_loading)
                      Center(
                        child: Padding(
                          padding: EdgeInsets.symmetric(
                              vertical: scaleSize(ctx, 24)),
                          child: const CircularProgressIndicator(
                              color: _accent, strokeWidth: 2.5),
                        ),
                      )
                    else if (_selectedDayData != null)
                      _buildDayDetail(ctx, _selectedDayData!, t)
                    else if (widget.latitude == null)
                      _buildNoLocation(ctx, t),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCalendarGrid(BuildContext ctx, List<String> dayNames) {
    final offset = _firstWeekdayOffset();
    final daysInMonth =
        DateTime(_selectedMonth.year, _selectedMonth.month + 1, 0).day;
    final totalCells = offset + daysInMonth;
    final numRows = (totalCells / 7).ceil();

    return Container(
      decoration: BoxDecoration(
        color: _card,
        borderRadius: BorderRadius.circular(scaleSize(ctx, 20)),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF6366F1).withValues(alpha: 0.07),
            blurRadius: scaleSize(ctx, 20),
            offset: Offset(0, scaleSize(ctx, 4)),
          ),
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: scaleSize(ctx, 10),
            offset: Offset(0, scaleSize(ctx, 2)),
          ),
        ],
      ),
      padding: EdgeInsets.fromLTRB(
        scaleSize(ctx, 12),
        scaleSize(ctx, 16),
        scaleSize(ctx, 12),
        scaleSize(ctx, 8),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Day name header — 7 equal columns
          Row(
            children: List.generate(7, (i) {
              final isFriday = i == 4; // index 4 = Friday (Mo=0…Su=6)
              return Expanded(
                child: Center(
                  child: Text(
                    i < dayNames.length ? dayNames[i] : '',
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: scaleFont(ctx, 11.5),
                      fontWeight: FontWeight.w700,
                      color: isFriday ? _friday : _textTertiary,
                      letterSpacing: 0.2,
                    ),
                  ),
                ),
              );
            }),
          ),
          SizedBox(height: scaleSize(ctx, 10)),
          // Calendar cells — same 7-column layout so columns align with header
          LayoutBuilder(
            builder: (context, constraints) {
              final cellSize = constraints.maxWidth / 7;
              return Column(
                mainAxisSize: MainAxisSize.min,
                children: List.generate(numRows, (r) {
                  return Row(
                    children: List.generate(7, (c) {
                      final cellIndex = r * 7 + c;
                      Widget cell;
                      if (cellIndex < offset) {
                        cell = _EmptyCell(
                            key: ValueKey('e$r$c'),
                            ctx: ctx,
                            size: cellSize);
                      } else if (cellIndex < offset + daysInMonth) {
                        final day = cellIndex - offset + 1;
                        final dayData = _calendarData.isNotEmpty
                            ? _calendarData.cast<CalendarDayData?>().firstWhere(
                                (d) => d?.day == day,
                                orElse: () => null)
                            : null;
                        final isToday = _isToday(day);
                        final isSelected = _isSelected(day);
                        final weekdayIdx = cellIndex % 7;
                        final isFridayCell = weekdayIdx == 4;
                        cell = _DayCell(
                          key: ValueKey('d$day'),
                          ctx: ctx,
                          day: day,
                          isToday: isToday,
                          isSelected: isSelected,
                          hasData: dayData != null,
                          isFriday: isFridayCell,
                          onTap: () {
                            setState(() {
                              _selectedDate = DateTime(
                                  _selectedMonth.year,
                                  _selectedMonth.month,
                                  day);
                            });
                          },
                          size: cellSize,
                        );
                      } else {
                        cell = _EmptyCell(
                            key: ValueKey('e$r$c'),
                            ctx: ctx,
                            size: cellSize);
                      }
                      return Expanded(
                        child: SizedBox(
                          height: cellSize,
                          child: Center(child: cell),
                        ),
                      );
                    }),
                  );
                }),
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildDayDetail(
    BuildContext ctx,
    CalendarDayData data,
    String Function(String) t,
  ) {
    final hijriMonths = _hijriMonthNames(ctx);
    final monthNames = _monthNames(ctx);
    final selDate = _selectedDate!;
    final mName = selDate.month - 1 < monthNames.length
        ? monthNames[selDate.month - 1]
        : '';
    final hijriStr = data.hijri != null
        ? '${data.hijri!.day} ${data.hijri!.monthName} ${data.hijri!.year} AH'
        : null;
    final hijriStrLocale = (data.hijri != null &&
            data.hijri!.month >= 1 &&
            data.hijri!.month <= 12)
        ? '${data.hijri!.day} ${hijriMonths[data.hijri!.month - 1]} ${data.hijri!.year}'
        : hijriStr;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Date badge row
        Container(
          padding: EdgeInsets.symmetric(
            horizontal: scaleSize(ctx, 14),
            vertical: scaleSize(ctx, 10),
          ),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [Color(0xFF6366F1), Color(0xFF818CF8)],
              begin: Alignment.centerLeft,
              end: Alignment.centerRight,
            ),
            borderRadius: BorderRadius.circular(scaleSize(ctx, 14)),
            boxShadow: [
              BoxShadow(
                color: _accent.withValues(alpha: 0.25),
                blurRadius: scaleSize(ctx, 14),
                offset: Offset(0, scaleSize(ctx, 4)),
              ),
            ],
          ),
          child: Row(
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '${selDate.day} $mName ${selDate.year}',
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: scaleFont(ctx, 15),
                      fontWeight: FontWeight.w700,
                      color: Colors.white,
                    ),
                  ),
                  if (hijriStrLocale != null) ...[
                    SizedBox(height: scaleSize(ctx, 2)),
                    Text(
                      hijriStrLocale,
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: scaleFont(ctx, 11.5),
                        color: Colors.white.withValues(alpha: 0.82),
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ],
              ),
              const Spacer(),
              Container(
                padding: EdgeInsets.symmetric(
                  horizontal: scaleSize(ctx, 10),
                  vertical: scaleSize(ctx, 5),
                ),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.18),
                  borderRadius: BorderRadius.circular(scaleSize(ctx, 8)),
                ),
                child: Text(
                  t('hijri'),
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: scaleFont(ctx, 11),
                    color: Colors.white.withValues(alpha: 0.9),
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
        ),
        SizedBox(height: scaleSize(ctx, 14)),
        // Prayer time mini cards
        Row(
          children: [
            _PrayerMiniCard(
                ctx: ctx, label: t('fajr'), time: data.fajr, icon: Icons.nightlight_round),
            SizedBox(width: scaleSize(ctx, 6)),
            _PrayerMiniCard(
                ctx: ctx, label: t('sunrise'), time: data.sunrise, icon: Icons.wb_twilight_outlined),
            SizedBox(width: scaleSize(ctx, 6)),
            _PrayerMiniCard(
                ctx: ctx, label: t('dhuhr'), time: data.dhuhr, icon: Icons.wb_sunny_outlined),
            SizedBox(width: scaleSize(ctx, 6)),
            _PrayerMiniCard(
                ctx: ctx, label: t('asr'), time: data.asr, icon: Icons.wb_cloudy_outlined),
            SizedBox(width: scaleSize(ctx, 6)),
            _PrayerMiniCard(
                ctx: ctx, label: t('maghrib'), time: data.maghrib, icon: Icons.wb_twilight),
            SizedBox(width: scaleSize(ctx, 6)),
            _PrayerMiniCard(
                ctx: ctx, label: t('isha'), time: data.isha, icon: Icons.nights_stay_outlined),
          ],
        ),
      ],
    );
  }

  Widget _buildNoLocation(BuildContext ctx, String Function(String) t) {
    return Padding(
      padding: EdgeInsets.symmetric(vertical: scaleSize(ctx, 40)),
      child: Column(
        children: [
          Icon(Icons.location_off_outlined,
              size: scaleSize(ctx, 40), color: _textTertiary),
          SizedBox(height: scaleSize(ctx, 12)),
          Text(
            t('noLocation'),
            style: GoogleFonts.plusJakartaSans(
              fontSize: scaleFont(ctx, 14),
              color: _textSecondary,
            ),
          ),
        ],
      ),
    );
  }
}

// ── Sub-widgets ──────────────────────────────────────────────────────────────

class _NavButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;

  const _NavButton({required this.icon, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: scaleSize(context, 34),
        height: scaleSize(context, 34),
        decoration: BoxDecoration(
          color: const Color(0xFFEEF2FF),
          borderRadius: BorderRadius.circular(scaleSize(context, 10)),
        ),
        child: Icon(icon,
            size: scaleSize(context, 20), color: const Color(0xFF6366F1)),
      ),
    );
  }
}

class _EmptyCell extends StatelessWidget {
  const _EmptyCell({super.key, required this.ctx, required this.size});
  final BuildContext ctx;
  final double size;

  @override
  Widget build(BuildContext context) {
    return SizedBox(width: size, height: size);
  }
}

class _DayCell extends StatelessWidget {
  final BuildContext ctx;
  final int day;
  final bool isToday;
  final bool isSelected;
  final bool hasData;
  final bool isFriday;
  final VoidCallback onTap;
  final double size;

  const _DayCell({
    super.key,
    required this.ctx,
    required this.day,
    required this.isToday,
    required this.isSelected,
    required this.hasData,
    required this.isFriday,
    required this.onTap,
    required this.size,
  });

  @override
  Widget build(BuildContext context) {
    final radius = scaleSize(ctx, 10);

    Color bgColor = Colors.transparent;
    Color textColor = isFriday ? const Color(0xFF10B981) : const Color(0xFF1E293B);
    FontWeight fontWeight = FontWeight.w500;
    List<BoxShadow> shadows = [];

    if (isSelected) {
      bgColor = const Color(0xFF6366F1);
      textColor = Colors.white;
      fontWeight = FontWeight.w700;
      shadows = [
        BoxShadow(
          color: const Color(0xFF6366F1).withValues(alpha: 0.35),
          blurRadius: scaleSize(ctx, 10),
          offset: Offset(0, scaleSize(ctx, 3)),
        ),
      ];
    } else if (isToday) {
      bgColor = const Color(0xFFEEF2FF);
      textColor = const Color(0xFF6366F1);
      fontWeight = FontWeight.w700;
    }

    return GestureDetector(
      onTap: onTap,
      child: SizedBox(
        width: size,
        height: size,
        child: Center(
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 180),
            curve: Curves.easeOut,
            width: size * 0.82,
            height: size * 0.82,
            decoration: BoxDecoration(
              color: bgColor,
              borderRadius: BorderRadius.circular(radius),
              boxShadow: shadows,
            ),
            child: Stack(
              alignment: Alignment.center,
              children: [
                Text(
                  '$day',
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: scaleFont(ctx, 13.5),
                    color: textColor,
                    fontWeight: fontWeight,
                  ),
                ),
                // Today dot
                if (isToday && !isSelected)
                  Positioned(
                    bottom: scaleSize(ctx, 3),
                    child: Container(
                      width: scaleSize(ctx, 4),
                      height: scaleSize(ctx, 4),
                      decoration: const BoxDecoration(
                        color: Color(0xFF6366F1),
                        shape: BoxShape.circle,
                      ),
                    ),
                  ),
                // Data dot (loaded day indicator)
                if (hasData && !isToday && !isSelected)
                  Positioned(
                    bottom: scaleSize(ctx, 3),
                    child: Container(
                      width: scaleSize(ctx, 3),
                      height: scaleSize(ctx, 3),
                      decoration: BoxDecoration(
                        color: isFriday
                            ? const Color(0xFF10B981).withValues(alpha: 0.5)
                            : const Color(0xFF94A3B8).withValues(alpha: 0.6),
                        shape: BoxShape.circle,
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _PrayerMiniCard extends StatelessWidget {
  final BuildContext ctx;
  final String label;
  final String time;
  final IconData icon;

  const _PrayerMiniCard({
    required this.ctx,
    required this.label,
    required this.time,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: EdgeInsets.symmetric(
          vertical: scaleSize(ctx, 10),
          horizontal: scaleSize(ctx, 2),
        ),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(scaleSize(ctx, 14)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.05),
              blurRadius: scaleSize(ctx, 8),
              offset: Offset(0, scaleSize(ctx, 2)),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon,
                size: scaleSize(ctx, 14),
                color: const Color(0xFF94A3B8)),
            SizedBox(height: scaleSize(ctx, 4)),
            Text(
              label,
              style: GoogleFonts.plusJakartaSans(
                fontSize: scaleFont(ctx, 9),
                color: const Color(0xFF64748B),
                fontWeight: FontWeight.w500,
              ),
              textAlign: TextAlign.center,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            SizedBox(height: scaleSize(ctx, 3)),
            Text(
              time,
              style: GoogleFonts.plusJakartaSans(
                fontSize: scaleFont(ctx, 10.5),
                color: const Color(0xFF1E293B),
                fontWeight: FontWeight.w700,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}
