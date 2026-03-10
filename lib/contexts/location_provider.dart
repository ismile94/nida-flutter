import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/location_service.dart';

/// Single source of truth for cities list. Same as RN: @app_cities array, HomeScreen and SettingsScreen
/// both use it. When Settings updates location it saves here and notifies (MainLocationUpdated).
class LocationProvider extends ChangeNotifier {
  List<Map<String, dynamic>> _cities = [];
  int _selectedCityIndex = 0;
  bool _loaded = false;
  /// Incremented when cities or main location change; HomeScreen uses this to reload prayer times.
  int _prayerTimesDataVersion = 0;

  List<Map<String, dynamic>> get cities => List.unmodifiable(_cities);
  int get selectedCityIndex => _selectedCityIndex;
  int get prayerTimesDataVersion => _prayerTimesDataVersion;
  bool get hasCities => _cities.isNotEmpty;
  Map<String, dynamic>? get selectedCity => _cities.isEmpty ? null : _cities[_selectedCityIndex.clamp(0, _cities.length - 1)];

  /// Load cities from SharedPreferences (same key as RN: @app_cities).
  Future<void> loadFromStorage() async {
    if (_loaded) return;
    try {
      final prefs = await SharedPreferences.getInstance();
      final json = prefs.getString(citiesStorageKey);
      if (json != null) {
        final list = jsonDecode(json) as List<dynamic>?;
        _cities = list?.map((e) => Map<String, dynamic>.from(e as Map)).toList() ?? [];
      } else {
        _cities = [];
      }
      // Default to first city (current location) on every app open; persist so dots show leftmost.
      _selectedCityIndex = 0;
      if (_selectedCityIndex >= _cities.length) _selectedCityIndex = 0;
      _loaded = true;
      await _persist();
      notifyListeners();
    } catch (_) {
      _cities = [];
      _loaded = true;
      notifyListeners();
    }
  }

  /// Replace first city (main location) or set as only city. Then save and notify (MainLocationUpdated).
  Future<void> setMainLocation(Map<String, dynamic> city) async {
    if (_cities.isEmpty) {
      _cities = [city];
    } else {
      _cities = [city, ..._cities.sublist(1)];
    }
    _selectedCityIndex = 0;
    _prayerTimesDataVersion++;
    await _persist();
    notifyListeners();
  }

  Future<void> _persist() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(citiesStorageKey, jsonEncode(_cities));
      await prefs.setString('@app_selected_city_index', _selectedCityIndex.toString());
    } catch (_) {}
  }

  /// Called when Settings updates location; HomeScreen listens and refreshes.
  void notifyMainLocationUpdated() {
    notifyListeners();
  }

  /// Set full cities list (e.g. after loadFromStorage elsewhere) and persist.
  /// Increments prayerTimesDataVersion so HomeScreen reloads prayer times.
  Future<void> setCities(List<Map<String, dynamic>> list) async {
    _cities = List.from(list);
    if (_selectedCityIndex >= _cities.length) _selectedCityIndex = _cities.isEmpty ? 0 : _cities.length - 1;
    _prayerTimesDataVersion++;
    await _persist();
    notifyListeners();
  }

  void setSelectedCityIndex(int index) {
    if (index >= 0 && index < _cities.length) {
      _selectedCityIndex = index;
      _persist();
      notifyListeners();
    }
  }

  /// Add an extra city (max 3 total). Selects the new city. Same as RN addCity().
  /// Returns false if already 3 cities.
  Future<bool> addCity(Map<String, dynamic> city) async {
    if (_cities.length >= 3) return false;
    _cities.add(Map<String, dynamic>.from(city));
    _selectedCityIndex = _cities.length - 1;
    await _persist();
    notifyListeners();
    return true;
  }

  /// Remove city at index. Cannot remove first city (index 0). Same as RN removeCity().
  Future<bool> removeCity(int index) async {
    if (index <= 0 || index >= _cities.length) return false;
    _cities.removeAt(index);
    if (_selectedCityIndex >= _cities.length) {
      _selectedCityIndex = _cities.length - 1;
    } else if (_selectedCityIndex > index) {
      _selectedCityIndex--;
    }
    await _persist();
    notifyListeners();
    return true;
  }

  /// Display name for a city map (same logic as RN getCityDisplayName).
  /// Never returns raw coordinates; uses fallback if name looks like "lat, lng".
  static String getCityDisplayName(Map<String, dynamic> city, String fallback) {
    final name = city['name'];
    if (name is String) {
      if (_looksLikeCoordinates(name)) return fallback;
      return name;
    }
    if (name is Map && name['city'] != null) {
      final cityStr = name['city'] as String;
      if (_looksLikeCoordinates(cityStr)) return fallback;
      return cityStr;
    }
    final admin = city['admin'] as Map<String, dynamic>?;
    if (admin != null && admin['country'] != null) return admin['country'] as String;
    return fallback;
  }

  static bool _looksLikeCoordinates(String s) {
    if (s.length < 5) return false;
    final trimmed = s.trim();
    return RegExp(r'^-?\d+[.,]\d+\s*,\s*-?\d+[.,]\d+$').hasMatch(trimmed);
  }
}
