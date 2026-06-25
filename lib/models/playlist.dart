import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/song.dart';

class Playlist {
  final String id;
  final String name;
  final DateTime createdAt;
  final List<Song> songs;

  Playlist({
    required this.id,
    required this.name,
    required this.createdAt,
    required this.songs,
  });

  String? get coverUrl {
    for (final s in songs) {
      if (s.imageLarge.isNotEmpty) return s.imageLarge;
      if (s.imageMedium.isNotEmpty) return s.imageMedium;
    }
    return null;
  }

  int get songCount => songs.length;

  Playlist copyWith({
    String? id,
    String? name,
    DateTime? createdAt,
    List<Song>? songs,
  }) {
    return Playlist(
      id: id ?? this.id,
      name: name ?? this.name,
      createdAt: createdAt ?? this.createdAt,
      songs: songs ?? this.songs,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'createdAt': createdAt.toIso8601String(),
      'songs': songs.map(songToMap).toList(),
    };
  }

  static Map<String, dynamic> songToMap(Song s) => {
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

  factory Playlist.fromMap(String docId, Map<String, dynamic> data) {
    final rawSongs = data['songs'] as List? ?? [];
    DateTime parsedDate = DateTime.now();
    final rawCreated = data['createdAt'];
    if (rawCreated != null) {
      if (rawCreated is Timestamp) {
        parsedDate = rawCreated.toDate();
      } else if (rawCreated is String) {
        parsedDate = DateTime.tryParse(rawCreated) ?? DateTime.now();
      }
    }
    return Playlist(
      id: docId,
      name: data['name'] as String? ?? 'Playlist',
      createdAt: parsedDate,
      songs: rawSongs
          .whereType<Map>()
          .map((e) => _songFromMap(Map<String, dynamic>.from(e)))
          .toList(),
    );
  }
}
