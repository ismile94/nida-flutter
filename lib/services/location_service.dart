import 'dart:convert';
import 'package:geolocator/geolocator.dart';
import 'package:http/http.dart' as http;

/// Mirrors RN services/location.js: Nominatim for search/reverse geocode, geolocator for current position.
/// Same storage key @app_cities is used by LocationProvider.
const String citiesStorageKey = '@app_cities';
const String userCityLocationKey = 'user_city_location';
const String _nominatimUserAgent = 'NidaunnurApp/1.0 (contact: support@nidaunnur.app)';
const _supportedLocales = ['tr', 'en', 'ar', 'pt', 'es', 'de', 'nl'];

String _apiLocale(String locale) {
  final l = locale.toString().toLowerCase();
  return _supportedLocales.contains(l) ? l : 'en';
}

/// Result of getCurrentLocation.
class LocationResult {
  final bool success;
  final double? latitude;
  final double? longitude;
  final String? message;
  const LocationResult({required this.success, this.latitude, this.longitude, this.message});
}

/// Request permission and get current position. Same semantics as RN getCurrentLocation().
Future<LocationResult> getCurrentLocation() async {
  try {
    final serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      return const LocationResult(success: false, message: 'Location services disabled');
    }
    var permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }
    if (permission == LocationPermission.denied || permission == LocationPermission.deniedForever) {
      return const LocationResult(success: false, message: 'Location permission denied');
    }
    final pos = await Geolocator.getCurrentPosition(
      locationSettings: const LocationSettings(accuracy: LocationAccuracy.medium),
    );
    return LocationResult(success: true, latitude: pos.latitude, longitude: pos.longitude);
  } catch (e) {
    return LocationResult(success: false, message: e.toString());
  }
}

/// Hızlı: son bilinen konumu döndürür (önbellek). Yoksa veya 10 dakikadan eskiyse success: false.
/// Kıble ekranı ilk açılışta beklemeyi kısaltmak için kullanılır.
Future<LocationResult> getLastKnownLocation() async {
  try {
    final serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) return const LocationResult(success: false);
    var permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }
    if (permission == LocationPermission.denied || permission == LocationPermission.deniedForever) {
      return const LocationResult(success: false);
    }
    final pos = await Geolocator.getLastKnownPosition();
    if (pos == null) return const LocationResult(success: false);
    final age = DateTime.now().difference(pos.timestamp);
    if (age.inMinutes > 10) return const LocationResult(success: false);
    return LocationResult(success: true, latitude: pos.latitude, longitude: pos.longitude);
  } catch (_) {
    return const LocationResult(success: false);
  }
}

/// Reverse geocode: lat/lng -> { city, country, state, district, countryCode }. Same as RN getLocationName.
Future<Map<String, dynamic>?> getLocationName(double latitude, double longitude, [String locale = 'en']) async {
  try {
    final lang = _apiLocale(locale);
    final url = Uri.parse(
      'https://nominatim.openstreetmap.org/reverse?format=json&lat=$latitude&lon=$longitude&addressdetails=1&accept-language=$lang',
    );
    final res = await http.get(url, headers: {'User-Agent': _nominatimUserAgent});
    if (res.statusCode != 200) return null;
    final data = jsonDecode(res.body) as Map<String, dynamic>?;
    final address = data?['address'] as Map<String, dynamic>?;
    if (address == null) return null;
    final city = address['city'] ?? address['town'] ?? address['village'] ?? address['municipality'] ?? address['county'] ?? address['state_district'] ?? address['state'];
    final country = address['country'];
    final countryCode = address['country_code'] != null ? (address['country_code'] as String).toUpperCase() : null;
    final state = address['province'] ?? address['state'] ?? address['region'];
    // county → municipality → city_district → district → town → village → city
    // For Turkey, Nominatim often returns the district as address.town (not address.county).
    final district = address['county'] ?? address['municipality'] ?? address['city_district'] ?? address['district'] ?? address['town'] ?? address['village'] ?? address['city'];
    if (city == null && country == null) return null;
    return {
      'city': city?.toString() ?? country?.toString(),
      'country': city != null ? (country?.toString()) : null,
      'state': state?.toString(),
      'district': district?.toString(),
      'countryCode': countryCode,
    };
  } catch (_) {
    return null;
  }
}

/// One search result item. name = primary label; village/town/district/city/state/country for hierarchy.
/// Short display: kasaba (village/town) > ilçe (district) > şehir (city).
class SearchResultItem {
  final String name;
  final double latitude;
  final double longitude;
  final String? village;
  final String? town;
  final String? city;
  final String? district;
  final String? state;
  final String? country;
  final String? countryCode;
  const SearchResultItem({
    required this.name,
    required this.latitude,
    required this.longitude,
    this.village,
    this.town,
    this.city,
    this.district,
    this.state,
    this.country,
    this.countryCode,
  });

  /// En küçük birim: kasaba (village/town) yoksa ilçe, o da yoksa şehir.
  String get shortDisplayName {
    final v = village?.trim();
    if (v != null && v.isNotEmpty) return v;
    final t = town?.trim();
    if (t != null && t.isNotEmpty) return t;
    final d = district?.trim();
    if (d != null && d.isNotEmpty) return d;
    final c = city?.trim();
    if (c != null && c.isNotEmpty) return c;
    final s = state?.trim();
    if (s != null && s.isNotEmpty) return s;
    return name;
  }

  /// Tam hiyerarşi: ilçe · kasaba/şehir · state · country (dropdown'da gösterim için).
  String get hierarchySubtitle {
    final seen = <String>{};
    final parts = <String>[];
    void add(String? s) {
      if (s == null || s.trim().isEmpty) return;
      final t = s.trim();
      if (seen.add(t)) parts.add(t);
    }
    add(district);
    add(village);
    add(town);
    add(city);
    add(state);
    add(country);
    return parts.join(' · ');
  }

  Map<String, dynamic> get location => {'latitude': latitude, 'longitude': longitude};
  Map<String, dynamic> get admin => {
        'province': state,
        'district': district,
        'country': country,
        'countryCode': countryCode,
      };
}

/// Search cities via Nominatim. Same as RN searchCities(query, limit, locale).
Future<List<SearchResultItem>> searchCities(String query, {int limit = 5, String locale = 'en'}) async {
  if (query.trim().length < 3) return [];
  try {
    final q = Uri.encodeComponent(query.trim());
    final url = Uri.parse(
      'https://nominatim.openstreetmap.org/search?format=json&q=$q&addressdetails=1&limit=$limit',
    );
    final res = await http.get(url, headers: {'User-Agent': _nominatimUserAgent});
    if (res.statusCode != 200) return [];
    final list = jsonDecode(res.body) as List<dynamic>?;
    if (list == null) return [];
    final items = <SearchResultItem>[];
    for (final e in list) {
      final map = e as Map<String, dynamic>;
      final address = map['address'] as Map<String, dynamic>? ?? {};
      final lat = double.tryParse('${map['lat']}') ?? 0.0;
      final lon = double.tryParse('${map['lon']}') ?? 0.0;
      final countryCode = (address['country_code'] ?? '').toString().toUpperCase();
      final country = (address['country'] ?? '').toString();
      final state = (address['state'] ?? address['province'] ?? address['region'] ?? '').toString();
      final village = (address['village'] ?? '').toString().trim();
      final town = (address['town'] ?? '').toString().trim();
      final city = (address['city'] ?? address['municipality'] ?? '').toString().trim();
      // For Turkey, Nominatim returns the district in address.town (not address.county).
      final district = (address['county'] ?? address['municipality'] ?? address['city_district'] ?? address['district'] ?? address['town'] ?? address['village'] ?? address['city'] ?? '').toString().trim();
      final displayName = (map['display_name'] ?? '').toString();
      final shortName = village.isNotEmpty ? village : (town.isNotEmpty ? town : (district.isNotEmpty ? district : (city.isNotEmpty ? city : (state.isNotEmpty ? state : displayName.split(',').first.trim()))));
      items.add(SearchResultItem(
        name: shortName,
        latitude: lat,
        longitude: lon,
        village: village.isNotEmpty ? village : null,
        town: town.isNotEmpty ? town : null,
        city: city.isNotEmpty ? city : null,
        district: district.isNotEmpty ? district : null,
        state: state.isNotEmpty ? state : null,
        country: country.isNotEmpty ? country : null,
        countryCode: countryCode.isNotEmpty ? countryCode : null,
      ));
    }
    return items;
  } catch (_) {
    return [];
  }
}
