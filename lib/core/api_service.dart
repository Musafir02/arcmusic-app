import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/song.dart';

class ApiService {
  static const String _baseUrl = 'https://arcmusic-api.vercel.app';
  static final Map<String, LyricsResult> _lyricsCache = {};

  Future<List<Song>> searchSongs(String query, {int limit = 15}) async {
    final uri = Uri.parse(
        '$_baseUrl/api/search/songs?query=${Uri.encodeComponent(query)}&page=1&limit=$limit');
    final response = await http.get(uri);
    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      if (data['success'] == true) {
        final results = data['data']['results'] as List? ?? [];
        return results.map((s) => Song.fromJson(s)).toList();
      }
    }
    return [];
  }

  Future<List<Song>> searchSongsRaw(Uri uri) async {
    final response = await http.get(uri);
    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      if (data['success'] == true) {
        final results = data['data']['results'] as List? ?? [];
        return results.map((s) => Song.fromJson(s)).toList();
      }
    }
    return [];
  }

  Future<List<Song>> getSongSuggestions(String songId,
      {int limit = 10}) async {
    final uri =
        Uri.parse('$_baseUrl/api/songs/$songId/suggestions?limit=$limit');
    final response = await http.get(uri);
    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      if (data['success'] == true) {
        final results = data['data'] as List? ?? [];
        return results.map((s) => Song.fromJson(s)).toList();
      }
    }
    return [];
  }

  Future<Song?> getSongById(String id) async {
    final uri = Uri.parse('$_baseUrl/api/songs/$id');
    final response = await http.get(uri);
    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      if (data['success'] == true) {
        return Song.fromJson(data['data'][0]);
      }
    }
    return null;
  }

  Future<LyricsResult> getLyrics(String songId, {String? trackName, String? artistName, String? albumName, int? durationSecs}) async {
    if (_lyricsCache.containsKey(songId)) return _lyricsCache[songId]!;

    if (trackName != null && artistName != null) {
      final firstArtist = artistName.split(',').first.trim();
      final List<Map<String, dynamic>> candidates = [];

      try {
        final params = <String, String>{
          'track_name': trackName,
          'artist_name': firstArtist,
        };
        final lrcUri = Uri.https('lrclib.net', '/api/get', params);
        final lrcResponse = await http.get(lrcUri, headers: {
          'User-Agent': 'ArcMusic/1.0 (https://github.com/Musafir02/arcmusic)',
        });

        if (lrcResponse.statusCode == 200) {
          final lrcData = jsonDecode(lrcResponse.body);
          if (lrcData is Map<String, dynamic>) {
            candidates.add(lrcData);
          }
        }
      } catch (_) {}

      if (candidates.isNotEmpty) {
        final bestMatch = candidates.first;
        final synced = bestMatch['syncedLyrics'] as String?;
        final plain = bestMatch['plainLyrics'] as String?;
        if (synced != null && synced.isNotEmpty) {
          final r = LyricsResult(syncedLrc: synced, plainText: plain);
          _lyricsCache[songId] = r;
          return r;
        } else if (plain != null && plain.isNotEmpty) {
          final r = LyricsResult(plainText: plain);
          _lyricsCache[songId] = r;
          return r;
        }
      }
    }

    return LyricsResult();
  }
}

class LyricsResult {
  final String? syncedLrc;
  final String? plainText;

  LyricsResult({this.syncedLrc, this.plainText});

  bool get isEmpty => syncedLrc == null && plainText == null;
  bool get hasSynced => syncedLrc != null && syncedLrc!.isNotEmpty;
}
