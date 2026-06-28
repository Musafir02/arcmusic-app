import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../core/theme.dart';
import 'song_tile.dart';
import '../core/download_service.dart';
import '../models/song.dart';

class SongCard extends StatelessWidget {
  final Song song;
  final VoidCallback? onTap;

  const SongCard({super.key, required this.song, this.onTap});

  @override
  Widget build(BuildContext context) {
    final imgLarge = song.imageLarge ?? '';
    final imgMedium = song.image ?? '';
    final id = song.id;

    return GestureDetector(
      onTap: onTap,
      onLongPress: () {
        if (onTap != null) {
          SongTile.showSongContext(context, song, onTap!);
        }
      },
      child: Container(
        width: 150,
        margin: const EdgeInsets.only(right: 14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(AppTheme.radiusDefault),
              child: CachedNetworkImage(
                imageUrl: imgLarge.isNotEmpty ? imgLarge : imgMedium,
                width: 150,
                height: 150,
                fit: BoxFit.cover,
                errorWidget: (_, __, ___) => Container(
                  width: 150,
                  height: 150,
                  color: AppTheme.surface,
                  child: const Icon(Icons.music_note_rounded, color: AppTheme.accent, size: 40),
                ),
                placeholder: (_, __) => Container(
                  width: 150,
                  height: 150,
                  color: AppTheme.surface,
                  child: const Center(
                    child: SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2, color: AppTheme.accent),
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: Text(
                    song.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppTheme.textPrimary),
                  ),
                ),
                ValueListenableBuilder<Set<String>>(
                  valueListenable: DownloadService().downloadedSongIdsNotifier,
                  builder: (context, downloadedIds, _) {
                    if (downloadedIds.contains(id)) {
                      return const Padding(
                        padding: EdgeInsets.only(left: 4),
                        child: Icon(Icons.check_circle_rounded, size: 13, color: AppTheme.accent),
                      );
                    }
                    return const SizedBox.shrink();
                  },
                ),
              ],
            ),
            const SizedBox(height: 3),
            Text(
              song.artist,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 11, color: AppTheme.textSecondary),
            ),
          ],
        ),
      ),
    );
  }
}
