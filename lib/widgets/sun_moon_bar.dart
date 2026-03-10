import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../utils/scaling.dart';

/// A horizontal bar that shows a line from sunrise to sunset,
/// with the current sun position (daytime) or moon position (nighttime)
/// animated along it — matching the React Native HomeScreen implementation.
class SunMoonBar extends StatelessWidget {
  final String sunrise; // "HH:MM"
  final String sunset;  // "HH:MM" (maghrib)
  final String sunriseLabel;
  final String sunsetLabel;

  const SunMoonBar({
    super.key,
    required this.sunrise,
    required this.sunset,
    required this.sunriseLabel,
    required this.sunsetLabel,
  });

  static int _toMin(String t) {
    final p = t.split(':');
    if (p.length < 2) return 0;
    return (int.tryParse(p[0]) ?? 0) * 60 + (int.tryParse(p[1]) ?? 0);
  }

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final nowMin = now.hour * 60 + now.minute;
    final sunriseMin = _toMin(sunrise);
    final sunsetMin = _toMin(sunset);

    final isDaytime = nowMin >= sunriseMin && nowMin <= sunsetMin;

    double? sunFraction;
    double? moonFraction;

    if (isDaytime) {
      final daylightMins = sunsetMin - sunriseMin;
      if (daylightMins > 0) {
        sunFraction = ((nowMin - sunriseMin) / daylightMins).clamp(0.0, 1.0);
      }
    } else {
      // Night: moon travels from right (just after sunset) → left (just before sunrise)
      final totalNightMins = (24 * 60 - sunsetMin) + sunriseMin;
      if (totalNightMins > 0) {
        final nightMins = nowMin > sunsetMin
            ? nowMin - sunsetMin
            : (24 * 60 - sunsetMin) + nowMin;
        final nightProgress = (nightMins / totalNightMins).clamp(0.0, 1.0);
        moonFraction = 1.0 - nightProgress;
      }
    }

    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        _SideLabel(
          icon: Icons.wb_sunny_outlined,
          iconColor: const Color(0xFFF59E0B),
          label: sunriseLabel,
          time: sunrise,
        ),
        Expanded(
          child: SizedBox(
            height: scaleSize(context, 44),
            child: CustomPaint(
              painter: _SunMoonPainter(
                sunFraction: sunFraction,
                moonFraction: moonFraction,
              ),
            ),
          ),
        ),
        _SideLabel(
          icon: Icons.nightlight_round,
          iconColor: const Color(0xFF6366F1),
          label: sunsetLabel,
          time: sunset,
        ),
      ],
    );
  }
}

// ── Side label (sunrise / sunset) ──────────────────────────────────────────

class _SideLabel extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final String label;
  final String time;

  const _SideLabel({
    required this.icon,
    required this.iconColor,
    required this.label,
    required this.time,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: scaleSize(context, 48),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, size: scaleSize(context, 13), color: iconColor),
          SizedBox(height: scaleSize(context, 3)),
          Text(
            label,
            style: GoogleFonts.cormorantGaramond(
              fontSize: scaleFont(context, 11),
              color: const Color(0xFF64748B),
              fontWeight: FontWeight.w500,
            ),
            textAlign: TextAlign.center,
          ),
          SizedBox(height: scaleSize(context, 2)),
          Text(
            time,
            style: TextStyle(
              fontSize: scaleFont(context, 10),
              color: const Color(0xFF475569),
              fontWeight: FontWeight.w600,
              fontFamily: 'monospace',
            ),
          ),
        ],
      ),
    );
  }
}

// ── Custom painter ──────────────────────────────────────────────────────────

class _SunMoonPainter extends CustomPainter {
  final double? sunFraction;   // 0.0–1.0, null when nighttime
  final double? moonFraction;  // 0.0–1.0, null when daytime

  const _SunMoonPainter({this.sunFraction, this.moonFraction});

  @override
  void paint(Canvas canvas, Size size) {
    final cy = size.height / 2;

    // Horizontal guide line
    canvas.drawLine(
      Offset(0, cy),
      Offset(size.width, cy),
      Paint()
        ..color = const Color(0xFF6366F1).withValues(alpha: 0.4)
        ..strokeWidth = 1.6
        ..style = PaintingStyle.stroke,
    );

    if (sunFraction != null) {
      _drawSun(canvas, Offset(sunFraction! * size.width, cy));
    }
    if (moonFraction != null) {
      _drawMoon(canvas, Offset(moonFraction! * size.width, cy));
    }
  }

  void _drawSun(Canvas canvas, Offset c) {
    // Concentric glow halos
    canvas.drawCircle(c, 16, Paint()..color = const Color(0xFFF59E0B).withValues(alpha: 0.2));
    canvas.drawCircle(c, 12.8, Paint()..color = const Color(0xFFF59E0B).withValues(alpha: 0.4));

    // Rays – 8 short lines at 45° intervals
    final rayPaint = Paint()
      ..color = const Color(0xFFFFD700)
      ..strokeWidth = 1.6
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke;
    for (int i = 0; i < 8; i++) {
      final a = i * math.pi / 4;
      canvas.drawLine(
        Offset(c.dx + math.cos(a) * 11.2, c.dy + math.sin(a) * 11.2),
        Offset(c.dx + math.cos(a) * 14.4, c.dy + math.sin(a) * 14.4),
        rayPaint,
      );
    }

    // Solid core
    canvas.drawCircle(c, 9.6, Paint()..color = const Color(0xFFFFD700));
  }

  void _drawMoon(Canvas canvas, Offset c) {
    // Concentric glow halos
    canvas.drawCircle(c, 14.4, Paint()..color = const Color(0xFF6366F1).withValues(alpha: 0.2));
    canvas.drawCircle(c, 11.2, Paint()..color = const Color(0xFF6366F1).withValues(alpha: 0.4));

    // Crescent: outer circle minus offset inner circle (evenOdd fill)
    const rOuter = 8.0;
    const rInner = 6.4;
    const innerDx = -2.4;
    final crescent = Path()
      ..fillType = PathFillType.evenOdd
      ..addOval(Rect.fromCircle(center: c, radius: rOuter))
      ..addOval(Rect.fromCircle(
          center: Offset(c.dx + innerDx, c.dy), radius: rInner));
    canvas.drawPath(crescent, Paint()..color = const Color(0xFF818CF8));

    // Small craters for texture
    canvas.drawCircle(
        Offset(c.dx - 1.6, c.dy - 2.4), 1.6,
        Paint()..color = const Color(0xFFA5B4FC).withValues(alpha: 0.6));
    canvas.drawCircle(
        Offset(c.dx - 0.8, c.dy + 1.6), 1.2,
        Paint()..color = const Color(0xFFA5B4FC).withValues(alpha: 0.5));
    canvas.drawCircle(
        Offset(c.dx + 0.8, c.dy - 0.8), 0.8,
        Paint()..color = const Color(0xFFA5B4FC).withValues(alpha: 0.4));
  }

  @override
  bool shouldRepaint(_SunMoonPainter old) =>
      old.sunFraction != sunFraction || old.moonFraction != moonFraction;
}
