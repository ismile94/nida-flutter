import 'package:flutter/material.dart';

/// Holds the current bottom navigation tab index.
/// Allows any screen to request navigation to home (e.g. on system back).
class BottomNavIndexProvider extends ChangeNotifier {
  int _currentIndex = 2; // Home is center (index 2)
  int get currentIndex => _currentIndex;

  void setIndex(int index) {
    if (_currentIndex != index) {
      _currentIndex = index;
      notifyListeners();
    }
  }

  /// Navigate to homepage (tab index 2).
  void goToHome() => setIndex(2);
}
