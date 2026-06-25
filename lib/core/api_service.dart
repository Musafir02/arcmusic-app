import 'dart:collection';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import '../models/song.dart';

class ApiService {
  static const String _baseUrl = 'https://arcmusic-api.vercel.app';
  static const int _lyricsCacheMaxSize = 50;
  static const Duration _httpTimeout = Duration(seconds: 10);

  static final LinkedHashMap<String, LyricsResult> _lyricsCache =
      LinkedHashMap();

  static LyricsResult? _getCached(String key) {
    final val = _lyricsCache.remove(key);
    if (val != null) _lyricsCache[key] = val;
    return val;
  }

  static void _putCache(String key, LyricsResult val) {
    _lyricsCache.remove(key);
    if (_lyricsCache.length >= _lyricsCacheMaxSize) {
      _lyricsCache.remove(_lyricsCache.keys.first);
    }
    _lyricsCache[key] = val;
  }

  Future<List<Song>> searchSongs(String query,
      {int page = 1, int limit = 15}) async {
    final uri = Uri.parse(
        '$_baseUrl/api/search/songs?query=${Uri.encodeComponent(query)}&page=$page&limit=$limit');
    try {
      final response = await http.get(uri).timeout(_httpTimeout);
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['success'] == true) {
          final results = data['data']['results'] as List? ?? [];
          return results.map((s) => Song.fromJson(s)).toList();
        }
      }
    } catch (e, s) {
      debugPrint('searchSongs error: $e\n$s');
    }
    return [];
  }

  Future<List<Song>> getSongSuggestions(String songId,
      {int limit = 10}) async {
    final uri =
        Uri.parse('$_baseUrl/api/songs/$songId/suggestions?limit=$limit');
    try {
      final response = await http.get(uri).timeout(_httpTimeout);
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['success'] == true) {
          final results = data['data'] as List? ?? [];
          return results.map((s) => Song.fromJson(s)).toList();
        }
      }
    } catch (e, s) {
      debugPrint('getSongSuggestions error: $e\n$s');
    }
    return [];
  }

  Future<LyricsResult> getLyrics(String songId,
      {String? trackName,
      String? artistName,
      String? albumName,
      int? durationSecs}) async {
    final cached = _getCached(songId);
    if (cached != null) return cached;

    if (trackName != null && artistName != null) {
      final firstArtist = artistName.split(',').first.trim();
      final List<Map<String, dynamic>> candidates = [];

      try {
        final params = <String, String>{
          'track_name': trackName,
          'artist_name': firstArtist,
        };
        if (albumName != null && albumName.isNotEmpty) {
          params['album_name'] = albumName;
        }
        if (durationSecs != null && durationSecs > 0) {
          params['duration'] = durationSecs.toString();
        }

        final lrcUri = Uri.https('lrclib.net', '/api/get', params);
        final lrcResponse = await http.get(lrcUri, headers: {
          'User-Agent': 'ArcMusic/1.0 (https://github.com/Musafir02/arcmusic)',
        }).timeout(_httpTimeout);

        if (lrcResponse.statusCode == 200) {
          final lrcData = jsonDecode(lrcResponse.body);
          if (lrcData is Map<String, dynamic>) {
            candidates.add(lrcData);
          }
        }
      } catch (_) {}

      try {
        final searchUri = Uri.https('lrclib.net', '/api/search', {
          'track_name': trackName,
          'artist_name': firstArtist,
        });
        final searchResponse = await http.get(searchUri, headers: {
          'User-Agent': 'ArcMusic/1.0 (https://github.com/Musafir02/arcmusic)',
        }).timeout(_httpTimeout);

        if (searchResponse.statusCode == 200) {
          final decoded = jsonDecode(searchResponse.body);
          final List<dynamic> results = (decoded is List) ? decoded : [];
          for (final item in results) {
            if (item is Map<String, dynamic>) {
              candidates.add(item);
            }
          }
        }
      } catch (_) {}

      if (candidates.isNotEmpty) {
        Map<String, dynamic>? bestMatch;
        int bestScore = -1;
        double bestDiff = double.infinity;

        for (final item in candidates) {
          final synced = item['syncedLyrics'] as String?;
          final plain = item['plainLyrics'] as String?;
          final dur = (item['duration'] as num?)?.toDouble() ?? 0.0;
          final diff = durationSecs != null ? (dur - durationSecs).abs() : 0.0;

          if (durationSecs != null && diff > 20) {
            continue;
          }

          int score = 0;
          if (synced != null && synced.isNotEmpty) {
            score += 2;
            if (_isRomanized(synced)) {
              score += 1;
            }
          } else if (plain != null && plain.isNotEmpty) {
            if (_isRomanized(plain)) {
              score += 1;
            }
          }

          if (score > bestScore) {
            bestScore = score;
            bestDiff = diff;
            bestMatch = item;
          } else if (score == bestScore) {
            if (diff < bestDiff) {
              bestDiff = diff;
              bestMatch = item;
            }
          }
        }

        if (bestMatch != null) {
          final synced = bestMatch['syncedLyrics'] as String?;
          final plain = bestMatch['plainLyrics'] as String?;
          if (synced != null && synced.isNotEmpty) {
            final r = LyricsResult(syncedLrc: synced, plainText: plain);
            _putCache(songId, r);
            return r;
          } else if (plain != null && plain.isNotEmpty) {
            final r = LyricsResult(plainText: plain);
            _putCache(songId, r);
            return r;
          }
        }
      }
    }

    return LyricsResult();
  }

  bool _isRomanized(String text) {
    for (final rune in text.runes) {
      if ((rune >= 0x0900 && rune <= 0x097F) ||
          (rune >= 0x0A00 && rune <= 0x0A7F) ||
          (rune >= 0x0600 && rune <= 0x06FF)) {
        return false;
      }
    }
    return true;
  }
}

class LyricsResult {
  final String? syncedLrc;
  final String? plainText;

  LyricsResult({this.syncedLrc, this.plainText});

  bool get isEmpty => syncedLrc == null && plainText == null;
  bool get hasSynced => syncedLrc != null && syncedLrc!.isNotEmpty;
}
