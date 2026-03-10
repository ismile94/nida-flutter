import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../contexts/theme_provider.dart';
import '../utils/scaling.dart';
import 'remote_content_card.dart';
import 'ramadan_fast_tracker.dart';
import 'dua_card.dart';
import 'hadith_card.dart';
import 'esmaulhusna_card.dart';

/// Renders the content cards below the prayer time row – in the same order
/// as the RN HomeScreen: Remote Content → [Fast tracker if Ramadan] → Dua → Hadith → Esmaul Husna.
class HomeContentCards extends StatelessWidget {
  final String prayerTime;
  final String? mood;
  final bool isRamadan;
  final bool isKandil;
  /// Current Hijri day of Ramadan (1–30). Required when [isRamadan] is true.
  final int hijriDay;
  /// Current Hijri year (e.g. 1447). Required when [isRamadan] is true.
  final int hijriYear;

  const HomeContentCards({
    super.key,
    this.prayerTime = 'fajr',
    this.mood,
    this.isRamadan = false,
    this.isKandil = false,
    this.hijriDay = 1,
    this.hijriYear = 1447,
  });

  @override
  Widget build(BuildContext context) {
    // Watch locale so that when the language changes the cards reload their content.
    final locale = context.watch<ThemeProvider>().language;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // 1. Remote content image card (between prayer times and Dua)
        const RemoteContentCard(),
        // 2. Ramadan fasting tracker — only shown during Ramadan
        if (isRamadan)
          RamadanFastTracker(
            hijriDay: hijriDay,
            hijriYear: hijriYear,
          ),
        SizedBox(height: scaleSize(context, 4)),
        // 3. Dua card — key forces rebuild on locale change
        DuaCard(
          key: ValueKey('dua_${prayerTime}_$locale'),
          prayerTime: prayerTime,
          mood: mood,
          isRamadan: isRamadan,
          isKandil: isKandil,
        ),
        SizedBox(height: scaleSize(context, 4)),
        // 3. Hadith card
        HadithCard(
          key: ValueKey('hadith_${prayerTime}_$locale'),
          prayerTime: prayerTime,
          mood: mood,
          isRamadan: isRamadan,
          isKandil: isKandil,
        ),
        SizedBox(height: scaleSize(context, 4)),
        // 4. Esmaul Husna card
        EsmaulHusnaCard(
          key: ValueKey('esma_$locale'),
          isRamadan: isRamadan,
          isKandil: isKandil,
        ),
      ],
    );
  }
}
