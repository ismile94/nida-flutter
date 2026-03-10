import 'package:flutter/material.dart';

/// Same concept as RN utils/scaling: scaleSize for layout, scaleFont for text,
/// so UI looks consistent across screen sizes and font scale settings.
/// Base reference: 390x844 (e.g. iPhone 12/13).

const double _baseWidth = 390;
const double _baseHeight = 844;
const double _minScale = 0.8;
const double _maxScale = 1.2;

/// Scales a layout dimension (padding, size, radius) by screen size and font scale.
/// When user has larger system font, we slightly reduce scale so content doesn't overflow.
double scaleSize(BuildContext context, double size) {
  final media = MediaQuery.of(context);
  final size_ = media.size;
  final textScale = media.textScaler.scale(1.0);
  final isLandscape = size_.width > size_.height;
  final w = isLandscape ? size_.height : size_.width;
  final h = isLandscape ? size_.width : size_.height;
  double scale = (w / _baseWidth).clamp(0.0, 10.0);
  final hScale = (h / _baseHeight).clamp(0.0, 10.0);
  if (hScale < scale) scale = hScale;
  final adjusted = scale * (1.0 / textScale.clamp(0.5, 2.0));
  final finalScale = adjusted.clamp(_minScale, _maxScale);
  return (size * finalScale).roundToDouble();
}

/// Scales a font size. Uses width + font-scale adjustment so text stays readable.
double scaleFont(BuildContext context, double size) {
  final media = MediaQuery.of(context);
  final w = media.size.width;
  final textScale = media.textScaler.scale(1.0);
  final widthScale = (w / _baseWidth).clamp(0.0, 10.0);
  final adjusted = size * widthScale * (1.0 / textScale.clamp(0.5, 2.0));
  return (adjusted.clamp(size * _minScale, size * _maxScale)).roundToDouble();
}
