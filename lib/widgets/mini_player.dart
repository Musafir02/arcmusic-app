import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../core/player_service.dart';
import '../core/theme.dart';
import '../screens/full_player_screen.dart';
import '../models/song.dart';

class MiniPlayer extends StatelessWidget {
  const MiniPlayer({super.key});

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<Song?>(
      valueListenable: audioHandler.currentSongNotifier,
      builder: (context, song, _) {
        if (song == null) return const SizedBox.shrink();
        return _MiniPlayerContent(song: song);
      },
    );
  }
}

class _MiniPlayerContent extends StatelessWidget {
  final Song song;
  const _MiniPlayerContent({required this.song});

  void _openFullPlayer(BuildContext context) {
    Navigator.push(
      context,
      PageRouteBuilder(
        pageBuilder: (_, __, ___) => const FullPlayerScreen(),
        transitionsBuilder: (_, anim, __, child) {
          return SlideTransition(
            position: Tween<Offset>(
              begin: const Offset(0, 1),
              end: Offset.zero,
            ).animate(CurvedAnimation(parent: anim, curve: Curves.easeOutCubic)),
            child: child,
          );
        },
        transitionDuration: const Duration(milliseconds: 350),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final bottomPadding = MediaQuery.of(context).padding.bottom;
    final imgMedium = song.image ?? '';
    final imgSmall = song.imageSmall ?? '';

    return GestureDetector(
      onTap: () => _openFullPlayer(context),
      child: Container(
        margin: EdgeInsets.fromLTRB(12, 0, 12, 8 + bottomPadding),
        decoration: BoxDecoration(
          color: AppTheme.surface,
          borderRadius: BorderRadius.circular(14),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            StreamBuilder<Duration>(
              stream: audioHandler.positionStream,
              builder: (context, posSnap) {
                final pos = posSnap.data ?? Duration.zero;
                final dur = audioHandler.duration;
                final total = dur.inMilliseconds.toDouble();
                final current = pos.inMilliseconds.toDouble().clamp(0.0, total > 0 ? total : 1.0);
                final progress = total > 0 ? current / total : 0.0;
                return ClipRRect(
                  borderRadius: const BorderRadius.only(
                    topLeft: Radius.circular(14),
                    topRight: Radius.circular(14),
                  ),
                  child: LinearProgressIndicator(
                    value: progress,
                    minHeight: 3,
                    backgroundColor: AppTheme.background.withValues(alpha: 0.4),
                    valueColor: const AlwaysStoppedAnimation(AppTheme.accent),
                  ),
                );
              },
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 8, 8, 10),
              child: Row(
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: CachedNetworkImage(
                      imageUrl: imgMedium.isNotEmpty ? imgMedium : imgSmall,
                      width: 44,
                      height: 44,
                      fit: BoxFit.cover,
                      errorWidget: (_, __, ___) => Container(
                        width: 44,
                        height: 44,
                        color: AppTheme.background,
                        child: const Icon(Icons.music_note_rounded, color: AppTheme.accent, size: 20),
                      ),
                      placeholder: (_, __) => Container(
                        width: 44,
                        height: 44,
                        color: AppTheme.background,
                        child: const Center(
                          child: SizedBox(
                            width: 12,
                            height: 12,
                            child: CircularProgressIndicator(strokeWidth: 1.5, color: AppTheme.accent),
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          song.name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppTheme.textPrimary),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          song.artist,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(fontSize: 11, color: AppTheme.textSecondary),
                        ),
                      ],
                    ),
                  ),
                  StreamBuilder<bool>(
                    stream: audioHandler.playingStream,
                    builder: (context, snap) {
                      final playing = snap.data ?? false;
                      return GestureDetector(
                        onTap: audioHandler.togglePlay,
                        child: Container(
                          width: 40,
                          height: 40,
                          decoration: const BoxDecoration(
                            color: AppTheme.accent,
                            shape: BoxShape.circle,
                          ),
                          child: Icon(
                            playing ? Icons.pause_rounded : Icons.play_arrow_rounded,
                            color: AppTheme.background,
                            size: 22,
                          ),
                        ),
                      );
                    },
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
