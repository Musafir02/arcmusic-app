import 'dart:io';
import 'package:flutter/material.dart';
import '../core/theme.dart';
import '../core/update_service.dart';

class UpdateDialog extends StatelessWidget {
  final AppUpdateInfo info;
  const UpdateDialog({required this.info, super.key});

  static void show(BuildContext context, AppUpdateInfo info) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      isDismissible: true,
      builder: (_) => UpdateDialog(info: info),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      padding: EdgeInsets.fromLTRB(24, 20, 24, MediaQuery.of(context).viewInsets.bottom + 32),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(
            child: Container(
              width: 40, height: 4,
              decoration: BoxDecoration(
                color: AppTheme.textSecondary.withValues(alpha: 0.3),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 20),
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: AppTheme.accent.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  info.isPatch ? Icons.auto_fix_high_rounded : Icons.system_update_rounded,
                  color: AppTheme.accent, size: 26,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      info.isPatch ? 'Quick Update' : 'Update Available',
                      style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: AppTheme.textPrimary),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '${info.tagName}  •  ${info.formattedSize}',
                      style: const TextStyle(fontSize: 13, color: AppTheme.textSecondary),
                    ),
                  ],
                ),
              ),
              TextButton(
                onPressed: () {
                  Navigator.pop(context);
                  UpdateService().dismiss();
                },
                child: const Text('Later', style: TextStyle(color: AppTheme.textSecondary, fontSize: 13)),
              ),
            ],
          ),
          if (info.changelog.isNotEmpty) ...[
            const SizedBox(height: 18),
            const Text("What's new", style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: AppTheme.accent)),
            const SizedBox(height: 8),
            Container(
              constraints: const BoxConstraints(maxHeight: 140),
              child: SingleChildScrollView(
                child: Text(
                  info.changelog,
                  style: const TextStyle(fontSize: 13, color: AppTheme.textSecondary, height: 1.5),
                ),
              ),
            ),
          ],
          const SizedBox(height: 22),
          ValueListenableBuilder<UpdateDownloadState>(
            valueListenable: UpdateService().downloadStateNotifier,
            builder: (context, state, _) {
              if (state == UpdateDownloadState.downloading) {
                return ValueListenableBuilder<double>(
                  valueListenable: UpdateService().downloadProgressNotifier,
                  builder: (context, progress, _) {
                    final pct = (progress * 100).toStringAsFixed(0);
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text('Downloading…', style: TextStyle(fontSize: 13, color: AppTheme.textSecondary, fontWeight: FontWeight.w600)),
                            Text('$pct%', style: const TextStyle(fontSize: 13, color: AppTheme.accent, fontWeight: FontWeight.w700)),
                          ],
                        ),
                        const SizedBox(height: 10),
                        ClipRRect(
                          borderRadius: BorderRadius.circular(6),
                          child: LinearProgressIndicator(
                            value: progress,
                            minHeight: 8,
                            backgroundColor: AppTheme.background,
                            valueColor: const AlwaysStoppedAnimation(AppTheme.accent),
                          ),
                        ),
                      ],
                    );
                  },
                );
              }

              if (state == UpdateDownloadState.done) {
                return Column(
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.check_circle_rounded, color: AppTheme.accent.withValues(alpha: 0.8), size: 18),
                        const SizedBox(width: 8),
                        Text(
                          info.isPatch ? 'Update applied! Restart app to use.' : 'Download complete.',
                          style: const TextStyle(fontSize: 13, color: AppTheme.accent, fontWeight: FontWeight.w600),
                        ),
                      ],
                    ),
                    if (info.isPatch) ...[
                      const SizedBox(height: 12),
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton.icon(
                          onPressed: () => exit(0),
                          icon: const Icon(Icons.restart_alt_rounded, size: 18),
                          label: const Text('Restart Now', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700)),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppTheme.accent,
                            foregroundColor: AppTheme.background,
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                          ),
                        ),
                      ),
                    ],
                  ],
                );
              }

              if (state == UpdateDownloadState.failed) {
                return Column(
                  children: [
                    const Text('Download failed. Please try again.', style: TextStyle(color: Colors.redAccent, fontSize: 13)),
                    const SizedBox(height: 10),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: () => UpdateService().downloadAndInstall(),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppTheme.accent,
                          foregroundColor: AppTheme.background,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                        ),
                        child: const Text('Retry', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700)),
                      ),
                    ),
                  ],
                );
              }

              return SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: () => UpdateService().downloadAndInstall(),
                  icon: Icon(info.isPatch ? Icons.auto_fix_high_rounded : Icons.download_rounded, size: 18),
                  label: Text(
                    info.isPatch ? 'Download Update' : 'Download & Install',
                    style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.accent,
                    foregroundColor: AppTheme.background,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  ),
                ),
              );
            },
          ),
        ],
      ),
    );
  }
}
