import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../models/song.dart';
import '../core/theme.dart';
import '../core/liked_service.dart';
import '../core/player_service.dart';
import '../core/download_service.dart';
import '../screens/playlist_song_picker.dart';

class SongTile extends StatelessWidget {
  final Song song;
  final int index;
  final VoidCallback? onTap;
  final VoidCallback? onLike;
  final VoidCallback? onRemove;
  final bool? isLiked;

  const SongTile({
    super.key,
    required this.song,
    required this.index,
    this.onTap,
    this.onLike,
    this.onRemove,
    this.isLiked,
  });

  void _showContextMenu(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => SongContextSheet(song: song),
    );
  }

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      onLongPress: () => _showContextMenu(context),
      borderRadius: BorderRadius.circular(12),
      splashColor: AppTheme.accent.withValues(alpha: 0.1),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
        child: Row(
          children: [
            SizedBox(
              width: 28,
              child: Text(
                '${index + 1}',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: index < 3 ? AppTheme.accent : AppTheme.textSecondary,
                ),
              ),
            ),
            const SizedBox(width: 12),
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: CachedNetworkImage(
                imageUrl: song.imageMedium.isNotEmpty
                    ? song.imageMedium
                    : song.imageSmall,
                width: 52,
                height: 52,
                fit: BoxFit.cover,
                errorWidget: (_, __, ___) => Container(
                  width: 52,
                  height: 52,
                  decoration: BoxDecoration(
                    color: AppTheme.surface,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(
                    Icons.music_note_rounded,
                    color: AppTheme.accent,
                    size: 24,
                  ),
                ),
                placeholder: (_, __) => Container(
                  width: 52,
                  height: 52,
                  decoration: BoxDecoration(
                    color: AppTheme.surface,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Center(
                    child: SizedBox(
                      width: 14,
                      height: 14,
                      child: CircularProgressIndicator(
                        strokeWidth: 1.5,
                        color: AppTheme.accent,
                      ),
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          song.name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: AppTheme.textPrimary,
                          ),
                        ),
                      ),
                      ValueListenableBuilder<Set<String>>(
                        valueListenable: DownloadService().downloadedSongIdsNotifier,
                        builder: (context, downloadedIds, _) {
                          if (downloadedIds.contains(song.id)) {
                            return const Padding(
                              padding: EdgeInsets.only(left: 6),
                              child: Icon(
                                Icons.check_circle_rounded,
                                size: 14,
                                color: Color(0xFFD97757),
                              ),
                            );
                          }
                          return const SizedBox.shrink();
                        },
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    song.artistNames,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 12,
                      color: AppTheme.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            if (onRemove != null)
              IconButton(
                icon: const Icon(Icons.remove_circle_outline_rounded),
                color: AppTheme.textSecondary,
                onPressed: onRemove,
              )
            else
              ValueListenableBuilder<List<Song>>(
                valueListenable: LikedService().likedNotifier,
                builder: (context, likedSongs, _) {
                  final activeLiked = isLiked ?? LikedService().isLiked(song.id);
                  return IconButton(
                    icon: Icon(
                      activeLiked ? Icons.favorite_rounded : Icons.favorite_border_rounded,
                    ),
                    color: activeLiked ? AppTheme.accent : AppTheme.textSecondary,
                    onPressed: onLike ?? () => LikedService().toggleLike(song),
                  );
                },
              ),
            IconButton(
              icon: const Icon(Icons.more_vert_rounded),
              color: AppTheme.textSecondary,
              onPressed: () => _showContextMenu(context),
            ),
          ],
        ),
      ),
    );
  }
}

class SongContextSheet extends StatelessWidget {
  final Song song;
  const SongContextSheet({required this.song, super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      padding: const EdgeInsets.fromLTRB(24, 12, 24, 32),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 36,
            height: 4,
            margin: const EdgeInsets.only(bottom: 20),
            decoration: BoxDecoration(
              color: AppTheme.textSecondary.withValues(alpha: 0.3),
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: const Icon(Icons.play_arrow_rounded, color: AppTheme.accent),
            title: const Text('Play Now', style: TextStyle(color: AppTheme.textPrimary)),
            onTap: () {
              Navigator.pop(context);
              audioHandler.playSong(song);
            },
          ),
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: const Icon(Icons.playlist_add_rounded, color: AppTheme.textSecondary),
            title: const Text('Add to Playlist', style: TextStyle(color: AppTheme.textPrimary)),
            onTap: () async {
              Navigator.pop(context);
              await showSongPicker(context, [song]);
            },
          ),
          ValueListenableBuilder<List<Song>>(
            valueListenable: LikedService().likedNotifier,
            builder: (context, likedSongs, _) {
              final isLiked = LikedService().isLiked(song.id);
              return ListTile(
                contentPadding: EdgeInsets.zero,
                leading: Icon(
                  isLiked ? Icons.favorite_rounded : Icons.favorite_border_rounded,
                  color: isLiked ? AppTheme.accent : AppTheme.textSecondary,
                ),
                title: Text(
                  isLiked ? 'Remove from Liked' : 'Like Song',
                  style: const TextStyle(color: AppTheme.textPrimary),
                ),
                onTap: () {
                  Navigator.pop(context);
                  LikedService().toggleLike(song);
                },
              );
            },
          ),
        ],
      ),
    );
  }
}
