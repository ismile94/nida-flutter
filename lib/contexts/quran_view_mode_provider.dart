import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Quran görünüm modu: sure sure (SurahView) veya mushaf sayfa (PureQuran).
/// RN: QuranViewModeContext.js
const String kQuranViewModeSurahBySurah = 'surah_by_surah';
const String kQuranViewModePureQuran = 'pure_quran';

const String _storageKey = '@quran_view_mode';

class QuranViewModeProvider extends ChangeNotifier {
  /// Quran sekmesi açıldığında varsayılan SurahView (sure sure) görünsün.
  String? _currentViewMode = defaultViewMode;
  bool _isInitialized = false;
  /// Pure Quran açılırken gösterilecek ilk sayfa (Quran Index’ten cüz seçilince)
  int? _pureQuranInitialPage;

  String? get currentViewMode => _currentViewMode;
  bool get isInitialized => _isInitialized;
  int? get pureQuranInitialPage => _pureQuranInitialPage;

  /// Varsayılan: sure sure görünüm (SurahView).
  static const String defaultViewMode = kQuranViewModeSurahBySurah;

  QuranViewModeProvider() {
    _loadFromStorage();
  }

  Future<void> _loadFromStorage() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final saved = prefs.getString(_storageKey);
      if (saved != null &&
          (saved == kQuranViewModeSurahBySurah || saved == kQuranViewModePureQuran)) {
        _currentViewMode = saved;
      } else {
        _currentViewMode = defaultViewMode;
        await prefs.setString(_storageKey, defaultViewMode);
      }
    } catch (_) {
      _currentViewMode = defaultViewMode;
    } finally {
      _isInitialized = true;
      notifyListeners();
    }
  }

  Future<void> setViewMode(String mode, {int? initialPage}) async {
    if (mode != kQuranViewModeSurahBySurah && mode != kQuranViewModePureQuran) return;
    _pureQuranInitialPage = (mode == kQuranViewModePureQuran) ? initialPage : null;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_storageKey, mode);
      _currentViewMode = mode;
      notifyListeners();
    } catch (_) {
      _currentViewMode = mode;
      notifyListeners();
    }
  }

  void clearPureQuranInitialPage() {
    if (_pureQuranInitialPage != null) {
      _pureQuranInitialPage = null;
      notifyListeners();
    }
  }

  bool get isSurahBySurah => _currentViewMode == kQuranViewModeSurahBySurah;
  bool get isPureQuran => _currentViewMode == kQuranViewModePureQuran;
}
