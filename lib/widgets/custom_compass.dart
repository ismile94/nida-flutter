// Kıble pusulası: yumuşak animasyon, kıble hizalaması reaksiyonu.

import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import '../utils/scaling.dart';

/// Hedef açıya göre en kısa yolu seçer (-180..180).
double _shortestAngle(double from, double to) {
  double d = (to - from) % 360;
  if (d > 180) d -= 360;
  if (d < -180) d += 360;
  return d;
}

class CustomCompass extends StatefulWidget {
  final double deviceHeading;
  final double qiblaAngle;
  /// Kıbleye hizalandığında gösterilecek metin (dil dosyasından: qiblaAligned).
  final String? alignedLabel;

  const CustomCompass({
    super.key,
    this.deviceHeading = 0,
    this.qiblaAngle = 0,
    this.alignedLabel,
  });

  @override
  State<CustomCompass> createState() => _CustomCompassState();
}

class _CustomCompassState extends State<CustomCompass> with SingleTickerProviderStateMixin {
  late double _smoothedHeading;
  late double _smoothedQibla;
  bool _wasAligned = false;
  static const double _smoothFactor = 0.14;
  static const double _alignThresholdDeg = 6;

  @override
  void initState() {
    super.initState();
    _smoothedHeading = widget.deviceHeading;
    _smoothedQibla = widget.qiblaAngle;
  }

  @override
  void didUpdateWidget(CustomCompass oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Hedef değer çok atlarsa anında yakala (örn. ekran açıldı)
    if ((widget.deviceHeading - _smoothedHeading).abs() > 90) _smoothedHeading = widget.deviceHeading;
    if ((widget.qiblaAngle - _smoothedQibla).abs() > 90) _smoothedQibla = widget.qiblaAngle;
  }

  void _tick() {
    final dh = widget.deviceHeading;
    final qa = widget.qiblaAngle;
    final newH = _smoothedHeading + _shortestAngle(_smoothedHeading, dh) * _smoothFactor;
    final newQ = _smoothedQibla + _shortestAngle(_smoothedQibla, qa) * _smoothFactor;
    final hChanged = (newH - _smoothedHeading).abs() > 0.02;
    final qChanged = (newQ - _smoothedQibla).abs() > 0.02;
    if (hChanged || qChanged) {
      setState(() {
        _smoothedHeading = newH % 360;
        _smoothedQibla = newQ % 360;
      });
    }
  }

  bool _isAligned(double qiblaAngle) {
    final a = qiblaAngle.abs();
    return a <= _alignThresholdDeg || a >= 360 - _alignThresholdDeg;
  }

  @override
  Widget build(BuildContext context) {
    WidgetsBinding.instance.addPostFrameCallback((_) => _tick());
    final w = MediaQuery.sizeOf(context).width;
    final size = scaleSize(context, w * 0.62);
    final center = size / 2;
    final radius = center - scaleSize(context, 20);
    final headingRad = -_smoothedHeading * math.pi / 180;
    final qiblaRad = _smoothedQibla * math.pi / 180;
    final aligned = _isAligned(_smoothedQibla);
    if (aligned && !_wasAligned) {
      _wasAligned = true;
      HapticFeedback.mediumImpact();
    } else if (!aligned) _wasAligned = false;

    return SizedBox(
      width: size,
      height: size,
      child: Stack(
        alignment: Alignment.center,
        children: [
          // Arka plan gölge
          Container(
            width: size,
            height: size,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: Colors.white,
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFF6366F1).withValues(alpha: 0.12),
                  offset: Offset(0, scaleSize(context, 12)),
                  blurRadius: scaleSize(context, 28),
                  spreadRadius: 0,
                ),
              ],
            ),
          ),
          // Gradient disk (hafif iç gölge hissi)
          Container(
            width: size,
            height: size,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(color: Colors.white.withValues(alpha: 0.9), width: scaleSize(context, 2)),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.04),
                  blurRadius: scaleSize(context, 20),
                  offset: Offset(0, scaleSize(context, 4)),
                  spreadRadius: scaleSize(context, -4),
                ),
              ],
              gradient: const LinearGradient(
                begin: Alignment(-0.9, -0.9),
                end: Alignment(0.9, 0.9),
                colors: [Color(0xFFFFFFFF), Color(0xFFF1F5F9), Color(0xFFE2E8F0)],
                stops: [0.0, 0.6, 1.0],
              ),
            ),
          ),
          // Dönen kadran (ticks + daire)
          Transform.rotate(
            angle: headingRad,
            child: CustomPaint(
              size: Size(size, size),
              painter: _CompassTicksPainter(
                center: center,
                radius: radius,
                tickLenMain: scaleSize(context, 22),
                tickLenSub: scaleSize(context, 10),
                strokeMain: scaleSize(context, 3),
                strokeSub: scaleSize(context, 1),
              ),
            ),
          ),
          // N E S W (kadranla birlikte döner)
          Transform.rotate(
            angle: headingRad,
            child: SizedBox(
              width: size,
              height: size,
              child: Stack(
                alignment: Alignment.center,
                children: ['N', 'E', 'S', 'W'].asMap().entries.map((e) {
                  final i = e.key;
                  final angle = i * 90 * math.pi / 180;
                  final rLabel = radius - scaleSize(context, 55);
                  final dy = -rLabel * math.cos(angle);
                  final dx = rLabel * math.sin(angle);
                  return Positioned(
                    left: center + dx - scaleSize(context, 12),
                    top: center + dy - scaleSize(context, 11),
                    child: Transform.rotate(
                      angle: angle,
                      child: Text(
                        e.value,
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: scaleFont(context, 22),
                          fontWeight: FontWeight.w900,
                          color: const Color(0xFF1E293B),
                          letterSpacing: 0,
                        ),
                      ),
                    ),
                  );
                }).toList(),
              ),
            ),
          ),
          // Kıble göstergesi (yumuşak döner)
          Transform.rotate(
            angle: qiblaRad,
            child: SizedBox(
              width: size,
              height: size,
              child: Align(
                alignment: Alignment.topCenter,
                child: Padding(
                  padding: EdgeInsets.only(top: size * 0.04),
                  child: _KaabaIndicator(size: scaleSize(context, size * 0.08)),
                ),
              ),
            ),
          ),
          // Sabit kıble oku
          CustomPaint(
            size: Size(size, size),
            painter: _QiblaArrowPainter(
              center: center,
              radius: radius,
              strokeWidth: scaleSize(context, 6),
              triangleHalf: scaleSize(context, 15),
              topOffset: scaleSize(context, 10),
              bottomOffset: scaleSize(context, 20),
            ),
          ),
          // Merkez pivot
          Container(
            width: scaleSize(context, 24),
            height: scaleSize(context, 24),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: Colors.white,
              boxShadow: [
                BoxShadow(color: Colors.black.withValues(alpha: 0.15), blurRadius: scaleSize(context, 6), offset: Offset(0, scaleSize(context, 2))),
              ],
            ),
            child: Center(
              child: Container(
                width: scaleSize(context, 12),
                height: scaleSize(context, 12),
                decoration: const BoxDecoration(shape: BoxShape.circle, color: Color(0xFF4F46E5)),
              ),
            ),
          ),
          // Kıble hizalandığında reaksiyon: yeşil halka + metin
          if (aligned)
            Positioned.fill(
              child: IgnorePointer(
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    Center(
                      child: Container(
                        width: size * 0.88,
                        height: size * 0.88,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          border: Border.all(color: const Color(0xFF10B981), width: scaleSize(context, 3)),
                          color: const Color(0xFF10B981).withValues(alpha: 0.06),
                        ),
                      ),
                    ),
                    Positioned(
                      bottom: size * 0.05,
                      child: Container(
                        padding: EdgeInsets.symmetric(horizontal: scaleSize(context, 16), vertical: scaleSize(context, 8)),
                        decoration: BoxDecoration(
                          color: const Color(0xFF10B981).withValues(alpha: 0.18),
                          borderRadius: BorderRadius.circular(scaleSize(context, 20)),
                        ),
                        child: Text(
                          widget.alignedLabel ?? 'Kıbleye döndünüz',
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: scaleFont(context, 15),
                            fontWeight: FontWeight.w700,
                            color: const Color(0xFF059669),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _KaabaIndicator extends StatelessWidget {
  final double size;

  const _KaabaIndicator({required this.size});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: Icon(Icons.mosque, size: size, color: const Color(0xFF4F46E5)),
    );
  }
}

class _CompassTicksPainter extends CustomPainter {
  final double center;
  final double radius;
  final double tickLenMain;
  final double tickLenSub;
  final double strokeMain;
  final double strokeSub;

  _CompassTicksPainter({
    required this.center,
    required this.radius,
    this.tickLenMain = 22,
    this.tickLenSub = 10,
    this.strokeMain = 3,
    this.strokeSub = 1,
  });

  @override
  void paint(Canvas canvas, Size size) {
    for (int i = 0; i < 72; i++) {
      final angle = i * 5 * math.pi / 180;
      final isMain = (i * 5) % 90 == 0;
      final len = isMain ? tickLenMain : tickLenSub;
      final innerR = radius - len;
      final x1 = center + math.sin(angle) * innerR;
      final y1 = center - math.cos(angle) * innerR;
      final x2 = center + math.sin(angle) * radius;
      final y2 = center - math.cos(angle) * radius;
      canvas.drawLine(
        Offset(x1, y1),
        Offset(x2, y2),
        Paint()
          ..color = isMain ? const Color(0xFF4F46E5) : const Color(0xFF94A3B8).withValues(alpha: 0.4)
          ..strokeWidth = isMain ? strokeMain : strokeSub
          ..style = PaintingStyle.stroke
          ..strokeCap = StrokeCap.round,
      );
    }
    canvas.drawCircle(
      Offset(center, center),
      radius * 0.38,
      Paint()
        ..color = const Color(0xFFE2E8F0)
        ..style = PaintingStyle.stroke
        ..strokeWidth = strokeSub,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _QiblaArrowPainter extends CustomPainter {
  final double center;
  final double radius;
  final double strokeWidth;
  final double triangleHalf;
  final double topOffset;
  final double bottomOffset;

  _QiblaArrowPainter({
    required this.center,
    required this.radius,
    this.strokeWidth = 6,
    this.triangleHalf = 15,
    this.topOffset = 10,
    this.bottomOffset = 20,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final arrowTop = center - radius * 0.42;
    final arrowBottom = center - bottomOffset;
    final path = Path()
      ..moveTo(center, arrowBottom)
      ..lineTo(center, arrowTop);
    canvas.drawPath(
      path,
      Paint()
        ..color = const Color(0xFF4F46E5)
        ..strokeWidth = strokeWidth
        ..strokeCap = StrokeCap.round
        ..style = PaintingStyle.stroke,
    );
    final trianglePath = Path()
      ..moveTo(center, arrowTop - topOffset)
      ..lineTo(center - triangleHalf, center - radius * 0.34)
      ..lineTo(center + triangleHalf, center - radius * 0.34)
      ..close();
    canvas.drawPath(trianglePath, Paint()..color = const Color(0xFF4F46E5));
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
