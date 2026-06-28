import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:path_provider/path_provider.dart';
import 'package:flutter_patcher/flutter_patcher.dart';
import 'config.dart';
import 'notifications.dart';

enum UpdateDownloadState { idle, downloading, done, failed }

class AppUpdateInfo {
  final String version;
  final String tagName;
  final String changelog;
  final int sizeBytes;
  final String downloadUrl;
  final bool isPatch;

  const AppUpdateInfo({
    required this.version,
    required this.tagName,
    required this.changelog,
    required this.sizeBytes,
    required this.downloadUrl,
    required this.isPatch,
  });

  String get formattedSize {
    if (sizeBytes <= 0) return 'Unknown size';
    final mb = sizeBytes / (1024 * 1024);
    return '${mb.toStringAsFixed(1)} MB';
  }
}

class UpdateService {
  static final UpdateService _instance = UpdateService._();
  factory UpdateService() => _instance;
  UpdateService._();

  final ValueNotifier<AppUpdateInfo?> updateAvailableNotifier = ValueNotifier(null);
  final ValueNotifier<double> downloadProgressNotifier = ValueNotifier(0.0);
  final ValueNotifier<UpdateDownloadState> downloadStateNotifier =
      ValueNotifier(UpdateDownloadState.idle);

  http.Client? _client;
  bool _checked = false;

  Future<void> checkForUpdate() async {
    if (_checked) return;
    _checked = true;

    try {
      final info = await PackageInfo.fromPlatform();
      final currentVersion = info.version;

      final response = await http
          .get(
            Uri.parse(AppConfig.githubReleasesUrl),
            headers: {
              'Accept': 'application/vnd.github+json',
              'User-Agent': 'ArcMusic/1.0',
            },
          )
          .timeout(AppConfig.httpTimeout);

      if (response.statusCode != 200) return;

      final data = jsonDecode(response.body) as Map<String, dynamic>;
      final tagName = (data['tag_name'] as String? ?? '').replaceFirst('v', '');
      final changelog = data['body'] as String? ?? '';
      final assets = data['assets'] as List? ?? [];

      if (!_isNewerVersion(tagName, currentVersion)) return;

      // Prefer patch over full APK
      String patchUrl = '';
      int patchSize = 0;
      for (final asset in assets) {
        if (asset is Map) {
          final name = asset['name'] as String? ?? '';
          if (name == 'patch.zip') {
            patchUrl = asset['browser_download_url'] as String? ?? '';
            patchSize = (asset['size'] as num?)?.toInt() ?? 0;
            break;
          }
        }
      }

      if (patchUrl.isNotEmpty) {
        updateAvailableNotifier.value = AppUpdateInfo(
          version: tagName,
          tagName: data['tag_name'] as String? ?? 'v$tagName',
          changelog: changelog,
          sizeBytes: patchSize,
          downloadUrl: patchUrl,
          isPatch: true,
        );
        return;
      }
    } catch (e) {
      debugPrint('UpdateService.checkForUpdate error: $e');
    }
  }

  String _stripBuild(String v) => v.split('+').first;

  bool _isNewerVersion(String remote, String current) {
    try {
      final r = _stripBuild(remote).split('.').map(int.parse).toList();
      final c = _stripBuild(current).split('.').map(int.parse).toList();
      final maxLen = r.length > c.length ? r.length : c.length;
      for (int i = 0; i < maxLen; i++) {
        final rv = i < r.length ? r[i] : 0;
        final cv = i < c.length ? c[i] : 0;
        if (rv > cv) return true;
        if (rv < cv) return false;
      }
      return false;
    } catch (_) {
      return false;
    }
  }

  Future<void> downloadAndInstall() async {
    final info = updateAvailableNotifier.value;
    if (info == null) return;

    if (downloadStateNotifier.value == UpdateDownloadState.downloading) return;

    downloadStateNotifier.value = UpdateDownloadState.downloading;
    downloadProgressNotifier.value = 0.0;

    try {
      _client = http.Client();
      final request = http.Request('GET', Uri.parse(info.downloadUrl));
      final response = await _client!.send(request);

      if (response.statusCode != 200) {
        throw Exception('HTTP ${response.statusCode}');
      }

      final dir = await getApplicationDocumentsDirectory();
      final file = File('${dir.path}/update.${info.isPatch ? "zip" : "apk"}');
      if (await file.exists()) await file.delete();

      final total = response.contentLength ?? 0;
      int received = 0;
      final sink = file.openWrite();

      await for (final chunk in response.stream) {
        sink.add(chunk);
        received += chunk.length;
        if (total > 0) {
          downloadProgressNotifier.value = received / total;
        }
      }

      await sink.close();
      downloadProgressNotifier.value = 1.0;

      if (info.isPatch) {
        final bytes = await file.readAsBytes();
        final result = await FlutterPatcher.applyPatchBytes(
          bytes,
          version: info.version,
          targetVersionCode: _parseVersionCode(info.version),
        );
        await file.delete();
        if (result.ok) {
          downloadStateNotifier.value = UpdateDownloadState.done;
          AppNotifications.show('${info.changelog} — Update applied! Restart app.');
        } else {
          throw Exception('Patch apply failed: ${result.message}');
        }
      } else {
        downloadStateNotifier.value = UpdateDownloadState.done;
      }
    } catch (e) {
      debugPrint('UpdateService download error: $e');
      downloadStateNotifier.value = UpdateDownloadState.failed;
    }
  }

  int _parseVersionCode(String version) {
    try {
      final parts = version.split('+');
      if (parts.length > 1) return int.parse(parts.last);
      final nums = parts.first.split('.').map(int.parse).toList();
      return nums[0] * 1000000 + (nums.length > 1 ? nums[1] * 1000 : 0) + (nums.length > 2 ? nums[2] : 0);
    } catch (_) {
      return 1;
    }
  }

  void dismiss() {
    _client?.close();
    _client = null;
    downloadStateNotifier.value = UpdateDownloadState.idle;
    downloadProgressNotifier.value = 0.0;
    updateAvailableNotifier.value = null;
    resetForNextCheck();
  }

  void resetForNextCheck() {
    _checked = false;
  }
}
