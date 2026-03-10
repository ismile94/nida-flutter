// RN: services/audio/PlaybackEngine.js – playlist üretimi (repeat none/one/surah/range).

/// Playlist öğesi: sadece ayet (besmele Flutter'da atlanıyor, asset yok).
class PlaylistItem {
  final int surah;
  final int ayah;
  const PlaylistItem({required this.surah, required this.ayah});
}

/// RN getSurahAyahCount
int getSurahAyahCount(int surahNumber) {
  const counts = {
    1: 7, 2: 286, 3: 200, 4: 176, 5: 120, 6: 165, 7: 206, 8: 75, 9: 129, 10: 109,
    11: 123, 12: 111, 13: 43, 14: 52, 15: 99, 16: 128, 17: 111, 18: 110, 19: 98, 20: 135,
    21: 112, 22: 78, 23: 118, 24: 64, 25: 77, 26: 227, 27: 93, 28: 88, 29: 69, 30: 60,
    31: 34, 32: 30, 33: 73, 34: 54, 35: 45, 36: 83, 37: 182, 38: 88, 39: 75, 40: 85,
    41: 54, 42: 53, 43: 89, 44: 59, 45: 37, 46: 35, 47: 38, 48: 29, 49: 18, 50: 45,
    51: 60, 52: 49, 53: 62, 54: 55, 55: 78, 56: 96, 57: 29, 58: 22, 59: 24, 60: 13,
    61: 14, 62: 11, 63: 11, 64: 18, 65: 12, 66: 12, 67: 30, 68: 52, 69: 52, 70: 44,
    71: 28, 72: 28, 73: 20, 74: 56, 75: 40, 76: 31, 77: 50, 78: 40, 79: 46, 80: 42,
    81: 29, 82: 19, 83: 36, 84: 25, 85: 22, 86: 17, 87: 19, 88: 26, 89: 30, 90: 20,
    91: 15, 92: 21, 93: 11, 94: 8, 95: 8, 96: 19, 97: 5, 98: 8, 99: 8, 100: 11,
    101: 11, 102: 8, 103: 3, 104: 9, 105: 5, 106: 4, 107: 7, 108: 3, 109: 6, 110: 3,
    111: 5, 112: 4, 113: 5, 114: 6,
  };
  return counts[surahNumber] ?? 0;
}

/// 1. ve 9. sure hariç besmele (ayah 0) kullanılır.
bool _needsBismillah(int surahNumber) =>
    surahNumber != 1 && surahNumber != 9;

/// Sonraki ayet (RN getNextAyah). ayah 0 = besmele, sonrası (surah, 1).
PlaylistItem? getNextAyah(int currentSurah, int currentAyah) {
  if (currentAyah == 0) {
    return PlaylistItem(surah: currentSurah, ayah: 1);
  }
  final maxAyahs = getSurahAyahCount(currentSurah);
  if (currentAyah < maxAyahs) {
    return PlaylistItem(surah: currentSurah, ayah: currentAyah + 1);
  }
  if (currentSurah < 114) {
    final nextSurah = currentSurah + 1;
    if (_needsBismillah(nextSurah)) {
      return PlaylistItem(surah: nextSurah, ayah: 0);
    }
    return PlaylistItem(surah: nextSurah, ayah: 1);
  }
  return null;
}

/// Önceki ayet (RN getPreviousAyah). (surah, 1) öncesi besmele ise (surah, 0).
PlaylistItem? getPreviousAyah(int currentSurah, int currentAyah) {
  if (currentAyah == 1 && _needsBismillah(currentSurah)) {
    return PlaylistItem(surah: currentSurah, ayah: 0);
  }
  if (currentAyah > 1) {
    return PlaylistItem(surah: currentSurah, ayah: currentAyah - 1);
  }
  if (currentSurah > 1) {
    final prevSurah = currentSurah - 1;
    final maxAyahs = getSurahAyahCount(prevSurah);
    return PlaylistItem(surah: prevSurah, ayah: maxAyahs);
  }
  return null;
}

/// Aralık üretir (RN generateRange). Sure başında besmele (ayah 0) eklenir (1. ve 9. hariç).
List<PlaylistItem> generateRange(int startSurah, int startAyah, int endSurah, int endAyah) {
  final list = <PlaylistItem>[];
  int cSurah = startSurah;
  int cAyah = startAyah;
  while (cSurah < endSurah || (cSurah == endSurah && cAyah <= endAyah)) {
    if (cAyah == 1 && _needsBismillah(cSurah)) {
      list.add(PlaylistItem(surah: cSurah, ayah: 0));
    }
    list.add(PlaylistItem(surah: cSurah, ayah: cAyah));
    final maxAyahs = getSurahAyahCount(cSurah);
    if (cAyah < maxAyahs) {
      cAyah++;
    } else {
      cSurah++;
      cAyah = 1;
    }
    if (cSurah > 114) break;
  }
  return list;
}

/// Playlist oluşturur (RN generatePlaylist).
/// options: stopAtSurahEnd, playNextSurah (PrayerScreen için), endSurah, endAyah (range için)
List<PlaylistItem> generatePlaylist({
  required int startSurah,
  required int startAyah,
  required String repeatMode,
  bool stopAtSurahEnd = false,
  int? playNextSurah,
  int? endSurah,
  int? endAyah,
}) {
  final list = <PlaylistItem>[];

  if (stopAtSurahEnd) {
    final maxAyahs = getSurahAyahCount(startSurah);
    if (startAyah == 1 && _needsBismillah(startSurah)) {
      list.add(PlaylistItem(surah: startSurah, ayah: 0));
    }
    for (int a = startAyah; a <= maxAyahs; a++) {
      list.add(PlaylistItem(surah: startSurah, ayah: a));
    }
    if (playNextSurah != null) {
      if (_needsBismillah(playNextSurah)) {
        list.add(PlaylistItem(surah: playNextSurah, ayah: 0));
      }
      final nextMax = getSurahAyahCount(playNextSurah);
      for (int a = 1; a <= nextMax; a++) {
        list.add(PlaylistItem(surah: playNextSurah, ayah: a));
      }
    }
    return list;
  }

  switch (repeatMode) {
    case 'none':
      if (startAyah == 1 && _needsBismillah(startSurah)) {
        list.add(PlaylistItem(surah: startSurah, ayah: 0));
      }
      list.add(PlaylistItem(surah: startSurah, ayah: startAyah));
      break;
    case 'one':
      if (startAyah == 1 && _needsBismillah(startSurah)) {
        list.add(PlaylistItem(surah: startSurah, ayah: 0));
      }
      list.add(PlaylistItem(surah: startSurah, ayah: startAyah));
      break;
    case 'surah':
      if (startAyah == 1 && _needsBismillah(startSurah)) {
        list.add(PlaylistItem(surah: startSurah, ayah: 0));
      }
      final maxAyahs = getSurahAyahCount(startSurah);
      for (int a = startAyah; a <= maxAyahs; a++) {
        list.add(PlaylistItem(surah: startSurah, ayah: a));
      }
      break;
    case 'range':
      if (endSurah != null && endAyah != null) {
        list.addAll(generateRange(startSurah, startAyah, endSurah, endAyah));
      } else {
        if (startAyah == 1 && _needsBismillah(startSurah)) {
          list.add(PlaylistItem(surah: startSurah, ayah: 0));
        }
        list.add(PlaylistItem(surah: startSurah, ayah: startAyah));
      }
      break;
    case 'quran':
      // Tüm Kuran: baştan sona bir tur, sonra başa dön
      list.addAll(generateRange(startSurah, startAyah, 114, 6));
      final prev = getPreviousAyah(startSurah, startAyah);
      if (prev != null) {
        list.addAll(generateRange(1, 1, prev.surah, prev.ayah));
      }
      break;
    default:
      list.add(PlaylistItem(surah: startSurah, ayah: startAyah));
      break;
  }
  return list;
}
