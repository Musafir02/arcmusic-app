import 'package:flutter/material.dart';
import '../core/download_service.dart';
import '../core/theme.dart';

class DownloadProgressCard extends StatelessWidget {
  final String batchId;
  const DownloadProgressCard({required this.batchId, super.key});

  @override
  Widget build(BuildContext context) {
    final ds = DownloadService();
    return ValueListenableBuilder<String?>(
      valueListenable: ds.activeBatchIdNotifier,
      builder: (context, activeBatchId, _) {
        if (activeBatchId != batchId) return const SizedBox.shrink();

        return ValueListenableBuilder<List<DownloadTask>>(
          valueListenable: ds.queueNotifier,
          builder: (context, queue, _) {
            if (queue.isEmpty) return const SizedBox.shrink();

            final total = queue.length;
            final completed = queue.where((t) => t.status == DownloadStatus.completed).length;

            return ValueListenableBuilder<bool>(
              valueListenable: ds.isRunningNotifier,
              builder: (context, isRunning, _) {
                return ValueListenableBuilder<double>(
                  valueListenable: ds.overallProgressNotifier,
                  builder: (context, overallProgress, _) {
                    return Container(
                      margin: const EdgeInsets.fromLTRB(20, 0, 20, 16),
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: AppTheme.background,
                        borderRadius: BorderRadius.circular(AppTheme.radiusCard),
                        border: Border.all(
                          color: AppTheme.accent.withValues(alpha: 0.2),
                        ),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      isRunning ? 'Downloading Tracks' : 'Downloads Paused',
                                      style: const TextStyle(
                                        fontSize: 14,
                                        fontWeight: FontWeight.w700,
                                        color: AppTheme.textPrimary,
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      '$completed of $total tracks completed (${(overallProgress * 100).toStringAsFixed(0)}%)',
                                      style: const TextStyle(
                                        fontSize: 12,
                                        color: AppTheme.textSecondary,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              IconButton(
                                icon: Icon(
                                  isRunning ? Icons.pause_rounded : Icons.play_arrow_rounded,
                                  color: AppTheme.accent,
                                ),
                                onPressed: () {
                                  if (isRunning) {
                                    ds.pauseQueue();
                                  } else {
                                    ds.startQueue();
                                  }
                                },
                              ),
                              IconButton(
                                icon: const Icon(
                                  Icons.close_rounded,
                                  color: AppTheme.textSecondary,
                                ),
                                onPressed: () {
                                  ds.cancelAll();
                                },
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          ClipRRect(
                            borderRadius: BorderRadius.circular(4),
                            child: LinearProgressIndicator(
                              value: overallProgress,
                              backgroundColor: AppTheme.surface,
                              valueColor: const AlwaysStoppedAnimation<Color>(
                                AppTheme.accent,
                              ),
                              minHeight: 4,
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                );
              },
            );
          },
        );
      },
    );
  }
}
