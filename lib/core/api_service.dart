import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/song.dart';

class ApiService {
  static const String _baseUrl = 'https://arcmusic-api.vercel.app';

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
}
