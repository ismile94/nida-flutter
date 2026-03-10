import 'package:flutter/material.dart';

/// Optional back-key handler for the current screen.
/// When the system back is pressed, MainScaffold calls this handler if we're on Quran tab.
/// If the handler returns true, back was consumed; otherwise MainScaffold goes home.
class BackHandlerProvider extends ChangeNotifier {
  bool Function()? _handler;

  bool Function()? get handler => _handler;

  void setBackHandler(bool Function()? h) {
    if (_handler == h) return;
    _handler = h;
    notifyListeners();
  }
}
