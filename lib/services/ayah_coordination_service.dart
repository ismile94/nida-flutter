// RN: assets/data/ayahCoordination.json – sayfa bazlı ayet koordinatları.
// Pure Quran ekranında ayet tıklama ve highlight için kullanılır.

import 'dart:convert';
import 'package:flutter/services.dart';

/// Bir sayfa için koordinat verisi (image_size + bounding_boxes).
class AyahPageData {
  final int imageWidth;
  final int imageHeight;
  final List<AyahBoundingBox> boundingBoxes;

  AyahPageData({
    required this.imageWidth,
    required this.imageHeight,
    required this.boundingBoxes,
  });
}

/// Tek bir ayet kutusu (köşe koordinatları + surah/ayah).
class AyahBoundingBox {
  final double topLeftX;
  final double topLeftY;
  final double topRightX;
  final double topRightY;
  final double bottomLeftX;
  final double bottomLeftY;
  final double bottomRightX;
  final double bottomRightY;
  final int ayahNumber;
  final int surahNumber;

  AyahBoundingBox({
    required this.topLeftX,
    required this.topLeftY,
    required this.topRightX,
    required this.topRightY,
    required this.bottomLeftX,
    required this.bottomLeftY,
    required this.bottomRightX,
    required this.bottomRightY,
    required this.ayahNumber,
    required this.surahNumber,
  });

  /// Ekranda çizim için ölçeklenmiş Rect benzeri (minX, minY, width, height).
  ({double x, double y, double width, double height}) scaleTo(
    double layoutWidth,
    double layoutHeight,
    int refImageWidth,
    int refImageHeight,
  ) {
    final scaleX = layoutWidth / refImageWidth;
    final scaleY = layoutHeight / refImageHeight;
    final minX = [topLeftX, bottomLeftX].reduce((a, b) => a < b ? a : b);
    final maxX = [topRightX, bottomRightX].reduce((a, b) => a > b ? a : b);
    final minY = [topLeftY, topRightY].reduce((a, b) => a < b ? a : b);
    final maxY = [bottomLeftY, bottomRightY].reduce((a, b) => a > b ? a : b);
    return (
      x: minX * scaleX,
      y: minY * scaleY,
      width: (maxX - minX) * scaleX,
      height: (maxY - minY) * scaleY,
    );
  }
}

Map<String, AyahPageData>? _coordinationCache;

Future<Map<String, AyahPageData>> _loadCoordination() async {
  if (_coordinationCache != null) return _coordinationCache!;
  final raw = await rootBundle.loadString('assets/data/ayahCoordination.json');
  final map = jsonDecode(raw) as Map<String, dynamic>;
  _coordinationCache = {};
  for (final entry in map.entries) {
    final v = entry.value as Map<String, dynamic>?;
    if (v == null) continue;
    final imageSize = v['image_size'] as Map<String, dynamic>?;
    final boxes = v['bounding_boxes'] as List<dynamic>?;
    if (imageSize == null || boxes == null) continue;
    final w = (imageSize['width'] as num?)?.toInt() ?? 0;
    final h = (imageSize['height'] as num?)?.toInt() ?? 0;
    final list = <AyahBoundingBox>[];
    for (final b in boxes) {
      final box = b as Map<String, dynamic>?;
      if (box == null) continue;
      final tl = box['top_left'] as Map<String, dynamic>?;
      final tr = box['top_right'] as Map<String, dynamic>?;
      final bl = box['bottom_left'] as Map<String, dynamic>?;
      final br = box['bottom_right'] as Map<String, dynamic>?;
      if (tl == null || tr == null || bl == null || br == null) continue;
      list.add(AyahBoundingBox(
        topLeftX: (tl['x'] as num?)?.toDouble() ?? 0,
        topLeftY: (tl['y'] as num?)?.toDouble() ?? 0,
        topRightX: (tr['x'] as num?)?.toDouble() ?? 0,
        topRightY: (tr['y'] as num?)?.toDouble() ?? 0,
        bottomLeftX: (bl['x'] as num?)?.toDouble() ?? 0,
        bottomLeftY: (bl['y'] as num?)?.toDouble() ?? 0,
        bottomRightX: (br['x'] as num?)?.toDouble() ?? 0,
        bottomRightY: (br['y'] as num?)?.toDouble() ?? 0,
        ayahNumber: (box['ayet_number'] as num?)?.toInt() ?? 0,
        surahNumber: (box['sure_number'] as num?)?.toInt() ?? 0,
      ));
    }
    _coordinationCache![entry.key] = AyahPageData(imageWidth: w, imageHeight: h, boundingBoxes: list);
  }
  return _coordinationCache!;
}

/// Sayfa anahtarı: "001.png", "002.png", ...
String _pageKey(int page) => '${page.toString().padLeft(3, '0')}.png';

/// Verilen sayfa için ayet koordinat verisi; yoksa null.
Future<AyahPageData?> getAyahCoordinatesForPage(int page) async {
  final map = await _loadCoordination();
  var data = map[_pageKey(page)];
  if (data == null && page == 605) {
    for (final alt in ['605.png', '604.png', '603.png']) {
      data = map[alt];
      if (data != null) break;
    }
  }
  return data;
}

/// Sayfadaki ayet listesi (surah, ayah).
Future<List<({int surah, int ayah})>> getAyahsOnPage(int page) async {
  final data = await getAyahCoordinatesForPage(page);
  if (data == null) return [];
  return data.boundingBoxes.map((b) => (surah: b.surahNumber, ayah: b.ayahNumber)).toList();
}
