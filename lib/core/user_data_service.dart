import 'dart:async';
import 'dart:convert';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/song.dart';
import 'firebase_service.dart';

class UserDataService {
  static final UserDataService _instance = UserDataService._();
  factory UserDataService() => _instance;
  UserDataService._();

  final FirebaseService _fb = FirebaseService();

  List<Song> _likedSongs = [];
  final Set<String> _likedIds = {};
  Timer? _likedSaveDebouncer;

  List<Map<String, dynamic>> _playlists = [];
  StreamSubscription<QuerySnapshot>? _playlistSub;

  final ValueNotifier<List<Song>> likedNotifier = ValueNotifier([]);
  final ValueNotifier<List<Map<String, dynamic>>> playlistsNotifier = ValueNotifier([]);

  List<Song> get likedSongs => List.unmodifiable(_likedSongs);
  List<Map<String, dynamic>> get playlists => List.unmodifiable(_playlists);

  bool isLiked(String songId) => _likedIds.contains(songId);

  DocumentReference? get _likedDoc {
    final uid = _fb.uid;
    if (uid == null) return null;
    return _fb.db.collection('users').doc(uid).collection('liked').doc('songs');
  }

  CollectionReference? get _playlistCol {
    final uid = _fb.uid;
    if (uid == null) return null;
    return _fb.db.collection('users').doc(uid).collection('playlists');
  }

  String get _likedLocalKey => 'liked_songs_${_fb.uid ?? 'guest'}';
  String get _playlistLocalKey => 'playlists_${_fb.uid ?? 'guest'}';

  Future<void> load() async {
    _likedSongs = [];
    _likedIds.clear();
    likedNotifier.value = [];
    _playlists = [];
    playlistsNotifier.value = [];
    await _playlistSub?.cancel();
    _playlistSub = null;

    await _loadLikedLocal();
    await _loadPlaylistsLocal();

    _fetchLikedServer();
    _listenPlaylistsServer();
  }

  Future<void> _loadLikedLocal() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final jsonStr = prefs.getString(_likedLocalKey);
      if (jsonStr != null && jsonStr.isNotEmpty) {
        final List raw = jsonDecode(jsonStr);
        _likedSongs = raw
            .whereType<Map>()
            .map((e) => Song.fromJson(Map<String, dynamic>.from(e)))
            .toList();
        _likedIds.clear();
        _likedIds.addAll(_likedSongs.map((s) => s.id));
        likedNotifier.value = List.unmodifiable(_likedSongs);
      }
    } catch (e) {
      debugPrint('UserDataService._loadLikedLocal error: $e');
    }
  }

  Future<void> _loadPlaylistsLocal() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final jsonStr = prefs.getString(_playlistLocalKey);
      if (jsonStr != null && jsonStr.isNotEmpty) {
        final List raw = jsonDecode(jsonStr);
        _playlists = raw
            .whereType<Map>()
            .map((e) => Map<String, dynamic>.from(e))
            .toList();
        playlistsNotifier.value = List.unmodifiable(_playlists);
      }
    } catch (e) {
      debugPrint('UserDataService._loadPlaylistsLocal error: $e');
    }
  }

  Future<void> _saveLikedLocal() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final rawList = _likedSongs.map((song) => song.toJson()).toList();
      await prefs.setString(_likedLocalKey, jsonEncode(rawList));
    } catch (e) {
      debugPrint('UserDataService._saveLikedLocal error: $e');
    }
  }

  Future<void> _savePlaylistsLocal() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_playlistLocalKey, jsonEncode(_playlists));
    } catch (e) {
      debugPrint('UserDataService._savePlaylistsLocal error: $e');
    }
  }

  Future<void> _fetchLikedServer() async {
    final doc = _likedDoc;
    if (doc == null) return;
    try {
      final snap = await doc.get().timeout(const Duration(seconds: 4));
      if (!snap.exists) return;
      final data = snap.data() as Map<String, dynamic>? ?? {};
      final raw = data['songs'] as List? ?? [];
      _likedSongs = raw
          .whereType<Map>()
          .map((e) => Song.fromJson(Map<String, dynamic>.from(e)))
          .toList();
      _likedIds.clear();
      _likedIds.addAll(_likedSongs.map((s) => s.id));
      likedNotifier.value = List.unmodifiable(_likedSongs);
      await _saveLikedLocal();
    } catch (e, s) {
      debugPrint('UserDataService._fetchLikedServer error: $e\n$s');
    }
  }

  void _listenPlaylistsServer() {
    final col = _playlistCol;
    if (col == null) return;

    _playlistSub = col.orderBy('createdAt', descending: false).snapshots().listen(
      (snap) {
        _playlists = snap.docs.map((doc) {
          final data = Map<String, dynamic>.from(doc.data() as Map);
          data['id'] = doc.id;
          return data;
        }).toList();
        playlistsNotifier.value = List.unmodifiable(_playlists);
        _savePlaylistsLocal();
      },
      onError: (e, s) => debugPrint('UserDataService playlists stream error: $e\n$s'),
    );
  }

  Future<void> toggleLike(Song song) async {
    final id = song.id;
    if (_likedIds.contains(id)) {
      _likedSongs.removeWhere((s) => s.id == id);
      _likedIds.remove(id);
    } else {
      _likedSongs.insert(0, song);
      _likedIds.add(id);
    }
    likedNotifier.value = List.unmodifiable(_likedSongs);
    await _saveLikedLocal();
    _debouncedLikedSave();
  }

  void _debouncedLikedSave() {
    _likedSaveDebouncer?.cancel();
    _likedSaveDebouncer = Timer(const Duration(seconds: 2), _performLikedSave);
  }

  Future<void> _performLikedSave() async {
    final doc = _likedDoc;
    if (doc == null) return;
    try {
      await doc.set({
        'songs': _likedSongs.map((song) => song.toJson()).toList(),
        'updatedAt': FieldValue.serverTimestamp(),
      });
    } catch (e, s) {
      debugPrint('UserDataService._performLikedSave error: $e\n$s');
    }
  }

  Future<Map<String, dynamic>> createPlaylist(String name) async {
    final col = _playlistCol;
    if (col == null) throw Exception('Not authenticated');

    final doc = col.doc();
    final playlist = {
      'id': doc.id,
      'name': name.trim(),
      'createdAt': DateTime.now().toIso8601String(),
      'songs': [],
    };

    await doc.set({
      ...playlist,
      'createdAt': FieldValue.serverTimestamp(),
    });

    return playlist;
  }

  Future<void> deletePlaylist(String playlistId) async {
    final col = _playlistCol;
    if (col == null) return;
    try {
      await col.doc(playlistId).delete();
    } catch (e, s) {
      debugPrint('UserDataService.deletePlaylist error: $e\n$s');
    }
  }

  Future<void> addSongToPlaylist(String playlistId, Song song) async {
    final col = _playlistCol;
    if (col == null) return;

    final idx = _playlists.indexWhere((p) => p['id'] == playlistId);
    if (idx == -1) throw Exception('Playlist not found');

    final playlist = _playlists[idx];
    final List songs = List.from(playlist['songs'] ?? []);
    if (songs.any((s) => s['id'] == song.id)) return;

    songs.add(song.toJson());
    try {
      await col.doc(playlistId).update({
        'songs': songs,
      });
    } catch (e, s) {
      debugPrint('UserDataService.addSongToPlaylist error: $e\n$s');
    }
  }

  Future<void> removeSongFromPlaylist(
      String playlistId, String songId) async {
    final col = _playlistCol;
    if (col == null) return;

    final idx = _playlists.indexWhere((p) => p['id'] == playlistId);
    if (idx == -1) throw Exception('Playlist not found');

    final playlist = _playlists[idx];
    final List songs = List.from(playlist['songs'] ?? []);
    songs.removeWhere((s) => s['id'] == songId);

    try {
      await col.doc(playlistId).update({
        'songs': songs,
      });
    } catch (e, s) {
      debugPrint('UserDataService.removeSongFromPlaylist error: $e\n$s');
    }
  }

  Future<void> reorderSongs(
      String playlistId, List<Song> reorderedSongs) async {
    final col = _playlistCol;
    if (col == null) return;
    try {
      await col.doc(playlistId).update({
        'songs': reorderedSongs.map((s) => s.toJson()).toList(),
      });
    } catch (e, s) {
      debugPrint('UserDataService.reorderSongs error: $e\n$s');
    }
  }

  void clear() {
    _likedSaveDebouncer?.cancel();
    _playlistSub?.cancel();
    _playlistSub = null;
    _likedSongs = [];
    _likedIds.clear();
    likedNotifier.value = [];
    _playlists = [];
    playlistsNotifier.value = [];
  }
}
