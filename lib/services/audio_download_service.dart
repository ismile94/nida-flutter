// Reciter audio download: save MP3s to app documents for offline playback.

import 'dart:io';

import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';

import 'quran_audio_service.dart';

/// Returns the path where a downloaded ayah file would be stored (does not check existence).
/// ayah 0 (besmele) aynı okuyucunun 001001 dosyasıyla eşlenir.
Future<String> getAyahAudioFilePath(String reciterKey, int surah, int ayah) async {
  final dir = await getApplicationDocumentsDirectory();
  final safeKey = reciterKey.replaceAll(RegExp(r'[^a-zA-Z0-9._-]'), '_');
  final int fileSurah = ayah == 0 ? 1 : surah;
  final int fileAyah = ayah == 0 ? 1 : ayah;
  final s = fileSurah.toString().padLeft(3, '0');
  final a = fileAyah.toString().padLeft(3, '0');
  return '${dir.path}/quran_audio/$safeKey/$s$a.mp3';
}

/// Returns whether the ayah audio file exists on disk.
Future<bool> isAyahAudioDownloaded(String reciterKey, int surah, int ayah) async {
  final path = await getAyahAudioFilePath(reciterKey, surah, ayah);
  return File(path).existsSync();
}

/// Returns file path if downloaded, otherwise the network URL for playback.
Future<String?> getAyahAudioSource(String reciterKey, int surah, int ayah) async {
  final downloaded = await isAyahAudioDownloaded(reciterKey, surah, ayah);
  if (downloaded) {
    return await getAyahAudioFilePath(reciterKey, surah, ayah);
  }
  return getAyahAudioUrl(reciterKey, surah, ayah);
}

/// Downloads ayah audio files to app documents. [ayahs] is a list of (surah, ayah).
/// [onProgress] is called with (current, total).
/// [isCancelled] if returns true, download stops; already-downloaded files are kept.
Future<({bool success, String? error})> downloadAyahRange(
  List<(int surah, int ayah)> ayahs,
  String reciterKey, {
  void Function(int current, int total)? onProgress,
  bool Function()? isCancelled,
}) async {
  if (ayahs.isEmpty) return (success: true, error: null);
  try {
    final dir = await getApplicationDocumentsDirectory();
    final safeKey = reciterKey.replaceAll(RegExp(r'[^a-zA-Z0-9._-]'), '_');
    final baseDir = Directory('${dir.path}/quran_audio/$safeKey');
    if (!await baseDir.exists()) await baseDir.create(recursive: true);

    final total = ayahs.length;
    int current = 0;

    for (final a in ayahs) {
      if (isCancelled?.call() ?? false) return (success: false, error: null);
      final url = getAyahAudioUrl(reciterKey, a.$1, a.$2);
      if (url != null) {
        final path = await getAyahAudioFilePath(reciterKey, a.$1, a.$2);
        try {
          final res = await http.get(Uri.parse(url));
          if (res.statusCode == 200 && res.bodyBytes.isNotEmpty) {
            await File(path).writeAsBytes(res.bodyBytes);
          }
        } catch (_) {}
      }
      current++;
      onProgress?.call(current, total);
    }

    return (success: true, error: null);
  } catch (e) {
    return (success: false, error: e.toString());
  }
}

/// Deletes downloaded ayah audio files for the given list. Does not remove prefs (caller does).
Future<void> deleteAyahRange(
  List<(int surah, int ayah)> ayahs,
  String reciterKey,
) async {
  if (ayahs.isEmpty) return;
  try {
    for (final a in ayahs) {
      final path = await getAyahAudioFilePath(reciterKey, a.$1, a.$2);
      final file = File(path);
      if (await file.exists()) await file.delete();
    }
  } catch (_) {}
}
