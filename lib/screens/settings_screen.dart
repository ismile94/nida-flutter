import 'dart:convert';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../contexts/navigation_bar_provider.dart';
import '../contexts/theme_provider.dart';
import '../contexts/location_provider.dart';
import '../l10n/app_localizations.dart';
import '../services/app_permission_service.dart';
import '../utils/scaling.dart';
import '../services/country_calculation_service.dart';
import '../services/location_service.dart';
import '../widgets/location_input_modal.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:google_fonts/google_fonts.dart';

import '../app_version.g.dart';

const String _timeFormatKey = '@app_time_format';
const String _supportEmail = 'nidaadhan2025@gmail.com';
const String _ezanSoundKey = '@app_ezan_sound';

/// Asset paths for left icons – same as SettingsScreen.js (require('../assets/...')).
/// Each row uses the same icon as in RN.
class _SettingsIcons {
  static const String timeFormat = 'assets/simple-clock.png';      // SettingItemRow
  static const String language = 'assets/translate.png';
  static const String prayerNotifications = 'assets/crescent.png';
  static const String ezanSound = 'assets/adhan.png';
  static const String location = 'assets/pin.png';
  static const String calculationMethod = 'assets/mosque2.png';    // large 28x28
  static const String about = 'assets/info.png';
  static const String helpSupport = 'assets/support.png';
  // RN uses Ionicons for these (no asset): time-outline -> Icons.access_time, calculator-outline -> Icons.calculate
}

/// Flutter port of SettingsScreen.js – same layout, sections, modals, and styling.
class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> with SingleTickerProviderStateMixin {
  late AnimationController _logoController;
  late Animation<double> _logoOpacity;

  bool _notificationsEnabled = true;
  bool _ezanSoundEnabled = true;
  String _timeFormat = '24';
  String _selectedLanguage = 'en';
  int _selectedCalculationMethod = 2;
  String _selectedMadhab = 'standard';
  bool _isTurkeyUser = false;
  bool _notificationLoading = false;

  bool _showLocationModal = false;
  bool _showLanguageModal = false;
  bool _showAboutModal = false;
  bool _showHelpModal = false;

  @override
  void initState() {
    super.initState();
    _logoController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 10),
    );
    _logoOpacity = TweenSequence<double>([
      TweenSequenceItem(tween: Tween<double>(begin: 0.03, end: 0.25), weight: 1),
      TweenSequenceItem(tween: Tween<double>(begin: 0.25, end: 0.03), weight: 1),
    ]).animate(_logoController);
    _logoController.repeat();
    _loadSettings();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      context.read<NavigationBarProvider>().setVisible(true);
      await context.read<LocationProvider>().loadFromStorage();
    });
  }

  @override
  void dispose() {
    _logoController.dispose();
    super.dispose();
  }

  Future<void> _loadSettings() async {
    final prefs = await SharedPreferences.getInstance();
    final loc = context.read<LocationProvider>();
    if (!loc.hasCities) await loc.loadFromStorage();
    if (!mounted) return;
    List<Map<String, dynamic>> cities = List.from(loc.cities);
    bool citiesChanged = false;
    for (int i = 0; i < cities.length; i++) {
      final c = cities[i];
      final admin = c['admin'] as Map<String, dynamic>?;
      final needMethod = c['calculationMethod'] == null;
      final needMadhab = (c['madhab'] as String? ?? '').isEmpty;
      if (needMethod || needMadhab) {
        final defaults = await CountryCalculationService.getCountryDefaultsForLocation(admin);
        if (defaults != null) {
          cities[i] = Map<String, dynamic>.from(c);
          if (needMethod) cities[i]['calculationMethod'] = defaults.methodId;
          if (needMadhab) cities[i]['madhab'] = defaults.madhab;
          citiesChanged = true;
        }
      }
    }
    if (citiesChanged) await loc.setCities(cities);
    if (!mounted) return;
    final notificationGranted = await AppPermissionService.isNotificationGranted();
    if (!mounted) return;
    final firstCity = cities.isNotEmpty ? cities.first : null;
    final isTurkey = cities.any((c) {
      final admin = c['admin'] as Map?;
      final cc = admin?['countryCode'] as String?;
      final country = admin?['country'] as String?;
      return cc == 'TR' || cc == 'TUR' || country == 'Turkey' || country == 'Türkiye' || country == 'Turkiye';
    });
    setState(() {
      _timeFormat = prefs.getString(_timeFormatKey) ?? '24';
      _ezanSoundEnabled = prefs.getString(_ezanSoundKey) != 'false';
      _notificationsEnabled = notificationGranted;
      _selectedCalculationMethod = (firstCity?['calculationMethod'] as int?) ?? 2;
      _selectedMadhab = (firstCity?['madhab'] as String?) ?? 'standard';
      _isTurkeyUser = isTurkey;
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final lang = context.read<ThemeProvider>().language;
    if (_selectedLanguage != lang) setState(() => _selectedLanguage = lang);
  }

  Future<void> _saveTimeFormat(String format) async {
    setState(() => _timeFormat = format);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_timeFormatKey, format);
  }

  Future<void> _saveEzanSound(bool value) async {
    setState(() => _ezanSoundEnabled = value);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_ezanSoundKey, value.toString());
  }

  String _getCityDisplayName(BuildContext context, Map<String, dynamic> city) {
    final name = city['name'];
    if (name is String) return name;
    if (name is Map && name['city'] != null) return name['city'] as String;
    final admin = city['admin'] as Map?;
    if (admin != null && admin['country'] != null) return admin['country'] as String;
    return _l10n(context, 'locationLoading');
  }

  /// Same as RN: languages with names from i18n (languageTurkish, languageEnglish, ...).
  List<Map<String, String>> _getLanguages(BuildContext context) => [
    {'code': 'tr', 'name': _l10n(context, 'languageTurkish'), 'flag': '🇹🇷'},
    {'code': 'en', 'name': _l10n(context, 'languageEnglish'), 'flag': '🇬🇧'},
    {'code': 'ar', 'name': _l10n(context, 'languageArabic'), 'flag': '🇸🇦'},
    {'code': 'pt', 'name': _l10n(context, 'languagePortuguese'), 'flag': '🇧🇷'},
    {'code': 'es', 'name': _l10n(context, 'languageSpanish'), 'flag': '🇪🇸'},
    {'code': 'de', 'name': _l10n(context, 'languageGerman'), 'flag': '🇩🇪'},
    {'code': 'nl', 'name': _l10n(context, 'languageDutch'), 'flag': '🇳🇱'},
  ];

  static const List<Map<String, dynamic>> _calculationMethods = [
    {'id': 0, 'name': 'Jafari', 'description': 'Shia Ithna-Ashari, Leva Institute, Qum'},
    {'id': 1, 'name': 'Karachi', 'description': 'University of Islamic Sciences, Karachi'},
    {'id': 2, 'name': 'ISNA', 'description': 'Islamic Society of North America'},
    {'id': 3, 'name': 'MWL', 'description': 'Muslim World League'},
    {'id': 4, 'name': 'Makkah', 'description': 'Umm Al-Qura University, Makkah'},
    {'id': 5, 'name': 'Egyptian', 'description': 'Egyptian General Authority of Survey'},
    {'id': 7, 'name': 'Tehran', 'description': 'Institute of Geophysics, University of Tehran'},
    {'id': 8, 'name': 'Gulf', 'description': 'Gulf Region'},
    {'id': 9, 'name': 'Kuwait', 'description': 'Kuwait'},
    {'id': 10, 'name': 'Qatar', 'description': 'Qatar'},
    {'id': 11, 'name': 'Singapore', 'description': 'Majlis Ugama Islam Singapura'},
    {'id': 12, 'name': 'France', 'description': 'Union Organization Islamic de France'},
    {'id': 13, 'name': 'Turkey', 'description': 'Diyanet İşleri Başkanlığı, Turkey'},
    {'id': 14, 'name': 'Russia', 'description': 'Spiritual Administration of Muslims of Russia'},
    {'id': 15, 'name': 'Moonsighting', 'description': 'Moonsighting Committee Worldwide'},
    {'id': 16, 'name': 'Dubai', 'description': 'Dubai (UAE)'},
    {'id': 17, 'name': 'Malaysia', 'description': 'JAKIM (Malaysia)'},
    {'id': 18, 'name': 'Tunisia', 'description': 'Tunisia'},
    {'id': 19, 'name': 'Algeria', 'description': 'Algeria'},
    {'id': 20, 'name': 'Indonesia', 'description': 'Kementerian Agama Republik Indonesia'},
    {'id': 21, 'name': 'Morocco', 'description': 'Morocco'},
    {'id': 22, 'name': 'Portugal', 'description': 'Comunidade Islâmica de Lisboa'},
    {'id': 23, 'name': 'Jordan', 'description': 'Ministry of Awqaf, Jordan'},
  ];

  /// Same as RN: madhab options with name/description from i18n (madhabStandard, madhabStandardDesc, ...).
  List<Map<String, String>> _getMadhabOptions(BuildContext context) => [
    {'id': 'standard', 'name': _l10n(context, 'madhabStandard'), 'description': _l10n(context, 'madhabStandardDesc')},
    {'id': 'hanafi', 'name': _l10n(context, 'madhabHanafi'), 'description': _l10n(context, 'madhabHanafiDesc')},
  ];

  @override
  Widget build(BuildContext context) {
    final loc = context.watch<LocationProvider>();
    final settingsCities = loc.cities;
    final bottomPadding = MediaQuery.paddingOf(context).bottom + scaleSize(context, 80);

    return Stack(
      children: [
        Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      body: SafeArea(
        top: true,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _buildHeader(),
            Expanded(
              child: SingleChildScrollView(
                padding: EdgeInsets.only(bottom: bottomPadding),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _buildSection(_l10n(context, 'timeFormat'), _buildTimeFormatSection()),
                    _buildSection(_l10n(context, 'languageSelection'), _buildLanguageItem()),
                    _buildSection(_l10n(context, 'notifications'), _buildNotificationsSection()),
                    _buildSection(_l10n(context, 'other'), _buildOtherSection(settingsCities)),
                    if (settingsCities.length > 1) _buildSection(_l10n(context, 'calculationPerCity'), _buildCalculationPerCity(settingsCities)),
                    _buildVersionFooter(),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    ),
        _buildModals(),
      ],
    );
  }

  Widget _buildModals() {
    return Stack(
      children: [
        if (_showLanguageModal) _languageModal(),
        if (_showAboutModal) _aboutModal(),
        if (_showHelpModal) _helpModal(),
        if (_showLocationModal) _locationModal(),
      ],
    );
  }

  void _showCalculationMethodDialog({int? cityIndex}) {
    final loc = context.read<LocationProvider>();
    final cities = List<Map<String, dynamic>>.from(loc.cities);
    final isCity = cityIndex != null;
    final idx = cityIndex ?? 0;
    if (isCity && idx < cities.length) {
      setState(() => _selectedCalculationMethod = (cities[idx]['calculationMethod'] as int?) ?? 2);
    }
    final title = isCity && idx < cities.length
        ? '${_l10n(context, 'calculationMethod')} - ${_getCityDisplayName(context, cities[idx])}'
        : _l10n(context, 'calculationMethod');
    showDialog<void>(
      context: context,
      builder: (ctx) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(scaleSize(ctx, 24))),
        child: ConstrainedBox(
          constraints: BoxConstraints(maxWidth: scaleSize(ctx, 400), maxHeight: MediaQuery.of(ctx).size.height * 0.7),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Padding(
                padding: EdgeInsets.fromLTRB(scaleSize(ctx, 20), scaleSize(ctx, 20), scaleSize(ctx, 8), scaleSize(ctx, 12)),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Text(
                        title,
                        style: GoogleFonts.plusJakartaSans(fontSize: scaleFont(ctx, 18), fontWeight: FontWeight.bold, color: const Color(0xFF1E293B)),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    IconButton(onPressed: () => Navigator.of(ctx).pop(), icon: Icon(Icons.close, size: scaleSize(ctx, 26), color: const Color(0xFF1E293B))),
                  ],
                ),
              ),
              Divider(height: scaleSize(ctx, 1)),
              Flexible(
                child: ListView.builder(
                  shrinkWrap: true,
                  itemCount: _calculationMethods.length,
                  itemBuilder: (_, i) {
                    final item = _calculationMethods[i];
                    final id = item['id'] as int;
                    final selected = _selectedCalculationMethod == id;
                    return ListTile(
                      title: Text(item['name'] as String, style: GoogleFonts.plusJakartaSans(fontWeight: selected ? FontWeight.w600 : FontWeight.w500, color: selected ? const Color(0xFF6366F1) : const Color(0xFF1E293B))),
                      subtitle: Text(item['description'] as String, style: GoogleFonts.plusJakartaSans(fontSize: scaleFont(ctx, 12), color: const Color(0xFF64748B))),
                      trailing: selected ? Icon(Icons.check_circle, color: const Color(0xFF6366F1), size: scaleSize(ctx, 22)) : null,
                      tileColor: selected ? const Color(0xFFEEF2FF) : null,
                      onTap: () async {
                        setState(() => _selectedCalculationMethod = id);
                        final current = context.read<LocationProvider>().cities;
                        if (current.isNotEmpty && idx < current.length) {
                          final updated = List<Map<String, dynamic>>.from(current);
                          updated[idx] = Map<String, dynamic>.from(updated[idx])..['calculationMethod'] = id;
                          await context.read<LocationProvider>().setCities(updated);
                        }
                        if (ctx.mounted) Navigator.of(ctx).pop();
                        if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(_l10n(context, 'calculationMethodUpdated'))));
                      },
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showMadhabDialog({int? cityIndex}) {
    final cities = List<Map<String, dynamic>>.from(context.read<LocationProvider>().cities);
    final isCity = cityIndex != null;
    final idx = cityIndex ?? 0;
    if (isCity && idx < cities.length) {
      setState(() => _selectedMadhab = (cities[idx]['madhab'] as String?) ?? 'standard');
    }
    final title = isCity && idx < cities.length
        ? '${_l10n(context, 'madhabAsr')} - ${_getCityDisplayName(context, cities[idx])}'
        : _l10n(context, 'madhabAsr');
    showDialog<void>(
      context: context,
      builder: (ctx) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(scaleSize(ctx, 24))),
        child: ConstrainedBox(
          constraints: BoxConstraints(maxWidth: scaleSize(ctx, 400), maxHeight: MediaQuery.of(ctx).size.height * 0.5),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Padding(
                padding: EdgeInsets.fromLTRB(scaleSize(ctx, 20), scaleSize(ctx, 20), scaleSize(ctx, 8), scaleSize(ctx, 12)),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Text(
                        title,
                        style: GoogleFonts.plusJakartaSans(fontSize: scaleFont(ctx, 18), fontWeight: FontWeight.bold, color: const Color(0xFF1E293B)),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    IconButton(onPressed: () => Navigator.of(ctx).pop(), icon: Icon(Icons.close, size: scaleSize(ctx, 26), color: const Color(0xFF1E293B))),
                  ],
                ),
              ),
              Divider(height: scaleSize(ctx, 1)),
              Flexible(
                child: ListView.builder(
                  shrinkWrap: true,
                  itemCount: _getMadhabOptions(context).length,
                  itemBuilder: (_, i) {
                    final item = _getMadhabOptions(context)[i];
                    final id = item['id']!;
                    final selected = _selectedMadhab == id;
                    return ListTile(
                      title: Text(item['name']!, style: GoogleFonts.plusJakartaSans(fontWeight: selected ? FontWeight.w600 : FontWeight.w500, color: selected ? const Color(0xFF6366F1) : const Color(0xFF1E293B))),
                      subtitle: Text(item['description']!, style: GoogleFonts.plusJakartaSans(fontSize: scaleFont(ctx, 12), color: const Color(0xFF64748B))),
                      trailing: selected ? Icon(Icons.check_circle, color: const Color(0xFF6366F1), size: scaleSize(ctx, 22)) : null,
                      tileColor: selected ? const Color(0xFFEEF2FF) : null,
                      onTap: () async {
                        setState(() => _selectedMadhab = id);
                        final current = context.read<LocationProvider>().cities;
                        if (current.isNotEmpty && idx < current.length) {
                          final updated = List<Map<String, dynamic>>.from(current);
                          updated[idx] = Map<String, dynamic>.from(updated[idx])..['madhab'] = id;
                          await context.read<LocationProvider>().setCities(updated);
                        }
                        if (ctx.mounted) Navigator.of(ctx).pop();
                        if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(_l10n(context, 'madhabUpdated'))));
                      },
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _l10n(BuildContext context, String key) {
    return AppLocalizations.t(context, key);
  }

  Widget _languageModal() {
    final langs = _getLanguages(context);
    return _modalBottom(
      title: _l10n(context, 'languageSelection'),
      onClose: () => setState(() => _showLanguageModal = false),
      maxHeightFactor: 0.58,
      // ListView without shrinkWrap fills the Flexible and scrolls inside
      child: ListView.builder(
        padding: EdgeInsets.zero,
        itemCount: langs.length,
        itemBuilder: (_, i) {
          final item = langs[i];
          final selected = _selectedLanguage == item['code'];
          return Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: () {
                setState(() => _selectedLanguage = item['code']!);
                context.read<ThemeProvider>().setLanguage(item['code']!);
                setState(() => _showLanguageModal = false);
              },
              child: Container(
                color: selected ? _kAccent.withValues(alpha: 0.07) : Colors.transparent,
                padding: EdgeInsets.symmetric(horizontal: scaleSize(context, 20), vertical: scaleSize(context, 14)),
                child: Row(
                  children: [
                    Text(item['flag']!, style: GoogleFonts.plusJakartaSans(fontSize: scaleFont(context, 22))),
                    SizedBox(width: scaleSize(context, 14)),
                    Expanded(
                      child: Text(
                        item['name']!,
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: scaleFont(context, 14),
                          fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
                          color: selected ? _kAccent : _kTextPrimary,
                        ),
                      ),
                    ),
                    if (selected)
                      Icon(Icons.check_circle, color: _kAccent, size: scaleSize(context, 18)),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _aboutModal() {
    return _modalBottom(
      title: _l10n(context, 'about'),
      onClose: () => setState(() => _showAboutModal = false),
      child: SingleChildScrollView(
        padding: EdgeInsets.fromLTRB(scaleSize(context, 24), scaleSize(context, 16), scaleSize(context, 24), scaleSize(context, 28)),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Text(_l10n(context, 'appName'), style: GoogleFonts.plusJakartaSans(fontSize: scaleFont(context, 22), fontWeight: FontWeight.w700, color: _kTextPrimary, letterSpacing: -0.5, decoration: TextDecoration.none)),
            SizedBox(height: scaleSize(context, 4)),
            Text('v$appVersionName', style: GoogleFonts.plusJakartaSans(fontSize: scaleFont(context, 12), color: _kTextSecondary, decoration: TextDecoration.none)),
            SizedBox(height: scaleSize(context, 16)),
            Text(_l10n(context, 'aboutDescription'), style: GoogleFonts.plusJakartaSans(fontSize: scaleFont(context, 14), color: _kTextSecondary, height: 1.6, decoration: TextDecoration.none), textAlign: TextAlign.center),
            SizedBox(height: scaleSize(context, 20)),
            Align(alignment: Alignment.centerLeft, child: Text(_l10n(context, 'features'), style: GoogleFonts.plusJakartaSans(fontSize: scaleFont(context, 14), fontWeight: FontWeight.w600, color: _kTextPrimary, decoration: TextDecoration.none))),
            SizedBox(height: scaleSize(context, 10)),
            ...[
              _l10n(context, 'prayerTimes'),
              _l10n(context, 'quran'),
              _l10n(context, 'qibla'),
              _l10n(context, 'dhikr'),
              _l10n(context, 'notifications'),
            ].map((f) => Align(
              alignment: Alignment.centerLeft,
              child: Padding(
                padding: EdgeInsets.only(bottom: scaleSize(context, 4)),
                child: Text('• $f', style: GoogleFonts.plusJakartaSans(fontSize: scaleFont(context, 13), color: _kTextSecondary, height: 1.5, decoration: TextDecoration.none)),
              ),
            )),
            SizedBox(height: scaleSize(context, 20)),
            Text(_l10n(context, 'copyright'), style: GoogleFonts.plusJakartaSans(fontSize: scaleFont(context, 11), color: _kTextSecondary, decoration: TextDecoration.none)),
            SizedBox(height: scaleSize(context, 20)),
            Material(
              color: Colors.transparent,
              child: InkWell(
                onTap: _launchErrorReportEmail,
                borderRadius: BorderRadius.circular(scaleSize(context, 12)),
                child: Padding(
                  padding: EdgeInsets.symmetric(vertical: scaleSize(context, 12), horizontal: scaleSize(context, 4)),
                  child: Row(
                    children: [
                      Icon(Icons.bug_report_outlined, size: scaleSize(context, 22), color: _kAccent),
                      SizedBox(width: scaleSize(context, 12)),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(_l10n(context, 'reportError'), style: GoogleFonts.plusJakartaSans(fontSize: scaleFont(context, 14), fontWeight: FontWeight.w600, color: _kTextPrimary, decoration: TextDecoration.none)),
                            SizedBox(height: scaleSize(context, 2)),
                            Text(_l10n(context, 'reportErrorSubtitle'), style: GoogleFonts.plusJakartaSans(fontSize: scaleFont(context, 12), color: _kTextSecondary, decoration: TextDecoration.none)),
                          ],
                        ),
                      ),
                      Icon(Icons.arrow_forward_ios, size: scaleSize(context, 14), color: _kTextSecondary),
                    ],
                  ),
                ),
              ),
            ),
            SizedBox(height: scaleSize(context, 12)),
            Material(
              color: Colors.transparent,
              child: InkWell(
                onTap: _launchSuggestionEmail,
                borderRadius: BorderRadius.circular(scaleSize(context, 12)),
                child: Padding(
                  padding: EdgeInsets.symmetric(vertical: scaleSize(context, 12), horizontal: scaleSize(context, 4)),
                  child: Row(
                    children: [
                      Icon(Icons.lightbulb_outline_rounded, size: scaleSize(context, 22), color: _kAccent),
                      SizedBox(width: scaleSize(context, 12)),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(_l10n(context, 'suggestFeature'), style: GoogleFonts.plusJakartaSans(fontSize: scaleFont(context, 14), fontWeight: FontWeight.w600, color: _kTextPrimary, decoration: TextDecoration.none)),
                            SizedBox(height: scaleSize(context, 2)),
                            Text(_l10n(context, 'suggestFeatureSubtitle'), style: GoogleFonts.plusJakartaSans(fontSize: scaleFont(context, 12), color: _kTextSecondary, decoration: TextDecoration.none)),
                          ],
                        ),
                      ),
                      Icon(Icons.arrow_forward_ios, size: scaleSize(context, 14), color: _kTextSecondary),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _helpModal() {
    return _modalBottom(
      title: _l10n(context, 'helpSupport'),
      onClose: () => setState(() => _showHelpModal = false),
      child: SingleChildScrollView(
        padding: EdgeInsets.fromLTRB(scaleSize(context, 24), scaleSize(context, 16), scaleSize(context, 24), scaleSize(context, 28)),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(_l10n(context, 'frequentlyAskedQuestions'), style: GoogleFonts.plusJakartaSans(fontSize: scaleFont(context, 15), fontWeight: FontWeight.w600, color: _kTextPrimary, decoration: TextDecoration.none)),
            SizedBox(height: scaleSize(context, 14)),
            _helpItem(_l10n(context, 'howToSetLocation'), _l10n(context, 'locationHelpAnswer')),
            _helpItem(_l10n(context, 'howToEnableNotifications'), _l10n(context, 'notificationsHelpAnswer')),
            _helpItem(_l10n(context, 'howToChangeLanguage'), _l10n(context, 'languageHelpAnswer')),
            _helpItem(_l10n(context, 'howToCalibrateCompass'), _l10n(context, 'compassHelpAnswer')),
            SizedBox(height: scaleSize(context, 20)),
            Text(_l10n(context, 'contactSupport'), style: GoogleFonts.plusJakartaSans(fontSize: scaleFont(context, 15), fontWeight: FontWeight.w600, color: _kTextPrimary, decoration: TextDecoration.none)),
            SizedBox(height: scaleSize(context, 10)),
            Text(_l10n(context, 'contactSupportText'), style: GoogleFonts.plusJakartaSans(fontSize: scaleFont(context, 13), color: _kTextSecondary, height: 1.6, decoration: TextDecoration.none)),
            SizedBox(height: scaleSize(context, 16)),
            Material(
              color: Colors.transparent,
              child: InkWell(
                onTap: _launchErrorReportEmail,
                borderRadius: BorderRadius.circular(scaleSize(context, 12)),
                child: Padding(
                  padding: EdgeInsets.symmetric(vertical: scaleSize(context, 12), horizontal: scaleSize(context, 4)),
                  child: Row(
                    children: [
                      Icon(Icons.bug_report_outlined, size: scaleSize(context, 22), color: _kAccent),
                      SizedBox(width: scaleSize(context, 12)),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(_l10n(context, 'reportError'), style: GoogleFonts.plusJakartaSans(fontSize: scaleFont(context, 14), fontWeight: FontWeight.w600, color: _kTextPrimary, decoration: TextDecoration.none)),
                            SizedBox(height: scaleSize(context, 2)),
                            Text(_l10n(context, 'reportErrorSubtitle'), style: GoogleFonts.plusJakartaSans(fontSize: scaleFont(context, 12), color: _kTextSecondary, decoration: TextDecoration.none)),
                          ],
                        ),
                      ),
                      Icon(Icons.arrow_forward_ios, size: scaleSize(context, 14), color: _kTextSecondary),
                    ],
                  ),
                ),
              ),
            ),
            SizedBox(height: scaleSize(context, 12)),
            Material(
              color: Colors.transparent,
              child: InkWell(
                onTap: _launchSuggestionEmail,
                borderRadius: BorderRadius.circular(scaleSize(context, 12)),
                child: Padding(
                  padding: EdgeInsets.symmetric(vertical: scaleSize(context, 12), horizontal: scaleSize(context, 4)),
                  child: Row(
                    children: [
                      Icon(Icons.lightbulb_outline_rounded, size: scaleSize(context, 22), color: _kAccent),
                      SizedBox(width: scaleSize(context, 12)),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(_l10n(context, 'suggestFeature'), style: GoogleFonts.plusJakartaSans(fontSize: scaleFont(context, 14), fontWeight: FontWeight.w600, color: _kTextPrimary, decoration: TextDecoration.none)),
                            SizedBox(height: scaleSize(context, 2)),
                            Text(_l10n(context, 'suggestFeatureSubtitle'), style: GoogleFonts.plusJakartaSans(fontSize: scaleFont(context, 12), color: _kTextSecondary, decoration: TextDecoration.none)),
                          ],
                        ),
                      ),
                      Icon(Icons.arrow_forward_ios, size: scaleSize(context, 14), color: _kTextSecondary),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _helpItem(String q, String a) {
    return Padding(
      padding: EdgeInsets.only(bottom: scaleSize(context, 18)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(q, style: GoogleFonts.plusJakartaSans(fontSize: scaleFont(context, 13), fontWeight: FontWeight.w600, color: _kTextPrimary, decoration: TextDecoration.none)),
          SizedBox(height: scaleSize(context, 6)),
          Text(a, style: GoogleFonts.plusJakartaSans(fontSize: scaleFont(context, 12), color: _kTextSecondary, height: 1.55, decoration: TextDecoration.none)),
        ],
      ),
    );
  }

  /// Opens the default email client with pre-filled subject and body for error reporting.
  /// Subject and body use the app language (l10n); suggests attaching a screenshot.
  Future<void> _launchErrorReportEmail() async {
    final subject = _l10n(context, 'errorReportSubject');
    final intro = _l10n(context, 'errorReportBodyIntro').replaceAll('{version}', appVersionName);
    final describe = _l10n(context, 'errorReportBodyDescribe');
    final screenshotHint = _l10n(context, 'errorReportScreenshotHint');
    final body = '$intro\n\n$describe\n\n$screenshotHint\n\n';
    final uri = Uri.parse(
      'mailto:$_supportEmail?subject=${Uri.encodeComponent(subject)}&body=${Uri.encodeComponent(body)}',
    );
    try {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(_l10n(context, 'error') + ': ' + 'Could not open email app')),
        );
      }
    }
  }

  /// Opens email for suggestions, feature requests, or other contributions (same address, different subject/body).
  Future<void> _launchSuggestionEmail() async {
    final subject = _l10n(context, 'suggestionEmailSubject');
    final intro = _l10n(context, 'suggestionEmailBodyIntro').replaceAll('{version}', appVersionName);
    final describe = _l10n(context, 'suggestionEmailBodyDescribe');
    final screenshotHint = _l10n(context, 'suggestionEmailScreenshotHint');
    final body = '$intro\n\n$describe\n\n$screenshotHint\n\n';
    final uri = Uri.parse(
      'mailto:$_supportEmail?subject=${Uri.encodeComponent(subject)}&body=${Uri.encodeComponent(body)}',
    );
    try {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(_l10n(context, 'error') + ': ' + 'Could not open email app')),
        );
      }
    }
  }

  /// Same as RN handleLocationSelected: save to user_city_location (legacy), update @app_cities first city, emit MainLocationUpdated.
  Future<void> _handleLocationSelected(double lat, double lng, dynamic name, Map<String, dynamic>? meta) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(userCityLocationKey, jsonEncode({
        'latitude': lat,
        'longitude': lng,
        'name': name,
      }));

      Map<String, dynamic> nameObj;
      if (name is Map) {
        nameObj = Map<String, dynamic>.from(name);
      } else {
        final locale = context.read<ThemeProvider>().language;
        final fetched = await getLocationName(lat, lng, locale);
        nameObj = fetched ?? {'city': name?.toString() ?? 'Unknown', 'country': null};
      }

      final admin = meta?['admin'] as Map<String, dynamic>? ?? {
        'province': nameObj['state'],
        'district': nameObj['district'],
        'country': nameObj['country'],
        'countryCode': nameObj['countryCode'],
      };

      final cc = (admin['countryCode'] as String?)?.toString().toUpperCase();
      final country = (admin['country'] as String?)?.toString().toLowerCase();
      final isTurkey = cc == 'TR' || cc == 'TUR' || country == 'turkey' || country == 'türkiye' || country == 'turkiye';
      final defaults = await CountryCalculationService.getCountryDefaultsForLocation(admin);
      final city = {
        'location': {'latitude': lat, 'longitude': lng},
        'name': nameObj,
        'admin': admin,
        'timezone': null,
        'calculationMethod': isTurkey ? 13 : (defaults?.methodId ?? _selectedCalculationMethod),
        'madhab': isTurkey ? 'hanafi' : (defaults?.madhab ?? _selectedMadhab),
      };

      await context.read<LocationProvider>().setMainLocation(city);
      await _loadSettings();
      if (mounted) {
        setState(() => _showLocationModal = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(_l10n(context, 'locationUpdated'))),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('${_l10n(context, 'error')}: $e')),
        );
      }
    }
  }

  Widget _locationModal() {
    return LocationInputModal(
      visible: _showLocationModal,
      onClose: () => setState(() => _showLocationModal = false),
      onLocationSelected: _handleLocationSelected,
    );
  }

  // ── Design tokens matching LocationInputModal ──────────────────────────────
  static const _kRadius     = 28.0;
  static const _kSurface    = Color(0xE6FFFFFF);
  static const _kTextPrimary   = Color(0xFF0F172A);
  static const _kTextSecondary = Color(0xFF64748B);
  static const _kAccent     = Color(0xFF6366F1);

  /// Frosted-glass centered modal — same identity as LocationInputModal.
  /// [maxHeightFactor] controls maximum height as a fraction of screen height.
  Widget _modalBottom({
    required String title,
    required VoidCallback onClose,
    required Widget child,
    double maxHeightFactor = 0.72,
  }) {
    final screenSize = MediaQuery.of(context).size;

    return Stack(
      children: [
        // ── Blurred backdrop ──────────────────────────────────────────────
        GestureDetector(
          onTap: onClose,
          behavior: HitTestBehavior.opaque,
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 8, sigmaY: 8),
            child: Container(color: Colors.black38),
          ),
        ),
        // ── Frosted-glass dialog ──────────────────────────────────────────
        Center(
          child: GestureDetector(
            onTap: () {},
            child: ClipRRect(
              borderRadius: BorderRadius.circular(scaleSize(context, _kRadius)),
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
                child: Container(
                  width: (screenSize.width * 0.88).clamp(0.0, scaleSize(context, 420)),
                  constraints: BoxConstraints(
                    maxHeight: screenSize.height * maxHeightFactor,
                  ),
                  decoration: BoxDecoration(
                    color: _kSurface,
                    borderRadius: BorderRadius.circular(scaleSize(context, _kRadius)),
                    border: Border.all(
                      color: Colors.white.withValues(alpha: 0.5),
                      width: scaleSize(context, 1.5),
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.08),
                        blurRadius: scaleSize(context, 32),
                        offset: Offset(0, scaleSize(context, 12)),
                      ),
                      BoxShadow(
                        color: _kAccent.withValues(alpha: 0.06),
                        blurRadius: scaleSize(context, 24),
                        spreadRadius: scaleSize(context, -4),
                        offset: Offset(0, scaleSize(context, 4)),
                      ),
                    ],
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // ── Header ─────────────────────────────────────────
                      Padding(
                        padding: EdgeInsets.fromLTRB(scaleSize(context, 24), scaleSize(context, 22), scaleSize(context, 8), scaleSize(context, 14)),
                        child: Row(
                          children: [
                            Expanded(
                              child: Text(
                                title,
                                style: GoogleFonts.plusJakartaSans(
                                  fontSize: scaleFont(context, 20),
                                  fontWeight: FontWeight.w600,
                                  color: _kTextPrimary,
                                  letterSpacing: -0.3,
                                  decoration: TextDecoration.none,
                                ),
                              ),
                            ),
                            Material(
                              color: Colors.transparent,
                              child: InkWell(
                                onTap: onClose,
                                borderRadius: BorderRadius.circular(scaleSize(context, 12)),
                                child: Padding(
                                  padding: EdgeInsets.all(scaleSize(context, 8)),
                                  child: Icon(Icons.close_rounded,
                                      size: scaleSize(context, 26), color: _kTextSecondary),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      // ── Scrollable content (no divider for cleaner look) ──
                      Flexible(child: child),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildHeader() {
    final logoSize = scaleSize(context, 190); // öncekinin yarısı (264/2)
    final headerHeight = scaleSize(context, 88); // logo için yeterli yükseklik
    return Container(
      padding: EdgeInsets.fromLTRB(scaleSize(context, 16), scaleSize(context, 14), scaleSize(context, 16), scaleSize(context, 14)),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(bottom: Radius.circular(scaleSize(context, 24))),
      ),
      child: SizedBox(
        height: headerHeight,
        child: Row(
          children: [
            Expanded(
              child: Align(
                alignment: Alignment.centerLeft,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(_l10n(context, 'settings'), style: GoogleFonts.plusJakartaSans(fontSize: scaleFont(context, 24), fontWeight: FontWeight.bold, color: const Color(0xFF1E293B))),
                    SizedBox(height: scaleSize(context, 4)),
                    Text(_l10n(context, 'preferencesSubtitle'), style: GoogleFonts.plusJakartaSans(fontSize: scaleFont(context, 15), color: const Color(0xFF64748B), fontWeight: FontWeight.w400)),
                  ],
                ),
              ),
            ),
            FadeTransition(
              opacity: _logoOpacity,
              child: SizedBox(
                width: logoSize,
                height: logoSize,
                child: Image.asset('assets/nida.png', fit: BoxFit.contain),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSection(String title, Widget child) {
    return Container(
      margin: EdgeInsets.fromLTRB(scaleSize(context, 20), scaleSize(context, 20), scaleSize(context, 20), 0),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(scaleSize(context, 16)),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: scaleSize(context, 8), offset: Offset(0, scaleSize(context, 2)))],
      ),
      padding: EdgeInsets.all(scaleSize(context, 16)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: GoogleFonts.plusJakartaSans(fontSize: scaleFont(context, 16), fontWeight: FontWeight.w600, color: const Color(0xFF1E293B))),
          child,
        ],
      ),
    );
  }

  Widget _buildTimeFormatSection() {
    return Padding(
      padding: EdgeInsets.only(top: scaleSize(context, 12)),
      child: Row(
        children: [
          Container(
            width: scaleSize(context, 40),
            height: scaleSize(context, 40),
            decoration: BoxDecoration(color: const Color(0xFFEEF2FF), borderRadius: BorderRadius.circular(scaleSize(context, 20))),
            child: Center(child: Image.asset(_SettingsIcons.timeFormat, width: scaleSize(context, 22), height: scaleSize(context, 22), fit: BoxFit.contain)),
          ),
          SizedBox(width: scaleSize(context, 12)),
          Expanded(child: Text(_l10n(context, 'timeFormat'), style: GoogleFonts.plusJakartaSans(fontSize: scaleFont(context, 15), fontWeight: FontWeight.w500, color: const Color(0xFF1E293B)))),
          Container(
            decoration: BoxDecoration(color: const Color(0xFFF1F5F9), borderRadius: BorderRadius.circular(scaleSize(context, 16)), border: null),
            padding: EdgeInsets.all(scaleSize(context, 2)),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                _segmentedOption('12H', _timeFormat == '12', () => _saveTimeFormat('12')),
                _segmentedOption('24H', _timeFormat == '24', () => _saveTimeFormat('24')),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _segmentedOption(String label, bool active, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: EdgeInsets.symmetric(vertical: scaleSize(context, 6), horizontal: scaleSize(context, 12)),
        decoration: BoxDecoration(
          color: active ? const Color(0xFF6366F1) : Colors.transparent,
          borderRadius: BorderRadius.circular(scaleSize(context, 16)),
        ),
        child: Text(
          label,
          style: GoogleFonts.plusJakartaSans(
            fontSize: scaleFont(context, 11),
            fontWeight: active ? FontWeight.w600 : FontWeight.w500,
            color: active ? Colors.white : const Color(0xFF6366F1),
          ),
        ),
      ),
    );
  }

  Widget _buildLanguageItem() {
    final langs = _getLanguages(context);
    final current = langs.firstWhere((l) => l['code'] == _selectedLanguage, orElse: () => langs.first);
    return _settingItem(
      iconImage: _SettingsIcons.language,
      title: _l10n(context, 'languageSelection'),
      onTap: () => setState(() => _showLanguageModal = true),
      right: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text('${current['flag']} ${current['name']}', style: GoogleFonts.plusJakartaSans(fontSize: scaleFont(context, 13), fontWeight: FontWeight.w500, color: const Color(0xFF6366F1))),
          SizedBox(width: scaleSize(context, 8)),
          Icon(Icons.chevron_right, size: scaleSize(context, 20), color: const Color(0xFF94A3B8)),
        ],
      ),
    );
  }

  Widget _buildNotificationsSection() {
    return Column(
      children: [
        _settingItem(
          iconImage: _SettingsIcons.prayerNotifications,
          title: _l10n(context, 'prayerTimeNotifications'),
          subtitle: _l10n(context, 'prayerTimeNotificationsSubtitle'),
          right: Stack(
            alignment: Alignment.center,
            children: [
              if (_notificationLoading)
                Container(
                  padding: EdgeInsets.symmetric(horizontal: scaleSize(context, 16), vertical: scaleSize(context, 8)),
                  decoration: BoxDecoration(color: const Color(0xFF6366F1).withValues(alpha: 0.9), borderRadius: BorderRadius.circular(scaleSize(context, 8))),
                  child: Text(_l10n(context, 'enabling'), style: GoogleFonts.plusJakartaSans(color: Colors.white, fontSize: scaleFont(context, 11), fontWeight: FontWeight.w600)),
                ),
              Switch(
                value: _notificationsEnabled,
                onChanged: (v) async {
                  if (!v) {
                    setState(() => _notificationsEnabled = false);
                    return;
                  }
                  setState(() {
                    _notificationLoading = true;
                    _notificationsEnabled = true;
                  });
                  final granted = await AppPermissionService.requestNotification();
                  if (!mounted) return;
                  setState(() => _notificationLoading = false);
                  if (granted) {
                    if (mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text(_l10n(context, 'success'))),
                      );
                    }
                  } else {
                    setState(() => _notificationsEnabled = false);
                    if (mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(_l10n(context, 'notificationPermissionRequired')),
                          action: SnackBarAction(
                            label: _l10n(context, 'openSettings'),
                            onPressed: () => AppPermissionService.openSettings(),
                          ),
                        ),
                      );
                    }
                  }
                },
                activeTrackColor: const Color(0xFF6366F1),
              ),
            ],
          ),
        ),
        _settingItem(
          iconImage: _SettingsIcons.ezanSound,
          title: _l10n(context, 'ezanSound'),
          subtitle: _l10n(context, 'ezanSoundSubtitle'),
          right: Switch(
            value: _ezanSoundEnabled,
            onChanged: (v) => _saveEzanSound(v),
            activeTrackColor: const Color(0xFF6366F1),
          ),
        ),
      ],
    );
  }

  Widget _buildOtherSection(List<Map<String, dynamic>> settingsCities) {
    final singleCity = settingsCities.length <= 1 && settingsCities.isNotEmpty ? settingsCities.first : null;
    final methodId = singleCity != null ? (singleCity['calculationMethod'] as int?) ?? 2 : _selectedCalculationMethod;
    final madhabId = singleCity != null ? (singleCity['madhab'] as String?) ?? 'standard' : _selectedMadhab;
    final methodName = _getCalculationMethodName(methodId);
    final madhabName = _getMadhabDisplayName(context, madhabId);
    return Column(
      children: [
        _settingItem(
          iconImage: _SettingsIcons.location,
          title: _l10n(context, 'locationSettings'),
          subtitle: _l10n(context, 'locationSettingsSubtitle'),
          onTap: () async {
            await AppPermissionService.requestLocation();
            if (mounted) setState(() => _showLocationModal = true);
          },
        ),
        if (settingsCities.length <= 1) ...[
          _settingItem(
            iconImage: _SettingsIcons.calculationMethod,
            iconSize: 28,
            title: _l10n(context, 'calculationMethod'),
            subtitle: methodName,
            subtitleColor: const Color(0xFF6366F1),
            onTap: _isTurkeyUser ? null : () => _showCalculationMethodDialog(),
            disabled: _isTurkeyUser,
            right: _isTurkeyUser ? Icon(Icons.lock, size: scaleSize(context, 18), color: const Color(0xFF94A3B8)) : null,
          ),
          _settingItem(
            icon: Icons.access_time, // RN: Ionicons "time-outline"
            title: _l10n(context, 'madhabAsr'),
            subtitle: madhabName,
            subtitleColor: const Color(0xFF6366F1),
            onTap: _isTurkeyUser ? null : () => _showMadhabDialog(),
            disabled: _isTurkeyUser,
            right: _isTurkeyUser ? Icon(Icons.lock, size: scaleSize(context, 18), color: const Color(0xFF94A3B8)) : null,
          ),
        ],
        _settingItem(iconImage: _SettingsIcons.about, title: _l10n(context, 'about'), subtitle: _l10n(context, 'aboutSubtitle'), onTap: () => setState(() => _showAboutModal = true)),
        _settingItem(iconImage: _SettingsIcons.helpSupport, title: _l10n(context, 'helpSupport'), subtitle: _l10n(context, 'helpSupportSubtitle'), onTap: () => setState(() => _showHelpModal = true)),
      ],
    );
  }

  String _getCalculationMethodName(int methodId) {
    for (final m in _calculationMethods) {
      if (m['id'] as int == methodId) return m['name'] as String;
    }
    return 'ISNA';
  }

  String _getMadhabDisplayName(BuildContext context, String madhab) {
    final id = madhab == 'hanafi' ? 'hanafi' : 'standard';
    final list = _getMadhabOptions(context);
    return list.firstWhere((m) => m['id'] == id, orElse: () => list.first)['name']!;
  }

  /// RN: admin.countryCode === 'TR' | 'TUR' or country Turkey/Türkiye/Turkiye → Diyanet (R2), disabled.
  bool _isCityTurkey(Map<String, dynamic>? city) {
    if (city == null) return false;
    final admin = city['admin'] as Map<String, dynamic>?;
    final cc = (admin?['countryCode'] as String?)?.toUpperCase();
    final country = (admin?['country'] as String?)?.toLowerCase();
    if (cc == 'TR' || cc == 'TUR') return true;
    if (country == 'turkey' || country == 'türkiye' || country == 'turkiye') return true;
    return false;
  }

  static const String _diyanetLabel = 'Diyanet (R2)';

  Widget _buildCalculationPerCity(List<Map<String, dynamic>> cities) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: cities.asMap().entries.map((e) {
        final i = e.key;
        final city = e.value;
        final name = _getCityDisplayName(context, city);
        final isCityTurkey = _isCityTurkey(city);
        final methodId = (city['calculationMethod'] as int?) ?? _selectedCalculationMethod;
        final madhab = (city['madhab'] as String?) ?? _selectedMadhab;
        final methodName = isCityTurkey ? _diyanetLabel : _getCalculationMethodName(methodId);
        final madhabName = isCityTurkey ? _diyanetLabel : _getMadhabDisplayName(context, madhab);
        return Padding(
          padding: EdgeInsets.only(bottom: i == cities.length - 1 ? 0 : scaleSize(context, 16)),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: EdgeInsets.only(left: scaleSize(context, 4), bottom: scaleSize(context, 8)),
                child: Text(name, style: GoogleFonts.plusJakartaSans(fontSize: scaleFont(context, 14), fontWeight: FontWeight.w600, color: const Color(0xFF6366F1))),
              ),
              _settingItem(
                icon: Icons.calculate,
                title: _l10n(context, 'calculationMethod'),
                subtitle: methodName,
                subtitleColor: const Color(0xFF6366F1),
                onTap: isCityTurkey ? null : () => _showCalculationMethodDialog(cityIndex: i),
                disabled: isCityTurkey,
                right: isCityTurkey ? Icon(Icons.lock, size: scaleSize(context, 18), color: const Color(0xFF94A3B8)) : null,
              ),
              _settingItem(
                icon: Icons.access_time,
                title: _l10n(context, 'madhabAsr'),
                subtitle: madhabName,
                subtitleColor: const Color(0xFF6366F1),
                onTap: isCityTurkey ? null : () => _showMadhabDialog(cityIndex: i),
                disabled: isCityTurkey,
                right: isCityTurkey ? Icon(Icons.lock, size: scaleSize(context, 18), color: const Color(0xFF94A3B8)) : null,
              ),
            ],
          ),
        );
      }).toList(),
    );
  }

  Widget _settingItem({
    String? iconImage,
    double iconSize = 20,
    IconData? icon,
    required String title,
    String? subtitle,
    Color? subtitleColor,
    VoidCallback? onTap,
    Widget? right,
    bool disabled = false,
  }) {
    final effectiveSubtitleColor = subtitleColor ?? const Color(0xFF64748B);
    return Opacity(
      opacity: disabled ? 0.6 : 1,
      child: InkWell(
        onTap: disabled ? null : onTap,
        child: Padding(
          padding: EdgeInsets.symmetric(vertical: scaleSize(context, 12)),
          child: Row(
            children: [
              Container(
                width: scaleSize(context, 40),
                height: scaleSize(context, 40),
                decoration: BoxDecoration(color: const Color(0xFFEEF2FF), borderRadius: BorderRadius.circular(scaleSize(context, 20))),
                child: Center(
                  child: iconImage != null
                      ? Image.asset(iconImage, width: scaleSize(context, iconSize), height: scaleSize(context, iconSize), fit: BoxFit.contain)
                      : Icon(icon ?? Icons.settings, size: scaleSize(context, 22), color: const Color(0xFF6366F1)),
                ),
              ),
              SizedBox(width: scaleSize(context, 12)),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(title, style: GoogleFonts.plusJakartaSans(fontSize: scaleFont(context, 15), fontWeight: FontWeight.w500, color: const Color(0xFF1E293B))),
                    if (subtitle != null) Text(subtitle, style: GoogleFonts.plusJakartaSans(fontSize: scaleFont(context, 12), color: effectiveSubtitleColor, fontWeight: FontWeight.w400)),
                  ],
                ),
              ),
              if (right != null) right else Icon(Icons.chevron_right, size: scaleSize(context, 22), color: const Color(0xFF94A3B8)),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildVersionFooter() {
    return Padding(
      padding: EdgeInsets.symmetric(vertical: scaleSize(context, 32)),
      child: Column(
        children: [
          Text('Nida Adhan v$appVersionName', style: GoogleFonts.plusJakartaSans(fontSize: scaleFont(context, 13), color: const Color(0xFF64748B), fontWeight: FontWeight.w500)),
          SizedBox(height: scaleSize(context, 4)),
          Text(_l10n(context, 'copyright'), style: GoogleFonts.plusJakartaSans(fontSize: scaleFont(context, 11), color: const Color(0xFF94A3B8), fontWeight: FontWeight.w400)),
        ],
      ),
    );
  }
}
