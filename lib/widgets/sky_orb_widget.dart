import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';

/// Animated sky background: shows the current sky state based on prayer times.
/// Sun travels a semicircular arc during the day (sunrise → maghrib),
/// Moon crescent travels at night (maghrib → sunrise), stars fade in/out.
class SkyOrbWidget extends StatefulWidget {
  final String fajr;
  final String sunrise;
  final String dhuhr;
  final String asr;
  final String maghrib;
  final String isha;

  const SkyOrbWidget({
    super.key,
    required this.fajr,
    required this.sunrise,
    required this.dhuhr,
    required this.asr,
    required this.maghrib,
    required this.isha,
  });

  @override
  State<SkyOrbWidget> createState() => _SkyOrbWidgetState();
}

class _SkyOrbWidgetState extends State<SkyOrbWidget>
    with SingleTickerProviderStateMixin {
  late final AnimationController _glowCtrl;
  Timer? _timer;

  // Stars are seeded-random so their positions are stable across redraws.
  late final List<_Star> _stars;

  @override
  void initState() {
    super.initState();
    _glowCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2800),
    )..repeat(reverse: true);
    // Re-calculate time-based position every 30 seconds.
    _timer = Timer.periodic(const Duration(seconds: 30), (_) {
      if (mounted) setState(() {});
    });
    _stars = List.generate(62, (i) {
      final rng = math.Random(i * 37 + 13);
      return _Star(
        x: rng.nextDouble(),
        y: rng.nextDouble() * 0.72,
        size: 0.5 + rng.nextDouble() * 1.8,
        opacity: 0.35 + rng.nextDouble() * 0.65,
      );
    });
  }

  @override
  void dispose() {
    _glowCtrl.dispose();
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _glowCtrl,
      builder: (context, _) => CustomPaint(
        painter: _SkyPainter(
          fajr: widget.fajr,
          sunrise: widget.sunrise,
          dhuhr: widget.dhuhr,
          asr: widget.asr,
          maghrib: widget.maghrib,
          isha: widget.isha,
          now: DateTime.now(),
          glowPulse: _glowCtrl.value,
          stars: _stars,
        ),
        child: const SizedBox.expand(),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────

class _Star {
  final double x, y, size, opacity;
  const _Star({
    required this.x,
    required this.y,
    required this.size,
    required this.opacity,
  });
}

class _SkyStop {
  final double t;
  final Color top, bottom;
  const _SkyStop(this.t, this.top, this.bottom);
}

// ─────────────────────────────────────────────────────────────────────────────

class _SkyPainter extends CustomPainter {
  final String fajr, sunrise, dhuhr, asr, maghrib, isha;
  final DateTime now;
  final double glowPulse;
  final List<_Star> stars;

  late final double _fM, _srM, _dhM, _asM, _mgM, _ishM, _nowM;

  _SkyPainter({
    required this.fajr,
    required this.sunrise,
    required this.dhuhr,
    required this.asr,
    required this.maghrib,
    required this.isha,
    required this.now,
    required this.glowPulse,
    required this.stars,
  }) {
    _fM = _pm(fajr);
    _srM = _pm(sunrise);
    _dhM = _pm(dhuhr);
    _asM = _pm(asr);
    _mgM = _pm(maghrib);
    _ishM = _pm(isha);
    _nowM = now.hour * 60.0 + now.minute + now.second / 60.0;
  }

  // ── helpers ──────────────────────────────────────────────────────────────

  static double _pm(String t) {
    final p = t.split(':');
    if (p.length < 2) return 0;
    return (int.tryParse(p[0]) ?? 0) * 60.0 + (int.tryParse(p[1]) ?? 0);
  }

  /// Sun arc progress: 0.0 at sunrise, 1.0 at maghrib. Null outside day.
  double? get _sunProgress {
    if (_nowM < _srM || _nowM > _mgM) return null;
    return ((_nowM - _srM) / (_mgM - _srM)).clamp(0.0, 1.0);
  }

  /// Moon arc progress: 0.0 at maghrib, 1.0 at next sunrise. Null during day.
  double? get _moonProgress {
    if (_nowM >= _srM && _nowM < _mgM) return null;
    final nightDur = (1440.0 - _mgM) + _srM;
    final intoNight = _nowM >= _mgM
        ? _nowM - _mgM
        : (1440.0 - _mgM) + _nowM;
    return (intoNight / nightDur).clamp(0.0, 1.0);
  }

  /// Star visibility alpha: 0 during full day, 1 during full night.
  double get _starAlpha {
    if (_nowM >= _srM && _nowM < _mgM) return 0.0;
    // Fade out: fajr-30 → sunrise
    if (_nowM >= _fM - 30 && _nowM < _srM) {
      return (1.0 - ((_nowM - (_fM - 30)) / (_srM - (_fM - 30)))).clamp(0.0, 1.0);
    }
    // Fade in: maghrib → maghrib+22
    if (_nowM >= _mgM && _nowM < _mgM + 22) {
      return ((_nowM - _mgM) / 22.0).clamp(0.0, 1.0);
    }
    return 1.0;
  }

  /// Returns (topColor, bottomColor) sky gradient for current time.
  (Color, Color) get _skyColors {
    final stops = <_SkyStop>[
      _SkyStop(0,              const Color(0xFF020B1C), const Color(0xFF071020)),
      _SkyStop(_fM - 90,       const Color(0xFF020B1C), const Color(0xFF071020)),
      _SkyStop(_fM,            const Color(0xFF0C083A), const Color(0xFF260E50)),
      _SkyStop(_fM + 20,       const Color(0xFF160A2E), const Color(0xFFBF360C)),
      _SkyStop(_srM,           const Color(0xFF1565C0), const Color(0xFFFF7043)),
      _SkyStop(_srM + 55,      const Color(0xFF1565C0), const Color(0xFF64B5F6)),
      _SkyStop(_dhM,           const Color(0xFF0D47A1), const Color(0xFF42A5F5)),
      _SkyStop(_asM,           const Color(0xFF1565C0), const Color(0xFF90CAF9)),
      _SkyStop(_mgM - 52,      const Color(0xFF1A237E), const Color(0xFFFF8A65)),
      _SkyStop(_mgM - 10,      const Color(0xFF0A0F2C), const Color(0xFFFF5722)),
      _SkyStop(_mgM + 25,      const Color(0xFF070A22), const Color(0xFF6A1B9A)),
      _SkyStop(_ishM,          const Color(0xFF020B1C), const Color(0xFF071020)),
      _SkyStop(_ishM + 60,     const Color(0xFF020B1C), const Color(0xFF071020)),
      _SkyStop(1440,           const Color(0xFF020B1C), const Color(0xFF071020)),
    ];
    for (int i = 0; i < stops.length - 1; i++) {
      if (_nowM >= stops[i].t && _nowM <= stops[i + 1].t) {
        final span = stops[i + 1].t - stops[i].t;
        final t = span == 0 ? 0.0 : (_nowM - stops[i].t) / span;
        return (
          Color.lerp(stops[i].top, stops[i + 1].top, t)!,
          Color.lerp(stops[i].bottom, stops[i + 1].bottom, t)!,
        );
      }
    }
    return (const Color(0xFF020B1C), const Color(0xFF071020));
  }

  // ── arc position ─────────────────────────────────────────────────────────

  /// Returns the canvas Offset for an orb at [progress] (0→left, 1→right).
  Offset _orbPos(double progress, Size size) {
    final cx = size.width / 2;
    final cy = size.height * 0.70;
    final r = math.min(size.width * 0.43, size.height * 0.62);
    final angle = math.pi * (1.0 - progress);
    return Offset(cx + r * math.cos(angle), cy - r * math.sin(angle));
  }

  // ── paint ─────────────────────────────────────────────────────────────────

  @override
  void paint(Canvas canvas, Size size) {
    _drawSky(canvas, size);
    _drawStars(canvas, size);
    _drawClouds(canvas, size);
    _drawHorizonGlow(canvas, size);
    final sunProg = _sunProgress;
    final moonProg = _moonProgress;
    if (moonProg != null) _drawMoon(canvas, size, moonProg);
    if (sunProg != null) _drawSun(canvas, size, sunProg);
  }

  void _drawSky(Canvas canvas, Size size) {
    final (topColor, bottomColor) = _skyColors;
    final rect = Offset.zero & size;
    canvas.drawRect(
      rect,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [topColor, bottomColor],
        ).createShader(rect),
    );
  }

  void _drawStars(Canvas canvas, Size size) {
    final alpha = _starAlpha;
    if (alpha < 0.02) return;
    final paint = Paint()..style = PaintingStyle.fill;
    for (final star in stars) {
      final a = (star.opacity * alpha).clamp(0.0, 1.0);
      paint.color = Color.fromRGBO(255, 255, 255, a);
      canvas.drawCircle(
        Offset(star.x * size.width, star.y * size.height),
        star.size,
        paint,
      );
    }
    // Twinkle a few larger stars using glowPulse
    for (int i = 0; i < 9; i++) {
      final star = stars[i * 7 % stars.length];
      final twinkle = ((glowPulse + i * 0.12) % 1.0);
      final a = (star.opacity * alpha * (0.45 + twinkle * 0.55)).clamp(0.0, 1.0);
      paint.color = Color.fromRGBO(220, 230, 255, a);
      canvas.drawCircle(
        Offset(star.x * size.width, star.y * size.height),
        star.size * 2.0,
        paint,
      );
    }
  }

  void _drawClouds(Canvas canvas, Size size) {
    if (_nowM < _srM || _nowM > _mgM) return;
    final fade = math.min((_nowM - _srM) / 25.0, 1.0) *
        math.min((_mgM - _nowM) / 25.0, 1.0);
    if (fade < 0.01) return;
    final paint = Paint()..color = Colors.white.withAlpha((22 * fade).round());
    _cloud(canvas, Offset(size.width * 0.27, size.height * 0.20), 68, 22, paint);
    _cloud(canvas, Offset(size.width * 0.72, size.height * 0.13), 52, 17, paint);
  }

  void _cloud(Canvas canvas, Offset c, double w, double h, Paint p) {
    canvas.drawOval(Rect.fromCenter(center: c, width: w, height: h), p);
    canvas.drawOval(Rect.fromCenter(center: c.translate(-w * 0.21, -h * 0.42), width: w * 0.54, height: h * 0.95), p);
    canvas.drawOval(Rect.fromCenter(center: c.translate(w * 0.20, -h * 0.38), width: w * 0.46, height: h * 0.85), p);
  }

  void _drawHorizonGlow(Canvas canvas, Size size) {
    // Sunrise glow: fajr+10 → sunrise+45
    if (_nowM >= _fM + 10 && _nowM <= _srM + 45) {
      final intensity = _nowM < _srM
          ? ((_nowM - (_fM + 10)) / math.max(_srM - _fM - 10, 1)).clamp(0.0, 1.0)
          : (1.0 - ((_nowM - _srM) / 45.0)).clamp(0.0, 1.0);
      if (intensity > 0.01) {
        _horizonGlow(canvas, size, const Color(0xFFFF6D00), intensity * 0.85);
      }
    }
    // Sunset glow: maghrib-50 → maghrib+30
    if (_nowM >= _mgM - 50 && _nowM <= _mgM + 30) {
      final intensity = _nowM < _mgM
          ? ((_nowM - (_mgM - 50)) / 50.0).clamp(0.0, 1.0)
          : (1.0 - ((_nowM - _mgM) / 30.0)).clamp(0.0, 1.0);
      if (intensity > 0.01) {
        _horizonGlow(canvas, size, const Color(0xFFFF3D00), intensity * 0.90);
      }
    }
  }

  void _horizonGlow(Canvas canvas, Size size, Color color, double intensity) {
    final cx = size.width / 2;
    final cy = size.height * 0.70;
    final rw = size.width * 0.75;
    final rh = size.height * 0.38;
    final glowRect = Rect.fromCenter(center: Offset(cx, cy), width: rw * 2, height: rh * 2);
    canvas.drawOval(
      glowRect,
      Paint()
        ..shader = RadialGradient(
          colors: [
            color.withAlpha((90 * intensity).round()),
            color.withAlpha((30 * intensity).round()),
            Colors.transparent,
          ],
          stops: const [0.0, 0.45, 1.0],
        ).createShader(Rect.fromCenter(center: Offset(cx, cy), width: rw * 2, height: rw * 2)),
    );
  }

  // ── Sun ──────────────────────────────────────────────────────────────────

  void _drawSun(Canvas canvas, Size size, double progress) {
    final pos = _orbPos(progress, size);
    final r = size.width * 0.060;
    final pulse = 1.0 + 0.10 * glowPulse;

    canvas.save();
    canvas.clipRect(Offset.zero & size);

    // Outer atmospheric haze
    canvas.drawCircle(
      pos, r * 5.0 * pulse,
      Paint()
        ..color = const Color(0x08FFB300)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 22),
    );
    // Mid glow
    canvas.drawCircle(
      pos, r * 2.8 * pulse,
      Paint()
        ..color = const Color(0x20FFCA28)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 10),
    );
    // Inner glow ring
    canvas.drawCircle(pos, r * 1.65, Paint()..color = const Color(0x38FFD740));

    // Sun disc with radial gradient
    final sunRect = Rect.fromCircle(center: pos, radius: r);
    canvas.drawCircle(
      pos, r,
      Paint()
        ..shader = RadialGradient(
          colors: const [
            Color(0xFFFFFDE7),
            Color(0xFFFFF176),
            Color(0xFFFFCA28),
          ],
          stops: const [0.0, 0.55, 1.0],
        ).createShader(sunRect),
    );

    // Subtle corona rays
    final rayPaint = Paint()
      ..color = const Color(0x18FFCA28)
      ..strokeWidth = 1.2
      ..strokeCap = StrokeCap.round;
    for (int i = 0; i < 8; i++) {
      final angle = (i / 8) * math.pi * 2 + glowPulse * 0.3;
      final rayLen = r * (1.35 + 0.15 * math.sin(glowPulse * math.pi * 2 + i));
      canvas.drawLine(
        Offset(pos.dx + math.cos(angle) * r * 1.08, pos.dy + math.sin(angle) * r * 1.08),
        Offset(pos.dx + math.cos(angle) * rayLen, pos.dy + math.sin(angle) * rayLen),
        rayPaint,
      );
    }

    canvas.restore();
  }

  // ── Moon ─────────────────────────────────────────────────────────────────

  void _drawMoon(Canvas canvas, Size size, double progress) {
    final pos = _orbPos(progress, size);
    final r = size.width * 0.053;
    final pulse = 1.0 + 0.07 * glowPulse;

    canvas.save();
    canvas.clipRect(Offset.zero & size);

    // Moon glow
    canvas.drawCircle(
      pos, r * 3.0 * pulse,
      Paint()
        ..color = const Color(0x0CB0BEC5)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 14),
    );
    canvas.drawCircle(pos, r * 1.6, Paint()..color = const Color(0x20C5CAE9));

    // Crescent: draw full moon then cut a shadow circle
    canvas.saveLayer(
      Rect.fromCircle(center: pos, radius: r * 1.2),
      Paint(),
    );

    // Moon face
    canvas.drawCircle(
      pos, r,
      Paint()
        ..shader = RadialGradient(
          colors: const [
            Color(0xFFEEF0E8),
            Color(0xFFDDE0D4),
          ],
          stops: const [0.0, 1.0],
        ).createShader(Rect.fromCircle(center: pos, radius: r)),
    );

    // Shadow (BlendMode.clear) to carve crescent
    // Direction: shadow faces away from horizon (roughly upward + left/right depending on phase)
    final shadowDx = (progress * 2 - 1) * 0.35 * r;
    final shadowDy = -(0.10 + 0.22 * math.sin(math.pi * progress)) * r;
    canvas.drawCircle(
      Offset(pos.dx + shadowDx, pos.dy + shadowDy),
      r * 0.86,
      Paint()..blendMode = BlendMode.clear,
    );

    canvas.restore(); // saveLayer
    canvas.restore(); // clipRect
  }

  @override
  bool shouldRepaint(_SkyPainter old) =>
      old.glowPulse != glowPulse || old._nowM != _nowM;
}
