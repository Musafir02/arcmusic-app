import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:path_provider/path_provider.dart';
import 'package:open_file/open_file.dart';
import 'config.dart';

enum UpdateDownloadState { idle, downloading, done, failed }

class AppUpdateInfo {
  final String version;
  final String tagName;
  final String changelog;
  final int apkSizeBytes;
  final String apkDownloadUrl;

  const AppUpdateInfo({
    required this.version,
    required this.tagName,
    required this.changelog,
    required this.apkSizeBytes,
    required this.apkDownloadUrl,
  });

  String get formattedSize {
    if (apkSizeBytes <= 0) return 'Unknown size';
    final mb = apkSizeBytes / (1024 * 1024);
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

  static const _abiChannel = MethodChannel('com.arcmusic.arcmusic/abi');

  Future<String> _getDeviceAbi() async {
    try {
      final abi = await _abiChannel.invokeMethod<String>('getSupportedAbis');
      if (abi != null && abi.isNotEmpty) return abi;
    } catch (_) {}
    return 'arm64-v8a';
  }

  Future<void> checkForUpdate() async {
    if (_checked) return;
    _checked = true;

    try {
      final info = await PackageInfo.fromPlatform();
      final currentVersion = info.version;
      final deviceAbi = await _getDeviceAbi();

      final response = await http
          .get(
            Uri.parse(AppConfig.githubReleasesUrl),
            headers: {
              'Accept': 'application/vnd.github+json',
              'User-Agent': 'ArcMusic/1.0',
            },
          )
          .timeout(const Duration(seconds: 10));

      if (response.statusCode != 200) return;

      final data = jsonDecode(response.body) as Map<String, dynamic>;
      final tagName = (data['tag_name'] as String? ?? '').replaceFirst('v', '');
      final changelog = data['body'] as String? ?? '';
      final assets = data['assets'] as List? ?? [];

      String apkUrl = '';
      int apkSize = 0;

      // First try to match APK by device ABI
      for (final asset in assets) {
        if (asset is Map) {
          final name = asset['name'] as String? ?? '';
          if (name.toLowerCase().contains(deviceAbi) && name.toLowerCase().endsWith('.apk')) {
            apkUrl = asset['browser_download_url'] as String? ?? '';
            apkSize = (asset['size'] as num?)?.toInt() ?? 0;
            break;
          }
        }
      }

      // Fallback: pick any APK if ABI-specific one not found
      if (apkUrl.isEmpty) {
        for (final asset in assets) {
          if (asset is Map) {
            final name = asset['name'] as String? ?? '';
            if (name.toLowerCase().endsWith('.apk')) {
              apkUrl = asset['browser_download_url'] as String? ?? '';
              apkSize = (asset['size'] as num?)?.toInt() ?? 0;
              break;
            }
          }
        }
      }

      if (apkUrl.isEmpty) return;

      if (_isNewerVersion(tagName, currentVersion)) {
        updateAvailableNotifier.value = AppUpdateInfo(
          version: tagName,
          tagName: data['tag_name'] as String? ?? 'v$tagName',
          changelog: changelog,
          apkSizeBytes: apkSize,
          apkDownloadUrl: apkUrl,
        );
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

    if (downloadStateNotifier.value == UpdateDownloadState.done) {
      final dir = await getApplicationDocumentsDirectory();
      final file = File('${dir.path}/update.apk');
      if (await file.exists()) {
        await OpenFile.open(file.path);
      }
      return;
    }

    if (downloadStateNotifier.value == UpdateDownloadState.downloading) return;

    downloadStateNotifier.value = UpdateDownloadState.downloading;
    downloadProgressNotifier.value = 0.0;

    try {
      _client = http.Client();
      final request = http.Request('GET', Uri.parse(info.apkDownloadUrl));
      final response = await _client!.send(request);

      if (response.statusCode != 200) {
        throw Exception('HTTP ${response.statusCode}');
      }

      final dir = await getApplicationDocumentsDirectory();
      final file = File('${dir.path}/update.apk');
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
      downloadStateNotifier.value = UpdateDownloadState.done;
      downloadProgressNotifier.value = 1.0;

      await OpenFile.open(file.path);
    } catch (e) {
      debugPrint('UpdateService download error: $e');
      downloadStateNotifier.value = UpdateDownloadState.failed;
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
