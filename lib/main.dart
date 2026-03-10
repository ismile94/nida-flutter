import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'contexts/theme_provider.dart';
import 'contexts/back_handler_provider.dart';
import 'contexts/navigation_bar_provider.dart';
import 'contexts/bottom_nav_index_provider.dart';
import 'contexts/location_provider.dart';
import 'contexts/quran_view_mode_provider.dart';
import 'services/country_calculation_service.dart';
import 'services/notification_service.dart';
import 'services/quran_playback_service.dart';
import 'app.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await CountryCalculationService.ensureLoaded();
  await NotificationService.initialize();

  final prefs = await SharedPreferences.getInstance();
  String initialLanguage = 'en';
  final saved = prefs.getString(kPrefKeyLanguage);
  if (saved != null && kSupportedLanguageCodes.contains(saved)) {
    initialLanguage = saved;
  } else {
    final systemCode = ui.PlatformDispatcher.instance.locale.languageCode.toLowerCase();
    if (kSupportedLanguageCodes.contains(systemCode)) {
      initialLanguage = systemCode;
    }
  }

  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.dark,
      systemNavigationBarColor: Colors.white,
      systemNavigationBarIconBrightness: Brightness.dark,
    ),
  );
  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(
          create: (_) => ThemeProvider(
            initialLanguage: initialLanguage,
            sharedPreferences: prefs,
          ),
        ),
        ChangeNotifierProvider(create: (_) => BackHandlerProvider()),
        ChangeNotifierProvider(create: (_) => NavigationBarProvider()),
        ChangeNotifierProvider(create: (_) => BottomNavIndexProvider()),
        ChangeNotifierProvider(create: (_) => LocationProvider()),
        ChangeNotifierProvider(create: (_) => QuranViewModeProvider()),
        ChangeNotifierProvider(create: (_) => QuranPlaybackService()),
      ],
      child: const NidaFlutterApp(),
    ),
  );
}
