import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import 'package:provider/provider.dart';
import 'package:share_plus/share_plus.dart' show SharePlus, ShareParams, XFile;
import 'dart:io';

import '../contexts/theme_provider.dart';
import '../l10n/app_localizations.dart';
import '../services/remote_content_service.dart';
import '../utils/scaling.dart';
import 'content_card_base.dart';

// Images are 1536×1024 (3:2 landscape).
const double _kImageAspect = 1536 / 1024;

// Share output: 1080×1350 (4:5 Instagram portrait)
const double _kShareW = 1080;
const double _kShareH = 1350;

class RemoteContentCard extends StatefulWidget {
  const RemoteContentCard({super.key});

  @override
  State<RemoteContentCard> createState() => _RemoteContentCardState();
}

class _RemoteContentCardState extends State<RemoteContentCard> {
  List<RemoteContentItem> _items = [];
  int _index = 0;
  bool _loading = true;
  bool _isSharing = false;
  double _shareProgress = 0;
  String? _loadedLocale;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final locale = context.read<ThemeProvider>().language;
    if (!mounted) return;
    setState(() {
      _loading = true;
      _loadedLocale = locale;
    });
    try {
      final items = await RemoteContentService.instance.getItems(locale);
      if (!mounted) return;
      setState(() {
        _items = items;
        _index = 0;
        _loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _loading = false);
    }
  }

  RemoteContentItem? get _item =>
      _items.isNotEmpty ? _items[_index] : null;

  void _prev() {
    if (_items.length < 2) return;
    setState(() => _index = (_index - 1 + _items.length) % _items.length);
  }

  void _next() {
    if (_items.length < 2) return;
    setState(() => _index = (_index + 1) % _items.length);
  }

  // ── Canvas-based share composition ─────────────────────────────────────────

  /// Loads an image from a URL into a [ui.Image].
  Future<ui.Image> _loadUiImage(String url) async {
    final res = await http
        .get(Uri.parse(url))
        .timeout(const Duration(seconds: 15));
    final codec = await ui.instantiateImageCodec(res.bodyBytes);
    final frame = await codec.getNextFrame();
    return frame.image;
  }

  /// Finds the largest font size (starting from [startSize]) where the text
  /// fits within [maxWidth] × [maxHeight] using Marcellus.
  double _fitTextSize(
    String text, {
    required double maxWidth,
    required double maxHeight,
    double startSize = 64,
    double minSize = 12,
  }) {
    double size = startSize;
    while (size > minSize) {
      final tp = TextPainter(
        text: TextSpan(
          text: text,
          style: GoogleFonts.marcellus(fontSize: size, height: 1.35),
        ),
        textDirection: TextDirection.ltr,
        textAlign: TextAlign.center,
      )..layout(maxWidth: maxWidth);
      if (tp.height <= maxHeight) break;
      size -= 1;
    }
    return size;
  }

  /// Composes the share image on a canvas:
  /// - [imageUrl]: the vertical variant URL (portrait)
  /// - [quoteText]: overlay text (Marcellus, black)
  /// - Output: 1080×1350 PNG bytes
  Future<Uint8List> _composeShareImage(
    String imageUrl,
    String? quoteText,
  ) async {
    final image = await _loadUiImage(imageUrl);

    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);

    // ── Draw image cover-fit into 1080×1350 ────────────────────────────────
    const destRect = Rect.fromLTWH(0, 0, _kShareW, _kShareH);
    final srcAspect = image.width / image.height;
    const dstAspect = _kShareW / _kShareH;
    Rect srcRect;
    if (srcAspect > dstAspect) {
      // Image wider → crop sides
      final srcH = image.height.toDouble();
      final srcW = srcH * dstAspect;
      srcRect = Rect.fromLTWH(
          (image.width - srcW) / 2, 0, srcW, srcH);
    } else {
      // Image taller → crop top/bottom
      final srcW = image.width.toDouble();
      final srcH = srcW / dstAspect;
      srcRect = Rect.fromLTWH(
          0, (image.height - srcH) / 2, srcW, srcH);
    }
    canvas.drawImageRect(image, srcRect, destRect, Paint());

    // ── Draw text overlay (centered, slightly above mid) ───────────────────
    if (quoteText != null && quoteText.trim().isNotEmpty) {
      final quoteWidthFraction = _dynamicQuoteWidth(quoteText.length);
      const maxH = _kShareH * 0.55;
      final maxW = _kShareW * quoteWidthFraction;

      final fontSize = _fitTextSize(
        quoteText,
        maxWidth: maxW,
        maxHeight: maxH,
        startSize: 52,
        minSize: 14,
      );

      final tp = TextPainter(
        text: TextSpan(
          text: quoteText,
          style: GoogleFonts.marcellus(
            fontSize: fontSize,
            color: Colors.black,
            height: 1.35,
          ),
        ),
        textDirection: TextDirection.ltr,
        textAlign: TextAlign.center,
      )..layout(maxWidth: maxW);

      final dx = (_kShareW - tp.width) / 2;
      final dy = (_kShareH - tp.height) / 2 - _kShareH * 0.11;
      tp.paint(canvas, Offset(dx, dy));
    }

    // ── Encode to PNG ──────────────────────────────────────────────────────
    final picture = recorder.endRecording();
    final composed =
        await picture.toImage(_kShareW.toInt(), _kShareH.toInt());
    final byteData =
        await composed.toByteData(format: ui.ImageByteFormat.png);
    if (byteData == null) throw Exception('PNG encoding failed');
    return byteData.buffer.asUint8List();
  }

  Future<void> _share() async {
    if (_item == null || _isSharing) return;
    _setProgress(5, sharing: true);

    try {
      _setProgress(20);
      final pngBytes = await _composeShareImage(
        _item!.effectiveShareImageUrl,
        _item!.quoteText,
      );
      _setProgress(75);

      final tempDir = await getTemporaryDirectory();
      final file = File(
        '${tempDir.path}/nida_share_${DateTime.now().millisecondsSinceEpoch}.png',
      );
      await file.writeAsBytes(pngBytes);
      _setProgress(90);

      final shareText = _item!.shareText ?? '';
      await SharePlus.instance.share(ShareParams(
        files: [XFile(file.path, mimeType: 'image/png')],
        subject: shareText.isNotEmpty ? shareText : null,
      ));

      _setProgress(100);
    } catch (e) {
      final msg = e.toString().toLowerCase();
      final isCancel =
          msg.contains('cancel') || msg.contains('user did not share');
      if (!isCancel && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(AppLocalizations.t(context, 'error')),
          duration: const Duration(seconds: 3),
        ));
      }
    } finally {
      if (mounted) {
        setState(() {
          _isSharing = false;
          _shareProgress = 0;
        });
      }
    }
  }

  void _setProgress(double v, {bool sharing = false}) {
    if (mounted) {
      setState(() {
        if (sharing) _isSharing = true;
        _shareProgress = v;
      });
    }
  }

  // ── Helpers ────────────────────────────────────────────────────────────────

  double _dynamicQuoteWidth(int len) {
    const base = 0.82;
    if (len > 200) return (base + 0.13).clamp(0.0, 0.95);
    if (len > 100) return (base + 0.08).clamp(0.0, 0.95);
    if (len > 50) return (base + 0.04).clamp(0.0, 0.95);
    return base;
  }

  // ── Build ──────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final locale = context.watch<ThemeProvider>().language;
    // Reload content when the app language changes.
    if (!_loading && locale != _loadedLocale) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _load();
      });
    }
    String t(String key) => AppLocalizations.t(context, key);

    final screenWidth = MediaQuery.sizeOf(context).width;
    final cardWidth = screenWidth - scaleSize(context, 40);
    final cardHeight = cardWidth / _kImageAspect;

    if (_loading) {
      return _buildPlaceholder(context, cardWidth, cardHeight, t('remoteContentLoading'));
    }

    if (_item == null) return const SizedBox.shrink();

    return Stack(
      clipBehavior: Clip.none,
      children: [
        // ── Main card ───────────────────────────────────────────────────────
        GestureDetector(
          onHorizontalDragEnd: (details) {
            final v = details.primaryVelocity ?? 0;
            if (v < -250) _next(); // swipe left → next
            if (v > 250) _prev(); // swipe right → prev
          },
          child: Container(
            width: cardWidth,
            margin: EdgeInsets.only(
              top: scaleSize(context, 12),
              bottom: scaleSize(context, 8),
            ),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(scaleSize(context, 12)),
              border: Border.all(color: const Color(0xFFF1F5F9)),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.05),
                  blurRadius: scaleSize(context, 8),
                  offset: Offset(0, scaleSize(context, 2)),
                ),
              ],
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(scaleSize(context, 12)),
              child: SizedBox(
                width: cardWidth,
                height: cardHeight,
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    // ── Black background ─────────────────────────────────
                    Container(color: Colors.black),

                    // ── Horizontal image (preview) ────────────────────────
                    Image.network(
                      _item!.imageUrl,
                      fit: BoxFit.contain,
                      width: cardWidth,
                      height: cardHeight,
                      loadingBuilder: (ctx, child, progress) {
                        if (progress == null) return child;
                        return Container(
                          color: const Color(0xFF0B1220),
                          child: Center(
                            child: CircularProgressIndicator(
                              value: progress.expectedTotalBytes != null
                                  ? progress.cumulativeBytesLoaded /
                                      progress.expectedTotalBytes!
                                  : null,
                              color: const Color(0xFF6366F1),
                              strokeWidth: 2,
                            ),
                          ),
                        );
                      },
                      errorBuilder: (ctx, err, st) => Container(
                        color: const Color(0xFF0B1220),
                        child: const Center(
                          child: Icon(Icons.broken_image_outlined,
                              color: Color(0xFF475569), size: 32),
                        ),
                      ),
                    ),

                    // ── Overlay text (auto-sized to fit) ─────────────────
                    if (_item!.quoteText != null &&
                        _item!.quoteText!.isNotEmpty)
                      _buildOverlayText(context, cardWidth, cardHeight),

                    // ── Subtle nav arrows ────────────────────────────────
                    if (_items.length > 1) ...[
                      _SmallNavButton(
                          onTap: _prev, icon: Icons.chevron_left, left: 6),
                      _SmallNavButton(
                          onTap: _next, icon: Icons.chevron_right, right: 6),
                    ],

                    // ── Share button ─────────────────────────────────────
                    Positioned(
                      bottom: scaleSize(context, 10),
                      right: scaleSize(context, 10),
                      child: GestureDetector(
                        onTap: _share,
                        child: Container(
                          width: scaleSize(context, 34),
                          height: scaleSize(context, 34),
                          decoration: BoxDecoration(
                            color: Colors.black.withValues(alpha: 0.45),
                            shape: BoxShape.circle,
                          ),
                          child: _isSharing
                              ? const Padding(
                                  padding: EdgeInsets.all(9),
                                  child: CircularProgressIndicator(
                                      color: Colors.white, strokeWidth: 2),
                                )
                              : const Icon(Icons.share_outlined,
                                  color: Colors.white, size: 17),
                        ),
                      ),
                    ),

                    // ── Progress overlay during sharing ───────────────────
                    if (_isSharing) _buildProgressOverlay(context, t),

                    // ── Page dots ─────────────────────────────────────────
                    if (_items.length > 1)
                      Positioned(
                        bottom: scaleSize(context, 10),
                        left: 0,
                        right: 0,
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: List.generate(
                            _items.length.clamp(0, 8),
                            (i) => AnimatedContainer(
                              duration: const Duration(milliseconds: 200),
                              margin: const EdgeInsets.symmetric(horizontal: 2),
                              width: i == _index ? 12 : 5,
                              height: 5,
                              decoration: BoxDecoration(
                                color: i == _index
                                    ? Colors.white
                                    : Colors.white.withValues(alpha: 0.45),
                                borderRadius: BorderRadius.circular(3),
                              ),
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ),
        ),

        // ── Card type label ─────────────────────────────────────────────────
        Positioned(
          top: scaleSize(context, 4),
          right: 0,
          child: CardTypeLabel(
            text: t('ramadan'),
            bgColor: kRemoteLabelBg,
            textColor: kRemoteLabelText,
          ),
        ),
      ],
    );
  }

  Widget _buildOverlayText(
      BuildContext context, double cardWidth, double cardHeight) {
    final text = _item!.quoteText!;

    // Text column: 14% inset on each side → ~72% of card width.
    // Bottom inset: 15% reserved for share button + page dots (was 18%).
    final textW  = cardWidth  * 0.72;
    final textH  = cardHeight * 0.80; // 100% - 5% top - 15% bottom

    // Tighter line height (1.28) so more text fits without shrinking font much.
    const double lineHeight = 1.28;

    // Find the largest font that makes the fully-wrapped text fit
    // within the available area. Start high, step down by 0.5 px.
    double fontSize = 15.5;
    const double minFs = 9.0;
    while (fontSize > minFs) {
      final tp = TextPainter(
        text: TextSpan(
          text: text,
          style: GoogleFonts.marcellus(fontSize: fontSize, height: lineHeight),
        ),
        textDirection: TextDirection.ltr,
        textAlign: TextAlign.center,
      )..layout(maxWidth: textW);
      if (tp.height <= textH) break;
      fontSize -= 0.5;
    }

    return Positioned.fill(
      child: Padding(
        padding: EdgeInsets.only(
          left:   cardWidth  * 0.14,
          right:  cardWidth  * 0.14,
          top:    cardHeight * 0.05,
          bottom: cardHeight * 0.15,
        ),
        child: Align(
          alignment: const Alignment(0, -0.15),
          child: Text(
            text,
            textAlign: TextAlign.center,
            softWrap: true,
            style: GoogleFonts.marcellus(
              fontSize: fontSize,
              color: Colors.black,
              height: lineHeight,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildPlaceholder(
      BuildContext context, double w, double h, String label) {
    return Container(
      width: w,
      height: h,
      margin: EdgeInsets.only(
        top: scaleSize(context, 12),
        bottom: scaleSize(context, 8),
      ),
      decoration: BoxDecoration(
        color: const Color(0xFF0F172A),
        borderRadius: BorderRadius.circular(scaleSize(context, 12)),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const CircularProgressIndicator(
              color: Color(0xFF6366F1), strokeWidth: 2),
          SizedBox(height: scaleSize(context, 8)),
          Text(
            label,
            style: TextStyle(
              fontSize: scaleFont(context, 12),
              color: const Color(0xFF94A3B8),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildProgressOverlay(
      BuildContext context, String Function(String) t) {
    return Positioned.fill(
      child: Container(
        color: Colors.black.withValues(alpha: 0.6),
        child: Center(
          child: SizedBox(
            width: scaleSize(context, 160),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(3),
                  child: LinearProgressIndicator(
                    value: _shareProgress / 100,
                    minHeight: 6,
                    backgroundColor: const Color(0xFF334155),
                    color: const Color(0xFF6366F1),
                  ),
                ),
                SizedBox(height: scaleSize(context, 8)),
                Text(
                  '${t('remoteContentProcessing')} ${_shareProgress.toInt()}%',
                  style: TextStyle(
                    fontSize: scaleFont(context, 13),
                    color: Colors.white,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ── Small nav arrow button ────────────────────────────────────────────────────

class _SmallNavButton extends StatelessWidget {
  final VoidCallback onTap;
  final IconData icon;
  final double? left;
  final double? right;

  const _SmallNavButton({
    required this.onTap,
    required this.icon,
    this.left,
    this.right,
  });

  @override
  Widget build(BuildContext context) {
    return Positioned(
      top: 0,
      bottom: 0,
      left: left,
      right: right,
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          width: scaleSize(context, 24),
          alignment: Alignment.center,
          color: Colors.transparent, // wider hit area
          child: Container(
            width: scaleSize(context, 20),
            height: scaleSize(context, 44),
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: Colors.black.withValues(alpha: 0.25),
              borderRadius: BorderRadius.circular(scaleSize(context, 6)),
            ),
            child: Icon(icon,
                color: Colors.white.withValues(alpha: 0.85),
                size: scaleSize(context, 14)),
          ),
        ),
      ),
    );
  }
}
