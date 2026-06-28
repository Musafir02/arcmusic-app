import 'dart:async';
import 'dart:convert';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/song.dart';
import 'config.dart';

class TasteService {
  static final TasteService _instance = TasteService._();
  factory TasteService() => _instance;
  TasteService._();

  final FirebaseFirestore _db = FirebaseFirestore.instance;

  List<Song> _recentlyPlayed = [];
  int _totalPlays = 0;
  Timer? _saveDebouncer;

  List<String> get topArtistNames {
    final artistCounts = <String, int>{};
    for (final data in _recentlyPlayed) {
      final artistNamesStr = data.artist;
      final artists = artistNamesStr.split(', ');
      for (final artist in artists) {
        final cleanArtist = artist.trim();
        if (cleanArtist.isNotEmpty) {
          artistCounts[cleanArtist] = (artistCounts[cleanArtist] ?? 0) + 1;
        }
      }
    }
    final sorted = artistCounts.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    return sorted.take(10).map((e) => e.key).toList();
  }

  List<String> get topMoods {
    final moodCounts = <String, int>{};
    for (final data in _recentlyPlayed) {
      final moods = _detectMoods(data);
      for (final mood in moods) {
        moodCounts[mood] = (moodCounts[mood] ?? 0) + 1;
      }
    }
    final sorted = moodCounts.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    return sorted.take(3).map((e) => e.key).toList();
  }

  List<Song> get recentlyPlayed => _recentlyPlayed;
  int get totalPlays => _totalPlays;

  Song? getLastSong() {
    if (_recentlyPlayed.isEmpty) return null;
    return _recentlyPlayed.first;
  }

  String? get _uid => FirebaseAuth.instance.currentUser?.uid;

  DocumentReference? get _tasteDoc {
    final uid = _uid;
    if (uid == null) return null;
    return _db.collection('users').doc(uid).collection('profile').doc('taste');
  }

  List<String> _detectMoods(Song song) {
    final name = song.name;
    final album = song.album ?? '';
    final artist = song.artist;
    final text = '$name $album $artist'.toLowerCase();
    final detected = <String>[];
    for (final entry in MoodConstants.keywords.entries) {
      for (final keyword in entry.value) {
        if (text.contains(keyword)) {
          detected.add(entry.key);
          break;
        }
      }
    }
    return detected;
  }

  void _parseData(Map<String, dynamic> data) {
    _totalPlays = data['totalPlays'] as int? ?? 0;
    _recentlyPlayed = (data['recentlyPlayed'] as List? ?? [])
        .map((e) => Song.fromJson(Map<String, dynamic>.from(e as Map)))
        .toList();
  }

  Future<void> _loadLocal() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final key = 'taste_${_uid ?? 'guest'}';
      final jsonStr = prefs.getString(key);
      if (jsonStr != null && jsonStr.isNotEmpty) {
        final Map<String, dynamic> data = jsonDecode(jsonStr);
        _parseData(data);
      }
    } catch (e) {
      debugPrint('TasteService._loadLocal error: $e');
    }
  }

  Future<void> _saveLocal() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final key = 'taste_${_uid ?? 'guest'}';
      final data = {
        'recentlyPlayed': _recentlyPlayed.map((s) => s.toJson()).toList(),
        'totalPlays': _totalPlays,
      };
      await prefs.setString(key, jsonEncode(data));
    } catch (e) {
      debugPrint('TasteService._saveLocal error: $e');
    }
  }

  Future<void> _fetchServer() async {
    final doc = _tasteDoc;
    if (doc == null) return;
    try {
      final snap = await doc.get().timeout(const Duration(seconds: 4));
      if (!snap.exists) return;
      final data = snap.data() as Map<String, dynamic>? ?? {};
      _parseData(data);
      await _saveLocal();
    } catch (e, s) {
      debugPrint('TasteService._fetchServer error: $e\n$s');
    }
  }

  Future<void> load() async {
    clear();
    await _loadLocal();
    _fetchServer();
  }

  Future<void> onSongPlayed(Song song) async {
    final id = song.id;
    if (id.isEmpty) return;
    _totalPlays++;

    _recentlyPlayed.removeWhere((e) => e.id == id);

    final item = song.copyWith(
      timestamp: DateTime.now().toIso8601String(),
      completed: false,
    );

    _recentlyPlayed.insert(0, item);

    if (_recentlyPlayed.length > 50) {
      _recentlyPlayed = _recentlyPlayed.sublist(0, 50);
    }

    await _save(immediate: true);
  }

  Future<void> onSongCompleted(Song song) async {
    final id = song.id;
    if (id.isEmpty) return;

    final idx = _recentlyPlayed.indexWhere(
      (e) => e.id == id && e.completed == false,
    );
    if (idx >= 0) {
      _recentlyPlayed[idx] = _recentlyPlayed[idx].copyWith(completed: true);
    }
    await _save();
  }

  double scoreSong(Song song) {
    double score = 0;
    final topArtists = topArtistNames;
    final userMoods = topMoods;

    final artist = song.artist;
    final songArtists = artist.split(', ');
    for (final artistName in songArtists) {
      if (topArtists.contains(artistName.trim())) {
        score += 10.0;
        break;
      }
    }

    final songMoods = _detectMoods(song);
    for (final mood in songMoods) {
      if (userMoods.contains(mood)) {
        score += 7.0;
      }
    }

    final wasRecentlyPlayed = _recentlyPlayed.any(
      (e) => e.id == song.id,
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
    await _saveLocal();
    final doc = _tasteDoc;
    if (doc == null) return;

    try {
      await doc.set({
        'recentlyPlayed': _recentlyPlayed.map((s) => s.toJson()).toList(),
        'totalPlays': _totalPlays,
        'lastUpdated': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
    } catch (e, s) {
      debugPrint('TasteService._performSave error: $e\n$s');
    }
  }

  void clear() {
    _saveDebouncer?.cancel();
    _recentlyPlayed.clear();
    _totalPlays = 0;
  }
}
