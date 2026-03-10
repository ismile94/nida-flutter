// RN services/googleCompass.js – yakındaki camiler ve rota.

import 'dart:convert';
import 'package:http/http.dart' as http;

const String _googleApiKey = 'AIzaSyD1kewHcjOI3r7TEVbWTiJ7JZDppqEnoyY';

/// Tek cami: place_id, name, vicinity, geometry: { location: { lat, lng } }, distance (eklenir).
List<Map<String, dynamic>> _normalizeMosqueList(List<Map<String, dynamic>> list) {
  return list.map((p) {
    final loc = p['geometry']?['location'] ?? p['location'];
    final lat = (loc is Map ? (loc['lat'] ?? loc['latitude']) : null) as num?;
    final lng = (loc is Map ? (loc['lng'] ?? loc['longitude']) : null) as num?;
    return {
      'place_id': p['place_id'] ?? p['id'],
      'name': p['name'] ?? 'Unknown',
      'vicinity': p['vicinity'] ?? p['formattedAddress'] ?? '',
      'geometry': {'location': {'lat': lat?.toDouble(), 'lng': lng?.toDouble()}},
      'types': p['types'] ?? [],
    };
  }).toList();
}

Future<List<Map<String, dynamic>>> _findMosquesWithNewApi(double lat, double lng, int radius) async {
  final url = Uri.parse('https://places.googleapis.com/v1/places:searchNearby');
  final body = jsonEncode({
    'includedTypes': ['mosque'],
    'maxResultCount': 20,
    'locationRestriction': {
      'circle': {'center': {'latitude': lat, 'longitude': lng}, 'radius': radius},
    },
    'languageCode': 'tr',
  });
  final res = await http.post(
    url,
    headers: {
      'Content-Type': 'application/json',
      'X-Goog-Api-Key': _googleApiKey,
      'X-Goog-FieldMask': 'places.id,places.displayName,places.formattedAddress,places.location,places.types,places.userRatingCount',
    },
    body: body,
  );
  if (res.statusCode != 200) return [];
  final data = jsonDecode(res.body) as Map<String, dynamic>?;
  final places = data?['places'] as List<dynamic>?;
  if (places == null || places.isEmpty) return [];
  final withReviews = places.where((p) => (((p as Map)['userRatingCount'] as num?)?.toInt() ?? 0) >= 1).toList();
  final converted = withReviews.map((p) {
    final m = p as Map<String, dynamic>;
    final loc = m['location'] as Map<String, dynamic>?;
    return {
      'place_id': m['id'],
      'name': (m['displayName'] is Map ? (m['displayName'] as Map)['text'] : m['displayName']) ?? 'Unknown',
      'vicinity': m['formattedAddress'] ?? '',
      'geometry': {'location': {'lat': (loc?['latitude'] as num?)?.toDouble(), 'lng': (loc?['longitude'] as num?)?.toDouble()}},
      'types': m['types'] ?? [],
    };
  }).toList();
  return _normalizeMosqueList(converted);
}

Future<List<Map<String, dynamic>>> _findMosquesByTextSearch(double lat, double lng, int radius) async {
  const keywords = ['mosque', 'masjid', 'cami'];
  final all = <Map<String, dynamic>>[];
  final seenIds = <String>{};
  for (final keyword in keywords) {
    try {
      final url = Uri.parse(
        'https://maps.googleapis.com/maps/api/place/textsearch/json?query=${Uri.encodeComponent(keyword)}&location=$lat,$lng&radius=$radius&key=$_googleApiKey&language=tr',
      );
      final res = await http.get(url);
      final data = jsonDecode(res.body) as Map<String, dynamic>?;
      if (data?['status'] != 'OK') continue;
      final results = data!['results'] as List<dynamic>? ?? [];
      for (final r in results) {
        final map = r as Map<String, dynamic>;
        final pid = map['place_id'] as String?;
        if (pid == null || seenIds.contains(pid)) continue;
        final types = (map['types'] as List<dynamic>?)?.cast<String>() ?? [];
        final name = (map['name'] as String?)?.toLowerCase() ?? '';
        final isMosque = types.any((t) => t.contains('mosque') || t.contains('place_of_worship')) ||
            name.contains('mosque') || name.contains('masjid') || name.contains('cami');
        final reviews = (map['user_ratings_total'] as num?)?.toInt() ?? 0;
        if (!isMosque || reviews < 1) continue;
        seenIds.add(pid);
        all.add({
          'place_id': pid,
          'name': map['name'] ?? 'Unknown',
          'vicinity': map['formatted_address'] ?? map['vicinity'] ?? '',
          'geometry': {'location': {'lat': (map['geometry']?['location']?['lat'] as num?)?.toDouble(), 'lng': (map['geometry']?['location']?['lng'] as num?)?.toDouble()}},
          'types': types,
        });
      }
    } catch (_) {}
  }
  return _normalizeMosqueList(all);
}

Future<List<Map<String, dynamic>>> _findMosquesLegacy(double lat, double lng, int radius) async {
  final url = Uri.parse(
    'https://maps.googleapis.com/maps/api/place/nearbysearch/json?location=$lat,$lng&radius=$radius&type=place_of_worship&key=$_googleApiKey&language=tr',
  );
  final res = await http.get(url);
  final data = jsonDecode(res.body) as Map<String, dynamic>?;
  if (data?['status'] != 'OK') return [];
  final results = (data!['results'] as List<dynamic>?) ?? [];
  final list = results.map((r) {
    final map = r as Map<String, dynamic>;
    final geo = map['geometry'] as Map<String, dynamic>?;
    final loc = geo?['location'] as Map<String, dynamic>?;
    return {
      'place_id': map['place_id'],
      'name': map['name'] ?? 'Unknown',
      'vicinity': map['vicinity'] ?? '',
      'geometry': {'location': {'lat': (loc?['lat'] as num?)?.toDouble(), 'lng': (loc?['lng'] as num?)?.toDouble()}},
      'types': (map['types'] as List<dynamic>?)?.cast<String>() ?? [],
      'user_ratings_total': map['user_ratings_total'],
    };
  }).toList();
  final filtered = list.where((p) {
    final types = (p['types'] as List<dynamic>?)?.cast<String>() ?? [];
    final name = (p['name'] as String?)?.toLowerCase() ?? '';
    final isMosque = types.any((t) => t.contains('mosque')) || name.contains('mosque') || name.contains('masjid') || name.contains('cami');
    final reviews = (p['user_ratings_total'] as num?)?.toInt() ?? 0;
    return isMosque && reviews >= 1;
  }).toList();
  for (final p in filtered) {
    p.remove('user_ratings_total');
  }
  return _normalizeMosqueList(filtered);
}

/// Yakındaki camileri getir (New API → Text Search → Legacy). radius metre.
/// Sadece en az bir review'u olan camiler döner; review'u olmayanlar listelenmez.
Future<List<Map<String, dynamic>>> findMosquesNearby(double latitude, double longitude, [int radius = 10000]) async {
  try {
    var list = await _findMosquesWithNewApi(latitude, longitude, radius);
    if (list.isNotEmpty) return list;
    list = await _findMosquesByTextSearch(latitude, longitude, radius);
    if (list.isNotEmpty) return list;
    list = await _findMosquesLegacy(latitude, longitude, radius);
    return list;
  } catch (_) {
    try {
      return await _findMosquesByTextSearch(latitude, longitude, radius);
    } catch (_) {
      return [];
    }
  }
}

/// Encoded polyline → liste { latitude, longitude }.
List<Map<String, double>> decodePolyline(String encoded) {
  final points = <Map<String, double>>[];
  int index = 0;
  int lat = 0, lng = 0;
  while (index < encoded.length) {
    int shift = 0, result = 0;
    int b;
    do {
      b = encoded.codeUnitAt(index++) - 63;
      result |= (b & 31) << shift;
      shift += 5;
    } while (b >= 32);
    final dlat = (result & 1) != 0 ? ~(result >> 1) : (result >> 1);
    lat += dlat;
    shift = 0;
    result = 0;
    do {
      b = encoded.codeUnitAt(index++) - 63;
      result |= (b & 31) << shift;
      shift += 5;
    } while (b >= 32);
    final dlng = (result & 1) != 0 ? ~(result >> 1) : (result >> 1);
    lng += dlng;
    points.add({'latitude': lat / 1e5, 'longitude': lng / 1e5});
  }
  return points;
}

/// Rota çizgisi (yürüyüş veya araç). Başarıda rota koordinat listesi.
Future<List<Map<String, double>>> fetchRoute(double fromLat, double fromLng, double toLat, double toLng, {bool walking = true}) async {
  try {
    final mode = walking ? 'walking' : 'driving';
    final url = Uri.parse(
      'https://maps.googleapis.com/maps/api/directions/json?origin=$fromLat,$fromLng&destination=$toLat,$toLng&mode=$mode&key=$_googleApiKey',
    );
    final res = await http.get(url);
    final data = jsonDecode(res.body) as Map<String, dynamic>?;
    if (data?['status'] != 'OK') return [];
    final routes = data!['routes'] as List<dynamic>?;
    if (routes == null || routes.isEmpty) return [];
    final overview = (routes[0] as Map<String, dynamic>)['overview_polyline'] as Map<String, dynamic>?;
    final points = overview?['points'] as String?;
    if (points == null || points.isEmpty) return [];
    return decodePolyline(points);
  } catch (_) {
    return [];
  }
}
