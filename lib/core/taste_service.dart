import 'dart:async';
import 'dart:math';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import '../models/song.dart';

class TasteService {
  static final TasteService _instance = TasteService._();
  factory TasteService() => _instance;
  TasteService._();

  final FirebaseFirestore _db = FirebaseFirestore.instance;

  Map<String, double> _artistScores = {};
  Map<String, String> _artistNames = {};
  Map<String, double> _languageScores = {};
  Map<String, double> _moodScores = {};
  List<Map<String, dynamic>> _recentlyPlayed = [];
  int _totalPlays = 0;
  DateTime? _lastDecayDate;
  Timer? _saveDebouncer;

  static const _moodKeywords = <String, List<String>>{
    'romantic': ['love', 'romance', 'pyaar', 'ishq', 'dil', 'heart', 'mohabbat', 'prem'],
    'sad': ['sad', 'broken', 'pain', 'dard', 'judai', 'tanha', 'alone', 'cry', 'rona', 'bewafa'],
    'party': ['party', 'dance', 'club', 'dj', 'bass', 'beat', 'nach', 'garba'],
    'chill': ['lofi', 'chill', 'relax', 'calm', 'sleep', 'peace', 'soothing', 'acoustic'],
    'devotional': ['bhajan', 'aarti', 'mantra', 'prayer', 'devotional', 'kirtan', 'hanuman', 'ram', 'krishna', 'shiv'],
    'rap': ['rap', 'hip hop', 'hiphop', 'freestyle', 'bars'],
    'pop': ['pop', 'viral', 'trending'],
    'folk': ['folk', 'sufi', 'qawwali', 'classical', 'ghazal'],
    'workout': ['gym', 'workout', 'pump', 'energy', 'motivation', 'power'],
    'retro': ['old', 'classic', 'retro', '90s', '80s', '70s', 'purane', 'evergreen'],
  };

  List<String> get _topArtistIds {
    final sorted = _artistScores.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    return sorted.take(10).map((e) => e.key).toList();
  }

  List<String> get topArtistNames {
    return _topArtistIds
        .map((id) => _artistNames[id] ?? '')
        .where((n) => n.isNotEmpty)
        .toList();
  }

  List<String> get topLanguages {
    final sorted = _languageScores.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    return sorted.take(5).map((e) => e.key).toList();
  }

  List<String> get topMoods {
    final sorted = _moodScores.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    return sorted.take(3).map((e) => e.key).toList();
  }

  List<Map<String, dynamic>> get recentlyPlayed => _recentlyPlayed;
  int get totalPlays => _totalPlays;
  bool get hasProfile => _totalPlays >= 1;

  Song? getLastSong() {
    if (_recentlyPlayed.isEmpty) return null;
    final data = _recentlyPlayed.first;
    if (data['songId'] == null) return null;
    try {
      return Song(
        id: data['songId'] as String? ?? '',
        name: data['name'] as String? ?? '',
        year: data['year'] as String? ?? '',
        duration: data['duration'] as int? ?? 0,
        playCount: data['playCount'] as int? ?? 0,
        language: data['language'] as String? ?? '',
        albumName: data['albumName'] as String? ?? '',
        albumId: data['albumId'] as String? ?? '',
        artistNames: data['artist'] as String? ?? '',
        artistIds: List<String>.from(data['artistIds'] as List? ?? []),
        imageSmall: data['imageSmall'] as String? ?? '',
        imageMedium: data['image'] as String? ?? '',
        imageLarge: data['imageLarge'] as String? ?? '',
        downloadUrl: data['downloadUrl'] as String?,
      );
    } catch (_) {
      return null;
    }
  }

  String? get _uid => FirebaseAuth.instance.currentUser?.uid;

  DocumentReference? get _tasteDoc {
    final uid = _uid;
    if (uid == null) return null;
    return _db.collection('users').doc(uid).collection('profile').doc('taste');
  }

  List<String> _detectMoods(Song song) {
    final text = '${song.name} ${song.albumName} ${song.artistNames}'.toLowerCase();
    final detected = <String>[];
    for (final entry in _moodKeywords.entries) {
      for (final keyword in entry.value) {
        if (text.contains(keyword)) {
          detected.add(entry.key);
          break;
        }
      }
    }
    return detected;
  }

  Future<void> load() async {
    clear();
    final doc = _tasteDoc;
    if (doc == null) return;

    try {
      final snap = await doc.get();
      if (!snap.exists) return;

      final data = snap.data() as Map<String, dynamic>? ?? {};

      _artistScores = Map<String, double>.from(
        (data['artistScores'] as Map? ?? {}).map(
          (k, v) => MapEntry(k as String, (v as num).toDouble()),
        ),
      );
      _artistNames = Map<String, String>.from(
        (data['artistNames'] as Map? ?? {}).map(
          (k, v) => MapEntry(k as String, v as String),
        ),
      );
      _languageScores = Map<String, double>.from(
        (data['languageScores'] as Map? ?? {}).map(
          (k, v) => MapEntry(k as String, (v as num).toDouble()),
        ),
      );
      _moodScores = Map<String, double>.from(
        (data['moodScores'] as Map? ?? {}).map(
          (k, v) => MapEntry(k as String, (v as num).toDouble()),
        ),
      );
      _recentlyPlayed = List<Map<String, dynamic>>.from(
        (data['recentlyPlayed'] as List? ?? []).map(
          (e) => Map<String, dynamic>.from(e as Map),
        ),
      );
      _totalPlays = data['totalPlays'] as int? ?? 0;

      final lastDecayStr = data['lastDecayDate'] as String?;
      if (lastDecayStr != null) {
        _lastDecayDate = DateTime.tryParse(lastDecayStr);
      }

      final oldDecayDate = _lastDecayDate;
      _applyDecay();
      if (oldDecayDate != null && _lastDecayDate != oldDecayDate) {
        await _save(immediate: true);
      }
    } catch (e, s) {
      debugPrint('TasteService.load error: $e\n$s');
    }
  }

  void _applyDecay() {
    if (_lastDecayDate == null) {
      _lastDecayDate = DateTime.now();
      return;
    }

    final daysSince = DateTime.now().difference(_lastDecayDate!).inDays;

    if (daysSince <= 0) {
      if (daysSince < -1) {
        debugPrint('TasteService: clock drift detected ($daysSince days), resetting decay date');
        _lastDecayDate = DateTime.now();
      }
      return;
    }

    final decayFactor = pow(0.95, daysSince).toDouble();

    _artistScores.updateAll((_, v) => v * decayFactor);
    _languageScores.updateAll((_, v) => v * decayFactor);
    _moodScores.updateAll((_, v) => v * decayFactor);

    _artistScores.removeWhere((_, v) => v < 0.5);
    _languageScores.removeWhere((_, v) => v < 0.5);
    _moodScores.removeWhere((_, v) => v < 0.5);

    _lastDecayDate = DateTime.now();
  }

  Future<void> onSongPlayed(Song song) async {
    _totalPlays++;

    for (final artistId in song.artistIds) {
      _artistScores[artistId] =
          (_artistScores[artistId] ?? 0) + 3.0;
    }

    final artists = song.artistNames.split(', ');
    for (int i = 0; i < song.artistIds.length && i < artists.length; i++) {
      _artistNames[song.artistIds[i]] = artists[i];
    }

    if (song.language.isNotEmpty) {
      _languageScores[song.language] =
          (_languageScores[song.language] ?? 0) + 2.0;
    }

    final moods = _detectMoods(song);
    for (final mood in moods) {
      _moodScores[mood] = (_moodScores[mood] ?? 0) + 3.0;
    }

    _recentlyPlayed.removeWhere((e) => e['songId'] == song.id);

    _recentlyPlayed.insert(0, {
      'songId': song.id,
      'name': song.name,
      'artist': song.artistNames,
      'artistIds': song.artistIds,
      'image': song.imageMedium,
      'imageSmall': song.imageSmall,
      'imageLarge': song.imageLarge,
      'language': song.language,
      'albumName': song.albumName,
      'albumId': song.albumId,
      'year': song.year,
      'duration': song.duration,
      'playCount': song.playCount,
      'downloadUrl': song.downloadUrl,
      'timestamp': DateTime.now().toIso8601String(),
      'completed': false,
    });

    if (_recentlyPlayed.length > 50) {
      _recentlyPlayed = _recentlyPlayed.sublist(0, 50);
    }

    await _save();
  }

  Future<void> onSongCompleted(Song song) async {
    for (final artistId in song.artistIds) {
      _artistScores[artistId] =
          (_artistScores[artistId] ?? 0) + 5.0;
    }

    if (song.language.isNotEmpty) {
      _languageScores[song.language] =
          (_languageScores[song.language] ?? 0) + 3.0;
    }

    final moods = _detectMoods(song);
    for (final mood in moods) {
      _moodScores[mood] = (_moodScores[mood] ?? 0) + 5.0;
    }

    final idx = _recentlyPlayed.indexWhere(
      (e) => e['songId'] == song.id && e['completed'] == false,
    );
    if (idx >= 0) {
      _recentlyPlayed[idx]['completed'] = true;
    }

    await _save();
  }

  Future<void> onSongSkipped(Song song) async {
    for (final artistId in song.artistIds) {
      _artistScores[artistId] =
          (_artistScores[artistId] ?? 0) - 1.0;
    }

    final moods = _detectMoods(song);
    for (final mood in moods) {
      _moodScores[mood] = (_moodScores[mood] ?? 0) - 1.0;
    }

    await _save();
  }

  Future<void> onSongLiked(Song song) async {
    for (final artistId in song.artistIds) {
      _artistScores[artistId] =
          (_artistScores[artistId] ?? 0) + 10.0;
    }

    if (song.language.isNotEmpty) {
      _languageScores[song.language] =
          (_languageScores[song.language] ?? 0) + 5.0;
    }

    final moods = _detectMoods(song);
    for (final mood in moods) {
      _moodScores[mood] = (_moodScores[mood] ?? 0) + 8.0;
    }

    await _save();
  }

  double scoreSong(Song song) {
    double score = 0;

    for (final artistId in song.artistIds) {
      if (_artistScores.containsKey(artistId)) {
        score += 10.0;
      }
    }

    if (song.language.isNotEmpty &&
        _languageScores.containsKey(song.language)) {
      score += 5.0;
    }

    final songMoods = _detectMoods(song);
    final userMoods = topMoods;
    for (final mood in songMoods) {
      if (userMoods.contains(mood)) {
        score += 7.0;
      }
    }

    final wasRecentlyPlayed = _recentlyPlayed.any(
      (e) => e['songId'] == song.id,
    );
    if (wasRecentlyPlayed) {
      score -= 8.0;
    }

    return score;
  }

  List<Song> rankSuggestions(List<Song> suggestions) {
    if (_totalPlays == 0) return suggestions;
    final scored = suggestions.map((s) => MapEntry(s, scoreSong(s))).toList();
    scored.sort((a, b) => b.value.compareTo(a.value));
    return scored.map((e) => e.key).toList();
  }

  List<String> getPersonalizedQueries() {
    final queries = <String>[];

    final artists = topArtistNames;
    if (artists.isNotEmpty) {
      queries.add(artists.first);
      if (artists.length > 1) queries.add(artists[1]);
    }

    final moods = topMoods;
    final moodQueries = <String, List<String>>{
      'romantic': ['romantic songs', 'love songs', 'romantic hits'],
      'sad': ['sad songs', 'heartbreak songs', 'emotional songs'],
      'party': ['party songs', 'dance hits', 'club songs'],
      'chill': ['lofi songs', 'chill vibes', 'relaxing music'],
      'devotional': ['bhajan', 'devotional songs', 'spiritual music'],
      'rap': ['rap songs', 'hip hop hits', 'desi rap'],
      'pop': ['pop hits', 'popular songs', 'viral songs'],
      'folk': ['sufi songs', 'folk music', 'ghazals'],
      'workout': ['workout songs', 'gym motivation', 'pump songs'],
      'retro': ['old songs', 'retro hits', 'evergreen songs'],
    };

    for (final mood in moods.take(2)) {
      final pool = moodQueries[mood];
      if (pool != null && pool.isNotEmpty) {
        final copy = List<String>.from(pool)..shuffle();
        queries.add(copy.first);
      }
    }

    final langs = topLanguages;
    final langQueries = {
      'hindi': ['bollywood hits', 'hindi romantic', 'hindi party'],
      'english': ['english pop hits', 'top english songs'],
      'punjabi': ['punjabi hits', 'punjabi party'],
      'tamil': ['tamil hits', 'kollywood'],
      'telugu': ['telugu hits', 'tollywood'],
      'bengali': ['bengali hits', 'bangla songs'],
      'marathi': ['marathi hits'],
      'kannada': ['kannada hits'],
      'malayalam': ['malayalam hits'],
      'gujarati': ['gujarati hits'],
    };

    for (final lang in langs.take(2)) {
      final pool = langQueries[lang.toLowerCase()];
      if (pool != null && pool.isNotEmpty) {
        final copy = List<String>.from(pool)..shuffle();
        queries.add(copy.first);
      } else {
        queries.add('$lang songs');
      }
    }

    return queries;
  }

  Future<void> _save({bool immediate = false}) async {
    _saveDebouncer?.cancel();
    if (immediate) {
      await _performSave();
    } else {
      _saveDebouncer = Timer(const Duration(seconds: 5), () {
        _performSave();
      });
    }
  }

  Future<void> _performSave() async {
    final doc = _tasteDoc;
    if (doc == null) return;

    try {
      await doc.set({
        'artistScores': _artistScores,
        'artistNames': _artistNames,
        'languageScores': _languageScores,
        'moodScores': _moodScores,
        'recentlyPlayed': _recentlyPlayed,
        'totalPlays': _totalPlays,
        'lastDecayDate': (_lastDecayDate ?? DateTime.now()).toIso8601String(),
        'lastUpdated': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
    } catch (e, s) {
      debugPrint('TasteService._performSave error: $e\n$s');
    }
  }

  void clear() {
    _saveDebouncer?.cancel();
    _artistScores.clear();
    _artistNames.clear();
    _languageScores.clear();
    _moodScores.clear();
    _recentlyPlayed.clear();
    _totalPlays = 0;
    _lastDecayDate = null;
  }
}
