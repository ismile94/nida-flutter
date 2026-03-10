import 'package:flutter/material.dart';

/// Controls bottom navigation bar visibility (e.g. hide on SurahView).
class NavigationBarProvider extends ChangeNotifier {
  bool _isVisible = true;
  bool get isVisible => _isVisible;

  void setVisible(bool value) {
    if (_isVisible != value) {
      _isVisible = value;
      notifyListeners();
    }
  }
}
