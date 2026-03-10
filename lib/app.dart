import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'keys.dart';
import 'contexts/theme_provider.dart';
import 'contexts/back_handler_provider.dart';
import 'contexts/location_provider.dart';
import 'contexts/bottom_nav_index_provider.dart';
import 'services/app_update_service.dart';
import 'services/quran_playback_service.dart';
import 'widgets/custom_navigation_bar.dart';
import 'screens/home_screen.dart';
import 'screens/prayer_screen.dart';
import 'screens/dhikr_screen.dart';
import 'screens/quran_screen.dart';
import 'screens/qibla_mosques_screen.dart';
import 'screens/settings_screen.dart';

class NidaFlutterApp extends StatelessWidget {
  const NidaFlutterApp({super.key});

  @override
  Widget build(BuildContext context) {
    final locale = context.watch<ThemeProvider>().language;
    return MaterialApp(
      navigatorKey: rootNavigatorKey,
      title: 'Nida Adhan',
      debugShowCheckedModeBanner: false,
      locale: Locale(locale),
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF6366F1),
          primary: const Color(0xFF6366F1),
          surface: const Color(0xFFF8FAFC),
        ),
        scaffoldBackgroundColor: const Color(0xFFF8FAFC),
      ),
      builder: (context, child) {
        return MediaQuery(
          data: MediaQuery.of(context).copyWith(
            textScaler: TextScaler.noScaling,
          ),
          child: MultiProvider(
            providers: [
              ChangeNotifierProvider<LocationProvider>.value(
                value: context.read<LocationProvider>(),
              ),
            ],
            child: child ?? const SizedBox.shrink(),
          ),
        );
      },
      home: const MainScaffold(),
    );
  }
}

class MainScaffold extends StatefulWidget {
  const MainScaffold({super.key});

  @override
  State<MainScaffold> createState() => _MainScaffoldState();
}

class _MainScaffoldState extends State<MainScaffold> with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<QuranPlaybackService>().loadSavedReciter();
      AppUpdateService.checkForUpdate(context);
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state != AppLifecycleState.resumed) return;
    AppUpdateService.checkForUpdate(context);
  }

  List<Widget> get _screens => [
    const PrayerScreen(),
    const QuranScreen(),
    const HomeScreen(),
    const QiblaMosquesScreen(),
    const SettingsScreen(),
  ];

  void _onNavTap(int index) {
    final nav = context.read<BottomNavIndexProvider>();
    if (index == 4) {
      nav.setIndex(4);
    } else {
      nav.setIndex(index);
    }
  }

  @override
  Widget build(BuildContext context) {
    final navIndex = context.watch<BottomNavIndexProvider>().currentIndex;
    return NavBarScope(
      currentIndex: navIndex,
      onTap: _onNavTap,
      child: PopScope(
        canPop: false,
        onPopInvokedWithResult: (bool didPop, dynamic result) {
          if (!didPop) {
            final navIndex = context.read<BottomNavIndexProvider>().currentIndex;
            final backHandler = context.read<BackHandlerProvider>().handler;
            if (navIndex == 1 && backHandler != null) {
              if (backHandler()) return;
            }
            context.read<BottomNavIndexProvider>().goToHome();
          }
        },
        child: Navigator(
          initialRoute: '/',
          onGenerateRoute: (RouteSettings settings) {
            if (settings.name == '/' || settings.name == '/main') {
              return MaterialPageRoute<void>(
                builder: (_) => Builder(
                  builder: (ctx) {
                    final idx = ctx.watch<BottomNavIndexProvider>().currentIndex;
                    final showBarNow = idx != 1;
                    return Stack(
                      children: [
                        IndexedStack(
                          index: idx,
                          children: _screens,
                        ),
                        if (showBarNow)
                          const Positioned(
                            left: 0,
                            right: 0,
                            bottom: 0,
                            child: CustomNavigationBar(),
                          ),
                      ],
                    );
                  },
                ),
              );
            }
            if (settings.name == '/dhikr') {
              return MaterialPageRoute<void>(
                builder: (_) => const DhikrScreen(),
              );
            }
            return null;
          },
        ),
      ),
    );
  }
}
