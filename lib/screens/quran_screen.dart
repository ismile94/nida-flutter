import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../contexts/back_handler_provider.dart';
import '../contexts/bottom_nav_index_provider.dart';
import '../contexts/navigation_bar_provider.dart';
import '../contexts/quran_view_mode_provider.dart';
import 'surah_view_screen.dart';
import 'pure_quran_screen.dart';

/// RN: QuranScreen.js – Kaydedilmiş view mode'a göre SurahView veya PureQuran gösterir.
/// Nav bar'da Quran sekmesi = bu widget; içeride SurahViewScreen veya PureQuranScreen.
class QuranScreen extends StatefulWidget {
  const QuranScreen({super.key});

  @override
  State<QuranScreen> createState() => _QuranScreenState();
}

class _QuranScreenState extends State<QuranScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<NavigationBarProvider>().setVisible(true);
    });
  }

  @override
  Widget build(BuildContext context) {
    final mode = context.watch<QuranViewModeProvider>();
    final isQuranTab = context.watch<BottomNavIndexProvider>().currentIndex == 1;
    if (!isQuranTab) {
      context.read<BackHandlerProvider>().setBackHandler(null);
    }

    // Henüz storage yüklenmediyse veya mod SurahView ise: varsayılan SurahView açılsın
    if (!mode.isInitialized || mode.isSurahBySurah) {
      return const SurahViewScreen();
    }

    // PureQuran (mushaf sayfa görünümü)
    final initialPage = mode.pureQuranInitialPage;
    return PureQuranScreen(
      initialPage: initialPage,
      onSwitchToSurahView: () {
        mode.clearPureQuranInitialPage();
        mode.setViewMode(kQuranViewModeSurahBySurah);
      },
    );
  }
}
