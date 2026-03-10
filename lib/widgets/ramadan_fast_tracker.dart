import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:hijri/hijri_calendar.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../l10n/app_localizations.dart';
import '../utils/scaling.dart';

/// Replicates the RN HomeScreen "Fast X/Y" Ramadan fasting tracker.
///
/// Shows a collapsible header (kept count / total) with an animated chevron.
/// When expanded, displays a horizontally-scrollable row of day pills; each
/// pill shows the Gregorian day+month and turns green (fasted) or red (missed).
/// Past/present days can be toggled; future days are dimmed and non-interactive.
///
/// The "Edit" pill opens a settings dialog with:
///   1. Ramadan start date question (18th or 19th)
///   2. Qadha (make-up) fast question (yes / no)
///   3. Qadha days input (only when answered yes)
class RamadanFastTracker extends StatefulWidget {
  /// Current Hijri day of Ramadan (1–30).
  final int hijriDay;

  /// Current Hijri year (e.g. 1447).
  final int hijriYear;

  const RamadanFastTracker({
    super.key,
    required this.hijriDay,
    required this.hijriYear,
  });

  @override
  State<RamadanFastTracker> createState() => _RamadanFastTrackerState();
}

class _RamadanFastTrackerState extends State<RamadanFastTracker>
    with SingleTickerProviderStateMixin {
  bool _expanded = false;
  Map<int, String> _statuses = {}; // dayNum → 'yes' | 'no'
  int _keptCount = 0;

  // Settings (persisted)
  String _startAnswer = '18';   // '18' | '19'
  String? _qadhaAnswer;         // 'yes' | 'no' | null
  String _qadhaDays = '';

  final _scrollCtrl = ScrollController();
  late final AnimationController _chevronCtrl;
  late final Animation<double> _chevronAngle;

  int get _totalDays => _startAnswer == '19' ? 29 : 30;

  int get _effectiveCurrentDay {
    if (_startAnswer == '19') {
      return math.max(0, math.min(widget.hijriDay - 1, _totalDays));
    }
    return math.max(1, math.min(widget.hijriDay, _totalDays));
  }

  @override
  void initState() {
    super.initState();
    _chevronCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 200),
    );
    _chevronAngle = Tween<double>(begin: 0, end: math.pi / 2)
        .animate(CurvedAnimation(parent: _chevronCtrl, curve: Curves.easeOut));
    _loadAll();
  }

  @override
  void dispose() {
    _chevronCtrl.dispose();
    _scrollCtrl.dispose();
    super.dispose();
  }

  // ── Persistence ─────────────────────────────────────────────────────────────

  Future<void> _loadAll() async {
    final prefs = await SharedPreferences.getInstance();
    final start =
        prefs.getString('ramadan_start_answer_${widget.hijriYear}') ?? '18';
    final qadha = prefs.getString('ramadan_qadha_${widget.hijriYear}');
    final qadhaDays =
        prefs.getString('ramadan_qadha_days_${widget.hijriYear}') ?? '';
    if (mounted) {
      setState(() {
        _startAnswer = start;
        _qadhaAnswer = qadha;
        _qadhaDays = qadhaDays;
      });
    }
    await _load(startAnswer: start);
  }

  Future<void> _load({String? startAnswer}) async {
    final answer = startAnswer ?? _startAnswer;
    final totalDays = answer == '19' ? 29 : 30;
    final currentDay = answer == '19'
        ? math.max(0, math.min(widget.hijriDay - 1, totalDays))
        : math.max(1, math.min(widget.hijriDay, totalDays));

    final prefs = await SharedPreferences.getInstance();
    final statuses = <int, String>{};
    int count = 0;
    for (int n = 1; n <= totalDays; n++) {
      final saved = prefs.getString('ramadan_fast_${widget.hijriYear}_$n');
      final status = saved ?? (n <= currentDay ? 'yes' : 'no');
      statuses[n] = status;
      if (status == 'yes') count++;
    }
    if (mounted) {
      setState(() {
        _statuses = statuses;
        _keptCount = count;
      });
    }
  }

  Future<void> _toggle(int dayNum) async {
    if (dayNum > _effectiveCurrentDay) return;
    final prefs = await SharedPreferences.getInstance();
    final next = _statuses[dayNum] == 'yes' ? 'no' : 'yes';
    await prefs.setString('ramadan_fast_${widget.hijriYear}_$dayNum', next);
    final nextStatuses = Map<int, String>.from(_statuses)..[dayNum] = next;
    final count = nextStatuses.values.where((v) => v == 'yes').length;
    if (mounted) setState(() { _statuses = nextStatuses; _keptCount = count; });
  }

  // ── UI helpers ──────────────────────────────────────────────────────────────

  void _toggleExpanded() {
    final next = !_expanded;
    next ? _chevronCtrl.forward() : _chevronCtrl.reverse();
    setState(() => _expanded = next);
  }

  DateTime _gregDate(int ramadanDay) {
    final hc = HijriCalendar();
    // Option 19: fasting begins one Hijri day later, so shift each pill date by +1
    final hijriDay = _startAnswer == '19' ? ramadanDay + 1 : ramadanDay;
    return hc.hijriToGregorian(widget.hijriYear, 9, hijriDay);
  }

  String _monthShort(DateTime date, BuildContext context) {
    final months = AppLocalizations.t(context, 'gregorianMonths').split(';');
    final full = months[(date.month - 1).clamp(0, 11)];
    return full.length > 3 ? full.substring(0, 3) : full;
  }

  void _showSettingsDialog(BuildContext context) {
    showDialog<void>(
      context: context,
      builder: (ctx) => _RamadanSettingsDialog(
        hijriYear: widget.hijriYear,
        initialStartAnswer: _startAnswer,
        initialQadhaAnswer: _qadhaAnswer,
        initialQadhaDays: _qadhaDays,
        onStartAnswerChanged: (answer) async {
          final prefs = await SharedPreferences.getInstance();
          await prefs.setString(
              'ramadan_start_answer_${widget.hijriYear}', answer);
          // Clear all saved day statuses so defaults are recalculated
          // fresh for the new start date (30 days covers both options).
          for (int n = 1; n <= 30; n++) {
            await prefs.remove('ramadan_fast_${widget.hijriYear}_$n');
          }
          if (mounted) setState(() => _startAnswer = answer);
          await _load(startAnswer: answer);
        },
        onQadhaAnswerChanged: (answer, days) async {
          final prefs = await SharedPreferences.getInstance();
          await prefs.setString('ramadan_qadha_${widget.hijriYear}', answer);
          if (answer == 'no') {
            await prefs.remove('ramadan_qadha_days_${widget.hijriYear}');
          }
          if (mounted) setState(() { _qadhaAnswer = answer; _qadhaDays = days; });
        },
        onQadhaDaysChanged: (days) async {
          final prefs = await SharedPreferences.getInstance();
          await prefs.setString(
              'ramadan_qadha_days_${widget.hijriYear}', days);
          if (mounted) setState(() => _qadhaDays = days);
        },
      ),
    );
  }

  // ── Build ───────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final t = (String k) => AppLocalizations.t(context, k);
    final keptLabel = t('ramadanProgressLabel')
        .replaceAll('{count}', '$_keptCount')
        .replaceAll('{total}', '$_totalDays');

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        // ── Header bar ───────────────────────────────────────────────────────
        GestureDetector(
          onTap: _toggleExpanded,
          child: Container(
            margin: EdgeInsets.only(
                top: scaleSize(context, 6), bottom: scaleSize(context, 4)),
            padding: EdgeInsets.symmetric(
              vertical: scaleSize(context, 10),
              horizontal: scaleSize(context, 16),
            ),
            decoration: BoxDecoration(
              color: const Color(0xFFEEF2FF),
              borderRadius: BorderRadius.circular(scaleSize(context, 10)),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  keptLabel,
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: scaleFont(context, 14),
                    fontWeight: FontWeight.w600,
                    color: const Color(0xFF4F46E5),
                  ),
                ),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (_expanded) ...[
                      GestureDetector(
                        onTap: () => _showSettingsDialog(context),
                        child: _EditPill(label: t('ramadanProgressEdit')),
                      ),
                      SizedBox(width: scaleSize(context, 8)),
                    ],
                    AnimatedBuilder(
                      animation: _chevronAngle,
                      builder: (_, child) =>
                          Transform.rotate(angle: _chevronAngle.value, child: child),
                      child: Icon(Icons.chevron_right,
                          size: scaleSize(context, 18),
                          color: const Color(0xFF94A3B8)),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),

        // ── Expanded day pills ───────────────────────────────────────────────
        if (_expanded)
          LayoutBuilder(
            builder: (context, constraints) {
              final hPad = scaleSize(context, 16);
              final contentWidth = constraints.maxWidth - hPad * 2;
              final itemWidth = (contentWidth / 7).floorToDouble();
              final sidePad = math
                  .max(0.0, (contentWidth / 2 - itemWidth / 2).floorToDouble());

              WidgetsBinding.instance.addPostFrameCallback((_) {
                if (_scrollCtrl.hasClients &&
                    _scrollCtrl.position.hasContentDimensions &&
                    _scrollCtrl.offset == 0) {
                  final target =
                      math.max(0.0, (_effectiveCurrentDay - 1) * itemWidth);
                  _scrollCtrl.jumpTo(
                      target.clamp(0.0, _scrollCtrl.position.maxScrollExtent));
                }
              });

              return Container(
                decoration: BoxDecoration(
                  color: const Color(0xFFF1F5F9),
                  borderRadius: BorderRadius.only(
                    bottomLeft:
                        Radius.circular(scaleSize(context, 10)),
                    bottomRight:
                        Radius.circular(scaleSize(context, 10)),
                  ),
                ),
                margin: EdgeInsets.only(bottom: scaleSize(context, 4)),
                child: ListenableBuilder(
                  listenable: _scrollCtrl,
                  builder: (_, __) {
                    final offset = _scrollCtrl.hasClients
                        ? _scrollCtrl.offset
                        : 0.0;
                    return SingleChildScrollView(
                      controller: _scrollCtrl,
                      scrollDirection: Axis.horizontal,
                      padding:
                          EdgeInsets.symmetric(horizontal: sidePad),
                      child: Row(
                        children:
                            List.generate(_totalDays, (index) {
                          final dayNum = index + 1;
                          final isToday =
                              dayNum == _effectiveCurrentDay;
                          final canToggle =
                              dayNum <= _effectiveCurrentDay;
                          final fasted = _statuses[dayNum] != 'no';

                          final pillBg = !canToggle
                              ? Colors.transparent
                              : fasted
                                  ? const Color(0xFFD1FAE5)
                                  : const Color(0xFFFEE2E2);

                          final centerX = index * itemWidth;
                          final dist = (centerX - offset).abs();
                          final t01 =
                              (dist / (itemWidth * 2)).clamp(0.0, 1.0);
                          final opacity = 1.0 - t01 * 0.55;
                          final scale = 1.0 - t01 * 0.15;

                          final gregDate = _gregDate(dayNum);

                          return Opacity(
                            opacity: opacity,
                            child: Transform.scale(
                              scale: scale,
                              child: GestureDetector(
                                onTap: canToggle
                                    ? () => _toggle(dayNum)
                                    : null,
                                child: SizedBox(
                                  width: itemWidth,
                                  child: Container(
                                    margin: EdgeInsets.symmetric(
                                      horizontal:
                                          scaleSize(context, 1),
                                      vertical: scaleSize(context, 4),
                                    ),
                                    padding: EdgeInsets.symmetric(
                                        vertical:
                                            scaleSize(context, 4)),
                                    decoration: BoxDecoration(
                                      color: pillBg,
                                      borderRadius:
                                          BorderRadius.circular(
                                              scaleSize(context, 6)),
                                      border: isToday
                                          ? Border.all(
                                              width:
                                                  scaleSize(context, 2),
                                              color: const Color(
                                                  0xFF4F46E5),
                                            )
                                          : null,
                                    ),
                                    child: Column(
                                      mainAxisAlignment:
                                          MainAxisAlignment.center,
                                      children: [
                                        Text(
                                          '${gregDate.day}',
                                          style: GoogleFonts.plusJakartaSans(
                                            fontSize: scaleFont(context,
                                                isToday ? 14 : 13),
                                            fontWeight: isToday
                                                ? FontWeight.w700
                                                : FontWeight.w500,
                                            color: !canToggle
                                                ? const Color(0xFF64748B)
                                                : fasted
                                                    ? const Color(
                                                        0xFF166534)
                                                    : const Color(
                                                        0xFF991B1B),
                                          ),
                                        ),
                                        SizedBox(
                                            height:
                                                scaleSize(context, 2)),
                                        Text(
                                          _monthShort(gregDate, context),
                                          style: GoogleFonts.plusJakartaSans(
                                            fontSize:
                                                scaleFont(context, 10),
                                            fontWeight: isToday
                                                ? FontWeight.w600
                                                : FontWeight.w500,
                                            color: !canToggle
                                                ? const Color(0xFF94A3B8)
                                                : fasted
                                                    ? const Color(
                                                        0xFF15803D)
                                                    : const Color(
                                                        0xFFB91C1C),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          );
                        }),
                      ),
                    );
                  },
                ),
              );
            },
          ),
      ],
    );
  }
}

// ── Settings dialog ──────────────────────────────────────────────────────────

class _RamadanSettingsDialog extends StatefulWidget {
  final int hijriYear;
  final String initialStartAnswer;
  final String? initialQadhaAnswer;
  final String initialQadhaDays;
  final ValueChanged<String> onStartAnswerChanged;
  final void Function(String answer, String days) onQadhaAnswerChanged;
  final ValueChanged<String> onQadhaDaysChanged;

  const _RamadanSettingsDialog({
    required this.hijriYear,
    required this.initialStartAnswer,
    required this.initialQadhaAnswer,
    required this.initialQadhaDays,
    required this.onStartAnswerChanged,
    required this.onQadhaAnswerChanged,
    required this.onQadhaDaysChanged,
  });

  @override
  State<_RamadanSettingsDialog> createState() =>
      _RamadanSettingsDialogState();
}

class _RamadanSettingsDialogState extends State<_RamadanSettingsDialog> {
  late String _startAnswer;
  late String? _qadhaAnswer;
  late final TextEditingController _daysCtrl;
  final _scrollCtrl = ScrollController();

  @override
  void initState() {
    super.initState();
    _startAnswer = widget.initialStartAnswer;
    _qadhaAnswer = widget.initialQadhaAnswer;
    _daysCtrl = TextEditingController(text: widget.initialQadhaDays);
  }

  @override
  void dispose() {
    _daysCtrl.dispose();
    _scrollCtrl.dispose();
    super.dispose();
  }

  void _scrollDown() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollCtrl.hasClients) {
        _scrollCtrl.animateTo(
          _scrollCtrl.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final t = (String k) => AppLocalizations.t(context, k);

    return Dialog(
      shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(scaleSize(context, 16))),
      backgroundColor: Colors.white,
      child: Padding(
        padding: EdgeInsets.all(scaleSize(context, 20)),
        child: ConstrainedBox(
          constraints: BoxConstraints(
              maxHeight: MediaQuery.of(context).size.height * 0.7),
          child: SingleChildScrollView(
            controller: _scrollCtrl,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // ── Q1: Start date ──────────────────────────────────────────
                _Question(
                  text: t('ramadanStartQuestion'),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      _OptionButton(
                        label: t('ramadanStartOption18'),
                        active: _startAnswer == '18',
                        onTap: () {
                          setState(() => _startAnswer = '18');
                          widget.onStartAnswerChanged('18');
                          _scrollDown();
                        },
                      ),
                      SizedBox(height: scaleSize(context, 6)),
                      _OptionButton(
                        label: t('ramadanStartOption19'),
                        active: _startAnswer == '19',
                        onTap: () {
                          setState(() => _startAnswer = '19');
                          widget.onStartAnswerChanged('19');
                          _scrollDown();
                        },
                      ),
                    ],
                  ),
                ),
                _CurrentAnswer(
                  prefix: t('ramadanStartCurrentAnswer'),
                  value: _startAnswer == '18'
                      ? t('ramadanStartOption18')
                      : t('ramadanStartOption19'),
                ),

                _Divider(),

                // ── Q2: Qadha ───────────────────────────────────────────────
                _Question(
                  text: t('ramadanQadhaQuestion'),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      _OptionButton(
                        label: t('ramadanQadhaYes'),
                        active: _qadhaAnswer == 'yes',
                        onTap: () {
                          setState(() => _qadhaAnswer = 'yes');
                          widget.onQadhaAnswerChanged('yes', _daysCtrl.text);
                          _scrollDown();
                        },
                      ),
                      SizedBox(height: scaleSize(context, 6)),
                      _OptionButton(
                        label: t('ramadanQadhaNo'),
                        active: _qadhaAnswer == 'no',
                        onTap: () {
                          setState(() { _qadhaAnswer = 'no'; _daysCtrl.clear(); });
                          widget.onQadhaAnswerChanged('no', '');
                        },
                      ),
                    ],
                  ),
                ),
                if (_qadhaAnswer != null)
                  _CurrentAnswer(
                    prefix: t('ramadanQadhaCurrentAnswer'),
                    value: _qadhaAnswer == 'yes'
                        ? t('ramadanQadhaYes')
                        : t('ramadanQadhaNo'),
                  ),

                // ── Q3: Qadha days (only when answered yes) ─────────────────
                if (_qadhaAnswer == 'yes') ...[
                  _Divider(),
                  _Question(
                    text: t('ramadanQadhaDaysLabel'),
                    child: TextField(
                      controller: _daysCtrl,
                      keyboardType: TextInputType.number,
                      maxLength: 3,
                      decoration: InputDecoration(
                        hintText: t('ramadanQadhaDaysPlaceholder'),
                        hintStyle: GoogleFonts.plusJakartaSans(
                            color: const Color(0xFF94A3B8),
                            fontSize: scaleFont(context, 14)),
                        counterText: '',
                        filled: true,
                        fillColor: const Color(0xFFF1F5F9),
                        border: OutlineInputBorder(
                          borderRadius:
                              BorderRadius.circular(scaleSize(context, 8)),
                          borderSide: BorderSide.none,
                        ),
                        contentPadding: EdgeInsets.symmetric(
                          vertical: scaleSize(context, 10),
                          horizontal: scaleSize(context, 12),
                        ),
                      ),
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: scaleFont(context, 16),
                        fontWeight: FontWeight.w600,
                        color: const Color(0xFF1E293B),
                      ),
                      onChanged: (val) {
                        final digits = val.replaceAll(RegExp(r'\D'), '');
                        if (digits != val) {
                          _daysCtrl.text = digits;
                          _daysCtrl.selection = TextSelection.collapsed(
                              offset: digits.length);
                        }
                        widget.onQadhaDaysChanged(digits);
                      },
                    ),
                  ),
                ],

                SizedBox(height: scaleSize(context, 16)),
                Align(
                  alignment: Alignment.centerRight,
                  child: TextButton(
                    onPressed: () => Navigator.of(context).pop(),
                    child: Text(
                      t('save'),
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: scaleFont(context, 14),
                        fontWeight: FontWeight.w700,
                        color: const Color(0xFF4F46E5),
                      ),
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

// ── Shared small widgets ─────────────────────────────────────────────────────

class _Question extends StatelessWidget {
  final String text;
  final Widget child;
  const _Question({required this.text, required this.child});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(top: scaleSize(context, 16)),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Text(
              text,
              style: GoogleFonts.plusJakartaSans(
                fontSize: scaleFont(context, 13),
                color: const Color(0xFF1E293B),
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          SizedBox(width: scaleSize(context, 12)),
          SizedBox(width: scaleSize(context, 90), child: child),
        ],
      ),
    );
  }
}

class _OptionButton extends StatelessWidget {
  final String label;
  final bool active;
  final VoidCallback onTap;
  const _OptionButton(
      {required this.label, required this.active, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: EdgeInsets.symmetric(
            vertical: scaleSize(context, 8),
            horizontal: scaleSize(context, 10)),
        decoration: BoxDecoration(
          color: active ? const Color(0xFF4F46E5) : const Color(0xFFEEF2FF),
          borderRadius: BorderRadius.circular(scaleSize(context, 8)),
        ),
        child: Text(
          label,
          textAlign: TextAlign.center,
          style: GoogleFonts.plusJakartaSans(
            fontSize: scaleFont(context, 13),
            fontWeight: FontWeight.w600,
            color:
                active ? Colors.white : const Color(0xFF4F46E5),
          ),
        ),
      ),
    );
  }
}

class _CurrentAnswer extends StatelessWidget {
  final String prefix;
  final String value;
  const _CurrentAnswer({required this.prefix, required this.value});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(top: scaleSize(context, 6)),
      child: Text(
        '$prefix $value',
        style: GoogleFonts.plusJakartaSans(
          fontSize: scaleFont(context, 12),
          color: const Color(0xFF6366F1),
          fontWeight: FontWeight.w500,
        ),
      ),
    );
  }
}

class _Divider extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(top: scaleSize(context, 16)),
      child: Divider(
          height: 1,
          thickness: 1,
          color: const Color(0xFFE2E8F0)),
    );
  }
}

class _EditPill extends StatelessWidget {
  final String label;
  const _EditPill({required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.symmetric(
        vertical: scaleSize(context, 4),
        horizontal: scaleSize(context, 8),
      ),
      decoration: BoxDecoration(
        color: const Color(0xFFE0E7FF),
        borderRadius: BorderRadius.circular(scaleSize(context, 999)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.edit_outlined,
              size: scaleSize(context, 14),
              color: const Color(0xFF4338CA)),
          SizedBox(width: scaleSize(context, 4)),
          Text(
            label,
            style: GoogleFonts.plusJakartaSans(
              fontSize: scaleFont(context, 11),
              fontWeight: FontWeight.w700,
              color: const Color(0xFF4338CA),
            ),
          ),
        ],
      ),
    );
  }
}
