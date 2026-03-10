import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../contexts/theme_provider.dart';
import '../l10n/app_localizations.dart';
import '../services/location_service.dart';
import '../utils/scaling.dart';

/// Flutter port of RN LocationInputModal: search cities (Nominatim) + "Use current location".
/// onLocationSelected(location: {latitude, longitude}, name: String|Map, meta: {admin?}).
class LocationInputModal extends StatefulWidget {
  final bool visible;
  final Future<void> Function(double lat, double lng, dynamic name, Map<String, dynamic>? meta) onLocationSelected;
  final VoidCallback onClose;

  const LocationInputModal({
    super.key,
    required this.visible,
    required this.onLocationSelected,
    required this.onClose,
  });

  @override
  State<LocationInputModal> createState() => _LocationInputModalState();
}

class _LocationInputModalState extends State<LocationInputModal> {
  final TextEditingController _controller = TextEditingController();
  List<SearchResultItem> _results = [];
  bool _searchLoading = false;
  bool _locationLoading = false;

  @override
  void didUpdateWidget(LocationInputModal oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!widget.visible && oldWidget.visible) {
      _controller.clear();
      _results = [];
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _search(String query) async {
    if (query.trim().length < 3) {
      setState(() => _results = []);
      return;
    }
    setState(() => _searchLoading = true);
    final locale = context.read<ThemeProvider>().language;
    final list = await searchCities(query, limit: 5, locale: locale);
    if (mounted) setState(() { _results = list; _searchLoading = false; });
  }

  Future<void> _useCurrentLocation() async {
    setState(() => _locationLoading = true);
    final result = await getCurrentLocation();
    if (!mounted) return;
    if (!result.success) {
      setState(() => _locationLoading = false);
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(result.message ?? AppLocalizations.t(context, 'locationError'))),
      );
      return;
    }
    final locale = context.read<ThemeProvider>().language;
    final nameObj = await getLocationName(result.latitude!, result.longitude!, locale);
    // Never pass raw coordinates as display name; use localized "Location" when geocoding fails
    final fallbackName = nameObj != null ? null : AppLocalizations.t(context, 'location');
    setState(() => _locationLoading = false);
    await widget.onLocationSelected(
      result.latitude!,
      result.longitude!,
      nameObj ?? fallbackName,
      nameObj != null ? {'admin': nameObj} : null,
    );
    widget.onClose();
  }

  Future<void> _selectResult(SearchResultItem item) async {
    // Seçince sadece en küçük birim: kasaba / ilçe / şehir
    final displayName = item.shortDisplayName;
    await widget.onLocationSelected(
      item.latitude,
      item.longitude,
      displayName,
      {'admin': item.admin},
    );
    widget.onClose();
  }

  @override
  Widget build(BuildContext context) {
    if (!widget.visible) return const SizedBox.shrink();
    final t = (String key) => AppLocalizations.t(context, key);
    final radius = scaleSize(context, 20);
    const surfaceLight = Color(0xFFF8FAFC);
    const surfaceGlass = Color(0xE6FFFFFF);
    const textPrimary = Color(0xFF0F172A);
    const textSecondary = Color(0xFF64748B);
    const accent = Color(0xFF6366F1);

    return Stack(
      children: [
        GestureDetector(
          onTap: widget.onClose,
          behavior: HitTestBehavior.opaque,
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 8, sigmaY: 8),
            child: Container(color: Colors.black38),
          ),
        ),
        Center(
          child: GestureDetector(
            onTap: () {},
            child: ClipRRect(
              borderRadius: BorderRadius.circular(radius),
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
                child: Material(
                  color: Colors.transparent,
                  child: Container(
                  constraints: BoxConstraints(
                    maxWidth: scaleSize(context, 340),
                    maxHeight: MediaQuery.of(context).size.height * 0.56,
                  ),
                  decoration: BoxDecoration(
                    color: surfaceGlass,
                    borderRadius: BorderRadius.circular(radius),
                    border: Border.all(color: Colors.white.withOpacity(0.5), width: 1.5),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.08),
                        blurRadius: scaleSize(context, 24),
                        spreadRadius: 0,
                        offset: Offset(0, scaleSize(context, 8)),
                      ),
                      BoxShadow(
                        color: accent.withOpacity(0.06),
                        blurRadius: scaleSize(context, 18),
                        spreadRadius: -4,
                        offset: Offset(0, scaleSize(context, 4)),
                      ),
                    ],
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Padding(
                        padding: EdgeInsets.fromLTRB(scaleSize(context, 18), scaleSize(context, 16), scaleSize(context, 6), scaleSize(context, 10)),
                        child: Row(
                          children: [
                            Expanded(
                              child: Text(
                                t('locationSettings'),
                                style: GoogleFonts.plusJakartaSans(
                                  fontSize: scaleFont(context, 18),
                                  fontWeight: FontWeight.w600,
                                  color: textPrimary,
                                  letterSpacing: -0.3,
                                ),
                              ),
                            ),
                            Material(
                              color: Colors.transparent,
                              child: InkWell(
                                onTap: widget.onClose,
                                borderRadius: BorderRadius.circular(scaleSize(context, 10)),
                                child: Padding(
                                  padding: EdgeInsets.all(scaleSize(context, 6)),
                                  child: Icon(Icons.close_rounded, size: scaleSize(context, 22), color: textSecondary),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      Padding(
                        padding: EdgeInsets.symmetric(horizontal: scaleSize(context, 16)),
                        child: Container(
                          decoration: BoxDecoration(
                            color: surfaceLight.withOpacity(0.8),
                            borderRadius: BorderRadius.circular(scaleSize(context, 12)),
                            border: Border.all(color: Colors.white.withOpacity(0.8)),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withOpacity(0.04),
                                blurRadius: scaleSize(context, 8),
                                offset: Offset(0, scaleSize(context, 3)),
                              ),
                            ],
                          ),
                          child: TextField(
                            controller: _controller,
                            style: GoogleFonts.plusJakartaSans(fontSize: scaleFont(context, 14), color: textPrimary),
                            decoration: InputDecoration(
                              hintText: t('enterYourCity'),
                              hintStyle: GoogleFonts.plusJakartaSans(color: textSecondary.withOpacity(0.9), fontSize: scaleFont(context, 13)),
                              prefixIcon: Icon(Icons.search_rounded, color: accent.withOpacity(0.85), size: scaleSize(context, 20)),
                              border: InputBorder.none,
                              enabledBorder: InputBorder.none,
                              focusedBorder: InputBorder.none,
                              contentPadding: EdgeInsets.symmetric(horizontal: scaleSize(context, 14), vertical: scaleSize(context, 12)),
                            ),
                            onChanged: (v) {
                              Future.delayed(const Duration(milliseconds: 400), () {
                                if (_controller.text == v) _search(v);
                              });
                            },
                          ),
                        ),
                      ),
                      SizedBox(height: scaleSize(context, 10)),
                      Padding(
                        padding: EdgeInsets.symmetric(horizontal: scaleSize(context, 16)),
                        child: Material(
                          color: Colors.transparent,
                          child: InkWell(
                            onTap: _locationLoading ? null : _useCurrentLocation,
                            borderRadius: BorderRadius.circular(scaleSize(context, 12)),
                            child: Container(
                              padding: EdgeInsets.symmetric(vertical: scaleSize(context, 10), horizontal: scaleSize(context, 14)),
                              decoration: BoxDecoration(
                                color: accent.withOpacity(0.08),
                                borderRadius: BorderRadius.circular(scaleSize(context, 12)),
                                border: Border.all(color: accent.withOpacity(0.2)),
                              ),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  if (_locationLoading)
                                    SizedBox(
                                      width: scaleSize(context, 18),
                                      height: scaleSize(context, 18),
                                      child: CircularProgressIndicator(strokeWidth: 2.2, color: accent),
                                    )
                                  else
                                    Icon(Icons.my_location_rounded, size: scaleSize(context, 18), color: accent),
                                  SizedBox(width: scaleSize(context, 8)),
                                  Text(
                                    _locationLoading ? t('loading') : t('location'),
                                    style: GoogleFonts.plusJakartaSans(
                                      fontSize: scaleFont(context, 13),
                                      fontWeight: FontWeight.w500,
                                      color: accent,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ),
                      SizedBox(height: scaleSize(context, 12)),
                      if (_searchLoading)
                        Padding(
                          padding: EdgeInsets.symmetric(horizontal: scaleSize(context, 16)),
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(scaleSize(context, 4)),
                            child: LinearProgressIndicator(
                              backgroundColor: accent.withOpacity(0.15),
                              valueColor: const AlwaysStoppedAnimation<Color>(accent),
                              minHeight: 2,
                            ),
                          ),
                        ),
                      if (_searchLoading) SizedBox(height: scaleSize(context, 6)),
                      Flexible(
                        child: ListView.builder(
                          shrinkWrap: true,
                          padding: EdgeInsets.fromLTRB(scaleSize(context, 10), 0, scaleSize(context, 10), scaleSize(context, 14)),
                          itemCount: _results.length,
                          itemBuilder: (_, i) {
                            final item = _results[i];
                            final subtitle = item.hierarchySubtitle;
                            return Material(
                              color: Colors.transparent,
                              child: InkWell(
                                onTap: () => _selectResult(item),
                                borderRadius: BorderRadius.circular(scaleSize(context, 10)),
                                child: Padding(
                                  padding: EdgeInsets.symmetric(horizontal: scaleSize(context, 10), vertical: scaleSize(context, 10)),
                                  child: Row(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Container(
                                        width: scaleSize(context, 34),
                                        height: scaleSize(context, 34),
                                        alignment: Alignment.center,
                                        decoration: BoxDecoration(
                                          color: accent.withOpacity(0.1),
                                          borderRadius: BorderRadius.circular(scaleSize(context, 10)),
                                        ),
                                        child: Icon(Icons.location_on_rounded, color: accent, size: scaleSize(context, 18)),
                                      ),
                                      SizedBox(width: scaleSize(context, 10)),
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              item.shortDisplayName,
                                              style: GoogleFonts.plusJakartaSans(
                                                fontWeight: FontWeight.w600,
                                                fontSize: scaleFont(context, 14),
                                                color: textPrimary,
                                              ),
                                            ),
                                            if (subtitle.isNotEmpty) ...[
                                              SizedBox(height: scaleSize(context, 3)),
                                              Text(
                                                subtitle,
                                                style: GoogleFonts.plusJakartaSans(
                                                  fontSize: scaleFont(context, 12),
                                                  color: textSecondary.withOpacity(0.95),
                                                  height: 1.3,
                                                ),
                                              ),
                                            ],
                                          ],
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            );
                          },
                        ),
                      ),
                    ],
                  ),
                ),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}
