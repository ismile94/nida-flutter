import 'dart:convert';
import 'package:flutter/services.dart';

/// Same as RN getCountryDefaultsForLocation: returns default calculation method and madhab
/// for a location's country (from admin.countryCode). TR/TUR returns null (Turkey uses Diyanet).
class CountryCalculationService {
  CountryCalculationService._();

  static const Map<String, int> _methodNameToId = {
    'Jafari': 0,
    'Karachi': 1,
    'ISNA': 2,
    'MWL': 3,
    'Makkah': 4,
    'Egyptian': 5,
    'Tehran': 7,
    'Gulf': 8,
    'Kuwait': 9,
    'Qatar': 10,
    'Singapore': 11,
    'France': 12,
    'Turkey': 13,
    'Russia': 14,
    'Moonsighting': 15,
    'Dubai': 16,
    'Malaysia': 17,
    'Tunisia': 18,
    'Algeria': 19,
    'Indonesia': 20,
    'Morocco': 21,
    'Portugal': 22,
    'Jordan': 23,
  };

  static Map<String, dynamic>? _countryCalculation;

  static Future<Map<String, dynamic>> _loadJson() async {
    if (_countryCalculation != null) return _countryCalculation!;
    final str = await rootBundle.loadString('assets/data/countryCalculation.json');
    _countryCalculation = jsonDecode(str) as Map<String, dynamic>?;
    return _countryCalculation ?? {};
  }

  /// Returns { methodId: int, madhab: String } for the country, or null for TR/TUR or unknown.
  /// Same as RN getCountryDefaultsForLocation(admin).
  static Future<CountryDefaults?> getCountryDefaultsForLocation(Map<String, dynamic>? admin) async {
    final countryCode = ((admin?['countryCode'] as String?) ?? '').toString().toUpperCase();
    if (countryCode.isEmpty || countryCode == 'TR' || countryCode == 'TUR') return null;
    final data = await _loadJson();
    final countryConfig = data[countryCode] as Map<String, dynamic>?;
    if (countryConfig == null) return null;
    final methodName = countryConfig['method'] as String?;
    final methodId = methodName != null ? _methodNameToId[methodName] : null;
    if (methodId == null) return null;
    final madhabRaw = (countryConfig['madhab'] as String? ?? '').toLowerCase();
    final madhab = madhabRaw == 'hanafi' ? 'hanafi' : 'standard';
    return CountryDefaults(methodId: methodId, madhab: madhab);
  }

  /// Synchronous version using pre-loaded data. Call [ensureLoaded] once (e.g. at startup) before using.
  static CountryDefaults? getCountryDefaultsForLocationSync(Map<String, dynamic>? admin) {
    final countryCode = ((admin?['countryCode'] as String?) ?? '').toString().toUpperCase();
    if (countryCode.isEmpty || countryCode == 'TR' || countryCode == 'TUR') return null;
    final data = _countryCalculation;
    if (data == null) return null;
    final countryConfig = data[countryCode] as Map<String, dynamic>?;
    if (countryConfig == null) return null;
    final methodName = countryConfig['method'] as String?;
    final methodId = methodName != null ? _methodNameToId[methodName] : null;
    if (methodId == null) return null;
    final madhabRaw = (countryConfig['madhab'] as String? ?? '').toLowerCase();
    final madhab = madhabRaw == 'hanafi' ? 'hanafi' : 'standard';
    return CountryDefaults(methodId: methodId, madhab: madhab);
  }

  static Future<void> ensureLoaded() async {
    await _loadJson();
  }
}

class CountryDefaults {
  final int methodId;
  final String madhab;
  const CountryDefaults({required this.methodId, required this.madhab});
}
