import 'dart:async';
import 'dart:convert';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/song.dart';

class LikedService {
  static final LikedService _instance = LikedService._();
  factory LikedService() => _instance;
  LikedService._();

  final FirebaseFirestore _db = FirebaseFirestore.instance;

  List<Song> _songs = [];
  final Set<String> _likedIds = {};
  Timer? _saveDebouncer;

  final ValueNotifier<List<Song>> likedNotifier = ValueNotifier([]);

  List<Song> get likedSongs => List.unmodifiable(_songs);

  bool isLiked(String songId) => _likedIds.contains(songId);

  String? get _uid => FirebaseAuth.instance.currentUser?.uid;

  DocumentReference? get _doc {
    final uid = _uid;
    if (uid == null) return null;
    return _db.collection('users').doc(uid).collection('liked').doc('songs');
  }

  String get _localKey => 'liked_songs_${_uid ?? 'guest'}';

  Future<void> load() async {
    _songs = [];
    _likedIds.clear();
    likedNotifier.value = [];

    await _loadLocal();

    final doc = _doc;
    if (doc == null) return;

    try {
      final snap = await doc.get();
      if (!snap.exists) return;
      final data = snap.data() as Map<String, dynamic>? ?? {};
      final raw = data['songs'] as List? ?? [];
      _songs = raw
          .whereType<Map>()
          .map((e) => _songFromMap(Map<String, dynamic>.from(e)))
          .toList();
      _likedIds.clear();
      _likedIds.addAll(_songs.map((s) => s.id));
      likedNotifier.value = List.unmodifiable(_songs);
      await _saveLocal();
    } catch (e, s) {
      debugPrint('LikedService.load error: $e\n$s');
    }
  }

  Future<void> _loadLocal() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final jsonStr = prefs.getString(_localKey);
      if (jsonStr != null && jsonStr.isNotEmpty) {
        final List raw = jsonDecode(jsonStr);
        _songs = raw
            .whereType<Map>()
            .map((e) => _songFromMap(Map<String, dynamic>.from(e)))
            .toList();
        _likedIds.clear();
        _likedIds.addAll(_songs.map((s) => s.id));
        likedNotifier.value = List.unmodifiable(_songs);
      }
    } catch (e) {
      debugPrint('LikedService._loadLocal error: $e');
    }
  }

  Future<void> _saveLocal() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final rawList = _songs.map(_songToMap).toList();
      await prefs.setString(_localKey, jsonEncode(rawList));
    } catch (e) {
      debugPrint('LikedService._saveLocal error: $e');
    }
  }

  Future<void> toggleLike(Song song) async {
    if (_likedIds.contains(song.id)) {
      _songs.removeWhere((s) => s.id == song.id);
      _likedIds.remove(song.id);
    } else {
      _songs.insert(0, song);
      _likedIds.add(song.id);
    }
    likedNotifier.value = List.unmodifiable(_songs);
    await _saveLocal();
    await _save();
  }

  Future<void> unlike(String songId) async {
    _songs.removeWhere((s) => s.id == songId);
    _likedIds.remove(songId);
    likedNotifier.value = List.unmodifiable(_songs);
    await _saveLocal();
    await _save();
  }

  Future<void> _save() async {
    _saveDebouncer?.cancel();
    _saveDebouncer = Timer(const Duration(seconds: 2), _performSave);
  }

  Future<void> _performSave() async {
    final doc = _doc;
    if (doc == null) return;
    try {
      await doc.set({
        'songs': _songs.map(_songToMap).toList(),
        'updatedAt': FieldValue.serverTimestamp(),
      });
    } catch (e, s) {
      debugPrint('LikedService._performSave error: $e\n$s');
    }
  }

  void clear() {
    _saveDebouncer?.cancel();
    _songs = [];
    _likedIds.clear();
    likedNotifier.value = [];
  }

  static Map<String, dynamic> _songToMap(Song s) => {
        'songId': s.id,
        'name': s.name,
        'artist': s.artistNames,
        'artistIds': s.artistIds,
        'image': s.imageMedium,
        'imageSmall': s.imageSmall,
        'imageLarge': s.imageLarge,
        'language': s.language,
        'albumName': s.albumName,
        'albumId': s.albumId,
        'year': s.year,
        'duration': s.duration,
        'playCount': s.playCount,
        'downloadUrl': s.downloadUrl,
        'likedAt': DateTime.now().toIso8601String(),
      };

  static Song _songFromMap(Map<String, dynamic> d) => Song(
        id: d['songId'] as String? ?? '',
        name: d['name'] as String? ?? '',
        year: d['year'] as String? ?? '',
        duration: d['duration'] as int? ?? 0,
        playCount: d['playCount'] as int? ?? 0,
        language: d['language'] as String? ?? '',
        albumName: d['albumName'] as String? ?? '',
        albumId: d['albumId'] as String? ?? '',
        artistNames: d['artist'] as String? ?? '',
        artistIds: List<String>.from(d['artistIds'] as List? ?? []),
        imageSmall: d['imageSmall'] as String? ?? '',
        imageMedium: d['image'] as String? ?? '',
        imageLarge: d['imageLarge'] as String? ?? '',
        downloadUrl: d['downloadUrl'] as String?,
      );
}
