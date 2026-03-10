import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../contexts/theme_provider.dart';
import '../l10n/app_localizations.dart';
import '../utils/scaling.dart';

/// Orbit kartının dış container, clip ve görünen iç alanı için tek radius (hepsi eşit, belirgin yuvarlak).
const double kOrbitContainerRadius = 22.0;

class PrayerOrbitWidget extends StatefulWidget {
  final String fajr;
  final String sunrise;
  final String dhuhr;
  final String asr;
  final String maghrib;
  final String isha;

  /// Today's recorded moods: {prayerKey: 'sad'|'neutral'|'happy'}.
  final Map<String, String> moods;

  const PrayerOrbitWidget({
    super.key,
    required this.fajr,
    required this.sunrise,
    required this.dhuhr,
    required this.asr,
    required this.maghrib,
    required this.isha,
    this.moods = const {},
  });

  @override
  State<PrayerOrbitWidget> createState() => _PrayerOrbitWidgetState();
}

class _PrayerOrbitWidgetState extends State<PrayerOrbitWidget>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late Timer _minuteTick;
  DateTime _now = DateTime.now();

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(minutes: 1),
    )..repeat();
    _minuteTick = Timer.periodic(const Duration(minutes: 1), (_) {
      if (mounted) setState(() => _now = DateTime.now());
    });
  }

  @override
  void dispose() {
    _ctrl.dispose();
    _minuteTick.cancel();
    super.dispose();
  }

  static String? _moodEmoji(String? mood) => switch (mood) {
        'sad' => '😢',
        'neutral' => '😐',
        'happy' => '😊',
        _ => null,
      };

  static int _mins(String t) {
    final p = t.split(':');
    if (p.length < 2) return 0;
    return (int.tryParse(p[0]) ?? 0) * 60 + (int.tryParse(p[1]) ?? 0);
  }

  /// Teheccüt başlangıç saati: gece (İsha–Fajr) son 1/3'ün başı = Fajr - (gece süresi/3).
  static String _tahajjudStartTime(String isha, String fajr) {
    final ishaMins = _mins(isha);
    final fajrMins = _mins(fajr);
    final nightLen = fajrMins > ishaMins
        ? fajrMins - ishaMins
        : (1440 - ishaMins) + fajrMins;
    if (nightLen < 10) return '';
    final lastThird = nightLen / 3.0;
    int startMins = (fajrMins - lastThird).round();
    if (startMins < 0) startMins += 1440;
    startMins = startMins % 1440;
    final h = startMins ~/ 60;
    final m = startMins % 60;
    return '${h.toString().padLeft(2, '0')}:${m.toString().padLeft(2, '0')}';
  }

  /// Returns the index (0-5) of the prayer we're currently in: the last one that has passed.
  /// Böylece vurgulama sadece o dakikada değil, o vakit diliminin tamamında görünür.
  int _computeHighlightedIndex() {
    final nowMins = _now.hour * 60 + _now.minute;
    final prayerMins = [
      _mins(widget.fajr),
      _mins(widget.sunrise),
      _mins(widget.dhuhr),
      _mins(widget.asr),
      _mins(widget.maghrib),
      _mins(widget.isha),
    ];
    if (nowMins < prayerMins[0]) return 5;
    int lastPassed = 0;
    for (int i = 0; i < prayerMins.length; i++) {
      if (prayerMins[i] <= nowMins) lastPassed = i;
    }
    return lastPassed;
  }

  @override
  Widget build(BuildContext context) {
    // Subscribe to ThemeProvider so the widget rebuilds on every language change.
    context.watch<ThemeProvider>();

    final nowF = (_now.hour * 60 + _now.minute) / 1440.0;
    final fajrF = _mins(widget.fajr) / 1440.0;
    final sunriseF = _mins(widget.sunrise) / 1440.0;
    final dhuhrF = _mins(widget.dhuhr) / 1440.0;
    final asrF = _mins(widget.asr) / 1440.0;
    final maghribF = _mins(widget.maghrib) / 1440.0;
    final ishaF = _mins(widget.isha) / 1440.0;

    // Localised names are read in the outer build so that a language change
    // immediately triggers a rebuild and the updated strings reach the painter.
    String loc(String k) => AppLocalizations.t(context, k);
    final names = [
      loc('fajr'),
      loc('sunrise'),
      loc('dhuhr'),
      loc('asr'),
      loc('maghrib'),
      loc('isha'),
    ];

    // Mood emojis aligned to the 6 prayer slots (sunrise has no mood).
    final moodEmojis = [
      _moodEmoji(widget.moods['fajr']),
      null, // sunrise – no mood
      _moodEmoji(widget.moods['dhuhr']),
      _moodEmoji(widget.moods['asr']),
      _moodEmoji(widget.moods['maghrib']),
      _moodEmoji(widget.moods['isha']),
    ];

    final highlightedIndex = _computeHighlightedIndex();
    final r = scaleSize(context, kOrbitContainerRadius);

    return Container(
      width: double.infinity,
      height: scaleSize(context, 184),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(r),
        color: const Color(0xFFF8FAFC),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.30),
            blurRadius: scaleSize(context, 10),
            offset: Offset(0, scaleSize(context, 3)),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(r),
        child: AnimatedBuilder(
          animation: _ctrl,
          builder: (_, __) {
            final preciseNowF = nowF + _ctrl.value / 1440.0;
            // 4 smooth pulses per minute via sine wave
            final highlightPhase =
                (math.sin(_ctrl.value * math.pi * 8) * 0.5 + 0.5)
                    .clamp(0.0, 1.0);
            return CustomPaint(
              painter: _OrbitPainter(
                fajrF: fajrF,
                sunriseF: sunriseF,
                dhuhrF: dhuhrF,
                asrF: asrF,
                maghribF: maghribF,
                ishaF: ishaF,
                nowF: preciseNowF,
                names: names,
                times: [
                  widget.fajr,
                  widget.sunrise,
                  widget.dhuhr,
                  widget.asr,
                  widget.maghrib,
                  widget.isha,
                ],
                moodEmojis: moodEmojis,
                highlightedIndex: highlightedIndex,
                highlightPhase: highlightPhase,
                clipRadius: r,
                tahajjudLabel: loc('tahajjud'),
                tahajjudLabelFontSize: scaleFont(context, 14),
                tahajjudLabelRadiusFactor: 0.62,
                tahajjudStartTime: _tahajjudStartTime(widget.isha, widget.fajr),
              ),
            );
          },
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────

class _OrbitPainter extends CustomPainter {
  final double fajrF, sunriseF, dhuhrF, asrF, maghribF, ishaF, nowF;
  final List<String> names;
  final List<String> times;

  /// Mood emojis for each of the 6 prayer slots (null = no mood yet).
  final List<String?> moodEmojis;

  /// Index of the prayer that just became active (0-5), or -1 for none.
  final int highlightedIndex;

  /// Pulse phase 0..1 for the highlight animation (driven by AnimationController).
  final double highlightPhase;

  /// Güneş/ay orbit alanının köşe radius’u (canvas bu RRect ile kırpılır).
  final double clipRadius;

  /// Teheccüt dilimi içinde gösterilecek etiket (dil dosyasından: tahajjud).
  final String tahajjudLabel;

  /// Teheccüt etiket yazı boyutu (scaleFont ile geçirilir).
  final double tahajjudLabelFontSize;

  /// Merkez–yay arası konum: 0.5 = tam orta, 0.62 = merkezden hafif uzak (yay tarafına).
  final double tahajjudLabelRadiusFactor;

  /// Teheccüt başlangıç saati (HH:mm), boşsa container çizilmez.
  final String tahajjudStartTime;

  static const double _pillW = 66.0;
  static const double _pillH = 34.0;

  /// Tüm pill/container köşelerinde eşit radius.
  static const double _pillRadius = 10.0;

  /// Güneş/ayın yüzdüğü orbit çizgisi: gece yayı (maghrib→sunrise) kalınlıkları.
  static const double orbitTrackNightGlowWidth = 5.0;
  static const double orbitTrackNightCoreWidth = 1.4;
  /// Güneş/ayın yüzdüğü orbit çizgisi: gündüz yayı (sunrise→maghrib) kalınlıkları.
  static const double orbitTrackDayGlowWidth = 6.0;
  static const double orbitTrackDayCoreWidth = 1.6;
  /// Orbit çizgisinin köşe radius’u (birleşim yerlerinde yuvarlaklık). 0 = sivri.
  static const double orbitTrackCornerRadius = 16.0;

  _OrbitPainter({
    required this.fajrF,
    required this.sunriseF,
    required this.dhuhrF,
    required this.asrF,
    required this.maghribF,
    required this.ishaF,
    required this.nowF,
    required this.names,
    required this.times,
    this.moodEmojis = const [null, null, null, null, null, null],
    this.highlightedIndex = -1,
    this.highlightPhase = 0.0,
    this.clipRadius = 28.0,
    this.tahajjudLabel = 'Teheccüt',
    this.tahajjudLabelFontSize = 14.0,
    this.tahajjudLabelRadiusFactor = 0.62,
    this.tahajjudStartTime = '',
  });

  // ── Star field: more realistic with color and size variation ───────────────
  static final List<List<double>> _stars = _genStars();
  static List<List<double>> _genStars() {
    final out = <List<double>>[];
    for (int i = 0; i < 180; i++) {
      // More stars
      final a = (((i + 1) * 2654435761) & 0xFFFFFFFF) / 4294967295.0;
      final b = (((i + 1) * 2246822519 + 1111111) & 0xFFFFFFFF) / 4294967295.0;
      final c = (((i + 1) * 3266489917 + 2222222) & 0xFFFFFFFF) / 4294967295.0;
      final d = (((i + 1) * 668265263 + 3333333) & 0xFFFFFFFF) / 4294967295.0;
      final double r;
      final double alpha;
      // Determine size tier
      if (i < 10) {
        // brightest
        r = 1.4 + c * 0.8;
        alpha = 0.85 + d * 0.15;
      } else if (i < 40) {
        // medium
        r = 0.8 + c * 0.5;
        alpha = 0.55 + d * 0.25;
      } else {
        // faint
        r = 0.25 + c * 0.3;
        alpha = 0.2 + d * 0.2;
      }
      // Add color variation: 0=white, 1=slightly blue, 2=slightly red
      final int colorType = (i * 7) % 3;
      out.add([a, b, r, alpha, colorType.toDouble()]);
    }
    return out;
  }

  // ── Perimeter mapping (sharp rectangle) ────────────────────────────────────
  static Offset _pt(
    double cx,
    double cy,
    double rl,
    double rt,
    double rr,
    double rb,
    double t,
  ) {
    final double W = rr - rl;
    final double H = rb - rt;
    final double P = 2 * (W + H);
    final double s1 = W / 2;
    final double s2 = s1 + H;
    final double s3 = s2 + W;
    final double s4 = s3 + H;
    final double d = (t % 1.0) * P;
    if (d < s1) return Offset(cx - d, rb);
    if (d < s2) return Offset(rl, rb - (d - s1));
    if (d < s3) return Offset(rl + (d - s2), rt);
    if (d < s4) return Offset(rr, rt + (d - s3));
    return Offset(rr - (d - s4), rb);
  }

  /// Yuvarlak köşeli orbit çizgisi: t ∈ [0,1] → perimeter üzerinde nokta (köşelerde radius).
  static Offset _ptRounded(
    double cx,
    double cy,
    double rl,
    double rt,
    double rr,
    double rb,
    double R,
    double t,
  ) {
    if (R <= 0) return _pt(cx, cy, rl, rt, rr, rb, t);
    final double W = rr - rl;
    final double H = rb - rt;
    final double halfW = W / 2;
    final double L = 2 * W + 2 * H - 8 * R + 2 * math.pi * R;
    double d = (t % 1.0) * L;
    final double s1 = halfW - R;
    final double s2 = s1 + math.pi * R / 2;
    final double s3 = s2 + (H - 2 * R);
    final double s4 = s3 + math.pi * R / 2;
    final double s5 = s4 + (W - 2 * R);
    final double s6 = s5 + math.pi * R / 2;
    final double s7 = s6 + (H - 2 * R);
    final double s8 = s7 + math.pi * R / 2;
    if (d < s1) return Offset(cx - d, rb);
    if (d < s2) {
      final double a = math.pi / 2 + (d - s1) / R;
      return Offset(rl + R + R * math.cos(a), rb - R + R * math.sin(a));
    }
    d -= s2;
    if (d < s3 - s2) return Offset(rl, rb - R - d);
    d -= (s3 - s2);
    if (d < s4 - s3) {
      final double a = math.pi + d / R;
      return Offset(rl + R + R * math.cos(a), rt + R + R * math.sin(a));
    }
    d -= (s4 - s3);
    if (d < s5 - s4) return Offset(rl + R + d, rt);
    d -= (s5 - s4);
    if (d < s6 - s5) {
      final double a = 3 * math.pi / 2 + d / R;
      return Offset(rr - R + R * math.cos(a), rt + R + R * math.sin(a));
    }
    d -= (s6 - s5);
    if (d < s7 - s6) return Offset(rr, rt + R + d);
    d -= (s7 - s6);
    if (d < s8 - s7) {
      final double a = d / R;
      return Offset(rr - R + R * math.cos(a), rb - R + R * math.sin(a));
    }
    d -= (s8 - s7);
    return Offset(rr - R - d, rb);
  }

  // ── Text helper (same) ─────────────────────────────────────────────────────
  void _text(
    Canvas canvas,
    String text,
    Offset center,
    Color color, {
    double size = 9.0,
    FontWeight weight = FontWeight.w700,
  }) {
    final TextPainter tp = TextPainter(
      text: TextSpan(
        text: text,
        style: GoogleFonts.plusJakartaSans(
          color: color,
          fontSize: size,
          fontWeight: weight,
          letterSpacing: 0.3,
          height: 1.0,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    tp.paint(canvas, center - Offset(tp.width / 2, tp.height / 2));
  }

  // ── Premium Sun with midday intensity ──────────────────────────────────────
  void _drawSun(Canvas canvas, Offset pos, double sunHeight) {
    // sunHeight: 0 at horizon, 1 at zenith (midday)
    // Base colors: at horizon warm, at midday white-hot
    final Color coreC = Color.lerp(
      const Color(0xFFFFD54F), // warm yellow
      Colors.white,
      sunHeight,
    )!;
    final Color midC = Color.lerp(
      const Color(0xFFFFB300), // orange
      const Color(0xFFFFF9C4), // light yellow
      sunHeight,
    )!;
    final Color rimC = Color.lerp(
      const Color(0xFFFF8F00), // dark orange
      const Color(0xFFFFF176), // pale yellow
      sunHeight,
    )!;

    // Glow size and opacity increase with height
    final double glowFactor = 0.8 + sunHeight * 0.8; // 0.8 .. 1.6
    final double rayFactor = 1.0 + sunHeight * 1.2; // 1.0 .. 2.2

    // Outer glows
    canvas.drawCircle(
      pos,
      68 * glowFactor,
      Paint()
        ..color = rimC.withValues(alpha: 0.055 + sunHeight * 0.06)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 34),
    );
    canvas.drawCircle(
      pos,
      46 * glowFactor,
      Paint()
        ..color = midC.withValues(alpha: 0.12 + sunHeight * 0.10)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 18),
    );
    canvas.drawCircle(
      pos,
      26 * glowFactor,
      Paint()
        ..color = coreC.withValues(alpha: 0.26 + sunHeight * 0.15)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 8),
    );

    // Sun rays – longer and brighter at midday
    for (int j = 0; j < 16; j++) {
      final double angle = j * math.pi / 8;
      final bool isLong = j % 4 == 0;
      final bool isMed = j % 4 == 2;
      final double baseOuterR = isLong ? 34.0 : (isMed ? 27.0 : 21.0);
      final double outerR = baseOuterR * rayFactor;
      final double baseAlpha = isLong ? 0.52 : (isMed ? 0.30 : 0.14);
      final double alpha = baseAlpha + sunHeight * 0.25;
      final double sw = isLong ? 2.1 : (isMed ? 1.4 : 0.85);
      canvas.drawLine(
        pos + Offset(math.cos(angle) * 13.5, math.sin(angle) * 13.5),
        pos + Offset(math.cos(angle) * outerR, math.sin(angle) * outerR),
        Paint()
          ..color = midC.withValues(alpha: alpha)
          ..strokeWidth = sw
          ..strokeCap = StrokeCap.round,
      );
    }

    // Core
    canvas.drawCircle(
      pos,
      12.5,
      Paint()
        ..shader = RadialGradient(
          colors: [Colors.white, coreC, midC, rimC],
          stops: const [0.0, 0.30, 0.65, 1.0],
        ).createShader(Rect.fromCircle(center: pos, radius: 12.5)),
    );
    // Outer glow overlay
    canvas.drawCircle(
      pos,
      12.5,
      Paint()
        ..shader = RadialGradient(
          colors: [
            Colors.transparent,
            rimC.withValues(alpha: 0.48 + sunHeight * 0.2)
          ],
          stops: const [0.60, 1.0],
        ).createShader(Rect.fromCircle(center: pos, radius: 12.5)),
    );
    // Highlight
    canvas.drawCircle(
      pos.translate(-3.0, -3.0),
      3.5,
      Paint()
        ..color = Colors.white.withValues(alpha: 0.55)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 2),
    );
  }

  // ── Premium Moon with phase and craters ────────────────────────────────────
  void _drawMoon(
      Canvas canvas, Offset pos, double cx, double cy, double phase) {
    // phase: 0 = new moon, 1 = full moon (approx)
    // Direction to center (for lighting)
    final double dx = cx - pos.dx;
    final double dy = cy - pos.dy;
    final double dist = math.sqrt(dx * dx + dy * dy);
    final double nx = dist > 1 ? dx / dist : 0.0;
    final double ny = dist > 1 ? dy / dist : -1.0;

    // Glow
    canvas.drawCircle(
      pos,
      40,
      Paint()
        ..color = const Color(0xFF90CAF9).withValues(alpha: 0.07)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 20),
    );
    canvas.drawCircle(
      pos,
      23,
      Paint()
        ..color = const Color(0xFFBBDEFB).withValues(alpha: 0.18)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 9),
    );
    canvas.drawCircle(
      pos,
      14,
      Paint()
        ..color = const Color(0xFFE3F2FD).withValues(alpha: 0.14)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4),
    );

    // Moon surface with shading and phase
    final Paint moonPaint = Paint()
      ..shader = RadialGradient(
        center: Alignment(nx * 0.50, ny * 0.50),
        colors: const [
          Color(0xFFF5F8FF),
          Color(0xFFCDD5E0),
          Color(0xFF8A94A6),
        ],
        stops: const [0.0, 0.56, 1.0],
      ).createShader(Rect.fromCircle(center: pos, radius: 10.5));

    if (phase < 0.99) {
      // Not full moon: dark part overlay
      canvas.save();
      // DÜZELTİLMİŞ SATIR:
      canvas.clipPath(
          Path()..addOval(Rect.fromCircle(center: pos, radius: 10.5)));
      // Draw full moon gradient first
      canvas.drawCircle(pos, 10.5, moonPaint);
      // Then draw shadow according to phase
      final double shadowOffset =
          (1.0 - phase) * 21.0; // max offset = 21 (diameter)
      final Offset shadowDir =
          Offset(nx, ny); // light direction from sun (approx)
      final Offset shadowCenter = pos - shadowDir * shadowOffset;
      canvas.drawCircle(
        shadowCenter,
        10.5,
        Paint()..color = const Color(0xFF1A2B3C).withValues(alpha: 0.9),
      );
      canvas.restore();
    } else {
      // Full moon: just the gradient
      canvas.drawCircle(pos, 10.5, moonPaint);
    }

    // Craters (small dark spots)
    final Paint craterPaint = Paint()
      ..color = Colors.black.withValues(alpha: 0.07);
    canvas.drawCircle(pos.translate(2.5, 2.0), 2.0, craterPaint);
    canvas.drawCircle(pos.translate(-2.0, -1.5), 1.4, craterPaint);
    canvas.drawCircle(pos.translate(3.2, -3.2), 1.0, craterPaint);
    canvas.drawCircle(pos.translate(-3.5, 2.5), 0.8, craterPaint);
    canvas.drawCircle(pos.translate(-1.0, 3.8), 1.1, craterPaint);
    canvas.drawCircle(pos.translate(4.0, 1.0), 1.3, craterPaint);
  }

  // ── Label pill with connector ──────────────────────────────────────────────
  void _drawLabel(
    Canvas canvas,
    Offset markerPos,
    Offset labelCenter,
    String name,
    String time,
    Color accent,
    bool isDay, {
    String? moodEmoji,
    bool isHighlighted = false,
    double highlightPhase = 0.0,
  }) {
    final Offset dir = labelCenter - markerPos;
    final double len = dir.distance;
    if (len > 1) {
      final Offset unit = dir / len;
      final Offset start = markerPos + unit * 5.5;
      final Offset end = labelCenter - unit * (_pillH / 2 + 1.5);
      canvas.drawLine(
        start,
        end,
        Paint()
          ..color = isHighlighted
              ? accent.withValues(alpha: isDay ? 0.70 + highlightPhase * 0.25 : 0.75 + highlightPhase * 0.25)
              : accent.withValues(alpha: 0.45)
          ..strokeWidth = isHighlighted ? 1.6 : 0.9
          ..strokeCap = StrokeCap.round,
      );
    }

    // ── Pulsing glow halo for highlighted prayer ─────────────────────────────
    if (isHighlighted) {
      final double glowRadius = 14.0 + highlightPhase * 10.0;
      final double glowAlpha = isDay
          ? (0.35 + highlightPhase * 0.35)
          : (0.25 + highlightPhase * 0.35);
      // Outer halo (gündüzde daha belirgin)
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromCenter(
            center: labelCenter,
            width: _pillW + glowRadius * 2,
            height: _pillH + glowRadius * 2,
          ),
          Radius.circular(_pillRadius + glowRadius),
        ),
        Paint()
          ..color = accent.withValues(alpha: (isDay ? glowAlpha * 0.7 : glowAlpha * 0.5))
          ..maskFilter =
              MaskFilter.blur(BlurStyle.normal, 8 + highlightPhase * 10),
      );
      // Inner ring
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromCenter(
            center: labelCenter,
            width: _pillW + 8,
            height: _pillH + 8,
          ),
          Radius.circular(_pillRadius + 4),
        ),
        Paint()
          ..color = accent.withValues(alpha: isDay ? 0.55 + highlightPhase * 0.35 : 0.4 + highlightPhase * 0.4)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.5 + highlightPhase * 1.0,
      );
    }

    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromCenter(
          center: labelCenter.translate(0, 1.5),
          width: _pillW,
          height: _pillH,
        ),
        const Radius.circular(_pillRadius),
      ),
      Paint()
        ..color = Colors.black.withValues(alpha: isDay ? 0.10 : 0.38)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 5),
    );

    final RRect pill = RRect.fromRectAndRadius(
      Rect.fromCenter(center: labelCenter, width: _pillW, height: _pillH),
      const Radius.circular(_pillRadius),
    );
    canvas.drawRRect(
      pill,
      Paint()
        ..color = isHighlighted
            ? (isDay
                ? accent.withValues(alpha: 0.42 + highlightPhase * 0.18)
                : accent.withValues(alpha: 0.30 + highlightPhase * 0.15))
            : (isDay
                ? Colors.white.withValues(alpha: 0.84)
                : const Color(0xFF08121F).withValues(alpha: 0.82)),
    );
    canvas.drawRRect(
      pill,
      Paint()
        ..color = isHighlighted
            ? (isDay
                ? accent.withValues(alpha: 0.95)
                : accent.withValues(alpha: 0.85 + highlightPhase * 0.15))
            : accent.withValues(alpha: isDay ? 0.40 : 0.62)
        ..style = PaintingStyle.stroke
        ..strokeWidth = isHighlighted ? 2.5 + highlightPhase * 0.8 : 0.9,
    );

    final Color fg = isHighlighted
        ? (isDay ? const Color(0xFF1A0A4E) : Colors.white)
        : (isDay ? const Color(0xFF0D1B3E) : Colors.white);
    _text(canvas, name, labelCenter.translate(0, -8.5), fg,
        size: 9.0, weight: FontWeight.w600);
    _text(canvas, time, labelCenter.translate(0, 5.5), fg,
        size: isHighlighted ? 13.0 : 12.0, weight: FontWeight.w800);

    // ── Mood emoji badge (bottom-right corner of pill) ─────────────────────
    if (moodEmoji != null) {
      const double badgeR = 9.0;
      final Offset badgeCenter =
          labelCenter.translate(_pillW / 2 - 1, _pillH / 2 - 1);
      // Thin shadow ring
      canvas.drawCircle(
        badgeCenter,
        badgeR + 1,
        Paint()..color = Colors.black.withValues(alpha: 0.18),
      );
      // White fill
      canvas.drawCircle(badgeCenter, badgeR, Paint()..color = Colors.white);
      // Emoji — use black as foreground; color fonts ignore it but it must be
      // non-transparent so the glyph is not discarded by the paint layer.
      final tp = TextPainter(
        text: TextSpan(
          text: moodEmoji,
          style: GoogleFonts.plusJakartaSans(
            fontSize: 11,
            color: Colors.black,
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      tp.paint(
        canvas,
        badgeCenter - Offset(tp.width / 2, tp.height / 2),
      );
    }
  }

  @override
  void paint(Canvas canvas, Size size) {
    canvas.save();
    canvas.clipRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(0, 0, size.width, size.height),
        Radius.circular(clipRadius),
      ),
    );

    // Inset the orbit track so the sun/moon orb is never clipped
    const double orbitMargin = 18.0;
    final double rr = size.width - orbitMargin;
    final double rb = size.height - orbitMargin;
    final double cx = size.width / 2;
    final double cy = size.height / 2;

    Offset pt(double t) =>
        orbitTrackCornerRadius > 0
            ? _ptRounded(
                cx, cy, orbitMargin, orbitMargin, rr, rb,
                orbitTrackCornerRadius, t)
            : _pt(cx, cy, orbitMargin, orbitMargin, rr, rb, t);
    Offset ptFull(double t) =>
        _pt(cx, cy, 0, 0, size.width, size.height, t); // full bounds (no inset)

    final Rect wRect = Offset.zero & size;

    // Calculate sun height factor for dynamic day gradient and sun intensity
    final double dayLen = (maghribF - sunriseF).clamp(0.01, 1.0);
    final double sunProgress = ((nowF - sunriseF) / dayLen).clamp(0.0, 1.0);
    // sunHeight: 0 at sunrise/sunset, 1 at solar noon (progress 0.5)
    final double sunHeight = 1.0 - (sunProgress - 0.5).abs() * 2;

    // ── 1. Night background ───────────────────────────────────────────────────
    canvas.drawRect(
      wRect,
      Paint()
        ..shader = const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            Color(0xFF0D1B2A),
            Color(0xFF060F1C),
            Color(0xFF020609),
          ],
          stops: [0.0, 0.52, 1.0],
        ).createShader(wRect),
    );

    // Nebulae
    canvas.drawCircle(
      Offset(size.width * 0.12, size.height * 0.16),
      size.width * 0.46,
      Paint()
        ..color = const Color(0xFF1A237E).withValues(alpha: 0.11)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 55),
    );
    canvas.drawCircle(
      Offset(size.width * 0.90, size.height * 0.84),
      size.width * 0.38,
      Paint()
        ..color = const Color(0xFF4A148C).withValues(alpha: 0.07)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 48),
    );

    // ── 2. Day polygon with dynamic gradient based on sun height ─────────────
    // Day path (inset)
    final Path dayPath = Path()..moveTo(cx, cy);
    for (int i = 0; i <= 100; i++) {
      final double t = sunriseF + (maghribF - sunriseF) * i / 100;
      final Offset p = pt(t);
      dayPath.lineTo(p.dx, p.dy);
    }
    dayPath.close();

    // Full day path (for gradient that covers entire day area)
    final Path fullDayPath = Path()..moveTo(cx, cy);
    for (int i = 0; i <= 100; i++) {
      final double t = sunriseF + (maghribF - sunriseF) * i / 100;
      fullDayPath.lineTo(ptFull(t).dx, ptFull(t).dy);
    }
    fullDayPath.close();

    // Determine sky colors based on sun height
    final Color skyTopDay = Color.lerp(
      const Color(0xFF0288D1), // midday blue
      const Color(0xFFFFB300), // sunset orange
      1.0 - sunHeight,
    )!;
    final Color skyBottomDay = Color.lerp(
      const Color(0xFFB3E5FC), // light blue
      const Color(0xFFFF7043), // coral
      1.0 - sunHeight,
    )!;

    // Draw day area with gradient
    final Paint dayPaint = Paint()
      ..shader = LinearGradient(
        begin: Alignment.bottomCenter,
        end: Alignment.topCenter,
        colors: [skyTopDay, skyBottomDay],
      ).createShader(wRect);
    canvas.drawPath(fullDayPath, dayPaint);
    canvas.drawPath(
        dayPath, dayPaint); // also fill inset (redundant but keeps consistency)

    // Horizon haze inside day wedge
    canvas.save();
    canvas.clipPath(dayPath);
    canvas.drawRect(
      Rect.fromLTWH(0, size.height * 0.68, size.width, size.height * 0.32),
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            Colors.transparent,
            skyBottomDay.withValues(alpha: 0.4),
          ],
        ).createShader(wRect),
    );
    canvas.restore();

    // ── 3. Twilight glows (fajr, isha) ───────────────────────────────────────
    canvas.drawCircle(
      pt(fajrF),
      68,
      Paint()
        ..color = const Color(0xFF3949AB).withValues(alpha: 0.12)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 32),
    );
    canvas.drawCircle(
      pt(ishaF),
      55,
      Paint()
        ..color = const Color(0xFF283593).withValues(alpha: 0.09)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 28),
    );

    // ── 4. Stars (only outside day polygon) with color variation ─────────────
    for (final List<double> s in _stars) {
      final Offset sp = Offset(s[0] * size.width, s[1] * size.height);
      if (!dayPath.contains(sp)) {
        final double sizeFactor = s[2];
        final double alpha = s[3];
        final int colorType = s[4].toInt();
        Color starColor = Colors.white;
        if (colorType == 1) starColor = const Color(0xFFAACCFF); // blueish
        if (colorType == 2) starColor = const Color(0xFFFFCCAA); // reddish

        if (sizeFactor > 1.0) {
          canvas.drawCircle(
            sp,
            sizeFactor * 3.0,
            Paint()
              ..color = starColor.withValues(alpha: alpha * 0.13)
              ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 3),
          );
        }
        canvas.drawCircle(
          sp,
          sizeFactor,
          Paint()..color = starColor.withValues(alpha: alpha),
        );
      }
    }

    // ── 5. Sunrise and sunset blooms (enhanced) ──────────────────────────────
    final Offset srPos = pt(sunriseF);
    canvas.drawCircle(
        srPos,
        84,
        Paint()
          ..color = const Color(0xFFFF8F00).withValues(alpha: 0.06)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 38));
    canvas.drawCircle(
        srPos,
        52,
        Paint()
          ..color = const Color(0xFFFFB300).withValues(alpha: 0.16)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 20));
    canvas.drawCircle(
        srPos,
        30,
        Paint()
          ..color = const Color(0xFFFFD54F).withValues(alpha: 0.36)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 10));

    final Offset mgPos = pt(maghribF);
    canvas.drawCircle(
        mgPos,
        84,
        Paint()
          ..color = const Color(0xFFD84315).withValues(alpha: 0.08)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 38));
    canvas.drawCircle(
        mgPos,
        52,
        Paint()
          ..color = const Color(0xFFFF5722).withValues(alpha: 0.20)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 20));
    canvas.drawCircle(
        mgPos,
        30,
        Paint()
          ..color = const Color(0xFFFF3D00).withValues(alpha: 0.40)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 10));

    // ── 6. Orbit track (night arc and day arc) ───────────────────────────────
    // Night arc: maghrib → (bottom) → sunrise (the long way round)
    final Path nightArcPath = Path();
    for (int i = 0; i <= 120; i++) {
      final double t =
          (maghribF + (1.0 - (maghribF - sunriseF)) * i / 120) % 1.0;
      final Offset p = pt(t);
      if (i == 0)
        nightArcPath.moveTo(p.dx, p.dy);
      else
        nightArcPath.lineTo(p.dx, p.dy);
    }
    // Outer glow
    canvas.drawPath(
        nightArcPath,
        Paint()
          ..color = const Color(0xFF90CAF9).withValues(alpha: 0.18)
          ..style = PaintingStyle.stroke
          ..strokeWidth = orbitTrackNightGlowWidth
          ..strokeCap = StrokeCap.round
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4));
    // Core line
    canvas.drawPath(
        nightArcPath,
        Paint()
          ..color = const Color(0xFFB0BEC5).withValues(alpha: 0.55)
          ..style = PaintingStyle.stroke
          ..strokeWidth = orbitTrackNightCoreWidth
          ..strokeCap = StrokeCap.round);

    // ── Teheccüt (Tahajjud): Yatsı–Fajr arası gece 3’e bölünür, Fajr’a yakın son 1/3’te ışık dalgalanması
    // Namaz aralıkları: hangi dilimdeysek (Sunrise–Dhuhr hariç) o dilimde merkezden distale ışık dalgası
    const int segmentSteps = 48;
    final Offset center = Offset(cx, cy);
    final List<(double, double)> segments = [
      (fajrF, sunriseF),
      (sunriseF, dhuhrF),
      (dhuhrF, asrF),
      (asrF, maghribF),
      (maghribF, ishaF),
      (ishaF, fajrF),
    ];
    (double, double)? currentSegment;
    for (final seg in segments) {
      final double s = seg.$1;
      final double e = seg.$2;
      final bool contains = e >= s
          ? (nowF >= s && nowF <= e)
          : (nowF >= s || nowF <= e);
      if (contains) {
        currentSegment = seg;
        break;
      }
    }
    final (double, double)? segCur = currentSegment;
    final bool isSunriseDhuhr = segCur != null &&
        segCur.$1 == sunriseF &&
        segCur.$2 == dhuhrF;
    if (segCur != null && !isSunriseDhuhr) {
      final double tStart = segCur.$1;
      final double tEnd = segCur.$2;
      final double segLen = tEnd >= tStart
          ? (tEnd - tStart)
          : ((1.0 - tStart) + tEnd);
      final Path segWedge = Path()
        ..moveTo(center.dx, center.dy)
        ..lineTo(pt(tStart).dx, pt(tStart).dy);
      for (int i = 1; i <= segmentSteps; i++) {
        final double t = (tStart + segLen * i / segmentSteps) % 1.0;
        final Offset p = pt(t);
        segWedge.lineTo(p.dx, p.dy);
      }
      segWedge.close();
      final double distMax = (pt(tStart) - center).distance;
      final double R = distMax * 1.1;
      final double bandCenter = (0.1 + 0.6 * highlightPhase).clamp(0.0, 1.0);
      const double bandWidth = 0.14;
      double segS1 = (bandCenter - bandWidth).clamp(0.02, 0.85);
      double segS2 = bandCenter.clamp(0.05, 0.9);
      double segS3 = (bandCenter + bandWidth).clamp(0.08, 0.98);
      if (segS1 >= segS2) segS2 = segS1 + 0.03;
      if (segS2 >= segS3) segS3 = segS2 + 0.03;
      canvas.save();
      canvas.clipPath(segWedge);
      canvas.drawCircle(
        center,
        R,
        Paint()
          ..shader = RadialGradient(
            colors: [
              const Color(0xFF90CAF9).withValues(alpha: 0.0),
              const Color(0xFFE3F2FD).withValues(alpha: 0.05),
              const Color(0xFFBBDEFB).withValues(alpha: 0.12),
              const Color(0xFFE3F2FD).withValues(alpha: 0.05),
              const Color(0xFF90CAF9).withValues(alpha: 0.0),
            ],
            stops: [0.0, segS1, segS2, segS3, 1.0],
          ).createShader(Rect.fromCircle(center: center, radius: R)),
      );
      canvas.restore();
    }

    final double nightLengthT = (1.0 - ishaF) + fajrF;
    final double lastThirdT = nightLengthT / 3.0;
    double tahajjudStartT = fajrF - lastThirdT;
    if (tahajjudStartT < 0) tahajjudStartT += 1.0;
    final double tahajjudEndT = fajrF;
    if (lastThirdT > 0.001) {
      final Path tahajjudPath = Path();
      final int steps = 48;
      final double segLen = tahajjudEndT >= tahajjudStartT
          ? (tahajjudEndT - tahajjudStartT)
          : ((1.0 - tahajjudStartT) + tahajjudEndT);
      for (int i = 0; i <= steps; i++) {
        final double t = (tahajjudStartT + segLen * i / steps) % 1.0;
        final Offset p = pt(t);
        if (i == 0)
          tahajjudPath.moveTo(p.dx, p.dy);
        else
          tahajjudPath.lineTo(p.dx, p.dy);
      }
      final double wave = 0.4 + 0.35 * math.sin(highlightPhase * math.pi * 2);
      canvas.drawPath(
          tahajjudPath,
          Paint()
            ..color = Color.lerp(
              const Color(0xFF90CAF9),
              Colors.white,
              wave * 0.5,
            )!.withValues(alpha: 0.15 + wave * 0.25)
            ..style = PaintingStyle.stroke
            ..strokeWidth = orbitTrackNightGlowWidth + 4.0 + wave * 4.0
            ..strokeCap = StrokeCap.round
            ..maskFilter = MaskFilter.blur(BlurStyle.normal, 8 + wave * 6));
      canvas.drawPath(
          tahajjudPath,
          Paint()
            ..color = const Color(0xFFE3F2FD).withValues(alpha: 0.25 + wave * 0.35)
            ..style = PaintingStyle.stroke
            ..strokeWidth = orbitTrackNightCoreWidth + 1.0 + wave * 1.5
            ..strokeCap = StrokeCap.round);

      // Merkez–Fajr ve merkez–Teheccüt yayı arası dilim; merkezden distale hafif ışık dalgası
      final Offset fajrPt = pt(fajrF);
      final Path wedgePath = Path()
        ..moveTo(center.dx, center.dy)
        ..lineTo(pt(tahajjudStartT).dx, pt(tahajjudStartT).dy);
      for (int i = 1; i <= steps; i++) {
        final double t = (tahajjudStartT + segLen * i / steps) % 1.0;
        final Offset p = pt(t);
        wedgePath.lineTo(p.dx, p.dy);
      }
      wedgePath.close();

      final double distMax = (fajrPt - center).distance;
      final double R = distMax * 1.1;
      // Merkezden distale giden dalga: parlak bant highlightPhase ile dışa kayar
      final double bandCenter = (0.1 + 0.6 * highlightPhase).clamp(0.0, 1.0);
      final double bandWidth = 0.14;
      double s1 = (bandCenter - bandWidth).clamp(0.02, 0.85);
      double s2 = bandCenter.clamp(0.05, 0.9);
      double s3 = (bandCenter + bandWidth).clamp(0.08, 0.98);
      if (s1 >= s2) s2 = s1 + 0.03;
      if (s2 >= s3) s3 = s2 + 0.03;
      canvas.save();
      canvas.clipPath(wedgePath);
      canvas.drawCircle(
        center,
        R,
        Paint()
          ..shader = RadialGradient(
            colors: [
              const Color(0xFF90CAF9).withValues(alpha: 0.0),
              const Color(0xFFE3F2FD).withValues(alpha: 0.05),
              const Color(0xFFBBDEFB).withValues(alpha: 0.12),
              const Color(0xFFE3F2FD).withValues(alpha: 0.05),
              const Color(0xFF90CAF9).withValues(alpha: 0.0),
            ],
            stops: [0.0, s1, s2, s3, 1.0],
          ).createShader(Rect.fromCircle(center: center, radius: R)),
      );
      canvas.restore();

      // Teheccüt dilimi ortasında, köşeden merkeze doğru eğimli, hafif silik etiket
      final double midT = (tahajjudStartT + segLen * 0.5) % 1.0;
      final Offset arcMid = pt(midT);
      final Offset midPoint = Offset(
        cx + (arcMid.dx - cx) * tahajjudLabelRadiusFactor,
        cy + (arcMid.dy - cy) * tahajjudLabelRadiusFactor,
      );
      final double angle = math.atan2(cy - midPoint.dy, cx - midPoint.dx);
      final TextPainter labelPainter = TextPainter(
        text: TextSpan(
          text: tahajjudLabel,
          style: GoogleFonts.plusJakartaSans(
            color: const Color(0xFFE3F2FD).withValues(alpha: 0.38),
            fontSize: tahajjudLabelFontSize,
            fontWeight: FontWeight.w500,
          ),
        ),
        textDirection: TextDirection.ltr,
        textAlign: TextAlign.center,
      );
      labelPainter.layout();
      canvas.save();
      canvas.clipPath(wedgePath);
      canvas.translate(midPoint.dx, midPoint.dy);
      canvas.rotate(angle);
      canvas.translate(-labelPainter.width / 2, -labelPainter.height / 2);
      labelPainter.paint(canvas, Offset.zero);
      canvas.restore();

      // Teheccüt başlangıç saati: dilimin başlangıç noktasında (orbit tarafında) container
      if (tahajjudStartTime.isNotEmpty) {
        final Offset startPt = pt(tahajjudStartT);
        final Offset timeBoxCenter = Offset(
          cx + (startPt.dx - cx) * 0.88,
          cy + (startPt.dy - cy) * 0.88,
        );
        final TextPainter timePainter = TextPainter(
          text: TextSpan(
            text: tahajjudStartTime,
            style: GoogleFonts.plusJakartaSans(
              color: const Color(0xFFE3F2FD).withValues(alpha: 0.55),
              fontSize: (tahajjudLabelFontSize * 0.9).clamp(9.0, 13.0),
              fontWeight: FontWeight.w600,
            ),
          ),
          textDirection: TextDirection.ltr,
        );
        timePainter.layout();
        const double padH = 6.0;
        const double padV = 4.0;
        final double boxW = timePainter.width + padH * 2;
        final double boxH = timePainter.height + padV * 2;
        final RRect timeBox = RRect.fromRectAndRadius(
          Rect.fromCenter(center: timeBoxCenter, width: boxW, height: boxH),
          const Radius.circular(6),
        );
        canvas.drawRRect(
          timeBox,
          Paint()
            ..color = const Color(0xFFE3F2FD).withValues(alpha: 0.22)
            ..style = PaintingStyle.fill,
        );
        canvas.drawRRect(
          timeBox,
          Paint()
            ..color = const Color(0xFFE3F2FD).withValues(alpha: 0.35)
            ..style = PaintingStyle.stroke
            ..strokeWidth = 0.9,
        );
        timePainter.paint(
          canvas,
          Offset(
            timeBoxCenter.dx - timePainter.width / 2,
            timeBoxCenter.dy - timePainter.height / 2,
          ),
        );
      }
    }

    // Day arc: sunrise → (top) → maghrib
    final Path dayArcPath = Path();
    for (int i = 0; i <= 100; i++) {
      final double t = sunriseF + (maghribF - sunriseF) * i / 100;
      final Offset p = pt(t);
      if (i == 0)
        dayArcPath.moveTo(p.dx, p.dy);
      else
        dayArcPath.lineTo(p.dx, p.dy);
    }
    // Outer glow
    canvas.drawPath(
        dayArcPath,
        Paint()
          ..color = const Color(0xFFFFD54F).withValues(alpha: 0.30)
          ..style = PaintingStyle.stroke
          ..strokeWidth = orbitTrackDayGlowWidth
          ..strokeCap = StrokeCap.round
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 5));
    // Core line
    canvas.drawPath(
        dayArcPath,
        Paint()
          ..color = const Color(0xFFFFEE58).withValues(alpha: 0.75)
          ..style = PaintingStyle.stroke
          ..strokeWidth = orbitTrackDayCoreWidth
          ..strokeCap = StrokeCap.round);

    // ── 7. Sun directional glow inside day area ──────────────────────────────
    if (nowF >= sunriseF && nowF <= maghribF) {
      final Offset sunPos = pt(nowF);
      canvas.save();
      canvas.clipPath(dayPath);
      canvas.drawCircle(
        sunPos,
        size.width * 0.6,
        Paint()
          ..shader = RadialGradient(
            colors: [
              Colors.white.withValues(alpha: 0.15 * sunHeight),
              Colors.transparent,
            ],
          ).createShader(
              Rect.fromCircle(center: sunPos, radius: size.width * 0.6)),
      );
      canvas.restore();
    }

    // ── 8. Prayer markers ─────────────────────────────────────────────────────
    const List<Color> markerColors = [
      Color(0xFFCE93D8),
      Color(0xFFFFCC02),
      Color(0xFFFFF176),
      Color(0xFFFFAB40),
      Color(0xFFFF7043),
      Color(0xFF9FA8DA),
    ];
    final List<double> fractions = [
      fajrF,
      sunriseF,
      dhuhrF,
      asrF,
      maghribF,
      ishaF,
    ];

    for (int i = 0; i < 6; i++) {
      final Offset p = pt(fractions[i]);
      final bool isHL = i == highlightedIndex;

      if (isHL) {
        // Pulsing outer ring on highlighted marker
        final double pulseR = 14.0 + highlightPhase * 8.0;
        canvas.drawCircle(
          p,
          pulseR,
          Paint()
            ..color =
                markerColors[i].withValues(alpha: 0.20 + highlightPhase * 0.20)
            ..maskFilter =
                MaskFilter.blur(BlurStyle.normal, 6 + highlightPhase * 6),
        );
        canvas.drawCircle(
          p,
          7.0 + highlightPhase * 1.5,
          Paint()
            ..color =
                markerColors[i].withValues(alpha: 0.5 + highlightPhase * 0.3)
            ..style = PaintingStyle.stroke
            ..strokeWidth = 1.5,
        );
      } else {
        canvas.drawCircle(
          p,
          9.0,
          Paint()
            ..color = markerColors[i].withValues(alpha: 0.18)
            ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 5),
        );
      }
      canvas.drawCircle(p, isHL ? 5.5 : 4.2, Paint()..color = markerColors[i]);
      canvas.drawCircle(
        p,
        isHL ? 5.5 : 4.2,
        Paint()
          ..color = Colors.white.withValues(alpha: isHL ? 0.75 : 0.52)
          ..style = PaintingStyle.stroke
          ..strokeWidth = isHL ? 1.4 : 0.9,
      );
      canvas.drawCircle(
        p.translate(-1.2, -1.2),
        1.3,
        Paint()..color = Colors.white.withValues(alpha: 0.44),
      );
    }

    // ── 9. Labels with iterative AABB overlap resolution ─────────────────────
    const double initPush = 36.0;
    final List<double> lx = List<double>.filled(6, 0.0);
    final List<double> ly = List<double>.filled(6, 0.0);
    for (int i = 0; i < 6; i++) {
      final Offset m = pt(fractions[i]);
      final double dx = cx - m.dx;
      final double dy = cy - m.dy;
      final double dist = math.sqrt(dx * dx + dy * dy);
      final double nx = dist > 1 ? dx / dist : 0.0;
      final double ny = dist > 1 ? dy / dist : 1.0;
      lx[i] = m.dx + nx * initPush;
      ly[i] = m.dy + ny * initPush;
    }

    const double sep = 5.0;
    for (int iter = 0; iter < 40; iter++) {
      for (int i = 0; i < 6; i++) {
        for (int j = i + 1; j < 6; j++) {
          final double overlapX = (_pillW + sep) - (lx[j] - lx[i]).abs();
          final double overlapY = (_pillH + sep) - (ly[j] - ly[i]).abs();
          if (overlapX > 0 && overlapY > 0) {
            if (overlapX < overlapY) {
              final double push = overlapX / 2 + 1.5;
              final double signX = lx[j] >= lx[i] ? 1.0 : -1.0;
              lx[i] -= push * signX;
              lx[j] += push * signX;
            } else {
              final double push = overlapY / 2 + 1.5;
              final double signY = ly[j] >= ly[i] ? 1.0 : -1.0;
              ly[i] -= push * signY;
              ly[j] += push * signY;
            }
          }
        }
      }
      for (int i = 0; i < 6; i++) {
        lx[i] = lx[i].clamp(_pillW / 2 + 2, size.width - _pillW / 2 - 2);
        ly[i] = ly[i].clamp(_pillH / 2 + 3, size.height - _pillH / 2 - 3);
      }
    }

    for (int i = 0; i < 6; i++) {
      final Offset labelCenter = Offset(lx[i], ly[i]);
      final bool isHighlighted = i == highlightedIndex;
      _drawLabel(
        canvas,
        pt(fractions[i]),
        labelCenter,
        names[i],
        times[i],
        markerColors[i],
        dayPath.contains(labelCenter),
        moodEmoji: i < moodEmojis.length ? moodEmojis[i] : null,
        isHighlighted: isHighlighted,
        highlightPhase: isHighlighted ? highlightPhase : 0.0,
      );
    }

    // ── 10. Sun / Moon (always on top) with improved rendering ───────────────
    final Offset orbPos = pt(nowF);
    if (nowF >= sunriseF && nowF <= maghribF) {
      _drawSun(canvas, orbPos, sunHeight);
    } else {
      // Approximate moon phase using current day of month (simplified)
      final DateTime now = DateTime.now();
      final double phase = (now.day % 30) / 30.0; // 0..1 cycle every ~30 days
      _drawMoon(canvas, orbPos, cx, cy, phase);
    }

    // ── 11. Final touch: horizon glow (night side) ───────────────────────────
    // Add a subtle light pollution/atmospheric glow near the bottom edge
    canvas.drawRect(
      Rect.fromLTWH(0, size.height * 0.8, size.width, size.height * 0.2),
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            Colors.transparent,
            const Color(0xFF3E5A70).withValues(alpha: 0.15),
          ],
        ).createShader(wRect),
    );
    canvas.restore();
  }

  @override
  bool shouldRepaint(_OrbitPainter old) =>
      old.nowF != nowF ||
      old.fajrF != fajrF ||
      old.sunriseF != sunriseF ||
      old.dhuhrF != dhuhrF ||
      old.asrF != asrF ||
      old.maghribF != maghribF ||
      old.ishaF != ishaF ||
      old.names != names ||
      old.moodEmojis != moodEmojis ||
      old.highlightedIndex != highlightedIndex ||
      old.highlightPhase != highlightPhase ||
      old.clipRadius != clipRadius ||
      old.tahajjudLabel != tahajjudLabel ||
      old.tahajjudLabelFontSize != tahajjudLabelFontSize ||
      old.tahajjudLabelRadiusFactor != tahajjudLabelRadiusFactor ||
      old.tahajjudStartTime != tahajjudStartTime;
}
