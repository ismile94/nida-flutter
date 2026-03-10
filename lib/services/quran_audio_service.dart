// RN: services/audio/AudioService.js RECITER_MAPPINGS – everyayah.com URL üretimi.
// Format: https://everyayah.com/data/{folder}/{SSS}{YYY}.mp3 (SSS=sure 3 hane, YYY=ayet 3 hane).
// Gerçek çalma için audioplayers veya just_audio paketi ile bu URL kullanılabilir.

/// Okuyucu anahtarı -> everyayah.com base URL (RN ile aynı)
const Map<String, String> _reciterBaseUrls = {
  'ar.mahermuaiqly': 'https://everyayah.com/data/Maher_AlMuaiqly_64kbps/',
  'ar.abdulbasitmurattal': 'https://everyayah.com/data/Abdul_Basit_Murattal_64kbps/',
  'ar.misharyrashid': 'https://everyayah.com/data/Alafasy_64kbps/',
  'ar.saadalghamdi': 'https://everyayah.com/data/Ghamadi_40kbps/',
  'ar.abdurrahmansudais': 'https://everyayah.com/data/Abdurrahmaan_As-Sudais_64kbps/',
  'ar.minshawi': 'https://everyayah.com/data/Minshawy_Mujawwad_64kbps/',
  'ar.husary': 'https://everyayah.com/data/Husary_64kbps/',
  'ar.shuraym': 'https://everyayah.com/data/Saood_ash-Shuraym_64kbps/',
  'ar.yasseraldossari': 'https://everyayah.com/data/Yasser_Ad-Dussary_128kbps/',
};

/// Belirtilen okuyucu ve ayet için everyayah.com MP3 URL'si.
/// ayahNumber 0 = besmele (1. ve 9. sure hariç); aynı okuyucunun Fatiha 1 sesi kullanılır.
String? getAyahAudioUrl(String reciterKey, int surahNumber, int ayahNumber) {
  final base = _reciterBaseUrls[reciterKey];
  if (base == null) return null;
  if (ayahNumber == 0) {
    return '${base}001001.mp3';
  }
  final s = surahNumber.toString().padLeft(3, '0');
  final a = ayahNumber.toString().padLeft(3, '0');
  return '$base$s$a.mp3';
}
