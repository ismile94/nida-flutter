import 'dart:async';

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../l10n/app_localizations.dart';
import '../utils/scaling.dart';

/// RN: CustomSoundPlayer.js – Quran için çok fonksiyonlu ses çalar.
/// Play/pause, stop, prev/next, hız, okuyucu, tekrar modu, settings (repeat mode panel), ön yükleme.
/// Okuyucu listesi ve API: RN AudioService RECITER_MAPPINGS / everyayah.com ile uyumlu.
class QuranSoundPlayer extends StatefulWidget {
  final bool visible;
  final VoidCallback? onClose;
  final VoidCallback? onPlayFirstAyah;

  final ({int surah, int ayah})? currentAyah;
  final bool isPlaying;
  final bool isPaused;
  final double playbackSpeed;
  final String selectedReciterKey;
  final String repeatMode;
  final VoidCallback? onPlayPause;
  final VoidCallback? onStop;
  final VoidCallback? onPrevious;
  final VoidCallback? onNext;
  final void Function(double speed)? onSpeedChange;
  final void Function(String reciterKey)? onReciterChange;
  final void Function(String mode) onRepeatModeChange;

  final ({int current, int total})? preloadProgress;

  const QuranSoundPlayer({
    super.key,
    this.visible = true,
    this.onClose,
    this.onPlayFirstAyah,
    this.currentAyah,
    this.isPlaying = false,
    this.isPaused = false,
    this.playbackSpeed = 1.0,
    this.selectedReciterKey = 'ar.yasseraldossari',
    this.repeatMode = 'quran',
    this.onPlayPause,
    this.onStop,
    this.onPrevious,
    this.onNext,
    this.onSpeedChange,
    this.onReciterChange,
    required this.onRepeatModeChange,
    this.preloadProgress,
  });

  /// RN AudioService RECITERS – everyayah.com ile uyumlu
  static const Map<String, String> reciters = {
    'ar.mahermuaiqly': 'Maher Al Muaiqly',
    'ar.abdulbasitmurattal': 'Abdul Basit Murattal',
    'ar.misharyrashid': 'Mishary Rashid (Alafasy)',
    'ar.saadalghamdi': 'Saad Al Ghamdi',
    'ar.abdurrahmansudais': 'Abdurrahman Sudais',
    'ar.minshawi': 'Al Minshawi',
    'ar.husary': 'Mahmoud Khalil Al-Husary',
    'ar.shuraym': 'Saood ash-Shuraym',
    'ar.yasseraldossari': 'Yasser Ad-Dussary',
  };

  static const List<double> speeds = [0.5, 0.75, 1.0, 1.25, 1.5, 2.0];
  /// Sıra: 1 bir ayet dur, 2 aynı ayet tekrar, 3 sure tekrar, 4 tüm Kuran tekrar (varsayılan).
  static const List<String> repeatModeKeys = ['none', 'one', 'surah', 'quran'];

  @override
  State<QuranSoundPlayer> createState() => _QuranSoundPlayerState();
}

class _QuranSoundPlayerState extends State<QuranSoundPlayer> {
  bool _showSettings = false;
  bool _showSpeedPanel = false;
  String? _repeatModeHint;
  Timer? _repeatModeHintTimer;

  static const Duration _panelDuration = Duration(milliseconds: 250);
  static const Curve _panelCurve = Curves.easeOut;
  static const Duration _repeatHintDuration = Duration(milliseconds: 1500);

  @override
  Widget build(BuildContext context) {
    if (!widget.visible) return const SizedBox.shrink();

    final bottom = MediaQuery.paddingOf(context).bottom;
    final t = (String k) => AppLocalizations.t(context, k);

    return Container(
      width: double.infinity,
      padding: EdgeInsets.only(
        left: scaleSize(context, 12),
        right: scaleSize(context, 12),
        top: scaleSize(context, 8),
        bottom: scaleSize(context, 6) + bottom,
      ),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(scaleSize(context, 16))),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.1),
            offset: Offset(0, -scaleSize(context, 2)),
            blurRadius: scaleSize(context, 8),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (widget.preloadProgress != null && widget.preloadProgress!.total > 0) ...[
            Padding(
              padding: EdgeInsets.only(bottom: scaleSize(context, 8)),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    t('preloadingProgress')
                        .replaceAll('{current}', '${widget.preloadProgress!.current}')
                        .replaceAll('{total}', '${widget.preloadProgress!.total}'),
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: scaleFont(context, 11),
                      color: const Color(0xFF64748B),
                    ),
                  ),
                  SizedBox(height: scaleSize(context, 3)),
                  ClipRRect(
                    borderRadius:
                        BorderRadius.circular(scaleSize(context, 2)),
                    child: LinearProgressIndicator(
                      value: widget.preloadProgress!.total > 0
                          ? widget.preloadProgress!.current /
                              widget.preloadProgress!.total
                          : 0,
                      backgroundColor: const Color(0xFFE2E8F0),
                      valueColor: const AlwaysStoppedAnimation<Color>(
                          Color(0xFF6366F1)),
                      minHeight: scaleSize(context, 4),
                    ),
                  ),
                ],
              ),
            ),
          ],
          LayoutBuilder(
            builder: (context, constraints) {
              return FittedBox(
                fit: BoxFit.scaleDown,
                alignment: Alignment.center,
                child: SizedBox(
                  width: constraints.maxWidth,
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      _speedButton(context, t),
                      _controlButton(context, Icons.stop_circle, const Color(0xFFEF4444), widget.onStop,
                          disabled: widget.currentAyah == null),
                      _controlButton(context, Icons.skip_previous, const Color(0xFF6366F1), widget.onPrevious,
                          disabled: widget.currentAyah == null),
                      _playPauseButton(context),
                      _controlButton(context, Icons.skip_next, const Color(0xFF6366F1), widget.onNext,
                          disabled: widget.currentAyah == null),
                      _settingsButton(context),
                      _reciterButton(context, t),
                    ],
                  ),
                ),
              );
            },
          ),
          AnimatedSize(
            duration: _panelDuration,
            curve: _panelCurve,
            alignment: Alignment.topCenter,
            child: _showSpeedPanel ? _speedPanel(context) : const SizedBox.shrink(),
          ),
          AnimatedSize(
            duration: _panelDuration,
            curve: _panelCurve,
            alignment: Alignment.topCenter,
            child: _showSettings ? _repeatModeSection(context, t) : const SizedBox.shrink(),
          ),
        ],
      ),
    );
  }

  Widget _speedButton(BuildContext context, String Function(String) t) {
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: scaleSize(context, 2)),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          IconButton(
            onPressed: () => setState(() => _showSpeedPanel = !_showSpeedPanel),
            icon: Icon(
              Icons.speed,
              color: _showSpeedPanel
                  ? const Color(0xFF6366F1)
                  : const Color(0xFF6366F1),
              size: scaleSize(context, 22),
            ),
            style: IconButton.styleFrom(
              padding: EdgeInsets.zero,
              minimumSize: Size(scaleSize(context, 36), scaleSize(context, 36)),
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            ),
          ),
          Text(
            '${widget.playbackSpeed}x',
            style: GoogleFonts.plusJakartaSans(
              fontSize: scaleFont(context, 9),
              color: const Color(0xFF6366F1),
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  Widget _speedPanel(BuildContext context) {
    if (widget.onSpeedChange == null) return const SizedBox.shrink();
    return Padding(
      padding: EdgeInsets.only(top: scaleSize(context, 8), bottom: scaleSize(context, 6)),
      child: FittedBox(
        fit: BoxFit.scaleDown,
        alignment: Alignment.center,
        child: Row(
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.center,
          children: QuranSoundPlayer.speeds.map((s) {
            final selected = (widget.playbackSpeed - s).abs() < 0.01;
            return Padding(
              padding: EdgeInsets.symmetric(horizontal: scaleSize(context, 4)),
              child: ActionChip(
                label: Text('${s}x'),
                onPressed: () {
                  widget.onSpeedChange!(s);
                  setState(() => _showSpeedPanel = false);
                },
                backgroundColor: selected ? const Color(0xFFEEF2FF) : const Color(0xFFF1F5F9),
                side: BorderSide(
                  color: selected
                      ? const Color(0xFF6366F1)
                      : Colors.transparent,
                  width: scaleSize(context, 1),
                ),
                padding: EdgeInsets.symmetric(
                  horizontal: scaleSize(context, 12),
                  vertical: scaleSize(context, 6),
                ),
              ),
            );
          }).toList(),
        ),
      ),
    );
  }

  Widget _controlButton(
    BuildContext context,
    IconData icon,
    Color color,
    VoidCallback? onPressed, {
    bool disabled = false,
  }) {
    return IconButton(
      onPressed: disabled ? null : onPressed,
      icon: Icon(icon,
          size: scaleSize(context, 22),
          color: disabled ? color.withValues(alpha: 0.3) : color),
      style: IconButton.styleFrom(
        padding: EdgeInsets.zero,
        minimumSize: Size(scaleSize(context, 36), scaleSize(context, 36)),
        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
      ),
    );
  }

  Widget _playPauseButton(BuildContext context) {
    final canPlay = widget.currentAyah != null || widget.onPlayFirstAyah != null;
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: scaleSize(context, 6)),
      child: Material(
        color: canPlay ? const Color(0xFFEEF2FF) : const Color(0xFFF1F5F9),
        shape: const CircleBorder(),
        elevation: scaleSize(context, 4).clamp(0.0, 24.0),
        shadowColor: const Color(0xFF6366F1).withValues(alpha: 0.15),
        child: InkWell(
          onTap: canPlay
              ? () {
                  if (widget.currentAyah == null && widget.onPlayFirstAyah != null) {
                    widget.onPlayFirstAyah!();
                  } else {
                    widget.onPlayPause?.call();
                  }
                }
              : null,
          customBorder: const CircleBorder(),
          child: SizedBox(
            width: scaleSize(context, 48),
            height: scaleSize(context, 48),
            child: Icon(
              widget.isPlaying && !widget.isPaused
                  ? Icons.pause
                  : Icons.play_arrow,
              size: scaleSize(context, 32),
              color: canPlay
                  ? const Color(0xFF6366F1)
                  : const Color(0xFF94A3B8),
            ),
          ),
        ),
      ),
    );
  }

  Widget _settingsButton(BuildContext context) {
    return IconButton(
      onPressed: () => setState(() => _showSettings = !_showSettings),
      icon: Icon(Icons.settings,
          size: scaleSize(context, 22), color: const Color(0xFF6366F1)),
      style: IconButton.styleFrom(
        padding: EdgeInsets.zero,
        minimumSize: Size(scaleSize(context, 36), scaleSize(context, 36)),
        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
      ),
    );
  }

  Widget _reciterButton(BuildContext context, String Function(String) t) {
    final raw = QuranSoundPlayer.reciters[widget.selectedReciterKey] ?? t('reciterShort');
    final name = raw.trim().replaceAll(RegExp(r'\s+'), ' ');
    final shortLabel = name.length > 6 ? '${name.substring(0, 6)}.' : name;
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: scaleSize(context, 2)),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          IconButton(
            onPressed: () => _showReciterModal(context),
            icon: Icon(Icons.person,
                color: const Color(0xFF6366F1),
                size: scaleSize(context, 22)),
            style: IconButton.styleFrom(
              padding: EdgeInsets.zero,
              minimumSize: Size(scaleSize(context, 36), scaleSize(context, 36)),
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            ),
          ),
          Text(
            shortLabel,
            style: GoogleFonts.plusJakartaSans(
              fontSize: scaleFont(context, 9),
              color: const Color(0xFF6366F1),
              fontWeight: FontWeight.w600,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }

  void _showReciterModal(BuildContext context) {
    if (widget.onReciterChange == null) return;
    showDialog<void>(
      context: context,
      barrierDismissible: true,
      builder: (ctx) => Center(
        child: Material(
          color: Colors.transparent,
          child: Container(
            margin: EdgeInsets.symmetric(horizontal: scaleSize(context, 24)),
            constraints: BoxConstraints(
              maxWidth: scaleSize(context, 400),
              maxHeight: MediaQuery.of(context).size.height * 0.6,
            ),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(scaleSize(context, 16)),
              boxShadow: [
                BoxShadow(
                    color: Colors.black26,
                    blurRadius: scaleSize(context, 16),
                    spreadRadius: 0),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Flexible(
                  child: ListView.builder(
                    shrinkWrap: true,
                    padding: EdgeInsets.symmetric(
                      horizontal: scaleSize(context, 16),
                      vertical: scaleSize(context, 8),
                    ),
                    itemCount: QuranSoundPlayer.reciters.length,
                    itemBuilder: (_, i) {
                      final key = QuranSoundPlayer.reciters.keys.elementAt(i);
                      final raw = QuranSoundPlayer.reciters[key]!;
                      final name = raw.trim().replaceAll(RegExp(r'\s+'), ' ');
                      final selected = widget.selectedReciterKey == key;
                      return ListTile(
                        contentPadding: EdgeInsets.symmetric(
                          horizontal: scaleSize(context, 8),
                          vertical: 0,
                        ),
                        visualDensity: const VisualDensity(horizontal: 0, vertical: -4),
                        title: Text(
                          name,
                          style: GoogleFonts.plusJakartaSans(
                            fontWeight: selected ? FontWeight.w600 : FontWeight.normal,
                            color: selected ? const Color(0xFF6366F1) : const Color(0xFF1E293B),
                          ),
                        ),
                        trailing: selected
                            ? Icon(Icons.check,
                                color: const Color(0xFF6366F1),
                                size: scaleSize(context, 18))
                            : null,
                        onTap: () {
                          widget.onReciterChange!(key);
                          Navigator.of(ctx).pop();
                        },
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _showRepeatHint(String mode, String Function(String) t) {
    _repeatModeHintTimer?.cancel();
    final key = _repeatModeDescriptionKey(mode);
    setState(() => _repeatModeHint = key != null ? t(key) : null);
    _repeatModeHintTimer = Timer(_repeatHintDuration, () {
      if (mounted) setState(() => _repeatModeHint = null);
    });
  }

  @override
  void dispose() {
    _repeatModeHintTimer?.cancel();
    super.dispose();
  }

  static String? _repeatModeDescriptionKey(String mode) {
    switch (mode) {
      case 'none': return 'repeatModeNoneDesc';
      case 'one': return 'repeatModeOneDesc';
      case 'surah': return 'repeatModeSurahDesc';
      case 'quran': return 'repeatModeQuranDesc';
      default: return null;
    }
  }

  Widget _repeatModeSection(BuildContext context, String Function(String) t) {
    return Padding(
      padding: EdgeInsets.only(top: scaleSize(context, 8), bottom: scaleSize(context, 6)),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            t('repeatMode'),
            style: GoogleFonts.plusJakartaSans(
              fontSize: scaleFont(context, 13),
              fontWeight: FontWeight.w600,
              color: const Color(0xFF1E293B),
            ),
          ),
          SizedBox(height: scaleSize(context, 8)),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: QuranSoundPlayer.repeatModeKeys.map((mode) {
              final selected = widget.repeatMode == mode;
              IconData icon = Icons.repeat;
              if (mode == 'none') icon = Icons.stop_circle_outlined;
              if (mode == 'one') icon = Icons.repeat_one;
              if (mode == 'surah') icon = Icons.loop;
              if (mode == 'quran') icon = Icons.menu_book_outlined;
              return Padding(
                padding: EdgeInsets.symmetric(horizontal: scaleSize(context, 6)),
                child: IconButton(
                  onPressed: () {
                    widget.onRepeatModeChange(mode);
                    _showRepeatHint(mode, t);
                  },
                  icon: Icon(
                    icon,
                    size: scaleSize(context, 24),
                    color: selected
                        ? const Color(0xFF6366F1)
                        : const Color(0xFF64748B),
                  ),
                  style: IconButton.styleFrom(
                    backgroundColor: selected
                        ? const Color(0xFFEEF2FF)
                        : const Color(0xFFF8FAFC),
                    side: BorderSide(
                      color: selected
                          ? const Color(0xFF6366F1)
                          : Colors.transparent,
                      width: scaleSize(context, 2),
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
          if (_repeatModeHint != null && _repeatModeHint!.isNotEmpty) ...[
            SizedBox(height: scaleSize(context, 6)),
            AnimatedOpacity(
              opacity: 1,
              duration: const Duration(milliseconds: 150),
              child: Text(
                _repeatModeHint!,
                style: GoogleFonts.plusJakartaSans(
                  fontSize: scaleFont(context, 12),
                  color: const Color(0xFF64748B),
                  fontStyle: FontStyle.italic,
                ),
                textAlign: TextAlign.center,
              ),
            ),
          ],
        ],
      ),
    );
  }
}
