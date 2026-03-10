// RN: AppUpdateService.ts – Google Play’da yeni sürüm varsa uygulama açılışında bildirim.

import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:in_app_update/in_app_update.dart';

import '../keys.dart';

const int _resumeDebounceMs = 8000;

/// Uygulama açıldığında (ve resume’da) güncelleme kontrolü.
/// Sadece Android; Play Store üzerinden yüklendiğinde çalışır.
class AppUpdateService {
  AppUpdateService._();

  static bool _checking = false;
  static int _lastCheckAt = 0;

  /// Ana ekran hazır olduktan sonra veya app resume’da çağrılmalı.
  static Future<void> checkForUpdate(BuildContext context) async {
    if (!Platform.isAndroid) return;
    if (_checking) return;
    final now = DateTime.now().millisecondsSinceEpoch;
    if (_lastCheckAt > 0 && now - _lastCheckAt < _resumeDebounceMs) return;
    _lastCheckAt = now;
    _checking = true;
    try {
      final info = await InAppUpdate.checkForUpdate();
      if (!context.mounted) return;
      if (info.updateAvailability != UpdateAvailability.updateAvailable) return;

      // Her açılışta sor; Later = bir sonraki açılışta yine sor
      final allowed = info.immediateUpdateAllowed || info.flexibleUpdateAllowed;
      if (!allowed) return;

      if (info.immediateUpdateAllowed) {
        await InAppUpdate.performImmediateUpdate();
        return;
      }

      // Flexible update: önce dialog göster, kullanıcı “Güncelle” derse indirmeyi başlat
      final shouldStart = await _showUpdateDialog(context);
      if (!context.mounted || shouldStart != true) return;

      final result = await InAppUpdate.startFlexibleUpdate();
      if (!context.mounted) return;
      if (result != AppUpdateResult.success) return;

      // İndirme tamamlanınca dinle (listener başka bağlamda tetiklenebilir)
      StreamSubscription<InstallStatus>? sub;
      sub = InAppUpdate.installUpdateListener.listen((status) async {
        if (status != InstallStatus.downloaded) return;
        sub?.cancel();
        final ctx = rootNavigatorKey.currentContext;
        if (ctx == null) return;
        final restart = await _showRestartDialog(ctx);
        if (restart == true) {
          await InAppUpdate.completeFlexibleUpdate();
        }
      });
    } catch (_) {
      // Play API yok / debug / başka hata – sessizce geç
    } finally {
      _checking = false;
    }
  }

  static Future<bool?> _showUpdateDialog(BuildContext context) async {
    return showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        title: const Text('Update Available'),
        content: const Text(
          'A new version is available on Google Play. Would you like to update now?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Later'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Update'),
          ),
        ],
      ),
    );
  }

  static Future<bool?> _showRestartDialog(BuildContext context) async {
    return showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        title: const Text('Update Ready'),
        content: const Text(
          'The update has been downloaded. Restart the app to install.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Later'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Restart'),
          ),
        ],
      ),
    );
  }
}
