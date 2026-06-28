import 'dart:collection';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'config.dart';

class ApiService {
  static final ApiService _instance = ApiService._();
  factory ApiService() => _instance;
  ApiService._();

  static final LinkedHashMap<String, LyricsResult> _lyricsCache =
      LinkedHashMap();

  static LyricsResult? _getCached(String key) {
    final val = _lyricsCache.remove(key);
    if (val != null) _lyricsCache[key] = val;
    return val;
  }

  static void _putCache(String key, LyricsResult val) {
    _lyricsCache.remove(key);
    if (_lyricsCache.length >= AppConfig.lyricsCacheMaxSize) {
      _lyricsCache.remove(_lyricsCache.keys.first);
    }
    _lyricsCache[key] = val;
  }

  Map<String, dynamic> _parseApiSong(Map<String, dynamic> s) {
    final imageRaw = s['image'];
    final images = imageRaw is List ? imageRaw : const [];

    final artistsRaw = s['artists']?['primary'];
    final artists = artistsRaw is List ? artistsRaw : const [];

    final artistNamesList = artists
        .map((a) => (a is Map && a['name'] != null) ? a['name'].toString() : '')
        .where((n) => n.isNotEmpty)
        .toList();

    final dlRaw = s['downloadUrl'];
    final downloadUrls = dlRaw is List ? dlRaw : const [];

    String bestDownload = '';
    for (final dl in downloadUrls.reversed) {
      if (dl is Map && dl['url'] != null) {
        bestDownload = dl['url'].toString();
        break;
      }
    }

    String getImageUrl(int index) {
      if (index >= 0 && index < images.length) {
        final item = images[index];
        if (item is Map && item['url'] != null) {
          return item['url'].toString();
        }
      }
      return '';
    }

    String cleanHtml(String text) {
      return text
          .replaceAll('&quot;', '"')
          .replaceAll('&amp;', '&')
          .replaceAll('&lt;', '<')
          .replaceAll('&gt;', '>')
          .replaceAll('&#039;', "'");
    }

    return {
      'id': s['id']?.toString() ?? '',
      'name': cleanHtml(s['name']?.toString() ?? ''),
      'year': s['year']?.toString() ?? '',
      'duration': s['duration'] as int? ?? 0,
      'playCount': s['playCount'] as int? ?? 0,
      'language': s['language']?.toString() ?? '',
      'album': cleanHtml(s['album']?['name']?.toString() ?? ''),
      'albumId': s['album']?['id']?.toString() ?? '',
      'artist': artistNamesList.join(', '),
      'artistIds': artists
          .map((a) => (a is Map && a['id'] != null) ? a['id'].toString() : '')
          .where((id) => id.isNotEmpty)
          .toList(),
      'imageSmall': getImageUrl(0),
      'image': getImageUrl(1),
      'imageLarge': getImageUrl(2),
      'downloadUrl': bestDownload,
    };
  }

  Future<List<Map<String, dynamic>>> searchSongs(String query,
      {int page = 1, int limit = 15}) async {
    final uri = Uri.parse(
        '${AppConfig.apiBaseUrl}/api/search/songs?query=${Uri.encodeComponent(query)}&page=$page&limit=$limit');
    try {
      final response = await http.get(uri).timeout(AppConfig.httpTimeout);
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['success'] == true) {
          final results = data['data']['results'] as List? ?? [];
          return results
              .whereType<Map>()
              .map((s) => _parseApiSong(Map<String, dynamic>.from(s)))
              .toList();
        }
      }
    } catch (e, s) {
      debugPrint('searchSongs error: $e\n$s');
    }
    return [];
  }

  Future<List<Map<String, dynamic>>> getSongSuggestions(String songId,
      {int limit = 10}) async {
    final uri =
        Uri.parse('${AppConfig.apiBaseUrl}/api/songs/$songId/suggestions?limit=$limit');
    try {
      final response = await http.get(uri).timeout(AppConfig.httpTimeout);
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['success'] == true) {
          final results = data['data'] as List? ?? [];
          return results
              .whereType<Map>()
              .map((s) => _parseApiSong(Map<String, dynamic>.from(s)))
              .toList();
        }
      }
    } catch (e, s) {
      debugPrint('getSongSuggestions error: $e\n$s');
    }
    return [];
  }

  Future<Map<String, dynamic>?> getSongDetails(String songId) async {
    final uri = Uri.parse('${AppConfig.apiBaseUrl}/api/songs?id=$songId');
    try {
      final response = await http.get(uri).timeout(AppConfig.httpTimeout);
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['success'] == true) {
          final list = data['data'] as List? ?? [];
          if (list.isNotEmpty && list.first is Map) {
            return _parseApiSong(Map<String, dynamic>.from(list.first as Map));
          }
        }
      }
    } catch (e, s) {
      debugPrint('getSongDetails error: $e\n$s');
    }
    return null;
  }

  Future<SpotifyPlaylistResult?> fetchSpotifyPlaylist(String spotifyUrl) async {
    final uri = Uri.parse(
        '${AppConfig.spotifyApiUrl}/api/playlist?url=${Uri.encodeComponent(spotifyUrl)}');
    try {
      final response = await http.get(uri).timeout(AppConfig.spotifyTimeout);
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final tracks = (data['tracks'] as List? ?? [])
            .whereType<Map>()
            .map((t) => SpotifyTrack(
                  name: t['name'] as String? ?? '',
                  artists: List<String>.from(t['artists'] as List? ?? []),
                  durationMs: (t['duration_ms'] as num?)?.toInt() ?? 0,
                  album: t['album'] as String? ?? '',
                ))
            .where((t) => t.name.isNotEmpty)
            .toList();
        return SpotifyPlaylistResult(
          name: data['name'] as String? ?? 'Spotify Import',
          owner: data['owner'] as String? ?? '',
          tracks: tracks,
        );
      }
      final errorBody = jsonDecode(response.body);
      throw Exception(errorBody['error'] ?? 'HTTP ${response.statusCode}');
    } catch (e, s) {
      debugPrint('fetchSpotifyPlaylist error: $e\n$s');
      rethrow;
    }
  }

  Future<Map<String, dynamic>?> matchSpotifyTrack(SpotifyTrack track) async {
    final targetSecs = track.durationMs / 1000.0;
    final cleanName = _cleanTitle(track.name);
    final primaryArtist =
        track.artists.isNotEmpty ? track.artists.first : '';

    final queries = <String>[
      '${track.name} $primaryArtist'.trim(),
      '$cleanName $primaryArtist'.trim(),
      cleanName,
      track.name,
    ].where((q) => q.isNotEmpty).toList();

    final seen = <String>{};
    final candidates = <Map<String, dynamic>>[];

    for (final query in queries) {
      if (!seen.add(query)) continue;
      try {
        final results = await searchSongs(query, limit: 8);
        for (final s in results) {
          if (!candidates.any((c) => c['id'] == s['id'])) candidates.add(s);
        }
      } catch (_) {}
      if (candidates.length >= 15) break;
    }

    Map<String, dynamic>? best;
    double bestScore = double.negativeInfinity;

    for (final song in candidates) {
      final songClean = _cleanTitle((song['name'] as String? ?? '').toLowerCase());
      final trackClean = cleanName.toLowerCase();

      final nameSim = _stringSimilarity(songClean, trackClean);
      if (nameSim < 0.38) continue;

      final duration = song['duration'] as int? ?? 0;
      final durDiff =
          targetSecs > 0 ? (duration - targetSecs).abs() : 0.0;
      final durOk = targetSecs == 0 || durDiff <= 30;
      if (!durOk && nameSim < 0.82) continue;

      final artistNames = song['artist'] as String? ?? '';
      final artistBonus = track.artists.any((a) => artistNames
                  .toLowerCase()
                  .contains(a.toLowerCase().split(' ').first) &&
              a.isNotEmpty)
          ? 1.5
          : 0.0;

      final durPenalty = targetSecs > 0 ? (durDiff * 0.08).clamp(0.0, 3.0) : 0.0;
      final score = nameSim * 10 + artistBonus - durPenalty;

      if (score > bestScore) {
        bestScore = score;
        best = song;
      }
    }

    return best;
  }

  String _cleanTitle(String title) {
    var t = title;
    t = t.replaceAll(RegExp(r'\s*\(from\s+"[^"]*"\)', caseSensitive: false), '');
    t = t.replaceAll(RegExp(r'\s*\(from\s+[^)]+\)', caseSensitive: false), '');
    t = t.replaceAll(RegExp(r'\s*-\s*(slowed|reverb|lofi|lo-fi|remix|unplugged|reprise|acoustic|male|female|version|cover|remastered|extended|edit|feat\.?.*|ft\.?.*)$', caseSensitive: false), '');
    t = t.replaceAll(RegExp(r'\s*\((slowed|reverb|lofi|lo-fi|remix|unplugged|reprise|acoustic|male|female|version|cover|remastered|extended|edit)[^)]*\)', caseSensitive: false), '');
    t = t.replaceAll(RegExp(r'\s*\(feat\.?[^)]*\)', caseSensitive: false), '');
    t = t.trim();
    return t.isEmpty ? title : t;
  }

  double _stringSimilarity(String a, String b) {
    if (a == b) return 1.0;
    if (a.isEmpty || b.isEmpty) return 0.0;

    final aClean = a.replaceAll(RegExp(r'[^\w\s]'), '').trim();
    final bClean = b.replaceAll(RegExp(r'[^\w\s]'), '').trim();

    if (aClean == bClean) return 1.0;

    if (aClean.contains(bClean) || bClean.contains(aClean)) {
      final longer = aClean.length > bClean.length ? aClean : bClean;
      final shorter = aClean.length <= bClean.length ? aClean : bClean;
      return shorter.length / longer.length * 0.95;
    }

    final aWords = aClean.split(RegExp(r'\s+')).where((w) => w.length > 1).toSet();
    final bWords = bClean.split(RegExp(r'\s+')).where((w) => w.length > 1).toSet();
    if (aWords.isEmpty || bWords.isEmpty) return 0.0;

    final intersection = aWords.intersection(bWords).length;
    final union = aWords.union(bWords).length;
    final jaccard = union == 0 ? 0.0 : intersection / union;

    final overlap =
        intersection / (aWords.length < bWords.length ? aWords.length : bWords.length);
    return (jaccard * 0.5 + overlap * 0.5);
  }

  static Future<LyricsResult?> _getLocalLyrics(String songId) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final jsonStr = prefs.getString('lyrics_cache_$songId');
      if (jsonStr != null && jsonStr.isNotEmpty) {
        final Map<String, dynamic> map = jsonDecode(jsonStr);
        return LyricsResult(
          syncedLrc: map['syncedLrc'] as String?,
          plainText: map['plainText'] as String?,
        );
      }
    } catch (e) {
      debugPrint('Error loading cached lyrics: $e');
    }
    return null;
  }

  static Future<void> _saveLocalLyrics(String songId, LyricsResult result) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final map = {
        'syncedLrc': result.syncedLrc,
        'plainText': result.plainText,
      };
      await prefs.setString('lyrics_cache_$songId', jsonEncode(map));
    } catch (e) {
      debugPrint('Error saving cached lyrics: $e');
    }
  }

  Future<LyricsResult> getLyrics(String songId,
      {String? trackName,
      String? artistName,
      String? albumName,
      int? durationSecs}) async {
    final cached = _getCached(songId);
    if (cached != null) return cached;

    final localCached = await _getLocalLyrics(songId);
    if (localCached != null) {
      _putCache(songId, localCached);
      return localCached;
    }

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
        }).timeout(AppConfig.httpTimeout);

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
        }).timeout(AppConfig.httpTimeout);

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
            await _saveLocalLyrics(songId, r);
            return r;
          } else if (plain != null && plain.isNotEmpty) {
            final r = LyricsResult(plainText: plain);
            _putCache(songId, r);
            await _saveLocalLyrics(songId, r);
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

class SpotifyTrack {
  final String name;
  final List<String> artists;
  final int durationMs;
  final String album;

  const SpotifyTrack({
    required this.name,
    required this.artists,
    required this.durationMs,
    required this.album,
  });

  String get primaryArtist => artists.isNotEmpty ? artists.first : '';
}

class SpotifyPlaylistResult {
  final String name;
  final String owner;
  final List<SpotifyTrack> tracks;

  const SpotifyPlaylistResult({
    required this.name,
    required this.owner,
    required this.tracks,
  });
}

class LrcLine {
  final Duration timestamp;
  final String text;
  LrcLine(this.timestamp, this.text);
}

List<LrcLine> parseLrc(String lrc) {
  final lines = <LrcLine>[];
  final regex = RegExp(r'\[(\d{2}):(\d{2})(?:\.(\d+))?\]\s*(.*)');

  for (final line in lrc.split('\n')) {
    final match = regex.firstMatch(line.trim());
    if (match != null) {
      final min = int.parse(match.group(1)!);
      final sec = int.parse(match.group(2)!);
      final msStr = match.group(3);
      int ms = 0;
      if (msStr != null) {
        if (msStr.length == 1) {
          ms = int.parse(msStr) * 100;
        } else if (msStr.length == 2) {
          ms = int.parse(msStr) * 10;
        } else {
          ms = int.parse(msStr.substring(0, 3));
        }
      }
      final text = match.group(4)?.trim() ?? '';
      if (text.isNotEmpty) {
        lines.add(LrcLine(
          Duration(minutes: min, seconds: sec, milliseconds: ms),
          text,
        ));
      }
    }
  }

  lines.sort((a, b) => a.timestamp.compareTo(b.timestamp));
  return lines;
}
