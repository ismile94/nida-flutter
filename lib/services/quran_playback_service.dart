// RN: AudioService.js + useAudioPlayback – oynatma, hız/okuyucu/tekrar, everyayah.com URL.
// Gapless: sonraki URL önceden alınır, parça bitince hemen setUrl+play (kısa gap kabul).

import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:just_audio/just_audio.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'audio_download_service.dart';
import 'playback_engine.dart';

const String _prefKeySelectedReciter = '@quran_selected_reciter';

class CurrentAyah {
  final int surah;
  final int ayah;
  const CurrentAyah(this.surah, this.ayah);
}

class QuranPlaybackService extends ChangeNotifier {
  QuranPlaybackService() {
    _player = AudioPlayer();
    _subscriptions.add(_player.positionStream.listen(_onPosition));
    _subscriptions.add(_player.playerStateStream.listen(_onPlayerState));
  }

  final List<StreamSubscription<dynamic>> _subscriptions = [];
  late final AudioPlayer _player;

  List<PlaylistItem> _playlist = [];
  int _currentIndex = -1;
  String? _preloadedNextUrl;
  bool _loadingNext = false;

  /// Namaz sırası (Fatiha+zammi) bittiğinde tekrar etmesin; sadece dur.
  bool _isPrayerSequence = false;

  /// RN: cache indicator – bu oturumda çalınan veya preload edilen ayetler (surah:ayah)
  final Set<String> _playedOrPreloadedAyahs = {};
  bool isCached(int surah, int ayah) => _playedOrPreloadedAyahs.contains('$surah:$ayah');

  /// Okuyucu değişince o ayette kalsın diye saklanan ayet (playlist boşken currentAyah bu olur).
  CurrentAyah? _savedAyahOnReciterChange;

  CurrentAyah? get currentAyah {
    if (_currentIndex >= 0 && _currentIndex < _playlist.length) {
      final item = _playlist[_currentIndex];
      return CurrentAyah(item.surah, item.ayah);
    }
    return _savedAyahOnReciterChange;
  }

  bool _isPlaying = false;
  bool get isPlaying => _isPlaying;

  bool _isPaused = false;
  bool get isPaused => _isPaused;

  double _playbackSpeed = 1.0;
  double get playbackSpeed => _playbackSpeed;

  String _selectedReciterKey = 'ar.yasseraldossari';
  String get selectedReciterKey => _selectedReciterKey;

  String _repeatMode = 'quran';
  String get repeatMode => _repeatMode;

  List<PlaylistItem> get playlist => List.unmodifiable(_playlist);
  int get currentIndex => _currentIndex;

  Duration _position = Duration.zero;
  Duration get position => _position;
  Duration _duration = Duration.zero;
  Duration get duration => _duration;

  ({int current, int total})? _preloadProgress;
  ({int current, int total})? get preloadProgress => _preloadProgress;

  /// Namaz: Önce Fatiha (1:1–7), ardından besmele + zammi sure. RN handlePlayForPrayer(1, 1, { stopAtSurahEnd: true, playNextSurah }).
  /// Bittiğinde tekrar etmez (_isPrayerSequence).
  Future<void> playPrayerSequence(int firstSurah, int? nextZammiSurah) async {
    _savedAyahOnReciterChange = null;
    await stop();
    _isPrayerSequence = true;
    _playlist = generatePlaylist(
      startSurah: firstSurah,
      startAyah: 1,
      repeatMode: _repeatMode,
      stopAtSurahEnd: true,
      playNextSurah: nextZammiSurah,
    );
    if (_playlist.isEmpty) return;
    _currentIndex = 0;
    _preloadedNextUrl = null;
    final item = _playlist[0];
    _isPlaying = true;
    _isPaused = false;
    notifyListeners();
    final source = await getAyahAudioSource(_selectedReciterKey, item.surah, item.ayah);
    if (source == null) {
      _isPlaying = false;
      notifyListeners();
      return;
    }
    try {
      _playedOrPreloadedAyahs.add('${item.surah}:${item.ayah}');
      await _player.setUrl(source.startsWith('http') ? source : 'file://$source');
      _player.setSpeed(_playbackSpeed);
      await _player.play();
      notifyListeners();
      unawaited(_preloadNextUrl());
    } catch (e) {
      _isPlaying = false;
      notifyListeners();
      debugPrint('[QuranPlaybackService] playPrayerSequence error: $e');
    }
  }

  /// When [repeatMode] is 'range', pass [endSurah] and [endAyah] to play that range (e.g. current surah).
  /// Namaz: endSurah/endAyah verildiğinde sadece o aralık çalınır (Fatiha+zammi veya sadece zammi), Kuran tekrarı uygulanmaz.
  Future<void> playAyah(int surah, int ayah, {int? endSurah, int? endAyah}) async {
    _savedAyahOnReciterChange = null;
    await stop();
    final useRange = endSurah != null && endAyah != null;
    _isPrayerSequence = useRange; // Namaz zammi-only: bitince tekrar etmesin
    _playlist = generatePlaylist(
      startSurah: surah,
      startAyah: ayah,
      repeatMode: useRange ? 'range' : _repeatMode,
      endSurah: endSurah,
      endAyah: endAyah,
    );
    if (_playlist.isEmpty) return;
    _currentIndex = 0;
    _preloadedNextUrl = null;
    final item = _playlist[0];
    _isPlaying = true;
    _isPaused = false;
    notifyListeners();
    final source = await getAyahAudioSource(_selectedReciterKey, item.surah, item.ayah);
    if (source == null) {
      _isPlaying = false;
      notifyListeners();
      return;
    }
    try {
      _playedOrPreloadedAyahs.add('${item.surah}:${item.ayah}');
      await _player.setUrl(source.startsWith('http') ? source : 'file://$source');
      _player.setSpeed(_playbackSpeed);
      await _player.play();
      notifyListeners();
      unawaited(_preloadNextUrl());
    } catch (e) {
      _isPlaying = false;
      notifyListeners();
      debugPrint('[QuranPlaybackService] playAyah error: $e');
    }
  }

  void _onPosition(Duration p) {
    _position = p;
    _duration = _player.duration ?? Duration.zero;
    notifyListeners();

    if (_playlist.isEmpty || _currentIndex < 0 || _currentIndex >= _playlist.length) return;
    final dur = _player.duration;
    if (dur == null || dur.inMilliseconds <= 0) return;
    final progress = p.inMilliseconds / dur.inMilliseconds;
    if (progress >= 0.7 && _preloadedNextUrl == null && !_loadingNext) {
      unawaited(_preloadNextUrl());
    }
  }

  void _onPlayerState(PlayerState state) {
    if (state.processingState == ProcessingState.completed) {
      unawaited(_playNextOrStop());
    }
  }

  Future<void> _preloadNextUrl() async {
    if (_loadingNext) return;
    final nextIndex = _currentIndex + 1;
    if (nextIndex >= _playlist.length) return;
    final reciterAtStart = _selectedReciterKey;
    _loadingNext = true;
    try {
      final next = _playlist[nextIndex];
      final source = await getAyahAudioSource(reciterAtStart, next.surah, next.ayah);
      // Okuyucu değiştiyse bu preload’ı kullanma; sonraki ayet yeni okuyucuyla yüklensin.
      if (_selectedReciterKey != reciterAtStart) return;
      _preloadedNextUrl = source;
      if (source != null) _playedOrPreloadedAyahs.add('${next.surah}:${next.ayah}');
    } finally {
      _loadingNext = false;
      notifyListeners();
    }
  }

  Future<void> _playNextOrStop() async {
    final nextIndex = _currentIndex + 1;
    if (nextIndex >= _playlist.length) {
      // Namaz sırası (Fatiha+zammi): tekrar yok, sadece dur
      if (_isPrayerSequence) {
        await stop();
        return;
      }
      if (_repeatMode == 'one' && _playlist.length == 1) {
        final item = _playlist[0];
        final source = await getAyahAudioSource(_selectedReciterKey, item.surah, item.ayah);
        if (source != null) {
          try {
            final url = source.startsWith('http') ? source : 'file://$source';
            await _player.setUrl(url);
            _player.setSpeed(_playbackSpeed);
            await _player.play();
            _isPlaying = true;
            _isPaused = false;
            notifyListeners();
            unawaited(_preloadNextUrl());
            return;
          } catch (_) {}
        }
      }
      if (_repeatMode == 'surah' && _playlist.isNotEmpty) {
        final item = _playlist[0];
        final source = await getAyahAudioSource(_selectedReciterKey, item.surah, item.ayah);
        if (source != null) {
          try {
            _currentIndex = 0;
            _preloadedNextUrl = null;
            final url = source.startsWith('http') ? source : 'file://$source';
            await _player.setUrl(url);
            _player.setSpeed(_playbackSpeed);
            await _player.play();
            _isPlaying = true;
            _isPaused = false;
            notifyListeners();
            unawaited(_preloadNextUrl());
            return;
          } catch (_) {}
        }
      }
      if (_repeatMode == 'quran' && _playlist.isNotEmpty) {
        final item = _playlist[0];
        final source = await getAyahAudioSource(_selectedReciterKey, item.surah, item.ayah);
        if (source != null) {
          try {
            _currentIndex = 0;
            _preloadedNextUrl = null;
            final url = source.startsWith('http') ? source : 'file://$source';
            await _player.setUrl(url);
            _player.setSpeed(_playbackSpeed);
            await _player.play();
            _isPlaying = true;
            _isPaused = false;
            notifyListeners();
            unawaited(_preloadNextUrl());
            return;
          } catch (_) {}
        }
      }
      // Playlist bitti (örn. zammi suresi); otomatik durdur – Prayer ekranı kuralları
      await stop();
      return;
    }
    String? nextSource = _preloadedNextUrl;
    if (nextSource == null) {
      nextSource = await getAyahAudioSource(
        _selectedReciterKey,
        _playlist[nextIndex].surah,
        _playlist[nextIndex].ayah,
      );
    }
    if (nextSource == null) {
      _isPlaying = false;
      notifyListeners();
      return;
    }
    _currentIndex = nextIndex;
    _preloadedNextUrl = null;
    final nextUrl = nextSource.startsWith('http') ? nextSource : 'file://$nextSource';
    try {
      await _player.setUrl(nextUrl);
      _player.setSpeed(_playbackSpeed);
      await _player.play();
      _isPlaying = true;
      _isPaused = false;
      notifyListeners();
      unawaited(_preloadNextUrl());
    } catch (e) {
      debugPrint('[QuranPlaybackService] _playNextOrStop error: $e');
      _isPlaying = false;
      notifyListeners();
    }
  }

  Future<void> pause() async {
    await _player.pause();
    _isPaused = true;
    notifyListeners();
  }

  Future<void> resume() async {
    await _player.play();
    _isPaused = false;
    notifyListeners();
  }

  Future<void> stop() async {
    await _player.stop();
    await _player.seek(Duration.zero);
    _playlist = [];
    _currentIndex = -1;
    _preloadedNextUrl = null;
    _isPlaying = false;
    _isPaused = false;
    _isPrayerSequence = false;
    _position = Duration.zero;
    _duration = Duration.zero;
    _preloadProgress = null;
    // _savedAyahOnReciterChange setReciter tarafından set edilir; stop() onu silmez
    notifyListeners();
  }

  Future<void> nextAyah() async {
    if (_playlist.isEmpty || _currentIndex >= _playlist.length - 1) return;
    final nextIndex = _currentIndex + 1;
    final next = _playlist[nextIndex];
    final source = await getAyahAudioSource(_selectedReciterKey, next.surah, next.ayah);
    if (source == null) return;
    _currentIndex = nextIndex;
    _preloadedNextUrl = null;
    final url = source.startsWith('http') ? source : 'file://$source';
    try {
      await _player.setUrl(url);
      _player.setSpeed(_playbackSpeed);
      await _player.play();
      _isPlaying = true;
      _isPaused = false;
      notifyListeners();
      unawaited(_preloadNextUrl());
    } catch (e) {
      debugPrint('[QuranPlaybackService] nextAyah error: $e');
    }
  }

  Future<void> previousAyah() async {
    if (_playlist.isEmpty) return;
    if (_currentIndex <= 0) return;
    final prevIndex = _currentIndex - 1;
    final prev = _playlist[prevIndex];
    final source = await getAyahAudioSource(_selectedReciterKey, prev.surah, prev.ayah);
    if (source == null) return;
    _currentIndex = prevIndex;
    _preloadedNextUrl = null;
    final url = source.startsWith('http') ? source : 'file://$source';
    try {
      await _player.setUrl(url);
      _player.setSpeed(_playbackSpeed);
      await _player.play();
      _isPlaying = true;
      _isPaused = false;
      notifyListeners();
      unawaited(_preloadNextUrl());
    } catch (e) {
      debugPrint('[QuranPlaybackService] previousAyah error: $e');
    }
  }

  Future<void> setSpeed(double speed) async {
    _playbackSpeed = speed;
    await _player.setSpeed(speed);
    notifyListeners();
  }

  /// Son seçilen okuyucuyu SharedPreferences’tan yükler (uygulama açılışında çağrılmalı).
  Future<void> loadSavedReciter() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final key = prefs.getString(_prefKeySelectedReciter);
      if (key != null && key.isNotEmpty) {
        _selectedReciterKey = key;
        notifyListeners();
      }
    } catch (_) {}
  }

  /// Okuyucu değişir: mevcut ayeti sakla, oynatmayı durdur, yeni okuyucuyu seç (aynı ayetten yeni okuyucuyla devam edilebilir).
  Future<void> setReciter(String reciterKey) async {
    final saved = currentAyah;
    if (saved != null) _savedAyahOnReciterChange = saved;
    await stop();
    _selectedReciterKey = reciterKey;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_prefKeySelectedReciter, reciterKey);
    } catch (_) {}
    notifyListeners();
  }

  void setRepeatMode(String mode) {
    _repeatMode = mode;
    notifyListeners();
  }

  /// RN: Clear Audio Cache – ses önbelleğini temizle (just_audio platform cache’i temizlenir).
  Future<bool> clearAudioCache() async {
    try {
      await stop();
      _preloadedNextUrl = null;
      _playedOrPreloadedAyahs.clear();
      notifyListeners();
      return true;
    } catch (_) {
      return false;
    }
  }

  @override
  void dispose() {
    for (final s in _subscriptions) {
      s.cancel();
    }
    _player.dispose();
    super.dispose();
  }
}
