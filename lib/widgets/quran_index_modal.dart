// components/quran_index_modal.dart
// React Native QuranIndexModal.js → Flutter birebir portu.
// Fade animasyonu, seçim çizgileri, opacity efekti, 5 görünür item,
// 20/55/20 genişlik oranı, momentum fizik, debounced önizleme.

import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/physics.dart';
import 'package:google_fonts/google_fonts.dart';
import '../l10n/app_localizations.dart';
import '../data/page_ayah_map.dart';
import '../data/surah_meta.dart';
import '../services/quran_service.dart'
    show calculateJuzByPage, getJuzStartPage;
import '../utils/scaling.dart';

// ─── Renkler (RN styles birebir) ──────────────────────────────────────────────
const Color _overlayColor = Color(0x338B7355); // rgba(139,115,85,0.2)
const Color _modalBg = Color(0xFFE8E0D3);
const Color _accentColor = Color(0xFF8B7355);

// ─── Sabit: seçili surenin ayet sayısı ────────────────────────────────────────
int _ayahCount(int surahNumber) =>
    kSurahMeta[(surahNumber - 1).clamp(0, 113)].numberOfAyahs;

// ─── iPhone tarzı momentum fizik ──────────────────────────────────────────────
// Düşük sürtünme katsayısı → parmak çekilince tekerlek uzun döner.
// FixedExtentScrollPhysics parent olarak eklenince momentum bittikten sonra
// item sınırına snap eder.
class _MomentumPhysics extends ScrollPhysics {
  const _MomentumPhysics({super.parent});

  @override
  _MomentumPhysics applyTo(ScrollPhysics? ancestor) =>
      _MomentumPhysics(parent: buildParent(ancestor));

  @override
  Simulation? createBallisticSimulation(
      ScrollMetrics position, double velocity) {
    // Sınırdaysa parent'a bırak (sıçramayı önler)
    if ((velocity <= 0.0 && position.pixels <= position.minScrollExtent) ||
        (velocity >= 0.0 && position.pixels >= position.maxScrollExtent)) {
      return super.createBallisticSimulation(position, velocity);
    }
    // Düşük sürtünme = uzun atalet hareketi
    return BoundedFrictionSimulation(
      0.00025,
      position.pixels,
      velocity,
      position.minScrollExtent,
      position.maxScrollExtent,
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════════
//  Ana widget
// ═══════════════════════════════════════════════════════════════════════════════
class QuranIndexModal extends StatefulWidget {
  final bool visible;
  final VoidCallback onClose;
  final void Function(int page)? onPreviewPage;
  final void Function(int page)? onCommitPage;
  final int currentPage;
  final int? pageInfoSurah;
  final int? pageInfoAyah;

  const QuranIndexModal({
    super.key,
    required this.visible,
    required this.onClose,
    this.onPreviewPage,
    this.onCommitPage,
    this.currentPage = 1,
    this.pageInfoSurah,
    this.pageInfoAyah,
  });

  @override
  State<QuranIndexModal> createState() => _QuranIndexModalState();
}

class _QuranIndexModalState extends State<QuranIndexModal>
    with SingleTickerProviderStateMixin {
  // ── Fade animasyonu ────────────────────────────────────────────────────────
  // RN: animationType="fade"  →  220 ms easeInOut
  late final AnimationController _fadeCtrl;
  late final Animation<double> _fadeAnim;

  // ── Yükleme durumu ─────────────────────────────────────────────────────────
  bool _dataLoaded = false;

  // ── Seçili değerler (1 tabanlı) ───────────────────────────────────────────
  int _juz = 1;
  int _surah = 1;
  int _ayah = 1;

  // ── Önizleme debounce (RN: 100ms) ────────────────────────────────────────
  Timer? _previewDebounce;
  static const _kDebounceMs = 100;

  // ── Tekerlek kontrolörleri ─────────────────────────────────────────────────
  late final FixedExtentScrollController _juzCtrl;
  late final FixedExtentScrollController _surahCtrl;
  late final FixedExtentScrollController _ayahCtrl;

  // ── Programatik senkronizasyon kilidi ─────────────────────────────────────
  // jumpToItem çağrıları onSelectedItemChanged'i tetikler; bu bayrak
  // zincirleme döngüyü kırar.
  bool _isProgrammaticSync = false;

  // ─────────────────────────────────────────────────────────────────────────
  @override
  void initState() {
    super.initState();

    _fadeCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 220),
    );
    _fadeAnim = CurvedAnimation(parent: _fadeCtrl, curve: Curves.easeInOut);

    _juzCtrl = FixedExtentScrollController(initialItem: 0);
    _surahCtrl = FixedExtentScrollController(initialItem: 0);
    _ayahCtrl = FixedExtentScrollController(initialItem: 0);

    // Modal zaten açıksa animasyonu sıfırdan başlatma
    if (widget.visible) _fadeCtrl.value = 1.0;

    _loadInitial();
  }

  @override
  void didUpdateWidget(covariant QuranIndexModal old) {
    super.didUpdateWidget(old);

    // Fade animasyonu: açılış / kapanış
    if (widget.visible && !old.visible) _fadeCtrl.forward();
    if (!widget.visible && old.visible) _fadeCtrl.reverse();

    // Sadece modal yeni AÇILDIĞINDA tekerlekleri senkronize et.
    // Kullanıcı kaydırırken parent currentPage değişir ama jump YAPMA —
    // akıcılığı bozar.
    if (widget.visible && !old.visible && _dataLoaded) {
      _syncToPage(
          widget.currentPage, widget.pageInfoSurah, widget.pageInfoAyah);
    }
  }

  @override
  void dispose() {
    _previewDebounce?.cancel();
    _fadeCtrl.dispose();
    _juzCtrl.dispose();
    _surahCtrl.dispose();
    _ayahCtrl.dispose();
    super.dispose();
  }

  // ── Veri önbelleğini ısıt, sonra ilk senkronu yap ───────────────────────
  Future<void> _loadInitial() async {
    await getPageStartAyah(1); // page_ayah_map cache ısınması
    if (!mounted) return;
    setState(() => _dataLoaded = true);
    await _syncToPage(
        widget.currentPage, widget.pageInfoSurah, widget.pageInfoAyah);
    if (widget.visible) _fadeCtrl.forward();
  }

  // ── Sayfa numarasından juz/surah/ayah senkronu ───────────────────────────
  Future<void> _syncToPage(int page, int? infoSurah, int? infoAyah) async {
    final juz = calculateJuzByPage(page);
    int surah = infoSurah ?? 1;
    int ayah = infoAyah ?? 1;

    // pageInfo yoksa page_ayah_map'ten bul
    if (infoSurah == null || infoAyah == null) {
      final start = await getPageStartAyah(page);
      if (start != null) {
        surah = start.surah;
        ayah = start.ayah;
      }
    }
    if (!mounted) return;

    _isProgrammaticSync = true;
    setState(() {
      _juz = juz;
      _surah = surah.clamp(1, 114);
      _ayah = ayah.clamp(1, _ayahCount(surah));
    });

    // İki frame bekle: (1) setState build'e yansısın,
    // (2) ayah tekerleği yeni itemCount ile yeniden oluşturulsun,
    // sonra jump yap.
    _postFrameX2(() {
      if (!mounted) return;
      _safeJump(_juzCtrl, (_juz - 1).clamp(0, 29));
      _safeJump(_surahCtrl, (_surah - 1).clamp(0, 113));
      _safeJump(_ayahCtrl, (_ayah - 1).clamp(0, _ayahCount(_surah) - 1));
      WidgetsBinding.instance
          .addPostFrameCallback((_) => _isProgrammaticSync = false);
    });
  }

  // ── Yardımcılar ──────────────────────────────────────────────────────────
  void _safeJump(FixedExtentScrollController ctrl, int index) {
    if (!ctrl.hasClients) return;
    ctrl.jumpToItem(index);
  }

  /// İki ardışık postFrameCallback — setState'in ve widget rebuild'in
  /// tamamlandığından emin olmak için.
  void _postFrameX2(VoidCallback fn) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      WidgetsBinding.instance.addPostFrameCallback((_) => fn());
    });
  }

  // ── Debounced önizleme ────────────────────────────────────────────────────
  void _notifyPreview(int page) {
    _previewDebounce?.cancel();
    _previewDebounce = Timer(
      const Duration(milliseconds: _kDebounceMs),
      () => widget.onPreviewPage?.call(page),
    );
  }

  // ── Event Handler 1: Cüz seçimi ───────────────────────────────────────────
  Future<void> _onJuzChanged(int index) async {
    if (!mounted || _isProgrammaticSync) return;
    final juzNum = index + 1;
    final page = getJuzStartPage(juzNum);
    final start = await getPageStartAyah(page);
    final surah = (start?.surah ?? 1).clamp(1, 114);
    final ayah = (start?.ayah ?? 1).clamp(1, _ayahCount(surah));
    if (!mounted) return;

    _isProgrammaticSync = true;
    setState(() {
      _juz = juzNum;
      _surah = surah;
      _ayah = ayah;
    });
    _notifyPreview(page);

    _postFrameX2(() {
      if (!mounted) return;
      _safeJump(_surahCtrl, (surah - 1).clamp(0, 113));
      _safeJump(_ayahCtrl, (ayah - 1).clamp(0, _ayahCount(surah) - 1));
      WidgetsBinding.instance
          .addPostFrameCallback((_) => _isProgrammaticSync = false);
    });
  }

  // ── Event Handler 2: Sure seçimi ─────────────────────────────────────────
  Future<void> _onSurahChanged(int index) async {
    if (!mounted || _isProgrammaticSync) return;
    final surahNum = index + 1;
    final page = await getPageForSurahAyah(surahNum, 1) ?? 1;
    final juz = calculateJuzByPage(page);
    if (!mounted) return;

    _isProgrammaticSync = true;
    setState(() {
      _surah = surahNum;
      _ayah = 1;
      _juz = juz;
    });
    _notifyPreview(page);

    _postFrameX2(() {
      if (!mounted) return;
      _safeJump(_juzCtrl, (juz - 1).clamp(0, 29));
      _safeJump(_ayahCtrl, 0);
      WidgetsBinding.instance
          .addPostFrameCallback((_) => _isProgrammaticSync = false);
    });
  }

  // ── Event Handler 3: Ayet seçimi ─────────────────────────────────────────
  Future<void> _onAyahChanged(int index) async {
    if (!mounted || _isProgrammaticSync) return;
    final ayahNum = index + 1;
    final page = await getPageForSurahAyah(_surah, ayahNum) ?? 1;
    final juz = calculateJuzByPage(page);
    if (!mounted) return;

    _isProgrammaticSync = true;
    setState(() {
      _ayah = ayahNum;
      _juz = juz;
    });
    _notifyPreview(page);

    _postFrameX2(() {
      if (!mounted) return;
      _safeJump(_juzCtrl, (juz - 1).clamp(0, 29));
      WidgetsBinding.instance
          .addPostFrameCallback((_) => _isProgrammaticSync = false);
    });
  }

  // ═════════════════════════════════════════════════════════════════════════
  //  BUILD
  // ═════════════════════════════════════════════════════════════════════════
  @override
  Widget build(BuildContext context) {
    if (!widget.visible && _fadeCtrl.isDismissed) return const SizedBox.shrink();

    final mq = MediaQuery.of(context);
    final sw = mq.size.width;
    final sh = mq.size.height;
    final isLandscape = sw > sh;

    final portraitW = isLandscape ? sh : sw;
    final portraitH = isLandscape ? sw : sh;

    final modalW = (isLandscape ? portraitW * 0.78 : sw * 0.78)
        .clamp(0.0, isLandscape ? scaleSize(context, 320) : double.infinity);
    final modalH = (isLandscape ? portraitH * 0.22 : sh * 0.22)
        .clamp(0.0, isLandscape ? scaleSize(context, 200) : double.infinity);

    final hPad = scaleSize(context, 10.0);
    final contentW = modalW - (hPad * 2);

    final itemH = scaleSize(context, 24.0);
    final wheelH = itemH * 5;

    return FadeTransition(
      opacity: _fadeAnim,
      child: Stack(
        children: [
          // ── Overlay: tıklanınca kapat ──────────────────────────────────
          Positioned.fill(
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: widget.onClose,
              child: const ColoredBox(color: _overlayColor),
            ),
          ),

          // ── Modal ──────────────────────────────────────────────────────
          Center(
            child: GestureDetector(
              onTap: () {},
              child: Material(
                color: Colors.transparent,
                child: Container(
                  width: modalW,
                  height: modalH,
                  decoration: BoxDecoration(
                    color: _modalBg,
                    borderRadius: BorderRadius.circular(scaleSize(context, 16)),
                  ),
                  padding: EdgeInsets.fromLTRB(
                    hPad,
                    scaleSize(context, 8),
                    hPad,
                    scaleSize(context, 6),
                  ),
                  child: !_dataLoaded
                      ? _buildLoading(context)
                      : _buildContent(context, contentW, wheelH, itemH),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLoading(BuildContext context) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        CircularProgressIndicator(
          color: _accentColor,
          strokeWidth: scaleSize(context, 2),
        ),
        SizedBox(height: scaleSize(context, 12)),
        Text(
          AppLocalizations.t(context, 'loading'),
          style: GoogleFonts.plusJakartaSans(
            fontSize: scaleFont(context, 16),
            color: _accentColor,
          ),
        ),
      ],
    );
  }

  Widget _buildContent(
      BuildContext context, double contentW, double wheelH, double itemH) {
    String t(String k) => AppLocalizations.t(context, k);

    final gap = scaleSize(context, 5);
    final totalWheelsW = contentW - (gap * 2);
    final juzW = totalWheelsW * 0.16;
    final surahW = totalWheelsW * 0.52;
    final ayahW = totalWheelsW * 0.16;

    return Column(
      mainAxisSize: MainAxisSize.max,
      children: [
        // ── Başlık satırı ────────────────────────────────────────────────
        Padding(
          padding: EdgeInsets.only(bottom: scaleSize(context, 2)),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              SizedBox(width: gap),
              SizedBox(
                width: juzW,
                child: Text(t('juz'),
                    textAlign: TextAlign.center,
                    style: GoogleFonts.plusJakartaSans(
                        fontSize: scaleFont(context, 16),
                        fontWeight: FontWeight.bold,
                        color: _accentColor)),
              ),
              SizedBox(width: gap),
              SizedBox(
                width: surahW,
                child: Text(t('surah'),
                    textAlign: TextAlign.center,
                    style: GoogleFonts.plusJakartaSans(
                        fontSize: scaleFont(context, 16),
                        fontWeight: FontWeight.bold,
                        color: _accentColor)),
              ),
              SizedBox(width: gap),
              SizedBox(
                width: ayahW,
                child: Text(t('ayah'),
                    textAlign: TextAlign.center,
                    style: GoogleFonts.plusJakartaSans(
                        fontSize: scaleFont(context, 16),
                        fontWeight: FontWeight.bold,
                        color: _accentColor)),
              ),
              SizedBox(width: gap),
            ],
          ),
        ),

        Divider(height: 1, thickness: 1, color: _accentColor.withValues(alpha: 0.4)),
        SizedBox(height: scaleSize(context, 2)),

        // ── Tekerlek satırı ──────────────────────────────────────────────
        Expanded(
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              SizedBox(width: gap),
              _WheelColumn(
                controller: _juzCtrl,
                width: juzW,
                height: wheelH,
                itemExtent: itemH,
                itemCount: 30,
                selectedIndex: _juz - 1,
                labelBuilder: (i) => '${i + 1}',
                onChanged: _onJuzChanged,
              ),
              SizedBox(width: gap),
              _WheelColumn(
                controller: _surahCtrl,
                width: surahW,
                height: wheelH,
                itemExtent: itemH,
                itemCount: 114,
                selectedIndex: _surah - 1,
                labelBuilder: (i) {
                  final s = kSurahMeta[i];
                  final name = s.name.length > 15
                      ? '${s.name.substring(0, 15)}...'
                      : s.name;
                  return '${s.number}. $name';
                },
                onChanged: _onSurahChanged,
              ),
              SizedBox(width: gap),
              _WheelColumn(
                key: ValueKey(_surah),
                controller: _ayahCtrl,
                width: ayahW,
                height: wheelH,
                itemExtent: itemH,
                itemCount: _ayahCount(_surah),
                selectedIndex: _ayah - 1,
                labelBuilder: (i) => '${i + 1}',
                onChanged: _onAyahChanged,
              ),
              SizedBox(width: gap),
            ],
          ),
        ),
      ],
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════════
//  _WheelColumn — react-native-wheely görünümünü taklit eden tekerlek widget'ı
// ═══════════════════════════════════════════════════════════════════════════════
class _WheelColumn extends StatelessWidget {
  final FixedExtentScrollController controller;
  final double width;
  final double height;
  final double itemExtent;
  final int itemCount;
  final int selectedIndex;
  final String Function(int) labelBuilder;
  final void Function(int) onChanged;

  const _WheelColumn({
    super.key,
    required this.controller,
    required this.width,
    required this.height,
    required this.itemExtent,
    required this.itemCount,
    required this.selectedIndex,
    required this.labelBuilder,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    if (width <= 0 || height <= 0 || itemCount <= 0) {
      return SizedBox(width: width, height: height);
    }

    return SizedBox(
      width: width,
      height: height,
      child: Stack(
        children: [

          // ── 1. Seçili item arka planı (beyaz, yuvarlak köşe) ────────────
          Positioned(
            left: 0,
            right: 0,
            top: (height - itemExtent) / 2,
            height: itemExtent,
            child: Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(scaleSize(context, 6)),
              ),
            ),
          ),

          // ── 2. Tekerlek + snap ───────────────────────────────────────────
          // FixedExtentScrollController'da: pixels = index × itemExtent
          // (viewport yüksekliği bu formüle girmez).
          // _MomentumPhysics BoundedFrictionSimulation kullandığından
          // momentum bitişi tam item sınırında olmayabilir.
          // ScrollEndNotification ile kalan fraksiyon düzeltilir.
          NotificationListener<ScrollEndNotification>(
            onNotification: (ScrollEndNotification n) {
              final pixels = n.metrics.pixels;
              // En yakın item: pixels / itemExtent yuvarlama
              final index =
                  (pixels / itemExtent).round().clamp(0, itemCount - 1);
              // O item'in kesin offseti
              final target = (index * itemExtent).clamp(
                n.metrics.minScrollExtent,
                n.metrics.maxScrollExtent,
              );
              // Anlamlı sapma varsa yumuşak animasyonla düzelt
              if ((pixels - target).abs() > 0.5) {
                controller.animateTo(
                  target,
                  duration: const Duration(milliseconds: 150),
                  curve: Curves.easeOut,
                );
              }
              return false;
            },
            child: ClipRRect(
              borderRadius: BorderRadius.circular(scaleSize(context, 12)),
              child: ListWheelScrollView.useDelegate(
                controller: controller,
                itemExtent: itemExtent,
                diameterRatio: 2.5,
                perspective: 0.001,
                physics: const _MomentumPhysics(
                  parent: FixedExtentScrollPhysics(),
                ),
                onSelectedItemChanged: onChanged,
                squeeze: 1.0,
                // RN wheely: seçili olmayan itemlar 0.4 opacity
                overAndUnderCenterOpacity: 0.4,
                childDelegate: ListWheelChildBuilderDelegate(
                  childCount: itemCount,
                  builder: (ctx, i) {
                    final isSelected = i == selectedIndex;
                    return Center(
                      child: Text(
                        labelBuilder(i),
                        textAlign: TextAlign.center,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: scaleFont(ctx, isSelected ? 14.0 : 13.0),
                          fontWeight: isSelected
                              ? FontWeight.bold
                              : FontWeight.normal,
                          color: isSelected
                              ? _accentColor
                              : const Color(0xFF333333),
                        ),
                      ),
                    );
                  },
                ),
              ),
            ),
          ),

          // ── 3. Seçim çizgileri (react-native-wheely stili) ──────────────
          IgnorePointer(
            child: Column(
              children: [
                SizedBox(height: (height - itemExtent) / 2),
                Container(height: 1, color: _accentColor.withValues(alpha: 0.55)),
                SizedBox(height: itemExtent - 1),
                Container(height: 1, color: _accentColor.withValues(alpha: 0.55)),
              ],
            ),
          ),

          // ── 4. Üst ve alt gradient fade (wheely kenar efekti) ───────────
          IgnorePointer(
            child: Column(
              children: [
                Container(
                  height: (height - itemExtent) / 2,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        _modalBg.withValues(alpha: 0.85),
                        _modalBg.withValues(alpha: 0.0),
                      ],
                    ),
                  ),
                ),
                SizedBox(height: itemExtent),
                Expanded(
                  child: Container(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          _modalBg.withValues(alpha: 0.0),
                          _modalBg.withValues(alpha: 0.85),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}