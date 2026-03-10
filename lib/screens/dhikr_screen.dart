import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../l10n/app_localizations.dart';
import '../utils/scaling.dart';
import '../widgets/rn_segment_bar.dart';

/// Flutter equivalent of RN DhikrScreen – Dua & Dhikr with categories (morning, evening, daily) and counters.
class DhikrScreen extends StatefulWidget {
  const DhikrScreen({super.key});

  @override
  State<DhikrScreen> createState() => _DhikrScreenState();
}

class _DhikrScreenState extends State<DhikrScreen> {
  String _selectedCategory = 'morning';
  final Map<int, int> _counters = {};

  static const Map<String, Map<String, dynamic>> _categories = {
    'morning': {
      'nameKey': 'morningDhikr',
      'icon': Icons.wb_sunny_outlined,
      'color': 0xFFF59E0B,
      'dhikrs': [
        {'id': 1, 'arabic': 'سُبْحَانَ اللَّهِ', 'transliteration': 'Subhanallah', 'meaningKey': 'dhikrSubhanallah', 'count': 33},
        {'id': 2, 'arabic': 'الْحَمْدُ لِلَّهِ', 'transliteration': 'Alhamdulillah', 'meaningKey': 'dhikrAlhamdulillah', 'count': 33},
        {'id': 3, 'arabic': 'اللَّهُ أَكْبَرُ', 'transliteration': 'Allahu Akbar', 'meaningKey': 'dhikrAllahuAkbar', 'count': 33},
        {'id': 4, 'arabic': 'لَا إِلَٰهَ إِلَّا اللَّهُ', 'transliteration': 'La ilaha illallah', 'meaningKey': 'dhikrLaIlahaIllallah', 'count': 100},
      ],
    },
    'evening': {
      'nameKey': 'eveningDhikr',
      'icon': Icons.nightlight_round_outlined,
      'color': 0xFF8B5CF6,
      'dhikrs': [
        {'id': 5, 'arabic': 'سُبْحَانَ اللَّهِ', 'transliteration': 'Subhanallah', 'meaningKey': 'dhikrSubhanallah', 'count': 33},
        {'id': 6, 'arabic': 'الْحَمْدُ لِلَّهِ', 'transliteration': 'Alhamdulillah', 'meaningKey': 'dhikrAlhamdulillah', 'count': 33},
        {'id': 7, 'arabic': 'اللَّهُ أَكْبَرُ', 'transliteration': 'Allahu Akbar', 'meaningKey': 'dhikrAllahuAkbar', 'count': 33},
        {'id': 8, 'arabic': 'أَسْتَغْفِرُ اللَّه', 'transliteration': 'Astaghfirullah', 'meaningKey': 'dhikrAstaghfirullah', 'count': 100},
      ],
    },
    'daily': {
      'nameKey': 'dailyPrayers',
      'icon': Icons.menu_book_outlined,
      'color': 0xFF10B981,
      'dhikrs': [
        {'id': 9, 'arabic': 'رَبَّنَا آتِنَا فِي الدُّنْيَا حَسَنَةً', 'transliteration': 'Rabbana atina fid-dunya hasanatan', 'meaningKey': 'dhikrRabbanaAtina', 'count': 0},
        {'id': 10, 'arabic': 'اللَّهُمَّ بَارِكْ لَنَا فِي رِزْقِنَا', 'transliteration': 'Allahumma barik lana fi rizqina', 'meaningKey': 'dhikrAllahummaBarik', 'count': 0},
        {'id': 11, 'arabic': 'اللَّهُمَّ اغْفِرْ لِي', 'transliteration': 'Allahumma ighfir li', 'meaningKey': 'dhikrAllahummaIghfirLi', 'count': 0},
      ],
    },
  };

  void _incrementCounter(int id) {
    setState(() {
      _counters[id] = (_counters[id] ?? 0) + 1;
    });
  }

  void _resetCounter(int id) {
    setState(() {
      _counters[id] = 0;
    });
  }

  void _showCategoryModal(BuildContext context) {
    String t(String key) => AppLocalizations.t(context, key);
    // RN: modal centered, 85% width max 400, items #F8F9FA, active #EEF2FF border #6366F1, checkmark when active
    showDialog<void>(
      context: context,
      barrierColor: const Color(0x66000000),
      builder: (ctx) => Center(
        child: Material(
          color: Colors.transparent,
          child: Container(
            width: MediaQuery.of(context).size.width * 0.85,
            constraints: BoxConstraints(maxWidth: scaleSize(context, 400), maxHeight: MediaQuery.of(context).size.height * 0.70),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(scaleSize(context, 20)),
              boxShadow: [
                BoxShadow(color: Colors.black.withValues(alpha: 0.25), blurRadius: 20, offset: Offset(0, scaleSize(context, 10))),
              ],
            ),
            child: ListView(
              padding: EdgeInsets.symmetric(horizontal: scaleSize(context, 16), vertical: scaleSize(context, 12)),
              shrinkWrap: true,
              children: [
                for (final entry in _categories.entries) ...[
                  Material(
                    color: _selectedCategory == entry.key ? const Color(0xFFEEF2FF) : const Color(0xFFF8F9FA),
                    borderRadius: BorderRadius.circular(scaleSize(context, 12)),
                    child: InkWell(
                      onTap: () {
                        setState(() => _selectedCategory = entry.key);
                        Navigator.of(ctx).pop();
                      },
                      borderRadius: BorderRadius.circular(scaleSize(context, 12)),
                      child: Container(
                        padding: EdgeInsets.symmetric(vertical: scaleSize(context, 12), horizontal: scaleSize(context, 16)),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(scaleSize(context, 12)),
                          border: _selectedCategory == entry.key
                              ? Border.all(color: const Color(0xFF6366F1), width: scaleSize(context, 1.5))
                              : null,
                        ),
                        child: Row(
                          children: [
                            Icon(entry.value['icon'] as IconData, size: scaleSize(context, 24), color: _selectedCategory == entry.key ? Color(entry.value['color'] as int) : const Color(0xFF64748B)),
                            SizedBox(width: scaleSize(context, 8)),
                            Expanded(child: Text(t(entry.value['nameKey'] as String), style: GoogleFonts.plusJakartaSans(fontSize: scaleFont(context, 16), fontWeight: FontWeight.w600, color: _selectedCategory == entry.key ? const Color(0xFF6366F1) : const Color(0xFF1E293B)))),
                            if (_selectedCategory == entry.key) Icon(Icons.check_circle, size: scaleSize(context, 20), color: Color(entry.value['color'] as int)),
                          ],
                        ),
                      ),
                    ),
                  ),
                  SizedBox(height: scaleSize(context, 8)),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    String t(String key) => AppLocalizations.t(context, key);
    final category = _categories[_selectedCategory]!;
    final color = Color(category['color'] as int);
    final headerHeight = scaleSize(context, 80);

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      body: SafeArea(
        top: true,
        child: Column(
          children: [
            // Segment: Prayer|Dua – same position as Prayer screen (top row, left 20)
            Padding(
              padding: EdgeInsets.fromLTRB(scaleSize(context, 20), scaleSize(context, 4), scaleSize(context, 20), scaleSize(context, 6)),
              child: Row(
                children: [
                  RnSegmentBar(
                    scaleContext: context,
                    labels: [t('prayer'), t('Dua')],
                    selectedIndex: 1,
                    onSelected: (i) { if (i == 0) Navigator.of(context).pop(); },
                  ),
                  const Spacer(),
                ],
              ),
            ),
            // Header: fixed height 80, logo bg, category selector center
            SizedBox(
              height: headerHeight,
              child: Stack(
                alignment: Alignment.center,
                children: [
                  Positioned.fill(
                    child: ClipRRect(
                      borderRadius: BorderRadius.vertical(bottom: Radius.circular(scaleSize(context, 24))),
                      child: Opacity(
                        opacity: 0.01,
                        child: Image.asset('assets/nida.png', fit: BoxFit.cover),
                      ),
                    ),
                  ),
                  GestureDetector(
                    onTap: () => _showCategoryModal(context),
                    child: Container(
                      padding: EdgeInsets.symmetric(horizontal: scaleSize(context, 20), vertical: scaleSize(context, 10)),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(category['icon'] as IconData, size: scaleSize(context, 22), color: color),
                          SizedBox(width: scaleSize(context, 6)),
                          Text(
                            t(category['nameKey'] as String),
                            style: GoogleFonts.plusJakartaSans(fontSize: scaleFont(context, 20), fontWeight: FontWeight.bold, color: const Color(0xFF6366F1)),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          SizedBox(width: scaleSize(context, 4)),
                          Icon(Icons.keyboard_arrow_down, size: scaleSize(context, 17), color: color),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
            // Content: padding 20, dhikr list, total counter – RN duaContainer
            Expanded(
              child: ListView(
                padding: EdgeInsets.fromLTRB(scaleSize(context, 20), scaleSize(context, 20), scaleSize(context, 20), scaleSize(context, 100)),
                children: [
                  for (final d in category['dhikrs'] as List<dynamic>)
                    _DhikrCard(
                      arabic: d['arabic'] as String,
                      transliteration: d['transliteration'] as String,
                      meaningKey: d['meaningKey'] as String,
                      count: d['count'] as int,
                      currentCount: _counters[d['id'] as int] ?? 0,
                      color: color,
                      onIncrement: () => _incrementCounter(d['id'] as int),
                      onReset: () => _resetCounter(d['id'] as int),
                    ),
                  if (_selectedCategory != 'daily') ...[
                    SizedBox(height: scaleSize(context, 20)),
                    Container(
                      padding: EdgeInsets.all(scaleSize(context, 24)),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(scaleSize(context, 16)),
                        boxShadow: [
                          BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 8, offset: Offset(0, scaleSize(context, 2))),
                        ],
                      ),
                      child: Column(
                        children: [
                          Padding(
                            padding: EdgeInsets.only(bottom: scaleSize(context, 8)),
                            child: Text(t('totalDhikr'), style: GoogleFonts.plusJakartaSans(fontSize: scaleFont(context, 16), color: const Color(0xFF64748B))),
                          ),
                          Text(
                            '${(category['dhikrs'] as List<dynamic>).fold<int>(0, (sum, d) => sum + (_counters[d['id'] as int] ?? 0))}',
                            style: GoogleFonts.plusJakartaSans(fontSize: scaleFont(context, 48), fontWeight: FontWeight.bold, color: const Color(0xFF6366F1)),
                          ),
                        ],
                      ),
                    ),
                    SizedBox(height: scaleSize(context, 40)),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _DhikrCard extends StatelessWidget {
  final String arabic;
  final String transliteration;
  final String meaningKey;
  final int count;
  final int currentCount;
  final Color color;
  final VoidCallback onIncrement;
  final VoidCallback onReset;

  const _DhikrCard({
    required this.arabic,
    required this.transliteration,
    required this.meaningKey,
    required this.count,
    required this.currentCount,
    required this.color,
    required this.onIncrement,
    required this.onReset,
  });

  @override
  Widget build(BuildContext context) {
    String t(String key) => AppLocalizations.t(context, key);
    final isComplete = count > 0 && currentCount >= count;

    // Layout: Arabic sağ üst; transliteration + meal + 0/33 solda; kart yüksekliği düşük
    return Container(
      margin: EdgeInsets.only(bottom: scaleSize(context, 6)),
      padding: EdgeInsets.symmetric(horizontal: scaleSize(context, 10), vertical: scaleSize(context, 6)),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(scaleSize(context, 12)),
        boxShadow: [
          BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: scaleSize(context, 6), offset: Offset(0, scaleSize(context, 1))),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          // Arabic: sağ üst (top right)
          Align(
            alignment: Alignment.centerRight,
            child: Text(
              arabic,
              textAlign: TextAlign.right,
              style: GoogleFonts.notoNaskhArabic(
                fontWeight: FontWeight.w400,
                fontSize: scaleFont(context, 24),
                height: 1.0,
                color: const Color(0xFF1E293B),
              ),
            ),
          ),
          SizedBox(height: scaleSize(context, 5)),
          // Transliteration + meaning: solda (left)
          Align(
            alignment: Alignment.centerLeft,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  transliteration,
                  textAlign: TextAlign.left,
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: scaleFont(context, 15),
                    fontStyle: FontStyle.italic,
                    color: const Color(0xFF64748B),
                  ),
                ),
                SizedBox(height: scaleSize(context, 2)),
                Text(
                  t(meaningKey),
                  textAlign: TextAlign.left,
                  style: GoogleFonts.plusJakartaSans(fontSize: scaleFont(context, 15), color: const Color(0xFF475569)),
                ),
              ],
            ),
          ),
          // 0/33: solda meal altında gri container
          if (count > 0) ...[
            SizedBox(height: scaleSize(context, 4)),
            Align(
              alignment: Alignment.centerLeft,
              child: Container(
                padding: EdgeInsets.symmetric(horizontal: scaleSize(context, 8), vertical: scaleSize(context, 4)),
                decoration: BoxDecoration(
                  color: const Color(0xFFF1F5F9),
                  borderRadius: BorderRadius.circular(scaleSize(context, 8)),
                ),
                child: Text(
                  '$currentCount / $count',
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: scaleFont(context, 12),
                    fontWeight: FontWeight.bold,
                    color: isComplete ? const Color(0xFF10B981) : const Color(0xFF1E293B),
                  ),
                ),
              ),
            ),
          ],
          SizedBox(height: scaleSize(context, 5)),
          if (count > 0)
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                GestureDetector(
                  onTap: onReset,
                  child: Container(
                    width: scaleSize(context, 32),
                    height: scaleSize(context, 32),
                    decoration: BoxDecoration(color: const Color(0xFFF1F5F9), borderRadius: BorderRadius.circular(scaleSize(context, 16))),
                    alignment: Alignment.center,
                    child: Icon(Icons.refresh, size: scaleSize(context, 16), color: color),
                  ),
                ),
                SizedBox(width: scaleSize(context, 10)),
                GestureDetector(
                  onTap: onIncrement,
                  child: Container(
                    width: scaleSize(context, 42),
                    height: scaleSize(context, 42),
                    decoration: BoxDecoration(
                      color: color,
                      borderRadius: BorderRadius.circular(scaleSize(context, 21)),
                      boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.2), blurRadius: scaleSize(context, 4), offset: Offset(0, scaleSize(context, 2)))],
                    ),
                    alignment: Alignment.center,
                    child: Icon(Icons.add, size: scaleSize(context, 24), color: Colors.white),
                  ),
                ),
                SizedBox(width: scaleSize(context, 12)),
                if (isComplete)
                  Container(
                    padding: EdgeInsets.symmetric(horizontal: scaleSize(context, 8), vertical: scaleSize(context, 3)),
                    decoration: BoxDecoration(color: const Color(0xFFECFDF5), borderRadius: BorderRadius.circular(scaleSize(context, 12))),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.check_circle, size: scaleSize(context, 14), color: const Color(0xFF10B981)),
                        SizedBox(width: scaleSize(context, 3)),
                        Text(t('completed'), style: GoogleFonts.plusJakartaSans(fontSize: scaleFont(context, 10), fontWeight: FontWeight.w600, color: const Color(0xFF10B981))),
                      ],
                    ),
                  ),
              ],
            )
          else
            Material(
              color: const Color(0xFFF1F5F9),
              borderRadius: BorderRadius.circular(scaleSize(context, 8)),
              child: InkWell(
                onTap: () {},
                borderRadius: BorderRadius.circular(scaleSize(context, 8)),
                child: Padding(
                  padding: EdgeInsets.symmetric(vertical: scaleSize(context, 6), horizontal: scaleSize(context, 10)),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.favorite_border, size: scaleSize(context, 16), color: color),
                      SizedBox(width: scaleSize(context, 4)),
                      Text(t('addToFavorites'), style: GoogleFonts.plusJakartaSans(fontSize: scaleFont(context, 11), fontWeight: FontWeight.w600, color: color)),
                    ],
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
