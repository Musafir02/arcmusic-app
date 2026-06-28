import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'config.dart';

enum DownloadStatus { pending, downloading, paused, completed, failed }

class DownloadTask {
  final Map<String, dynamic> song;
  double progress;
  DownloadStatus status;

  DownloadTask({
    required this.song,
    this.progress = 0.0,
    this.status = DownloadStatus.pending,
  });
}

class DownloadService {
  static final DownloadService _instance = DownloadService._();
  factory DownloadService() => _instance;
  DownloadService._();

  final List<DownloadTask> _queue = [];
  Set<String> _downloadedSongIds = {};
  final Map<String, double> _progressMap = {};
  bool _isRunning = false;
  bool _isLooping = false;
  String? _activeBatchId;
  http.Client? _client;

  final ValueNotifier<List<DownloadTask>> queueNotifier = ValueNotifier([]);
  final ValueNotifier<Set<String>> downloadedSongIdsNotifier = ValueNotifier({});
  final ValueNotifier<Map<String, double>> progressNotifier = ValueNotifier({});
  final ValueNotifier<bool> isRunningNotifier = ValueNotifier(false);
  final ValueNotifier<double> overallProgressNotifier = ValueNotifier(0.0);
  final ValueNotifier<String?> activeBatchIdNotifier = ValueNotifier(null);

  List<DownloadTask> get queue => List.unmodifiable(_queue);
  bool get isRunning => _isRunning;
  String? get activeBatchId => _activeBatchId;

  Future<void> load() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final idsList = prefs.getStringList(AppConfig.keyDownloadedSongIds) ?? [];
      _downloadedSongIds = idsList.toSet();
      downloadedSongIdsNotifier.value = Set.unmodifiable(_downloadedSongIds);

      final jsonStr = prefs.getString(AppConfig.keyDownloadedSongsList);
      if (jsonStr != null && jsonStr.isNotEmpty) {
        final List raw = jsonDecode(jsonStr);
        final songs = raw.whereType<Map>().map((e) => Map<String, dynamic>.from(e)).toList();
        for (final song in songs) {
          final id = song['id'] as String? ?? '';
          if (id.isNotEmpty) {
            _progressMap[id] = 1.0;
          }
        }
        progressNotifier.value = Map<String, double>.from(_progressMap);
      }
    } catch (e) {
      debugPrint('Error loading downloads: $e');
    }
  }

  bool isSongDownloaded(String songId) {
    return _downloadedSongIds.contains(songId);
  }

  Future<String?> getDownloadedPath(String songId) async {
    try {
      final dir = await getApplicationDocumentsDirectory();
      final file = File('${dir.path}/downloads/$songId.mp3');
      if (await file.exists()) {
        return file.path;
      }
    } catch (e) {
      debugPrint('Error checking download path: $e');
    }
    return null;
  }

  void downloadSong(Map<String, dynamic> song) {
    final id = song['id'] as String? ?? '';
    if (id.isEmpty || isSongDownloaded(id)) return;
    if (_queue.any((task) => task.song['id'] == id)) return;

    if (_queue.isEmpty) {
      _activeBatchId = null;
      activeBatchIdNotifier.value = null;
    }

    final task = DownloadTask(song: song);
    _queue.add(task);
    queueNotifier.value = List.unmodifiable(_queue);

    if (!_isRunning) {
      startQueue();
    } else {
      _runQueue();
    }
  }

  void downloadPlaylist(List<Map<String, dynamic>> songs, String batchId) {
    if (_queue.isEmpty) {
      _activeBatchId = batchId;
      activeBatchIdNotifier.value = batchId;
    }
    bool addedAny = false;
    for (final song in songs) {
      final id = song['id'] as String? ?? '';
      if (id.isEmpty || isSongDownloaded(id)) continue;
      if (_queue.any((task) => task.song['id'] == id)) continue;

      _queue.add(DownloadTask(song: song));
      addedAny = true;
    }

    if (addedAny) {
      queueNotifier.value = List.unmodifiable(_queue);
      if (!_isRunning) {
        startQueue();
      } else {
        _runQueue();
      }
    }
  }

  void pauseQueue() {
    _isRunning = false;
    isRunningNotifier.value = false;
    for (final task in _queue) {
      if (task.status == DownloadStatus.downloading) {
        task.status = DownloadStatus.paused;
      }
    }
    _client?.close();
    _client = null;
    _notify();
  }

  void startQueue() {
    if (_isRunning) return;
    _isRunning = true;
    isRunningNotifier.value = true;
    _client = http.Client();
    for (final task in _queue) {
      if (task.status == DownloadStatus.paused) {
        task.status = DownloadStatus.pending;
      }
    }
    _runQueue();
  }

  void cancelSong(String songId) {
    final index = _queue.indexWhere((task) => task.song['id'] == songId);
    if (index == -1) return;

    final task = _queue[index];
    if (task.status == DownloadStatus.downloading) {
      task.status = DownloadStatus.paused;
      _client?.close();
      _client = http.Client();
    }

    _queue.removeAt(index);
    _progressMap.remove(songId);
    queueNotifier.value = List.unmodifiable(_queue);
    _notifyProgress();
    _notify();

    if (_isRunning && _queue.isNotEmpty && !_isLooping) {
      _runQueue();
    }
  }

  Future<void> deleteSong(String songId) async {
    try {
      final dir = await getApplicationDocumentsDirectory();
      final file = File('${dir.path}/downloads/$songId.mp3');
      if (await file.exists()) {
        await file.delete();
      }

      _downloadedSongIds.remove(songId);
      downloadedSongIdsNotifier.value = Set.unmodifiable(_downloadedSongIds);

      final prefs = await SharedPreferences.getInstance();
      await prefs.setStringList(AppConfig.keyDownloadedSongIds, _downloadedSongIds.toList());

      final jsonStr = prefs.getString(AppConfig.keyDownloadedSongsList);
      if (jsonStr != null && jsonStr.isNotEmpty) {
        final List list = jsonDecode(jsonStr);
        list.removeWhere((e) => e['id'] == songId);
        await prefs.setString(AppConfig.keyDownloadedSongsList, jsonEncode(list));
      }

      _progressMap.remove(songId);
      _notifyProgress();
      _notify();
    } catch (e) {
      debugPrint('Error deleting song: $e');
    }
  }

  void clearQueue() {
    _queue.removeWhere((t) => t.status == DownloadStatus.completed || t.status == DownloadStatus.failed);
    queueNotifier.value = List.unmodifiable(_queue);
    if (_queue.isEmpty) {
      _activeBatchId = null;
      activeBatchIdNotifier.value = null;
    }
    _notifyProgress();
  }

  void cancelAll() {
    _isRunning = false;
    isRunningNotifier.value = false;
    _client?.close();
    _client = null;
    _queue.clear();
    _progressMap.clear();
    _activeBatchId = null;
    activeBatchIdNotifier.value = null;
    queueNotifier.value = List.unmodifiable(_queue);
    _notifyProgress();
  }

  Future<void> _runQueue() async {
    if (_isLooping) return;
    _isLooping = true;

    while (_isRunning) {
      DownloadTask? nextTask;
      for (final t in _queue) {
        if (t.status == DownloadStatus.pending) {
          nextTask = t;
          break;
        }
      }

      if (nextTask == null) {
        _activeBatchId = null;
        activeBatchIdNotifier.value = null;
        break;
      }

      _client ??= http.Client();

      await _downloadTask(nextTask);
    }

    _isLooping = false;
  }

  Future<void> _downloadTask(DownloadTask task) async {
    final song = task.song;
    final id = song['id'] as String? ?? '';
    final downloadUrl = song['downloadUrl'] as String? ?? '';
    if (id.isEmpty || downloadUrl.isEmpty) {
      task.status = DownloadStatus.failed;
      _notify();
      return;
    }

    try {
      task.status = DownloadStatus.downloading;
      task.progress = 0.0;
      _notify();

      final response = await _client!.send(http.Request('GET', Uri.parse(downloadUrl)));
      if (response.statusCode != 200) {
        throw Exception('Status code ${response.statusCode}');
      }

      final totalBytes = response.contentLength ?? 0;
      int receivedBytes = 0;

      final dir = await getApplicationDocumentsDirectory();
      final downloadsDir = Directory('${dir.path}/downloads');
      if (!await downloadsDir.exists()) {
        await downloadsDir.create(recursive: true);
      }

      final file = File('${downloadsDir.path}/$id.mp3');
      final tempFile = File('${downloadsDir.path}/$id.mp3.tmp');
      if (await tempFile.exists()) {
        await tempFile.delete();
      }

      final sink = tempFile.openWrite();

      await for (final chunk in response.stream) {
        if (!_isRunning || task.status == DownloadStatus.paused) {
          await sink.close();
          if (await tempFile.exists()) {
            await tempFile.delete();
          }
          return;
        }
        sink.add(chunk);
        receivedBytes += chunk.length;
        if (totalBytes > 0) {
          task.progress = receivedBytes / totalBytes;
          _progressMap[id] = task.progress;
          _notifyProgress();
        }
      }

      await sink.close();

      if (await file.exists()) {
        await file.delete();
      }
      await tempFile.rename(file.path);

      task.status = DownloadStatus.completed;
      task.progress = 1.0;
      _progressMap[id] = 1.0;
      _downloadedSongIds.add(id);
      await _saveDownloadedSongMetadata(song);
      _notifyProgress();
      _notify();
    } catch (e) {
      debugPrint('Download error: $e');
      if (task.status != DownloadStatus.paused) {
        task.status = DownloadStatus.failed;
      }
      _notify();
    }
  }

  Future<void> _saveDownloadedSongMetadata(Map<String, dynamic> song) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setStringList(AppConfig.keyDownloadedSongIds, _downloadedSongIds.toList());
      downloadedSongIdsNotifier.value = Set.unmodifiable(_downloadedSongIds);

      final jsonStr = prefs.getString(AppConfig.keyDownloadedSongsList);
      List<dynamic> list = [];
      if (jsonStr != null && jsonStr.isNotEmpty) {
        list = jsonDecode(jsonStr);
      }
      if (!list.any((e) => e['id'] == song['id'])) {
        list.add(song);
        await prefs.setString(AppConfig.keyDownloadedSongsList, jsonEncode(list));
      }
    } catch (e) {
      debugPrint('Error saving download metadata: $e');
    }
  }

  void _notify() {
    queueNotifier.value = List.unmodifiable(_queue);
  }

  void _notifyProgress() {
    progressNotifier.value = Map<String, double>.from(_progressMap);

    if (_queue.isEmpty) {
      overallProgressNotifier.value = 0.0;
      return;
    }

    double totalProgress = 0.0;
    for (final task in _queue) {
      if (task.status == DownloadStatus.completed) {
        totalProgress += 1.0;
      } else {
        totalProgress += task.progress;
      }
    }
    overallProgressNotifier.value = totalProgress / _queue.length;
  }
}
