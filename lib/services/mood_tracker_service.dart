import 'package:shared_preferences/shared_preferences.dart';

/// Mood values: 'sad' | 'neutral' | 'happy'
class MoodTrackerService {
  static const _moodKey    = 'prayer_moods';
  static const _checkedKey = 'prayer_moods_checked';

  static String _todayStr() {
    final n = DateTime.now();
    return '${n.year}-${n.month.toString().padLeft(2, '0')}-${n.day.toString().padLeft(2, '0')}';
  }

  // ── Read ──────────────────────────────────────────────────────────────────

  /// Returns {prayerKey: mood} for today.
  static Future<Map<String, String>> getTodayMoods() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString('${_moodKey}_${_todayStr()}') ?? '';
    if (raw.isEmpty) return {};
    final map = <String, String>{};
    for (final pair in raw.split(';')) {
      final p = pair.split(':');
      if (p.length == 2 && p[0].isNotEmpty) map[p[0]] = p[1];
    }
    return map;
  }

  // ── Write ─────────────────────────────────────────────────────────────────

  /// Save mood for a prayer and mark it as checked.
  static Future<void> saveMood(String prayerKey, String mood) async {
    final prefs = await SharedPreferences.getInstance();
    final today = _todayStr();

    // Update mood map
    final existing = await getTodayMoods();
    existing[prayerKey] = mood;
    final encoded = existing.entries.map((e) => '${e.key}:${e.value}').join(';');
    await prefs.setString('${_moodKey}_$today', encoded);

    // Mark checked
    await _markChecked(prayerKey, prefs, today);
  }

  static Future<void> _markChecked(
    String prayerKey,
    SharedPreferences prefs,
    String today,
  ) async {
    final raw = prefs.getString('${_checkedKey}_$today') ?? '';
    final checked = raw.isEmpty ? <String>[] : raw.split(',');
    if (!checked.contains(prayerKey)) {
      checked.add(prayerKey);
      await prefs.setString('${_checkedKey}_$today', checked.join(','));
    }
  }

  static Future<bool> _isChecked(String prayerKey) async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString('${_checkedKey}_${_todayStr()}') ?? '';
    return raw.split(',').contains(prayerKey);
  }

  // ── Logic ─────────────────────────────────────────────────────────────────

  /// Returns the key of the CURRENT prayer period if it hasn't been checked yet.
  /// "Current" = the most recently passed prayer we're still in.
  /// Missed prayers (older ones that were never checked) are intentionally ignored.
  static Future<String?> getNextUncheckedPrayer(Map<String, String> times) async {
    final now = DateTime.now();
    final nowMins = now.hour * 60 + now.minute;

    const prayers = ['fajr', 'dhuhr', 'asr', 'maghrib', 'isha'];

    // Find the most recently passed prayer (the one we're currently in).
    String? currentPrayer;
    for (final key in prayers) {
      final t = times[key] ?? '';
      final parts = t.split(':');
      if (parts.length < 2) continue;
      final pMins = (int.tryParse(parts[0]) ?? 0) * 60 + (int.tryParse(parts[1]) ?? 0);
      if (nowMins >= pMins) currentPrayer = key; // keep overwriting → last wins
    }

    if (currentPrayer == null) return null;
    // Only ask if current period hasn't been checked yet.
    return await _isChecked(currentPrayer) ? null : currentPrayer;
  }
}
