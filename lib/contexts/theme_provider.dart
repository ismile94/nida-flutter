import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Theme data matching the React Native app (indigo/gradient style).
class AppTheme {
  final String id;
  final String name;
  final List<Color> colors;
  final Color primary;
  final Color activeText;
  final Color inactiveText;

  const AppTheme({
    required this.id,
    required this.name,
    required this.colors,
    required this.primary,
    this.activeText = Colors.white,
    this.inactiveText = const Color(0xB3FFFFFF),
  });
}

/// Supported app language codes (must match app_localizations keys).
const List<String> kSupportedLanguageCodes = [
  'tr', 'en', 'ar', 'pt', 'es', 'de', 'nl',
];

const String kPrefKeyLanguage = 'app_language';

class ThemeProvider extends ChangeNotifier {
  ThemeProvider({
    String? initialLanguage,
    SharedPreferences? sharedPreferences,
  })  : _language = initialLanguage ?? 'en',
        _prefs = sharedPreferences;

  AppTheme _theme = const AppTheme(
    id: 'indigo',
    name: 'Indigo',
    colors: [Color(0xFF4338CA), Color(0xFF6366F1), Color(0xFF818CF8)],
    primary: Color(0xFF6366F1),
  );

  final SharedPreferences? _prefs;

  AppTheme get theme => _theme;
  String _language;
  String get language => _language;

  void setTheme(AppTheme t) {
    _theme = t;
    notifyListeners();
  }

  void setLanguage(String lang) {
    _language = lang;
    _prefs?.setString(kPrefKeyLanguage, lang);
    notifyListeners();
  }
}
