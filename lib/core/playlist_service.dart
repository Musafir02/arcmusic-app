import 'dart:async';
import 'dart:convert';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/playlist.dart';
import '../models/song.dart';

class PlaylistService {
  static final PlaylistService _instance = PlaylistService._();
  factory PlaylistService() => _instance;
  PlaylistService._();

  final FirebaseFirestore _db = FirebaseFirestore.instance;

  List<Playlist> _playlists = [];
  StreamSubscription<QuerySnapshot>? _sub;

  final ValueNotifier<List<Playlist>> playlistsNotifier = ValueNotifier([]);

  List<Playlist> get playlists => List.unmodifiable(_playlists);

  String? get _uid => FirebaseAuth.instance.currentUser?.uid;

  CollectionReference? get _col {
    final uid = _uid;
    if (uid == null) return null;
    return _db.collection('users').doc(uid).collection('playlists');
  }

  String get _localKey => 'playlists_${_uid ?? 'guest'}';

  Future<void> _loadLocal() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final jsonStr = prefs.getString(_localKey);
      if (jsonStr != null && jsonStr.isNotEmpty) {
        final List raw = jsonDecode(jsonStr);
        _playlists = raw
            .whereType<Map>()
            .map((e) => Playlist.fromMap(
                e['id'] as String? ?? '', Map<String, dynamic>.from(e)))
            .toList();
        playlistsNotifier.value = List.unmodifiable(_playlists);
      }
    } catch (e) {
      debugPrint('PlaylistService._loadLocal error: $e');
    }
  }

  Future<void> _saveLocal() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final rawList = _playlists.map((p) => p.toMap()).toList();
      await prefs.setString(_localKey, jsonEncode(rawList));
    } catch (e) {
      debugPrint('PlaylistService._saveLocal error: $e');
    }
  }

  Future<void> load() async {
    await _sub?.cancel();
    await _loadLocal();

    final col = _col;
    if (col == null) return;

    _sub = col.orderBy('createdAt', descending: false).snapshots().listen(
      (snap) {
        _playlists = snap.docs.map((doc) {
          return Playlist.fromMap(
              doc.id, Map<String, dynamic>.from(doc.data() as Map));
        }).toList();
        playlistsNotifier.value = List.unmodifiable(_playlists);
        _saveLocal();
      },
      onError: (e, s) => debugPrint('PlaylistService stream error: $e\n$s'),
    );
  }

  Future<Playlist> createPlaylist(String name) async {
    final col = _col;
    if (col == null) throw Exception('Not authenticated');

    final doc = col.doc();
    final playlist = Playlist(
      id: doc.id,
      name: name.trim(),
      createdAt: DateTime.now(),
      songs: [],
    );

    await doc.set({
      ...playlist.toMap(),
      'createdAt': FieldValue.serverTimestamp(),
    });

    return playlist;
  }

  Future<void> deletePlaylist(String playlistId) async {
    final col = _col;
    if (col == null) return;
    try {
      await col.doc(playlistId).delete();
    } catch (e, s) {
      debugPrint('PlaylistService.deletePlaylist error: $e\n$s');
    }
  }

  Future<void> addSongToPlaylist(String playlistId, Song song) async {
    final col = _col;
    if (col == null) return;

    final playlist = _playlists.firstWhere(
      (p) => p.id == playlistId,
      orElse: () => throw Exception('Playlist not found'),
    );

    if (playlist.songs.any((s) => s.id == song.id)) return;

    final updated = List<Song>.from(playlist.songs)..add(song);
    final updatedPlaylist = playlist.copyWith(songs: updated);

    try {
      await col.doc(playlistId).update({
        'songs': updatedPlaylist.songs.map(Playlist.songToMap).toList(),
      });
    } catch (e, s) {
      debugPrint('PlaylistService.addSong error: $e\n$s');
    }
  }

  Future<void> removeSongFromPlaylist(
      String playlistId, String songId) async {
    final col = _col;
    if (col == null) return;

    final playlist = _playlists.firstWhere(
      (p) => p.id == playlistId,
      orElse: () => throw Exception('Playlist not found'),
    );

    final updated = playlist.songs.where((s) => s.id != songId).toList();
    final updatedPlaylist = playlist.copyWith(songs: updated);

    try {
      await col.doc(playlistId).update({
        'songs': updatedPlaylist.songs.map(Playlist.songToMap).toList(),
      });
    } catch (e, s) {
      debugPrint('PlaylistService.removeSong error: $e\n$s');
    }
  }

  Future<void> reorderSongs(
      String playlistId, List<Song> reorderedSongs) async {
    final col = _col;
    if (col == null) return;
    try {
      await col.doc(playlistId).update({
        'songs': reorderedSongs.map(Playlist.songToMap).toList(),
      });
    } catch (e, s) {
      debugPrint('PlaylistService.reorderSongs error: $e\n$s');
    }
  }

  void clear() {
    _sub?.cancel();
    _sub = null;
    _playlists = [];
    playlistsNotifier.value = [];
  }
}
