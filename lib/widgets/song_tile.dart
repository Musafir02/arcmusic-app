import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../core/theme.dart';
import '../core/user_data_service.dart';
import '../core/download_service.dart';
import '../screens/playlist_song_picker.dart';

class SongTile extends StatelessWidget {
  final Map<String, dynamic> song;
  final int index;
  final VoidCallback onTap;
  final VoidCallback? onRemove;

  const SongTile({
    super.key,
    required this.song,
    required this.index,
    required this.onTap,
    this.onRemove,
  });

  static void showSongContext(BuildContext context, Map<String, dynamic> song, VoidCallback onTap, {VoidCallback? onRemove}) {
    final ds = DownloadService();
    final uds = UserDataService();
    final id = song['id'] as String;

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        decoration: BoxDecoration(
          color: AppTheme.surface,
          borderRadius: BorderRadius.vertical(top: Radius.circular(AppTheme.radiusSheet)),
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
                Navigator.pop(ctx);
                onTap();
              },
            ),
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.playlist_add_rounded, color: AppTheme.textSecondary),
              title: const Text('Add to Playlist', style: TextStyle(color: AppTheme.textPrimary)),
              onTap: () {
                Navigator.pop(ctx);
                showSongPicker(context, [song]);
              },
            ),
            if (onRemove != null)
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.delete_outline_rounded, color: Colors.redAccent),
                title: const Text('Remove from Playlist', style: TextStyle(color: AppTheme.textPrimary)),
                onTap: () {
                  Navigator.pop(ctx);
                  onRemove();
                },
              )
            else
              ValueListenableBuilder<List<Map<String, dynamic>>>(
                valueListenable: uds.likedNotifier,
                builder: (context, liked, _) {
                  final likedActive = uds.isLiked(id);
                  return ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: Icon(
                      likedActive ? Icons.favorite_rounded : Icons.favorite_border_rounded,
                      color: likedActive ? AppTheme.accent : AppTheme.textSecondary,
                    ),
                    title: Text(likedActive ? 'Remove from Liked' : 'Like Song', style: const TextStyle(color: AppTheme.textPrimary)),
                    onTap: () {
                      Navigator.pop(ctx);
                      uds.toggleLike(song);
                    },
                  );
                },
              ),
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: ValueListenableBuilder<Set<String>>(
                valueListenable: ds.downloadedSongIdsNotifier,
                builder: (context, ids, _) {
                  final dl = ids.contains(id);
                  return Icon(
                    dl ? Icons.check_circle_rounded : Icons.download_rounded,
                    color: dl ? const Color(0xFFD97757) : AppTheme.textSecondary,
                  );
                },
              ),
              title: const Text('Download Track', style: TextStyle(color: AppTheme.textPrimary)),
              onTap: () {
                Navigator.pop(ctx);
                ds.downloadSong(song);
              },
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final uds = UserDataService();
    final ds = DownloadService();
    final id = song['id'] as String? ?? '';

    return InkWell(
      onTap: onTap,
      onLongPress: () => showSongContext(context, song, onTap, onRemove: onRemove),
      borderRadius: BorderRadius.circular(AppTheme.radiusDefault),
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
                imageUrl: (song['image'] as String? ?? '').isNotEmpty
                    ? (song['image'] as String)
                    : (song['imageSmall'] as String? ?? ''),
                width: 52,
                height: 52,
                fit: BoxFit.cover,
                placeholder: (_, __) => Container(width: 52, height: 52, color: AppTheme.surface),
                errorWidget: (_, __, ___) => Container(
                  width: 52,
                  height: 52,
                  color: AppTheme.surface,
                  child: const Icon(Icons.music_note_rounded, color: AppTheme.accent, size: 24),
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
                          song['name'] as String? ?? '',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: AppTheme.textPrimary),
                        ),
                      ),
                      ValueListenableBuilder<Set<String>>(
                        valueListenable: ds.downloadedSongIdsNotifier,
                        builder: (context, ids, _) => ids.contains(id)
                            ? const Padding(
                                padding: EdgeInsets.only(left: 6),
                                child: Icon(Icons.check_circle_rounded, size: 14, color: Color(0xFFD97757)),
                              )
                            : const SizedBox.shrink(),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    song['artist'] as String? ?? '',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontSize: 12, color: AppTheme.textSecondary),
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
              ValueListenableBuilder<List<Map<String, dynamic>>>(
                valueListenable: uds.likedNotifier,
                builder: (context, liked, _) {
                  final activeLiked = uds.isLiked(id);
                  return IconButton(
                    icon: Icon(activeLiked ? Icons.favorite_rounded : Icons.favorite_border_rounded),
                    color: activeLiked ? AppTheme.accent : AppTheme.textSecondary,
                    onPressed: () => uds.toggleLike(song),
                  );
                },
              ),
            if (onRemove != null)
              ReorderableDragStartListener(
                index: index,
                child: const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 8),
                  child: Icon(Icons.drag_handle_rounded, color: AppTheme.textSecondary),
                ),
              )
            else
              IconButton(
                icon: const Icon(Icons.more_vert_rounded),
                color: AppTheme.textSecondary,
                onPressed: () => showSongContext(context, song, onTap, onRemove: onRemove),
              ),
          ],
        ),
      ),
    );
  }
}
