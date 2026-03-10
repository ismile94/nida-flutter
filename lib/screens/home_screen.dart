import 'dart:async';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../contexts/navigation_bar_provider.dart';
import '../contexts/location_provider.dart';
import '../contexts/theme_provider.dart';
import '../l10n/app_localizations.dart';
import '../services/country_calculation_service.dart';
import '../services/location_service.dart';
import '../services/mood_tracker_service.dart';
import '../services/prayer_times_service.dart';
import 'package:hijri/hijri_calendar.dart';
import '../utils/date_format_utils.dart';
import '../utils/scaling.dart';
import '../widgets/home_header.dart';
import '../widgets/location_input_modal.dart';
import '../widgets/prayer_time_card.dart';
import '../widgets/home_content_cards.dart';
import '../widgets/prayer_orbit_widget.dart' show PrayerOrbitWidget, kOrbitContainerRadius;
import '../widgets/sun_moon_bar.dart';
import '../widgets/alarm_settings_modal.dart';
import '../widgets/prayer_calendar_modal.dart';
import '../services/alarm_settings_service.dart';
import '../services/notification_service.dart';
import '../services/persistent_notification_service.dart';
import '../services/app_permission_service.dart';

/// Homepage matching the React Native HomeScreen layout and design.
/// Header: swipeable city pages + "Add City" (up to 3 cities).
class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final PageController _pageController = PageController(initialPage: 0);
  /// Controls the orbit ↔ prayer-cards swipeable view.
  // Even million → starts at orbit (0 % 2 == 0); ~500k rounds in each direction.
  static const int _kOrbitInitPage = 1000000;
  final PageController _orbitPageController = PageController(initialPage: _kOrbitInitPage);
  int _orbitPageIndex = 0;

  // ── Mood tracking ─────────────────────────────────────────────────────────
  Map<String, String> _todayMoods = {};
  /// Prayer key currently awaiting a mood check (drives the popup).
  String? _activeMoodPrayerKey;
  Timer? _moodCheckTimer;

  // ── Countdown timer ────────────────────────────────────────────────────────
  Timer? _countdownTimer;

  bool _showLocationModal = false;
  bool _showAlarmModal = false;
  bool _showCalendar = false;
  /// Konum değişikliği bu oturumda kontrol edildi mi (izin varsa her girişte bir kez).
  bool _locationChangeCheckDone = false;
  /// Tespit edilen yeni konum; diyalog gösterilip güncelle/oldüğu gibi kalsın seçeneği sunulacak.
  _PendingLocationUpdate? _pendingLocationUpdate;
  bool _didScheduleLocationChangeDialog = false;
  bool _persistentNotificationEnabled = true;
  bool _syncedInitialPage = false;
  bool _loading = true;
  /// 'add' = Add City (extra city); 'replaceOrFirst' = no location / set first location
  String? _locationModalIntent;
  /// Prayer times for the currently selected city (that city's calculation method & madhab).
  PrayerTimesResult? _prayerTimes;
  /// Tomorrow's times for scheduling alarms after midnight.
  PrayerTimesResult? _tomorrowPrayerTimes;
  int? _lastLoadedCityIndex;
  int? _lastPrayerTimesDataVersion;

  /// Returns the key of the most recently passed prayer (mirrors RN currentPrayerTime memo).
  static String _computeCurrentPrayerTime(PrayerTimesResult times) {
    final now = DateTime.now();
    final nowMins = now.hour * 60 + now.minute;
    final prayers = [
      ('fajr', times.fajr),
      ('dhuhr', times.dhuhr),
      ('asr', times.asr),
      ('maghrib', times.maghrib),
      ('isha', times.isha),
    ];
    String last = 'fajr';
    for (final (key, time) in prayers) {
      final parts = time.split(':');
      if (parts.length < 2) continue;
      final pMins = int.parse(parts[0]) * 60 + int.parse(parts[1]);
      if (nowMins >= pMins) last = key;
    }
    return last;
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      context.read<NavigationBarProvider>().setVisible(true);
      final loc = context.read<LocationProvider>();
      await loc.loadFromStorage();
      if (!mounted) return;
      // Uygulama ilk açıldığında hep ilk lokasyon (current) ve ilk nokta seçili olsun.
      if (loc.hasCities) {
        loc.setSelectedCityIndex(0);
        if (_pageController.hasClients) _pageController.jumpToPage(0);
      }
      _syncPageToSelectedCity();
      final hasCities = loc.hasCities;
      if (!mounted) return;
      setState(() {
        _loading = false;
        if (!hasCities) {
          _showLocationModal = true;
          _locationModalIntent = 'replaceOrFirst';
        }
      });
      // Load moods and start periodic check.
      _loadMoods();
      // Load persistent notification preference
      final settings = await AlarmSettingsService.load();
      if (mounted) {
        setState(() => _persistentNotificationEnabled =
            settings['persistentNotificationEnabled'] != false);
      }
      _moodCheckTimer = Timer.periodic(const Duration(seconds: 30), (_) => _checkMood());
      // Tick every second to keep the countdown display up-to-date.
      _countdownTimer = Timer.periodic(const Duration(seconds: 1), (_) {
        if (mounted) setState(() {});
      });
      // İzin varsa her girişte konum bir kez kontrol edilir; şehir/kasaba farklıysa güncelleme teklifi gösterilir.
      if (hasCities) _checkLocationChange();
    });
  }

  /// getLocationName sonucundan header ile karşılaştırılacak kısa isim (şehir/kasaba/ilçe).
  static String _displayNameFromNameObj(Map<String, dynamic>? nameObj) {
    if (nameObj == null) return '';
    final v = nameObj['city'] ?? nameObj['district'] ?? nameObj['state'] ?? nameObj['country'];
    return v?.toString().trim() ?? '';
  }

  /// Konum izni varsa mevcut GPS konumunu al, reverse geocode yap; header'daki "current" ile aynı değilse güncelleme teklifi göster.
  Future<void> _checkLocationChange() async {
    if (_locationChangeCheckDone || !mounted) return;
    final granted = await AppPermissionService.isLocationGranted();
    if (!granted || !mounted) return;
    final result = await getCurrentLocation();
    if (!result.success || result.latitude == null || result.longitude == null || !mounted) return;
    final loc = context.read<LocationProvider>();
    if (!loc.hasCities) return;
    final locale = context.read<ThemeProvider>().language;
    final nameMap = await getLocationName(result.latitude!, result.longitude!, locale);
    if (nameMap == null || !mounted) return;
    final newDisplayName = _displayNameFromNameObj(nameMap);
    if (newDisplayName.isEmpty) return;
    final currentDisplayName = LocationProvider.getCityDisplayName(loc.cities[0], '').trim();
    final normalizedNew = newDisplayName.toLowerCase();
    final normalizedCurrent = currentDisplayName.toLowerCase();
    if (normalizedNew == normalizedCurrent) return;
    _locationChangeCheckDone = true;
    final admin = {
      'province': nameMap['state'],
      'district': nameMap['district'],
      'country': nameMap['country'],
      'countryCode': nameMap['countryCode'],
    };
    if (!mounted) return;
    setState(() {
      _pendingLocationUpdate = _PendingLocationUpdate(
        lat: result.latitude!,
        lng: result.longitude!,
        nameObj: nameMap,
        admin: admin,
        displayName: newDisplayName,
      );
    });
  }

  void _showLocationChangeDialog(BuildContext context, _PendingLocationUpdate p) {
    String t(String key) => AppLocalizations.t(context, key);
    final message = t('locationChangedPrompt').replaceAll('{place}', p.displayName);
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(t('location')),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: Text(t('keepCurrentLocation')),
          ),
          FilledButton(
            onPressed: () async {
              Navigator.of(ctx).pop();
              await _applyLocationUpdate(p);
            },
            child: Text(t('updateLocation')),
          ),
        ],
      ),
    );
  }

  /// Kullanıcı "Güncelle" dediğinde: main location'ı yeni konumla güncelle, ezan vakitlerini yenile.
  Future<void> _applyLocationUpdate(_PendingLocationUpdate p) async {
    try {
      final isTurkey = _isCityTurkey(p.admin);
      final defaults = await CountryCalculationService.getCountryDefaultsForLocation(p.admin);
      final city = {
        'location': {'latitude': p.lat, 'longitude': p.lng},
        'name': p.nameObj,
        'admin': p.admin,
        'timezone': null,
        'calculationMethod': isTurkey ? 13 : (defaults?.methodId ?? 2),
        'madhab': isTurkey ? 'hanafi' : (defaults?.madhab ?? 'standard'),
      };
      await context.read<LocationProvider>().setMainLocation(city);
      if (!mounted) return;
      _lastLoadedCityIndex = null;
      await _loadPrayerTimesForSelectedCity(context);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(AppLocalizations.t(context, 'locationUpdated'))),
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('${AppLocalizations.t(context, 'error')}: $e')),
        );
      }
    }
  }

  Future<void> _loadMoods() async {
    final moods = await MoodTrackerService.getTodayMoods();
    if (!mounted) return;
    setState(() => _todayMoods = moods);
    _checkMood();
  }

  Future<void> _checkMood() async {
    if (_prayerTimes == null) return;
    final times = {
      'fajr':    _prayerTimes!.fajr,
      'dhuhr':   _prayerTimes!.dhuhr,
      'asr':     _prayerTimes!.asr,
      'maghrib': _prayerTimes!.maghrib,
      'isha':    _prayerTimes!.isha,
    };
    final key = await MoodTrackerService.getNextUncheckedPrayer(times);
    if (!mounted) return;
    if (key != _activeMoodPrayerKey) {
      setState(() => _activeMoodPrayerKey = key);
    }
  }

  Future<void> _saveMood(String mood) async {
    if (_activeMoodPrayerKey == null) return;
    final key = _activeMoodPrayerKey!;
    await MoodTrackerService.saveMood(key, mood);
    final moods = await MoodTrackerService.getTodayMoods();
    if (!mounted) return;
    setState(() {
      _todayMoods = moods;
      _activeMoodPrayerKey = null;
    });
  }

  void _syncPageToSelectedCity() {
    if (_syncedInitialPage || !mounted) return;
    final loc = context.read<LocationProvider>();
    if (!loc.hasCities) return;
    final index = loc.selectedCityIndex.clamp(0, loc.cities.length - 1);
    if (index == 0) return;
    _syncedInitialPage = true;
    if (_pageController.hasClients) {
      _pageController.jumpToPage(index);
    }
  }

  /// Load prayer times for the currently selected city (its location + calculation method + madhab).
  Future<void> _loadPrayerTimesForSelectedCity(BuildContext context) async {
    final loc = context.read<LocationProvider>();
    if (!loc.hasCities) return;
    final index = loc.selectedCityIndex.clamp(0, loc.cities.length - 1);
    if (index == _lastLoadedCityIndex && _prayerTimes != null) return;
    final city = loc.cities[index];
    final locMap = city['location'] as Map<String, dynamic>?;
    if (locMap == null) return;
    final lat = (locMap['latitude'] as num?)?.toDouble();
    final lng = (locMap['longitude'] as num?)?.toDouble();
    if (lat == null || lng == null) return;
    final admin = city['admin'] as Map<String, dynamic>?;
    final isTurkey = _isCityTurkey(admin);
    int method = (city['calculationMethod'] as int?) ?? 2;
    String madhab = (city['madhab'] as String?) ?? 'standard';
    // Persistent notification / prayer flow: no logging (per request).
    if (isTurkey) {
      method = 13;
      madhab = 'hanafi';
    } else if (method == 13) {
      final defaults = await CountryCalculationService.getCountryDefaultsForLocation(admin);
      if (defaults != null) {
        method = defaults.methodId;
        madhab = defaults.madhab;
      } else {
        method = 2;
      }
    }
    final (today, tomorrow) = await getPrayerTimesTodayAndTomorrow(
      latitude: lat,
      longitude: lng,
      method: method,
      madhab: madhab,
      admin: admin,
    );
    if (!mounted) return;
    setState(() {
      _prayerTimes = today;
      _tomorrowPrayerTimes = tomorrow;
      _lastLoadedCityIndex = index;
    });
    // Reload moods whenever prayer times update (city changed etc.)
    _loadMoods();
    // Reschedule prayer alarms (today + tomorrow so they fire after midnight)
    _scheduleNotifications(today, tomorrow);
    if (mounted) _refreshPersistentNotification(context);
  }

  void _refreshPersistentNotification(BuildContext context) {
    if (!_persistentNotificationEnabled) {
      PersistentNotificationService.stop();
      return;
    }
    if (_prayerTimes == null) return;
    final loc = context.read<LocationProvider>();
    if (!loc.hasCities) return;
    final cityName = loc.selectedCityIndex < loc.cities.length
        ? LocationProvider.getCityDisplayName(
            loc.cities[loc.selectedCityIndex],
            AppLocalizations.t(context, 'locationLoading'))
        : AppLocalizations.t(context, 'prayerTimes');
    String locKey(String k) => AppLocalizations.t(context, k);
    PersistentNotificationService.startUpdateTimer(
      times: _prayerTimes!,
      locationName: cityName,
      localize: locKey,
      appTitle: AppLocalizations.t(context, 'appName'),
    );
  }

  Future<void> _scheduleNotifications(PrayerTimesResult today, [PrayerTimesResult? tomorrow]) async {
    if (!mounted) return;
    final loc = context.read<LocationProvider>();
    final cityName = loc.hasCities && loc.selectedCityIndex < loc.cities.length
        ? LocationProvider.getCityDisplayName(
            loc.cities[loc.selectedCityIndex],
            AppLocalizations.t(context, 'locationLoading'))
        : '';
    final localize = (String k) => AppLocalizations.t(context, k);
    await NotificationService.requestPermission();
    if (!mounted) return;
    await NotificationService.schedulePrayerNotifications(
      today,
      cityName,
      tomorrow: tomorrow,
      localize: localize,
    );
  }

  @override
  void dispose() {
    _pageController.dispose();
    _orbitPageController.dispose();
    _moodCheckTimer?.cancel();
    _countdownTimer?.cancel();
    PersistentNotificationService.stop();
    super.dispose();
  }

  /// First location or replace main location (no permission / manual set). Same as RN handleLocationSelected when cities.length === 0 or replace.
  Future<void> _handleReplaceOrFirstLocationSelected(double lat, double lng, dynamic name, Map<String, dynamic>? meta) async {
    try {
      Map<String, dynamic> nameObj;
      if (name is Map) {
        nameObj = Map<String, dynamic>.from(name);
      } else {
        final locale = context.read<ThemeProvider>().language;
        final fetched = await getLocationName(lat, lng, locale);
        final fallbackCityName = _isCoordinateString(name?.toString())
            ? AppLocalizations.t(context, 'location')
            : (name?.toString() ?? 'Unknown');
        nameObj = fetched ?? {'city': fallbackCityName, 'country': null};
      }
      final admin = meta?['admin'] as Map<String, dynamic>? ?? {
        'province': nameObj['state'],
        'district': nameObj['district'],
        'country': nameObj['country'],
        'countryCode': nameObj['countryCode'],
      };
      final isTurkey = _isCityTurkey(admin);
      final defaults = await CountryCalculationService.getCountryDefaultsForLocation(admin);
      final city = {
        'location': {'latitude': lat, 'longitude': lng},
        'name': nameObj,
        'admin': admin,
        'timezone': null,
        'calculationMethod': isTurkey ? 13 : (defaults?.methodId ?? 2),
        'madhab': isTurkey ? 'hanafi' : (defaults?.madhab ?? 'standard'),
      };
      await context.read<LocationProvider>().setMainLocation(city);
      if (!mounted) return;
      setState(() {
        _showLocationModal = false;
        _locationModalIntent = null;
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(AppLocalizations.t(context, 'locationUpdated'))),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('${AppLocalizations.t(context, 'error')}: $e')),
        );
      }
    }
  }

  static bool _isCityTurkey(Map<String, dynamic>? admin) {
    if (admin == null) return false;
    final cc = (admin['countryCode'] as String?)?.toUpperCase();
    final country = (admin['country'] as String?)?.toLowerCase();
    return cc == 'TR' || cc == 'TUR' || country == 'turkey' || country == 'türkiye' || country == 'turkiye';
  }

  static bool _isCoordinateString(String? s) {
    if (s == null || s.length < 5) return false;
    return RegExp(r'^-?\d+[.,]\d+\s*,\s*-?\d+[.,]\d+$').hasMatch(s.trim());
  }

  Future<void> _handleAddCityLocationSelected(double lat, double lng, dynamic name, Map<String, dynamic>? meta) async {
    final loc = context.read<LocationProvider>();
    if (loc.cities.length >= 3) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(AppLocalizations.t(context, 'addCityError'))),
        );
      }
      return;
    }
    try {
      Map<String, dynamic> nameObj;
      if (name is Map) {
        nameObj = Map<String, dynamic>.from(name);
      } else {
        final locale = context.read<ThemeProvider>().language;
        final fetched = await getLocationName(lat, lng, locale);
        final fallbackCityName = _isCoordinateString(name?.toString())
            ? AppLocalizations.t(context, 'location')
            : (name?.toString() ?? 'Unknown');
        nameObj = fetched ?? {'city': fallbackCityName, 'country': null};
      }
      final admin = meta?['admin'] as Map<String, dynamic>? ?? {
        'province': nameObj['state'],
        'district': nameObj['district'],
        'country': nameObj['country'],
        'countryCode': nameObj['countryCode'],
      };
      final isTurkey = _isCityTurkey(admin);
      final defaults = await CountryCalculationService.getCountryDefaultsForLocation(admin);
      final city = {
        'location': {'latitude': lat, 'longitude': lng},
        'name': nameObj,
        'admin': admin,
        'timezone': null,
        'calculationMethod': isTurkey ? 13 : (defaults?.methodId ?? 2),
        'madhab': isTurkey ? 'hanafi' : (defaults?.madhab ?? 'standard'),
      };
      final added = await loc.addCity(city);
      if (!mounted) return;
      if (added && _pageController.hasClients) {
        _pageController.jumpToPage(loc.cities.length - 1);
      }
      setState(() {
        _showLocationModal = false;
        _locationModalIntent = null;
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(AppLocalizations.t(context, 'success'))),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('${AppLocalizations.t(context, 'error')}: $e')),
        );
      }
    }
  }

  void _openLocationModalForReplaceOrFirst() {
    setState(() {
      _showLocationModal = true;
      _locationModalIntent = 'replaceOrFirst';
    });
  }


  @override
  Widget build(BuildContext context) {
    final loc = context.watch<LocationProvider>();
    context.watch<ThemeProvider>(); // rebuild on language change
    final bottomPadding = MediaQuery.paddingOf(context).bottom + scaleSize(context, 80);
    String t(String key) => AppLocalizations.t(context, key);
    final cityNames = loc.cities
        .map((c) => LocationProvider.getCityDisplayName(c, t('locationLoading')))
        .toList();
    if (!_syncedInitialPage && loc.hasCities && loc.selectedCityIndex > 0) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _syncPageToSelectedCity());
    }
    if (loc.hasCities) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        final loc2 = context.read<LocationProvider>();
        if (loc2.prayerTimesDataVersion != _lastPrayerTimesDataVersion) {
          setState(() {
            _lastLoadedCityIndex = null;
            _lastPrayerTimesDataVersion = loc2.prayerTimesDataVersion;
          });
          WidgetsBinding.instance.addPostFrameCallback((_) => _loadPrayerTimesForSelectedCity(context));
          return;
        }
        _loadPrayerTimesForSelectedCity(context);
      });
    }

    // Konum değişti tespit edildiyse bir kez diyalog planla (build içinde state değiştirmemek için).
    if (_pendingLocationUpdate != null && !_didScheduleLocationChangeDialog) {
      _didScheduleLocationChangeDialog = true;
      final pending = _pendingLocationUpdate!;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        setState(() {
          _pendingLocationUpdate = null;
          _didScheduleLocationChangeDialog = false;
        });
        _showLocationChangeDialog(context, pending);
      });
    }

    if (_loading) {
      return Scaffold(
        backgroundColor: const Color(0xFFF8FAFC),
        body: SafeArea(
          top: true,
          child: Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const CircularProgressIndicator(color: Color(0xFF6366F1)),
                SizedBox(height: scaleSize(context, 12)),
                Text(
                  t('loading'),
                  style: GoogleFonts.cormorantGaramond(fontSize: scaleFont(context, 16), color: const Color(0xFF64748B)),
                ),
              ],
            ),
          ),
        ),
      );
    }

    final noLocation = !loc.hasCities;
    final times = _prayerTimes ?? PrayerTimesResult.fallback;
    // Always recalculate from the phone's current clock so the countdown ticks.
    final nextPrayer = getNextPrayer(times, DateTime.now());
    final nextPrayerLabel = '${t('nextPrayer')} ${t(nextPrayer.key)}';
    final nextPrayerTime = nextPrayer.remaining;
    final now = DateTime.now();
    final hijriDate = DateFormatUtils.formatHijriDate(now, context);
    final gregorianDate = DateFormatUtils.formatGregorianDate(now, context);
    final hijri = HijriCalendar.fromDate(now);
    final isRamadan = hijri.hMonth == 9;

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      body: SafeArea(
        top: true,
        child: Stack(
          children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                HomeHeader(
                  pageController: loc.hasCities ? _pageController : null,
                  cityNames: cityNames,
                  selectedCityIndex: loc.selectedCityIndex,
                  nextPrayerLabel: nextPrayerLabel,
                  nextPrayerTime: nextPrayerTime,
                  hijriDate: hijriDate,
                  gregorianDate: gregorianDate,
                  onPageChanged: loc.hasCities ? (index) => loc.setSelectedCityIndex(index) : null,
                  onAddCityTap: loc.cities.length < 3
                      ? () => setState(() {
                            _showLocationModal = true;
                            _locationModalIntent = 'add';
                          })
                      : null,
                  onRemoveCity: loc.cities.length > 1 ? (index) => loc.removeCity(index) : null,
                  addCityLabel: t('addCity'),
                  addCitySubtext: t('addCitySubtext'),
                  loadingText: t('locationLoading'),
                  onAlarmTap: () => setState(() => _showAlarmModal = true),
                  onCalendarTap: () => setState(() => _showCalendar = true),
                ),
                Expanded(
                  child: SingleChildScrollView(
                    padding: EdgeInsets.only(
                      left: scaleSize(context, 20),
                      right: scaleSize(context, 20),
                      bottom: bottomPadding,
                    ),
                    child: noLocation
                        ? _buildAddLocationContent(context, t)
                        : Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              SizedBox(height: scaleSize(context, 12)),
                              _buildOrbitSwiper(context, times, nextPrayer, t),
                              SizedBox(height: scaleSize(context, 20)),
                              HomeContentCards(
                                prayerTime: _computeCurrentPrayerTime(times),
                                mood: _todayMoods[_computeCurrentPrayerTime(times)],
                                isRamadan: isRamadan,
                                hijriDay: hijri.hDay,
                                hijriYear: hijri.hYear,
                              ),
                            ],
                          ),
                  ),
                ),
              ],
            ),
            if (_showAlarmModal)
              AlarmSettingsModal(
                onClose: () async {
                  setState(() => _showAlarmModal = false);
                  final settings = await AlarmSettingsService.load();
                  if (mounted) {
                    setState(() => _persistentNotificationEnabled =
                        settings['persistentNotificationEnabled'] != false);
                    if (_prayerTimes != null) {
                      _scheduleNotifications(_prayerTimes!, _tomorrowPrayerTimes);
                      _refreshPersistentNotification(context);
                    }
                  }
                },
              ),
            if (_showCalendar)
              _buildCalendarModal(context, loc),
            if (_showLocationModal)
              LocationInputModal(
                visible: true,
                onClose: () => setState(() {
                  _showLocationModal = false;
                  _locationModalIntent = null;
                }),
                onLocationSelected: _locationModalIntent == 'add'
                    ? _handleAddCityLocationSelected
                    : _handleReplaceOrFirstLocationSelected,
              ),
            if (_activeMoodPrayerKey != null)
              _buildMoodPopup(context, t),
          ],
        ),
      ),
    );
  }

  // ── Mood check popup ─────────────────────────────────────────────────────
  static const _kMoodAccent    = Color(0xFF6366F1);
  static const _kMoodSurface   = Color(0xF2FFFFFF);
  static const _kMoodTextPrimary   = Color(0xFF0F172A);
  static const _kMoodTextSecondary = Color(0xFF64748B);

  Widget _buildMoodPopup(BuildContext context, String Function(String) t) {
    final prayerName = t(_activeMoodPrayerKey!);

    const moods = [
      ('sad',     '😢', Color(0xFF3B82F6)),
      ('neutral', '😐', Color(0xFF64748B)),
      ('happy',   '😊', Color(0xFF10B981)),
    ];

    return Stack(
      children: [
        // ── Blurred backdrop ──────────────────────────────────────────────
        GestureDetector(
          onTap: () => setState(() => _activeMoodPrayerKey = null),
          behavior: HitTestBehavior.opaque,
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 5, sigmaY: 5),
            child: Container(color: Colors.black12),
          ),
        ),
        // ── Compact pill card (all sizes scaled) ─────────────────────────
        Center(
          child: GestureDetector(
            onTap: () {},
            child: ClipRRect(
              borderRadius: BorderRadius.circular(scaleSize(context, 20)),
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
                child: Container(
                  width: scaleSize(context, 230),
                  decoration: BoxDecoration(
                    color: _kMoodSurface,
                    borderRadius: BorderRadius.circular(scaleSize(context, 20)),
                    border: Border.all(
                      color: Colors.white.withValues(alpha: 0.55),
                      width: scaleSize(context, 1.2),
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: _kMoodAccent.withValues(alpha: 0.10),
                        blurRadius: scaleSize(context, 24),
                        offset: Offset(0, scaleSize(context, 6)),
                      ),
                    ],
                  ),
                  padding: EdgeInsets.fromLTRB(
                    scaleSize(context, 18),
                    scaleSize(context, 14),
                    scaleSize(context, 18),
                    scaleSize(context, 16),
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          RichText(
                            text: TextSpan(
                              children: [
                                TextSpan(
                                  text: '${t('yourMood').toUpperCase()}  ',
                                  style: TextStyle(
                                    fontSize: scaleFont(context, 9),
                                    fontWeight: FontWeight.w700,
                                    color: _kMoodAccent,
                                    letterSpacing: 1.1,
                                  ),
                                ),
                                TextSpan(
                                  text: prayerName,
                                  style: TextStyle(
                                    fontSize: scaleFont(context, 14),
                                    fontWeight: FontWeight.w700,
                                    color: _kMoodTextPrimary,
                                    letterSpacing: -0.2,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          GestureDetector(
                            onTap: () => setState(() => _activeMoodPrayerKey = null),
                            child: Text(
                              '×',
                              style: TextStyle(
                                fontSize: scaleFont(context, 18),
                                color: _kMoodTextSecondary.withValues(alpha: 0.45),
                                height: 1,
                              ),
                            ),
                          ),
                        ],
                      ),
                      SizedBox(height: scaleSize(context, 12)),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                        children: moods.map((m) {
                          final (moodKey, emoji, color) = m;
                          return GestureDetector(
                            onTap: () => _saveMood(moodKey),
                            child: Container(
                              width: scaleSize(context, 46),
                              height: scaleSize(context, 46),
                              decoration: BoxDecoration(
                                color: color.withValues(alpha: 0.10),
                                shape: BoxShape.circle,
                                border: Border.all(
                                  color: color.withValues(alpha: 0.25),
                                  width: scaleSize(context, 1.2),
                                ),
                              ),
                              alignment: Alignment.center,
                              child: Text(emoji,
                                  style: TextStyle(fontSize: scaleFont(context, 22))),
                            ),
                          );
                        }).toList(),
                      ),
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

  // ── Orbit ↔ Prayer-cards depth swiper ──────────────────────────────────────
  Widget _buildOrbitSwiper(
    BuildContext context,
    PrayerTimesResult times,
    NextPrayer nextPrayer,
    String Function(String) t,
  ) {
    final orbitRadius = scaleSize(context, kOrbitContainerRadius);
    return Column(
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(orbitRadius),
          child: SizedBox(
            height: scaleSize(context, 184),
            child: PageView.builder(
            controller: _orbitPageController,
            // null itemCount → infinite; mod 2 maps to our two actual pages.
            onPageChanged: (i) => setState(() => _orbitPageIndex = i % 2),
            itemBuilder: (ctx, index) {
              final pageIndex = index % 2;
              final child = pageIndex == 0
                  ? PrayerOrbitWidget(
                      fajr: times.fajr,
                      sunrise: times.sunrise,
                      dhuhr: times.dhuhr,
                      asr: times.asr,
                      maghrib: times.maghrib,
                      isha: times.isha,
                      moods: _todayMoods,
                    )
                  // Cards page: SunMoonBar on top, prayer cards centered below.
                  // Spacers on each side guarantee the Row takes its natural height.
                  : Column(
                      mainAxisSize: MainAxisSize.max,
                      children: [
                        SunMoonBar(
                          sunrise: times.sunrise,
                          sunset: times.maghrib,
                          sunriseLabel: t('sunrise'),
                          sunsetLabel: t('sunset'),
                        ),
                        const Spacer(),
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.center,
                          children: [
                            Expanded(
                              child: PrayerTimeCard(
                                name: t('fajr'),
                                time: times.fajr,
                                icon: Icons.nightlight_round,
                                isCurrent: false,
                                isNext: nextPrayer.key == 'fajr',
                                mood: _todayMoods['fajr'],
                              ),
                            ),
                            SizedBox(width: scaleSize(context, 8)),
                            Expanded(
                              child: PrayerTimeCard(
                                name: t('dhuhr'),
                                time: times.dhuhr,
                                icon: Icons.wb_sunny_outlined,
                                isCurrent: false,
                                isNext: nextPrayer.key == 'dhuhr',
                                mood: _todayMoods['dhuhr'],
                              ),
                            ),
                            SizedBox(width: scaleSize(context, 8)),
                            Expanded(
                              child: PrayerTimeCard(
                                name: t('asr'),
                                time: times.asr,
                                icon: Icons.wb_cloudy_outlined,
                                isCurrent: false,
                                isNext: nextPrayer.key == 'asr',
                                mood: _todayMoods['asr'],
                              ),
                            ),
                            SizedBox(width: scaleSize(context, 8)),
                            Expanded(
                              child: PrayerTimeCard(
                                name: t('maghrib'),
                                time: times.maghrib,
                                icon: Icons.wb_twilight_outlined,
                                isCurrent: false,
                                isNext: nextPrayer.key == 'maghrib',
                                mood: _todayMoods['maghrib'],
                              ),
                            ),
                            SizedBox(width: scaleSize(context, 8)),
                            Expanded(
                              child: PrayerTimeCard(
                                name: t('isha'),
                                time: times.isha,
                                icon: Icons.nightlight_round,
                                isCurrent: false,
                                isNext: nextPrayer.key == 'isha',
                                mood: _todayMoods['isha'],
                              ),
                            ),
                          ],
                        ),
                        const Spacer(),
                      ],
                    );

              // Depth scale: current page = 1.0, neighbour starts at 0.82.
              // Uses raw index (same space as controller.page) for correct math
              // in both directions.
              return AnimatedBuilder(
                animation: _orbitPageController,
                child: child,
                builder: (_, c) {
                  double scale;
                  if (_orbitPageController.hasClients &&
                      _orbitPageController.position.haveDimensions) {
                    final page = _orbitPageController.page ?? index.toDouble();
                    final dist = (page - index).abs().clamp(0.0, 1.0);
                    // Outgoing shrinks (1.0→0.82), incoming grows (0.82→1.0)
                    scale = 1.0 - dist * 0.18;
                  } else {
                    // Before first layout: current content = full scale, others = small
                    scale = (pageIndex == _orbitPageIndex) ? 1.0 : 0.82;
                  }
                  return Transform.scale(
                    scale: scale,
                    alignment: Alignment.center,
                    child: c,
                  );
                },
              );
            },
          ),
        ),
        ),
        // ── Page indicator dots (scaled) ─────────────────────────────────
        SizedBox(height: scaleSize(context, 10)),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          mainAxisSize: MainAxisSize.min,
          children: List.generate(2, (i) {
            final active = _orbitPageIndex == i;
            return GestureDetector(
              onTap: () => _orbitPageController.animateToPage(
                i,
                duration: const Duration(milliseconds: 380),
                curve: Curves.easeInOutCubic,
              ),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 280),
                curve: Curves.easeInOut,
                width: active ? scaleSize(context, 20) : scaleSize(context, 7),
                height: scaleSize(context, 7),
                margin: EdgeInsets.symmetric(horizontal: scaleSize(context, 3)),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(scaleSize(context, 4)),
                  color: active
                      ? const Color(0xFF6366F1)
                      : const Color(0xFFCBD5E1),
                ),
              ),
            );
          }),
        ),
      ],
    );
  }

  Widget _buildCalendarModal(BuildContext context, LocationProvider loc) {
    double? lat;
    double? lng;
    Map<String, dynamic>? admin;
    int method = 2;
    String madhab = 'standard';

    if (loc.hasCities) {
      final city = loc.cities[loc.selectedCityIndex];
      final locMap = city['location'] as Map<String, dynamic>?;
      lat = (locMap?['latitude'] as num?)?.toDouble();
      lng = (locMap?['longitude'] as num?)?.toDouble();
      admin = city['admin'] as Map<String, dynamic>?;
      method = (city['calculationMethod'] as int?) ?? 2;
      madhab = (city['madhab'] as String?) ?? 'standard';
    }

    return Positioned.fill(
      child: PrayerCalendarModal(
        latitude: lat,
        longitude: lng,
        method: method,
        madhab: madhab,
        admin: admin,
        onClose: () => setState(() => _showCalendar = false),
      ),
    );
  }

  Widget _buildAddLocationContent(BuildContext context, String Function(String) t) {
    return Padding(
      padding: EdgeInsets.only(top: scaleSize(context, 20)),
      child: Material(
        color: Colors.white,
        borderRadius: BorderRadius.circular(scaleSize(context, 16)),
        elevation: 2,
        shadowColor: Colors.black.withValues(alpha: 0.05),
        child: InkWell(
          onTap: _openLocationModalForReplaceOrFirst,
          borderRadius: BorderRadius.circular(scaleSize(context, 16)),
          child: Padding(
            padding: EdgeInsets.symmetric(vertical: scaleSize(context, 40), horizontal: scaleSize(context, 24)),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.location_on_outlined, size: scaleSize(context, 36), color: const Color(0xFF94A3B8)),
                SizedBox(height: scaleSize(context, 16)),
                Text(
                  t('addLocation'),
                  style: GoogleFonts.cormorantGaramond(
                    fontSize: scaleFont(context, 18),
                    fontWeight: FontWeight.w600,
                    color: const Color(0xFF1E293B),
                  ),
                  textAlign: TextAlign.center,
                ),
                SizedBox(height: scaleSize(context, 8)),
                Text(
                  t('addLocationSubtext'),
                  style: GoogleFonts.cormorantGaramond(fontSize: scaleFont(context, 14), color: const Color(0xFF64748B)),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Konum değişti tespit edildiğinde diyalog için tutulan veri.
class _PendingLocationUpdate {
  final double lat;
  final double lng;
  final Map<String, dynamic> nameObj;
  final Map<String, dynamic> admin;
  final String displayName;
  _PendingLocationUpdate({
    required this.lat,
    required this.lng,
    required this.nameObj,
    required this.admin,
    required this.displayName,
  });
}
