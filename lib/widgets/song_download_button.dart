import 'package:flutter/material.dart';
import '../core/download_service.dart';
import '../core/theme.dart';

class SongDownloadButton extends StatelessWidget {
  final Map<String, dynamic> song;
  const SongDownloadButton({required this.song, super.key});

  @override
  Widget build(BuildContext context) {
    final ds = DownloadService();
    final id = song['id'] as String? ?? '';
    if (id.isEmpty) return const SizedBox.shrink();

    return ValueListenableBuilder<Set<String>>(
      valueListenable: ds.downloadedSongIdsNotifier,
      builder: (context, downloadedIds, _) {
        final isDownloaded = downloadedIds.contains(id);
        if (isDownloaded) {
          return IconButton(
            icon: const Icon(Icons.check_rounded, color: Color(0xFFD97757), size: 20),
            onPressed: () {
              showDialog(
                context: context,
                builder: (context) => AlertDialog(
                  backgroundColor: AppTheme.surface,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppTheme.radiusCard)),
                  title: const Text('Delete Download', style: TextStyle(color: AppTheme.textPrimary)),
                  content: Text('Delete "${song['name']}" from your local storage?', style: const TextStyle(color: AppTheme.textSecondary)),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.pop(context),
                      child: const Text('Cancel', style: TextStyle(color: AppTheme.textSecondary)),
                    ),
                    TextButton(
                      onPressed: () {
                        Navigator.pop(context);
                        ds.deleteSong(id);
                      },
                      child: const Text('Delete', style: TextStyle(color: Colors.redAccent)),
                    ),
                  ],
                ),
              );
            },
          );
        }

        return ValueListenableBuilder<List<DownloadTask>>(
          valueListenable: ds.queueNotifier,
          builder: (context, queue, _) {
            final taskIndex = queue.indexWhere((t) => t.song['id'] == id);
            if (taskIndex != -1) {
              final task = queue[taskIndex];
              return ValueListenableBuilder<Map<String, double>>(
                valueListenable: ds.progressNotifier,
                builder: (context, progressMap, _) {
                  final progress = progressMap[id] ?? 0.0;
                  return GestureDetector(
                    onTap: () => ds.cancelSong(id),
                    child: Container(
                      width: 36,
                      height: 36,
                      alignment: Alignment.center,
                      child: SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                          value: (task.status == DownloadStatus.downloading || task.status == DownloadStatus.paused) ? progress : 0.0,
                          strokeWidth: 2,
                          color: const Color(0xFFD97757),
                          backgroundColor: AppTheme.surface,
                        ),
                      ),
                    ),
                  );
                },
              );
            }

            return IconButton(
              icon: const Icon(Icons.download_rounded, color: AppTheme.textSecondary, size: 20),
              onPressed: () => ds.downloadSong(song),
            );
          },
        );
      },
    );
  }
}
