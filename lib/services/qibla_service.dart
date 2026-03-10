// Kıble (Kabe) yönü hesaplama – RN services/qibla.js ile aynı mantık.

import 'dart:math' as math;

/// Kabe koordinatları (Mekke, Suudi Arabistan)
const double kaabaLat = 21.4225;
const double kaabaLng = 39.8262;

double _toRadians(double degrees) => degrees * (math.pi / 180);
double _toDegrees(double radians) => radians * (180 / math.pi);

/// Kıble bearing (derece 0–360) – kullanıcı konumundan Kabe'ye.
double calculateQiblaBearing(double latitude, double longitude) {
  final lat1 = _toRadians(latitude);
  final lat2 = _toRadians(kaabaLat);
  final dLon = _toRadians(kaabaLng - longitude);
  final y = math.sin(dLon) * math.cos(lat2);
  final x = math.cos(lat1) * math.sin(lat2) - math.sin(lat1) * math.cos(lat2) * math.cos(dLon);
  double bearing = _toDegrees(math.atan2(y, x));
  bearing = (bearing + 360) % 360;
  return bearing;
}

/// Kıble açısı: qiblaBearing - deviceHeading (0–360).
double calculateQiblaAngle(double qiblaBearing, double deviceHeading) {
  return (qiblaBearing - deviceHeading + 360) % 360;
}
