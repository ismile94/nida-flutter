// RN QiblaMosquesScreen.js – kıble + yakındaki camiler, liste/harita, rota.

import 'dart:async';
import 'dart:math' as math;
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:flutter_compass/flutter_compass.dart';

import '../contexts/theme_provider.dart';
import '../l10n/app_localizations.dart';
import '../utils/scaling.dart';
import '../services/qibla_service.dart';
import '../services/cache_service.dart';
import '../services/location_service.dart';
import '../services/nearby_mosques_service.dart';
import '../widgets/custom_compass.dart';

const int _radiusMeters = 10000;

double _distanceKm(double lat1, double lon1, double lat2, double lon2) {
  const R = 6371.0;
  final dLat = (lat2 - lat1) * math.pi / 180;
  final dLon = (lon2 - lon1) * math.pi / 180;
  final a = math.sin(dLat / 2) * math.sin(dLat / 2) +
      math.cos(lat1 * math.pi / 180) *
          math.cos(lat2 * math.pi / 180) *
          math.sin(dLon / 2) *
          math.sin(dLon / 2);
  return R * (2 * math.atan2(math.sqrt(a), math.sqrt(1 - a)));
}

String _formatDistance(double km) =>
    km < 1 ? '${(km * 1000).round()}m' : '${km.toStringAsFixed(1)}km';

class QiblaMosquesScreen extends StatefulWidget {
  const QiblaMosquesScreen({super.key});

  @override
  State<QiblaMosquesScreen> createState() => _QiblaMosquesScreenState();
}

class _QiblaMosquesScreenState extends State<QiblaMosquesScreen> {
  String _screenMode = 'mosques'; // 'qibla' | 'mosques'
  String _viewMode = 'list'; // 'list' | 'map'

  double _deviceHeading = 0;
  double _qiblaAngle = 0;
  double? _qiblaBearing;
  bool _compassAvailable = false;
  String? _qiblaError;
  bool _qiblaLoading = true;
  Map<String, dynamic>? _locationInfo;
  Map<String, dynamic>? _locationName;
  StreamSubscription<CompassEvent>? _compassSub;

  List<Map<String, dynamic>> _mosques = [];
  bool _mosquesLoading = true;
  Map<String, double>? _userLocation;
  String? _mosquesError;
  Map<String, dynamic>? _selectedMosque;
  List<Map<String, double>> _routeCoords = [];
  String _transportMode = 'walking';
  GoogleMapController? _mapController;
  BitmapDescriptor? _userLocationIcon;
  double _lastHeadingSent = 0;
  DateTime _lastHeadingTime = DateTime.now();
  static const double _headingThrottleDeg = 1.2;
  static const int _headingThrottleMs = 120;

  @override
  void initState() {
    super.initState();
    if (_screenMode == 'qibla') {
      _initQibla();
    } else {
      _loadMosques();
      _startLocationTracking();
      if (_viewMode == 'map') _startCompass();
    }
  }

  @override
  void dispose() {
    _compassSub?.cancel();
    super.dispose();
  }

  Future<void> _initQibla() async {
    setState(() {
      _qiblaLoading = true;
      _qiblaError = null;
    });
    try {
      // Önce önbelleğe bak: varsa pusulayı hemen göster, arkada konum güncelle
      final locCached = await getCache(cacheKeyLocation);
      if (locCached['success'] == true && locCached['data'] != null) {
        final loc = locCached['data'] as Map<String, dynamic>;
        final clat = (loc['latitude'] as num?)?.toDouble();
        final clng = (loc['longitude'] as num?)?.toDouble();
        if (clat != null && clng != null) {
          final latKey = clat.toStringAsFixed(4);
          final lngKey = clng.toStringAsFixed(4);
          double? bearing;
          final qiblaCached =
              await getCache(cacheKeyQiblaDirection(latKey, lngKey));
          if (qiblaCached['success'] == true && qiblaCached['data'] != null) {
            final data = qiblaCached['data'] as Map<String, dynamic>;
            bearing = (data['bearing'] as num?)?.toDouble();
          }
          bearing ??= calculateQiblaBearing(clat, clng);
          if (!mounted) return;
          setState(() {
            _locationInfo = {'latitude': clat, 'longitude': clng};
            _qiblaBearing = bearing;
            _qiblaLoading = false;
          });
          _loadLocationName(clat, clng);
          _startCompass();
          _refreshQiblaInBackground();
          return;
        }
      }

      // Önbellek yoksa son bilinen konumu dene (genelde çok hızlı)
      final lastKnown = await getLastKnownLocation();
      if (lastKnown.success &&
          lastKnown.latitude != null &&
          lastKnown.longitude != null) {
        final lat = lastKnown.latitude!;
        final lng = lastKnown.longitude!;
        final latKey = lat.toStringAsFixed(4);
        final lngKey = lng.toStringAsFixed(4);
        double? bearing;
        final qiblaCached =
            await getCache(cacheKeyQiblaDirection(latKey, lngKey));
        if (qiblaCached['success'] == true && qiblaCached['data'] != null) {
          final data = qiblaCached['data'] as Map<String, dynamic>;
          bearing = (data['bearing'] as num?)?.toDouble();
        }
        bearing ??= calculateQiblaBearing(lat, lng);
        if (!mounted) return;
        setState(() {
          _locationInfo = {'latitude': lat, 'longitude': lng};
          _qiblaBearing = bearing;
          _qiblaLoading = false;
        });
        _loadLocationName(lat, lng);
        _startCompass();
        _refreshQiblaInBackground();
        return;
      }

      final res = await getCurrentLocation();
      if (!res.success) {
        setState(() {
          _qiblaError = _t('locationPermissionRequired');
          _qiblaLoading = false;
        });
        return;
      }
      final lat = res.latitude!;
      final lng = res.longitude!;
      final latKey = lat.toStringAsFixed(4);
      final lngKey = lng.toStringAsFixed(4);
      await setCache(cacheKeyLocation, {'latitude': lat, 'longitude': lng},
          expiryLocation);

      final cached = await getCache(cacheKeyQiblaDirection(latKey, lngKey));
      if (cached['success'] == true && cached['data'] != null) {
        final data = cached['data'] as Map<String, dynamic>;
        _qiblaBearing = (data['bearing'] as num?)?.toDouble();
        setState(() {
          _locationInfo = {'latitude': lat, 'longitude': lng};
          _qiblaLoading = false;
        });
        _loadLocationName(lat, lng);
        _startCompass();
        return;
      }

      final bearing = calculateQiblaBearing(lat, lng);
      _qiblaBearing = bearing;
      await setCache(cacheKeyQiblaDirection(latKey, lngKey),
          {'bearing': bearing}, expiryQibla);
      setState(() {
        _locationInfo = {'latitude': lat, 'longitude': lng};
        _qiblaLoading = false;
      });
      _loadLocationName(lat, lng);
      _startCompass();
    } catch (e) {
      setState(() {
        _qiblaError = '${_t('error')}: $e';
        _qiblaLoading = false;
      });
    }
  }

  Future<void> _refreshQiblaInBackground() async {
    try {
      final res = await getCurrentLocation();
      if (!res.success || !mounted) return;
      final lat = res.latitude!;
      final lng = res.longitude!;
      await setCache(cacheKeyLocation, {'latitude': lat, 'longitude': lng},
          expiryLocation);
      final latKey = lat.toStringAsFixed(4);
      final lngKey = lng.toStringAsFixed(4);
      double? bearing;
      final cached = await getCache(cacheKeyQiblaDirection(latKey, lngKey));
      if (cached['success'] == true && cached['data'] != null) {
        final data = cached['data'] as Map<String, dynamic>;
        bearing = (data['bearing'] as num?)?.toDouble();
      }
      bearing ??= calculateQiblaBearing(lat, lng);
      await setCache(cacheKeyQiblaDirection(latKey, lngKey),
          {'bearing': bearing}, expiryQibla);
      if (!mounted) return;
      setState(() {
        _locationInfo = {'latitude': lat, 'longitude': lng};
        _qiblaBearing = bearing;
      });
      _loadLocationName(lat, lng);
    } catch (_) {}
  }

  void _loadLocationName(double lat, double lng) async {
    final locale = context.read<ThemeProvider>().language;
    final name = await getLocationName(lat, lng, locale);
    if (mounted) setState(() => _locationName = name);
  }

  void _startCompass() {
    _compassSub?.cancel();
    _compassSub = FlutterCompass.events?.listen((event) {
      if (event.heading == null || !mounted) return;
      final h = event.heading!;
      final now = DateTime.now();
      final elapsed = now.difference(_lastHeadingTime).inMilliseconds;
      final delta = (h - _lastHeadingSent).abs();
      if (delta > _headingThrottleDeg || elapsed >= _headingThrottleMs) {
        _lastHeadingSent = h;
        _lastHeadingTime = now;
        setState(() {
          _deviceHeading = h;
          _qiblaAngle = calculateQiblaAngle(_qiblaBearing ?? 0, _deviceHeading);
          _compassAvailable = true;
          _qiblaError = null;
        });
      }
    });
  }

  void _stopCompass() {
    _compassSub?.cancel();
    _compassSub = null;
  }

  Future<void> _ensureUserLocationIcon() async {
    if (_userLocationIcon != null) return;
    const int size = 80;
    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);
    final c = size / 2.0;
    // Google tarzı yön oku: koni uç yukarıda, konum merkezde (anchor)
    final path = Path()
      ..moveTo(c, 8)
      ..lineTo(c - 22, c + 18)
      ..lineTo(c - 8, c + 8)
      ..lineTo(c - 8, size - 2)
      ..lineTo(c + 8, size - 2)
      ..lineTo(c + 8, c + 8)
      ..lineTo(c + 22, c + 18)
      ..close();
    canvas.drawPath(path, Paint()..color = const Color(0xFF4285F4));
    canvas.drawPath(
        path,
        Paint()
          ..color = const Color(0xFF1A73E8)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2.5);
    canvas.drawCircle(Offset(c, c), 8, Paint()..color = Colors.white);
    canvas.drawCircle(
        Offset(c, c), 5, Paint()..color = const Color(0xFF4285F4));
    final picture = recorder.endRecording();
    final image = await picture.toImage(size, size);
    final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
    if (byteData == null || !mounted) return;
    final icon = BitmapDescriptor.fromBytes(byteData.buffer.asUint8List());
    if (mounted) setState(() => _userLocationIcon = icon);
  }

  Future<void> _loadMosques({bool force = false}) async {
    setState(() => _mosquesLoading = true);
    try {
      var res = await getCurrentLocation();
      if (!res.success) {
        final cached = await getCache(cacheKeyLocation);
        if (cached['success'] == true && cached['data'] != null) {
          final loc = cached['data'] as Map<String, dynamic>;
          final clat = (loc['latitude'] as num?)?.toDouble();
          final clng = (loc['longitude'] as num?)?.toDouble();
          if (clat != null && clng != null) {
            res =
                LocationResult(success: true, latitude: clat, longitude: clng);
          }
        }
      }
      if (!res.success || res.latitude == null) {
        setState(() {
          _mosquesLoading = false;
          _mosquesError = _t('error');
        });
        return;
      }
      final lat = res.latitude!;
      final lng = res.longitude!;
      setState(() => _userLocation = {'latitude': lat, 'longitude': lng});

      if (!force) {
        final latKey = lat.toStringAsFixed(4);
        final lngKey = lng.toStringAsFixed(4);
        final cached =
            await getCache(cacheKeyMosques(latKey, lngKey, _radiusMeters));
        if (cached['success'] == true && cached['data'] != null) {
          final list =
              (cached['data'] as List<dynamic>).cast<Map<String, dynamic>>();
          final withDistance = list.map((m) {
            final loc = m['geometry']?['location'] as Map<String, dynamic>?;
            final mlat = (loc?['lat'] as num?)?.toDouble() ?? lat;
            final mlng = (loc?['lng'] as num?)?.toDouble() ?? lng;
            final dist = _distanceKm(lat, lng, mlat, mlng);
            return {...m, 'distance': dist};
          }).toList();
          withDistance.sort((a, b) =>
              (a['distance'] as double).compareTo(b['distance'] as double));
          setState(() {
            _mosques = withDistance;
            _mosquesLoading = false;
          });
          return;
        }
      }

      final results = await findMosquesNearby(lat, lng, _radiusMeters);
      final withDistance = results.map((m) {
        final loc = m['geometry']?['location'] as Map<String, dynamic>?;
        final mlat = (loc?['lat'] as num?)?.toDouble() ?? lat;
        final mlng = (loc?['lng'] as num?)?.toDouble() ?? lng;
        return {...m, 'distance': _distanceKm(lat, lng, mlat, mlng)};
      }).toList();
      withDistance.sort((a, b) =>
          (a['distance'] as double).compareTo(b['distance'] as double));
      await setCache(
          cacheKeyMosques(
              lat.toStringAsFixed(4), lng.toStringAsFixed(4), _radiusMeters),
          withDistance,
          expiryMosques);
      setState(() {
        _mosques = withDistance;
        _mosquesLoading = false;
      });
    } catch (_) {
      setState(() {
        _mosquesLoading = false;
        _mosquesError = _t('error');
      });
    }
  }

  void _startLocationTracking() async {
    final res = await getCurrentLocation();
    if (res.success && res.latitude != null) {
      setState(() => _userLocation = {
            'latitude': res.latitude!,
            'longitude': res.longitude!
          });
    }
  }

  Future<void> _openNavigation(Map<String, dynamic> mosque) async {
    final loc = mosque['geometry']?['location'] as Map<String, dynamic>?;
    final lat = (loc?['lat'] as num?)?.toDouble();
    final lng = (loc?['lng'] as num?)?.toDouble();
    if (lat == null || lng == null) return;
    final url =
        Uri.parse('https://www.google.com/maps/search/?api=1&query=$lat,$lng');
    if (await canLaunchUrl(url)) {
      await launchUrl(url, mode: LaunchMode.externalApplication);
    } else {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(_t('mapAppNotFound'))),
        );
      }
    }
  }

  Future<void> _fetchRoute(double destLat, double destLng) async {
    if (_userLocation == null) return;
    final coords = await fetchRoute(
      _userLocation!['latitude']!,
      _userLocation!['longitude']!,
      destLat,
      destLng,
      walking: _transportMode == 'walking',
    );
    if (!mounted) return;
    setState(() => _routeCoords = coords);
    WidgetsBinding.instance.addPostFrameCallback((_) => _fitMapToRoute());
  }

  void _fitMapToRoute() {
    if (_mapController == null) return;
    final points = <LatLng>[];
    if (_userLocation != null) {
      points.add(
          LatLng(_userLocation!['latitude']!, _userLocation!['longitude']!));
    }
    if (_selectedMosque != null) {
      final loc =
          _selectedMosque!['geometry']?['location'] as Map<String, dynamic>?;
      final lat = (loc?['lat'] as num?)?.toDouble();
      final lng = (loc?['lng'] as num?)?.toDouble();
      if (lat != null && lng != null) points.add(LatLng(lat, lng));
    }
    for (final c in _routeCoords) {
      points.add(LatLng(c['latitude']!, c['longitude']!));
    }
    if (points.length < 2) return;
    double minLat = points.first.latitude, maxLat = minLat;
    double minLng = points.first.longitude, maxLng = minLng;
    for (final p in points) {
      if (p.latitude < minLat) minLat = p.latitude;
      if (p.latitude > maxLat) maxLat = p.latitude;
      if (p.longitude < minLng) minLng = p.longitude;
      if (p.longitude > maxLng) maxLng = p.longitude;
    }
    final bounds = LatLngBounds(
      southwest: LatLng(minLat, minLng),
      northeast: LatLng(maxLat, maxLng),
    );
    _mapController!.animateCamera(CameraUpdate.newLatLngBounds(bounds, 80));
  }

  void _onScreenModeChanged(String mode) {
    // Bir frame geciktir ki sol segment’te InkWell splash görünsün (sağdaki gibi)
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      setState(() => _screenMode = mode);
      if (mode == 'qibla') {
        _initQibla();
      } else {
        _loadMosques();
        _startLocationTracking();
        if (_viewMode == 'map')
          _startCompass();
        else
          _stopCompass();
      }
    });
  }

  String _t(String key) => AppLocalizations.t(context, key);

  @override
  Widget build(BuildContext context) {
    final insets = MediaQuery.paddingOf(context);
    final bottomPad = insets.bottom + 80;

    if (_screenMode == 'qibla' && _qiblaLoading) {
      return Scaffold(
        backgroundColor: const Color(0xFFF8FAFC),
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const CircularProgressIndicator(color: Color(0xFF6366F1)),
              SizedBox(height: scaleSize(context, 16)),
              Text(_t('qiblaCalculating'),
                  style: GoogleFonts.plusJakartaSans(
                      fontSize: scaleFont(context, 16),
                      color: const Color(0xFF64748B))),
            ],
          ),
        ),
      );
    }

    if (_screenMode == 'qibla' && _qiblaError != null) {
      return Scaffold(
        backgroundColor: const Color(0xFFF8FAFC),
        body: SafeArea(
          child: Padding(
            padding: EdgeInsets.all(scaleSize(context, 20)),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(_t('error'),
                    style: GoogleFonts.plusJakartaSans(
                        color: const Color(0xFFEF4444),
                        fontSize: scaleFont(context, 18),
                        fontWeight: FontWeight.w600)),
                SizedBox(height: scaleSize(context, 8)),
                Text(_qiblaError!,
                    textAlign: TextAlign.center,
                    style: GoogleFonts.plusJakartaSans(
                        color: const Color(0xFF64748B),
                        fontSize: scaleFont(context, 14))),
                SizedBox(height: scaleSize(context, 16)),
                TextButton(
                  onPressed: () {
                    setState(() => _qiblaError = null);
                    _initQibla();
                  },
                  style: TextButton.styleFrom(
                    backgroundColor: const Color(0xFFEFF6FF),
                    foregroundColor: const Color(0xFF6366F1),
                    padding: EdgeInsets.symmetric(
                        horizontal: scaleSize(context, 12),
                        vertical: scaleSize(context, 12)),
                  ),
                  child: Text(_t('retry'),
                      style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w600)),
                ),
              ],
            ),
          ),
        ),
      );
    }

    if (_screenMode == 'qibla' && !_compassAvailable && !_qiblaLoading) {
      return Scaffold(
        backgroundColor: const Color(0xFFF8FAFC),
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const CircularProgressIndicator(color: Color(0xFF6366F1)),
              SizedBox(height: scaleSize(context, 16)),
              Text(_t('enabling'),
                  style: GoogleFonts.plusJakartaSans(
                      fontSize: scaleFont(context, 16),
                      color: const Color(0xFF64748B))),
            ],
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      body: SafeArea(
        top: true,
        child: Stack(
          children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Header with logo bg – segmentler sol/sağ üstte
                SizedBox(
                  width: double.infinity,
                  height: scaleSize(context, 100),
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      Positioned.fill(
                        child: Image.asset('assets/nida.png',
                            fit: BoxFit.cover,
                            opacity: const AlwaysStoppedAnimation(0.06)),
                      ),
                      if (_screenMode == 'qibla' &&
                          _locationName != null &&
                          _locationName!['city'] != null)
                        Positioned(
                          bottom: scaleSize(context, 10),
                          left: 0,
                          right: 0,
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                _locationName!['city'].toString(),
                                style: GoogleFonts.plusJakartaSans(
                                    fontSize: scaleFont(context, 16),
                                    fontWeight: FontWeight.w700,
                                    color: const Color(0xFF1E293B)),
                                textAlign: TextAlign.center,
                              ),
                              if (_locationName!['country'] != null)
                                Padding(
                                  padding: EdgeInsets.only(
                                      top: scaleSize(context, 2)),
                                  child: Text(
                                    _locationName!['country'].toString(),
                                    style: GoogleFonts.plusJakartaSans(
                                        fontSize: scaleFont(context, 11),
                                        color: const Color(0xFF64748B)),
                                    textAlign: TextAlign.center,
                                  ),
                                ),
                            ],
                          ),
                        ),
                      if (_screenMode == 'mosques')
                        Padding(
                          padding: EdgeInsets.only(top: scaleSize(context, 44)),
                          child: Center(
                            child: Text(
                              _t('nearbyMosques'),
                              style: GoogleFonts.plusJakartaSans(
                                  fontSize: scaleFont(context, 20),
                                  fontWeight: FontWeight.bold,
                                  color: const Color(0xFF1E293B)),
                            ),
                          ),
                        ),
                      // Sol üst: Kıble / Camiler (tek arka plan, sadece aktif seçim radius’lu)
                      Positioned(
                        left: scaleSize(context, 16),
                        top: scaleSize(context, 8),
                        child: _segmentGroup(
                          context,
                          [
                            (
                              Icons.place,
                              () => _onScreenModeChanged('mosques')
                            ),
                            (
                              Icons.explore,
                              () => _onScreenModeChanged('qibla')
                            ),
                          ],
                          _screenMode == 'mosques' ? 0 : 1,
                          groupKey: 'header_left_segment',
                        ),
                      ),
                      // Sağ üst: Liste / Harita – Cami/Kıble ile birebir aynı _segmentGroup tasarımı
                      if (_screenMode == 'mosques')
                        Positioned(
                          right: scaleSize(context, 16),
                          top: scaleSize(context, 8),
                          child: _segmentGroup(
                            context,
                            [
                              (
                                Icons.list_alt,
                                () {
                                  setState(() => _viewMode = 'list');
                                  _stopCompass();
                                }
                              ),
                              (
                                Icons.map_outlined,
                                () {
                                  setState(() => _viewMode = 'map');
                                  _startCompass();
                                }
                              ),
                            ],
                            _viewMode == 'list' ? 0 : 1,
                            groupKey: 'header_right_segment',
                          ),
                        ),
                    ],
                  ),
                ),
                SizedBox(height: scaleSize(context, 6)),
                Expanded(
                  child: _screenMode == 'qibla'
                      ? SingleChildScrollView(
                          padding:
                              EdgeInsets.only(bottom: scaleSize(context, 120)),
                          child: Column(
                            children: [
                              SizedBox(height: scaleSize(context, 40)),
                              CustomCompass(
                                  deviceHeading: _deviceHeading,
                                  qiblaAngle: _qiblaAngle,
                                  alignedLabel: _t('qiblaAligned')),
                              SizedBox(height: scaleSize(context, 24)),
                              Container(
                                margin: EdgeInsets.symmetric(
                                    horizontal: scaleSize(context, 20)),
                                padding: EdgeInsets.all(scaleSize(context, 12)),
                                decoration: BoxDecoration(
                                  color: Colors.white.withValues(alpha: 0.95),
                                  borderRadius: BorderRadius.circular(
                                      scaleSize(context, 12)),
                                  boxShadow: [
                                    BoxShadow(
                                        color: Colors.black
                                            .withValues(alpha: 0.15),
                                        blurRadius: scaleSize(context, 8),
                                        offset:
                                            Offset(0, scaleSize(context, 2))),
                                  ],
                                ),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                        '${_t('compassHeading')}: ${_deviceHeading.round()}°',
                                        style: GoogleFonts.plusJakartaSans(
                                            fontSize: scaleFont(context, 14),
                                            color: const Color(0xFF64748B))),
                                    SizedBox(height: scaleSize(context, 4)),
                                    Text(
                                      '${_t('qiblaDirectionTitle')}: ${_qiblaBearing != null ? _qiblaBearing!.round() : '-'}°',
                                      style: GoogleFonts.plusJakartaSans(
                                          fontSize: scaleFont(context, 14),
                                          color: const Color(0xFF6366F1),
                                          fontWeight: FontWeight.w600),
                                    ),
                                    if (_locationInfo != null) ...[
                                      SizedBox(height: scaleSize(context, 4)),
                                      Text(
                                        '${(_locationInfo!['latitude'] as num?)?.toStringAsFixed(4)}, ${(_locationInfo!['longitude'] as num?)?.toStringAsFixed(4)}',
                                        style: GoogleFonts.plusJakartaSans(
                                            fontSize: scaleFont(context, 12),
                                            color: const Color(0xFF94A3B8)),
                                      ),
                                    ],
                                  ],
                                ),
                              ),
                            ],
                          ),
                        )
                      : _viewMode == 'list'
                          ? _mosquesLoading
                              ? const Center(
                                  child: CircularProgressIndicator(
                                      color: Color(0xFF6366F1)))
                              : _mosquesError != null
                                  ? Center(
                                      child: Padding(
                                        padding: EdgeInsets.all(
                                            scaleSize(context, 24)),
                                        child: Column(
                                          mainAxisAlignment:
                                              MainAxisAlignment.center,
                                          children: [
                                            Text(_mosquesError!,
                                                textAlign: TextAlign.center,
                                                style: GoogleFonts.plusJakartaSans(
                                                    color:
                                                        const Color(0xFF64748B),
                                                    fontSize: scaleFont(
                                                        context, 14))),
                                            SizedBox(
                                                height: scaleSize(context, 16)),
                                            TextButton(
                                              onPressed: () =>
                                                  _loadMosques(force: true),
                                              style: TextButton.styleFrom(
                                                  foregroundColor:
                                                      const Color(0xFF6366F1)),
                                              child: Text(_t('retry')),
                                            ),
                                          ],
                                        ),
                                      ),
                                    )
                                  : RefreshIndicator(
                                      onRefresh: () =>
                                          _loadMosques(force: true),
                                      color: const Color(0xFF6366F1),
                                      child: ListView.builder(
                                        padding: EdgeInsets.only(
                                            left: scaleSize(context, 15),
                                            right: scaleSize(context, 15),
                                            bottom: bottomPad),
                                        itemCount: _mosques.length,
                                        itemBuilder: (_, i) => _MosqueCard(
                                          mosque: _mosques[i],
                                          index: i,
                                          onTap: () =>
                                              _openNavigation(_mosques[i]),
                                          t: _t,
                                        ),
                                      ),
                                    )
                          : _mapContent(context, _t, insets, bottomPad),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  /// Tek arka plan, sadece aktif seçimde radius’lu pill. [groupKey] ile sol/sağ ayrımı – rebuild’de splash korunur.
  Widget _segmentGroup(
    BuildContext context,
    List<(IconData icon, VoidCallback onTap)> segments,
    int activeIndex, {
    String? groupKey,
  }) {
    final r = scaleSize(context, 14);
    final paddingV = scaleSize(context, 10);
    final paddingH = scaleSize(context, 16);
    final innerR = scaleSize(context, 10);
    final margin = scaleSize(context, 3);
    return Container(
      key: groupKey != null ? ValueKey<String>(groupKey) : null,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(r),
        color: Colors.white.withValues(alpha: 0.75),
      ),
      clipBehavior: Clip.antiAlias,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: List.generate(segments.length, (i) {
          final (icon, onTap) = segments[i];
          final active = i == activeIndex;
          return Material(
            key: groupKey != null ? ValueKey<String>('$groupKey-$i') : null,
            color: Colors.transparent,
            child: InkWell(
              onTap: onTap,
              borderRadius: BorderRadius.circular(innerR),
              splashColor: const Color(0xFF6366F1).withValues(alpha: 0.2),
              highlightColor: const Color(0xFF6366F1).withValues(alpha: 0.1),
              child: Stack(
                alignment: Alignment.center,
                children: [
                  if (active)
                    Positioned.fill(
                      child: Container(
                        margin: EdgeInsets.all(margin),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(innerR),
                          color: const Color(0xFF6366F1).withValues(alpha: 0.2),
                        ),
                      ),
                    ),
                  Padding(
                    padding: EdgeInsets.symmetric(
                        vertical: paddingV, horizontal: paddingH),
                    child: Icon(
                      icon,
                      size: scaleSize(context, 22),
                      color: active
                          ? const Color(0xFF4F46E5)
                          : const Color(0xFF64748B),
                    ),
                  ),
                ],
              ),
            ),
          );
        }),
      ),
    );
  }

  Widget _mapContent(BuildContext context, String Function(String) t,
      EdgeInsets insets, double bottomPad) {
    WidgetsBinding.instance
        .addPostFrameCallback((_) => _ensureUserLocationIcon());
    final lat = _userLocation?['latitude'] ?? 39.9334;
    final lng = _userLocation?['longitude'] ?? 32.8597;
    final initialPosition = LatLng(lat, lng);

    final Set<Polyline> polylines = {};
    if (_routeCoords.length >= 2) {
      polylines.add(
        Polyline(
          polylineId: const PolylineId('route'),
          points: _routeCoords
              .map((c) => LatLng(c['latitude']!, c['longitude']!))
              .toList(),
          color: _transportMode == 'walking'
              ? const Color(0xFF10B981)
              : const Color(0xFF6366F1),
          width: 5,
        ),
      );
    }

    final Set<Marker> allMarkers = {};
    if (_userLocation != null) {
      allMarkers.add(
        Marker(
          markerId: const MarkerId('user'),
          position:
              LatLng(_userLocation!['latitude']!, _userLocation!['longitude']!),
          rotation: _deviceHeading,
          icon: _userLocationIcon ??
              BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueAzure),
          zIndex: 10,
        ),
      );
    }
    allMarkers.addAll(
      _mosques.map((m) {
        final loc = m['geometry']?['location'] as Map<String, dynamic>?;
        final mlat = (loc?['lat'] as num?)?.toDouble() ?? 0.0;
        final mlng = (loc?['lng'] as num?)?.toDouble() ?? 0.0;
        final isSelected = _selectedMosque?['place_id'] == m['place_id'];
        return Marker(
          markerId: MarkerId(m['place_id']?.toString() ?? ''),
          position: LatLng(mlat, mlng),
          icon: BitmapDescriptor.defaultMarkerWithHue(isSelected
              ? BitmapDescriptor.hueGreen
              : BitmapDescriptor.hueViolet),
          onTap: () {
            setState(() {
              if (_selectedMosque?['place_id'] == m['place_id']) {
                _openNavigation(m);
              } else {
                _selectedMosque = m;
                _fetchRoute(mlat, mlng);
              }
            });
          },
        );
      }),
    );

    return Stack(
      children: [
        GoogleMap(
          initialCameraPosition:
              CameraPosition(target: initialPosition, zoom: 14),
          onMapCreated: (c) => _mapController = c,
          myLocationEnabled: false,
          myLocationButtonEnabled: true,
          polylines: polylines,
          markers: allMarkers,
          onTap: (_) => setState(() => _selectedMosque = null),
        ),
        // Transport picker
        Positioned(
          left: scaleSize(context, 15),
          top: MediaQuery.sizeOf(context).height * 0.25,
          child: Container(
            padding: EdgeInsets.all(scaleSize(context, 6)),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.95),
              borderRadius: BorderRadius.circular(scaleSize(context, 12)),
              boxShadow: [
                BoxShadow(
                    color: Colors.black.withValues(alpha: 0.1),
                    blurRadius: scaleSize(context, 8))
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                IconButton(
                  icon: Icon(Icons.directions_walk,
                      size: scaleSize(context, 28),
                      color: _transportMode == 'walking'
                          ? Colors.white
                          : const Color(0xFF64748B)),
                  onPressed: () {
                    setState(() => _transportMode = 'walking');
                    if (_selectedMosque != null) {
                      final loc = _selectedMosque!['geometry']?['location']
                          as Map<String, dynamic>?;
                      final mlat = (loc?['lat'] as num?)?.toDouble();
                      final mlng = (loc?['lng'] as num?)?.toDouble();
                      if (mlat != null && mlng != null) _fetchRoute(mlat, mlng);
                    }
                  },
                  style: IconButton.styleFrom(
                    backgroundColor: _transportMode == 'walking'
                        ? const Color(0xFF6366F1)
                        : const Color(0xFFF1F5F9),
                  ),
                ),
                SizedBox(height: scaleSize(context, 8)),
                IconButton(
                  icon: Icon(Icons.directions_car,
                      size: scaleSize(context, 28),
                      color: _transportMode == 'driving'
                          ? Colors.white
                          : const Color(0xFF64748B)),
                  onPressed: () {
                    setState(() => _transportMode = 'driving');
                    if (_selectedMosque != null) {
                      final loc = _selectedMosque!['geometry']?['location']
                          as Map<String, dynamic>?;
                      final mlat = (loc?['lat'] as num?)?.toDouble();
                      final mlng = (loc?['lng'] as num?)?.toDouble();
                      if (mlat != null && mlng != null) _fetchRoute(mlat, mlng);
                    }
                  },
                  style: IconButton.styleFrom(
                    backgroundColor: _transportMode == 'driving'
                        ? const Color(0xFF6366F1)
                        : const Color(0xFFF1F5F9),
                  ),
                ),
              ],
            ),
          ),
        ),
        if (_selectedMosque != null)
          Positioned(
            left: scaleSize(context, 15),
            right: scaleSize(context, 15),
            bottom: bottomPad + scaleSize(context, 10),
            child: Material(
              elevation: 10,
              borderRadius: BorderRadius.circular(scaleSize(context, 20)),
              child: _MosqueCard(
                mosque: _selectedMosque!,
                index: 0,
                onTap: () => _openNavigation(_selectedMosque!),
                t: t,
                isMapModal: true,
              ),
            ),
          ),
        Positioned(
          top: scaleSize(context, 15),
          left: 0,
          right: 0,
          child: Center(
            child: Container(
              padding: EdgeInsets.symmetric(
                  horizontal: scaleSize(context, 15),
                  vertical: scaleSize(context, 8)),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.9),
                borderRadius: BorderRadius.circular(scaleSize(context, 20)),
                boxShadow: [
                  BoxShadow(
                      color: Colors.black.withValues(alpha: 0.1),
                      blurRadius: scaleSize(context, 4))
                ],
              ),
              child: Text(
                '${_mosques.length} ${t('mosquesFound')}',
                style: GoogleFonts.plusJakartaSans(
                    fontWeight: FontWeight.bold,
                    color: const Color(0xFF1E293B),
                    fontSize: scaleFont(context, 14)),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _MosqueCard extends StatelessWidget {
  final Map<String, dynamic> mosque;
  final int index;
  final VoidCallback onTap;
  final String Function(String) t;
  final bool isMapModal;

  const _MosqueCard({
    required this.mosque,
    required this.index,
    required this.onTap,
    required this.t,
    this.isMapModal = false,
  });

  @override
  Widget build(BuildContext context) {
    final name = mosque['name'] as String? ?? '';
    final vicinity = mosque['vicinity'] as String? ?? '';
    final distance = (mosque['distance'] as num?)?.toDouble();
    final distStr = distance != null ? _formatDistance(distance) : '';

    final cardRadius = scaleSize(context, 16);
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(cardRadius),
      child: Container(
        padding: EdgeInsets.all(scaleSize(context, isMapModal ? 10 : 15)),
        margin: EdgeInsets.only(bottom: scaleSize(context, 10)),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(cardRadius),
          boxShadow: [
            BoxShadow(
                color: Colors.black.withValues(alpha: 0.05),
                blurRadius: scaleSize(context, 2),
                offset: Offset(0, scaleSize(context, 1))),
          ],
        ),
        child: Row(
          children: [
            Container(
              width: scaleSize(context, 44),
              height: scaleSize(context, 44),
              margin: EdgeInsets.only(right: scaleSize(context, 15)),
              decoration: const BoxDecoration(
                  color: Color(0xFFEEF2FF), shape: BoxShape.circle),
              child: Stack(
                alignment: Alignment.center,
                children: [
                  Icon(Icons.place,
                      size: scaleSize(context, 24),
                      color: const Color(0xFF6366F1)),
                  if (!isMapModal)
                    Positioned(
                      top: -scaleSize(context, 2),
                      right: -scaleSize(context, 2),
                      child: Container(
                        width: scaleSize(context, 18),
                        height: scaleSize(context, 18),
                        decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: const Color(0xFF6366F1),
                            border: Border.fromBorderSide(BorderSide(
                                color: Colors.white,
                                width: scaleSize(context, 1.5)))),
                        alignment: Alignment.center,
                        child: Text('${index + 1}',
                            style: GoogleFonts.plusJakartaSans(
                                color: Colors.white,
                                fontSize: scaleFont(context, 9),
                                fontWeight: FontWeight.bold)),
                      ),
                    ),
                ],
              ),
            ),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.plusJakartaSans(
                          fontSize: scaleFont(context, 16),
                          fontWeight: FontWeight.bold,
                          color: const Color(0xFF1E293B))),
                  Padding(
                    padding: EdgeInsets.only(top: scaleSize(context, 4)),
                    child: Text(vicinity,
                        maxLines: isMapModal ? 1 : 2,
                        overflow: TextOverflow.ellipsis,
                        style: GoogleFonts.plusJakartaSans(
                            fontSize: scaleFont(context, 13),
                            color: const Color(0xFF64748B))),
                  ),
                  if (distStr.isNotEmpty)
                    Padding(
                      padding: EdgeInsets.only(top: scaleSize(context, 4)),
                      child: Row(
                        children: [
                          Icon(
                              distance! < 1.5
                                  ? Icons.directions_walk
                                  : Icons.directions_car,
                              size: scaleSize(context, 14),
                              color: const Color(0xFF64748B)),
                          SizedBox(width: scaleSize(context, 4)),
                          Text('$distStr ${t('away')}',
                              style: GoogleFonts.plusJakartaSans(
                                  fontSize: scaleFont(context, 12),
                                  color: const Color(0xFF64748B))),
                        ],
                      ),
                    ),
                ],
              ),
            ),
            IconButton(
              onPressed: onTap,
              icon: Icon(Icons.navigation,
                  size: scaleSize(context, 36), color: const Color(0xFF6366F1)),
            ),
          ],
        ),
      ),
    );
  }
}
