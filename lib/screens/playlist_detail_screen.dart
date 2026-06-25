import 'dart:math';
import 'package:flutter/material.dart';
import '../core/playlist_service.dart';
import '../core/player_service.dart';
import '../core/theme.dart';
import '../core/download_service.dart';
import '../models/playlist.dart';
import '../models/song.dart';
import 'search_screen.dart';
import '../widgets/mini_player.dart';

class PlaylistDetailScreen extends StatefulWidget {
  final String playlistId;

  const PlaylistDetailScreen({
    super.key,
    required this.playlistId,
  });

  @override
  State<PlaylistDetailScreen> createState() => _PlaylistDetailScreenState();
}

class _PlaylistDetailScreenState extends State<PlaylistDetailScreen> {
  Future<void> _deletePlaylist(BuildContext context) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          backgroundColor: AppTheme.surface,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          title: const Text(
            'Delete Playlist',
            style: TextStyle(color: AppTheme.textPrimary),
          ),
          content: const Text(
            'Are you sure you want to delete this playlist? This action cannot be undone.',
            style: TextStyle(color: AppTheme.textSecondary),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text(
                'Cancel',
                style: TextStyle(color: AppTheme.textSecondary),
              ),
            ),
            TextButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text(
                'Delete',
                style: TextStyle(color: Colors.redAccent),
              ),
            ),
          ],
        );
      },
    );

    if (confirm == true) {
      await PlaylistService().deletePlaylist(widget.playlistId);
      if (!context.mounted) return;
      Navigator.pop(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.background,
      body: ValueListenableBuilder<List<Playlist>>(
        valueListenable: PlaylistService().playlistsNotifier,
        builder: (context, playlists, _) {
          final playlistIndex = playlists.indexWhere((p) => p.id == widget.playlistId);
          if (playlistIndex == -1) {
            return const Scaffold(
              backgroundColor: AppTheme.background,
              body: Center(
                child: CircularProgressIndicator(
                  color: AppTheme.accent,
                ),
              ),
            );
          }

          final playlist = playlists[playlistIndex];

          return CustomScrollView(
            physics: const BouncingScrollPhysics(),
            slivers: [
              SliverAppBar(
                backgroundColor: AppTheme.background,
                surfaceTintColor: Colors.transparent,
                leading: IconButton(
                  icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 20),
                  onPressed: () => Navigator.pop(context),
                ),
                title: Text(
                  playlist.name,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                centerTitle: true,
                actions: [
                  IconButton(
                    icon: const Icon(Icons.delete_outline_rounded, color: Colors.redAccent),
                    onPressed: () => _deletePlaylist(context),
                  ),
                  const SizedBox(width: 8),
                ],
                pinned: true,
                elevation: 0,
              ),
              if (playlist.songs.isEmpty)
                SliverFillRemaining(
                  child: Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.music_note_rounded,
                          size: 72,
                          color: AppTheme.textSecondary.withValues(alpha: 0.3),
                        ),
                        const SizedBox(height: 16),
                        const Text(
                          'No songs in this playlist',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w600,
                            color: AppTheme.textSecondary,
                          ),
                        ),
                        const SizedBox(height: 8),
                        const Text(
                          'Add songs by searching',
                          style: TextStyle(
                            fontSize: 14,
                            color: AppTheme.textSecondary,
                          ),
                        ),
                        const SizedBox(height: 24),
                        ElevatedButton(
                          onPressed: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => const SearchScreen(),
                              ),
                            );
                          },
                          child: const Text('Search Songs'),
                        ),
                      ],
                    ),
                  ),
                )
              else ...[
                SliverToBoxAdapter(
                  child: Column(
                    children: [
                      const SizedBox(height: 24),
                      Container(
                        width: 180,
                        height: 180,
                        decoration: BoxDecoration(
                          color: AppTheme.surface,
                          borderRadius: BorderRadius.circular(24),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.3),
                              blurRadius: 32,
                              offset: const Offset(0, 12),
                            ),
                          ],
                        ),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(24),
                          child: playlist.coverUrl != null
                              ? Image.network(
                                  playlist.coverUrl!,
                                  fit: BoxFit.cover,
                                  errorBuilder: (_, __, ___) => const Icon(
                                    Icons.music_note_rounded,
                                    color: AppTheme.accent,
                                    size: 80,
                                  ),
                                )
                              : const Icon(
                                  Icons.music_note_rounded,
                                  color: AppTheme.accent,
                                  size: 80,
                                ),
                        ),
                      ),
                      const SizedBox(height: 20),
                      Text(
                        playlist.name,
                        style: const TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.w800,
                          color: AppTheme.textPrimary,
                          letterSpacing: -0.5,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        '${playlist.songCount} track${playlist.songCount == 1 ? '' : 's'}',
                        style: const TextStyle(
                          fontSize: 14,
                          color: AppTheme.textSecondary,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      const SizedBox(height: 24),
                    ],
                  ),
                ),
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
                    child: Row(
                      children: [
                        Expanded(
                          child: _ActionButton(
                            label: 'Play All',
                            icon: Icons.play_arrow_rounded,
                            filled: true,
                            onTap: () {
                              audioHandler.playSong(
                                playlist.songs.first,
                                playlist: playlist.songs,
                              );
                            },
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: _ActionButton(
                            label: 'Shuffle',
                            icon: Icons.shuffle_rounded,
                            filled: false,
                            onTap: () {
                              final shuffled = List<Song>.from(playlist.songs)..shuffle(Random());
                              audioHandler.playSong(
                                shuffled.first,
                                playlist: shuffled,
                              );
                            },
                          ),
                        ),
                        const SizedBox(width: 12),
                        GestureDetector(
                          onTap: () {
                            DownloadService().downloadPlaylist(playlist.songs, playlist.id);
                          },
                          child: Container(
                            width: 46,
                            height: 46,
                            decoration: BoxDecoration(
                              color: AppTheme.surface,
                              borderRadius: BorderRadius.circular(50),
                              border: Border.all(
                                color: AppTheme.textSecondary.withValues(alpha: 0.3),
                              ),
                            ),
                            child: const Center(
                              child: Icon(
                                Icons.download_rounded,
                                color: Color(0xFFD97757),
                                size: 22,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                SliverToBoxAdapter(
                  child: _DownloadProgressCard(batchId: playlist.id),
                ),
                SliverPadding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  sliver: SliverReorderableList(
                    itemBuilder: (context, index) {
                      final song = playlist.songs[index];
                      return _PlaylistSongTile(
                        key: ValueKey(song.id),
                        song: song,
                        index: index,
                        playlistId: playlist.id,
                        onTap: () {
                          audioHandler.playSong(
                            song,
                            playlist: playlist.songs,
                          );
                        },
                      );
                    },
                    itemCount: playlist.songs.length,
                    onReorder: (oldIndex, newIndex) {
                      if (newIndex > oldIndex) newIndex -= 1;
                      final songs = List<Song>.from(playlist.songs);
                      final item = songs.removeAt(oldIndex);
                      songs.insert(newIndex, item);
                      PlaylistService().reorderSongs(playlist.id, songs);
                    },
                  ),
                ),
                const SliverToBoxAdapter(child: SizedBox(height: 100)),
              ],
            ],
          );
        },
      ),
      bottomNavigationBar: const MiniPlayer(),
    );
  }
}

class _ActionButton extends StatelessWidget {
  final String label;
  final IconData icon;
  final bool filled;
  final VoidCallback onTap;

  const _ActionButton({
    required this.label,
    required this.icon,
    required this.filled,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: 46,
        decoration: BoxDecoration(
          color: filled ? AppTheme.accent : Colors.transparent,
          borderRadius: BorderRadius.circular(50),
          border: filled
              ? null
              : Border.all(
                  color: AppTheme.textSecondary.withValues(alpha: 0.3),
                ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              icon,
              size: 20,
              color: filled ? AppTheme.background : AppTheme.textSecondary,
            ),
            const SizedBox(width: 6),
            Text(
              label,
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: filled ? AppTheme.background : AppTheme.textSecondary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PlaylistSongTile extends StatelessWidget {
  final Song song;
  final int index;
  final String playlistId;
  final VoidCallback onTap;

  const _PlaylistSongTile({
    super.key,
    required this.song,
    required this.index,
    required this.playlistId,
    required this.onTap,
  });

  void _showContextMenu(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (_) => Container(
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
              leading: const Icon(Icons.delete_outline_rounded, color: Colors.redAccent),
              title: const Text('Remove from Playlist', style: TextStyle(color: AppTheme.textPrimary)),
              onTap: () {
                Navigator.pop(context);
                PlaylistService().removeSongFromPlaylist(playlistId, song.id);
              },
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 2),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(12),
          onLongPress: () => _showContextMenu(context),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 10),
            child: Row(
              children: [
                SizedBox(
                  width: 28,
                  child: Text(
                    '${index + 1}',
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontSize: 13,
                      color: AppTheme.textSecondary,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: song.imageMedium.isNotEmpty
                      ? Image.network(
                          song.imageMedium,
                          width: 48,
                          height: 48,
                          fit: BoxFit.cover,
                          errorBuilder: (_, __, ___) => _fallbackArt(song.name),
                        )
                      : _fallbackArt(song.name),
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
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: AppTheme.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 3),
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
                _SongDownloadButton(song: song),
                const SizedBox(width: 8),
                GestureDetector(
                  onTap: () => PlaylistService().removeSongFromPlaylist(playlistId, song.id),
                  child: const Padding(
                    padding: EdgeInsets.all(8),
                    child: Icon(
                      Icons.remove_circle_outline_rounded,
                      color: AppTheme.textSecondary,
                      size: 20,
                    ),
                  ),
                ),
                ReorderableDragStartListener(
                  index: index,
                  child: const Padding(
                    padding: EdgeInsets.all(8),
                    child: Icon(
                      Icons.drag_handle_rounded,
                      color: AppTheme.textSecondary,
                      size: 20,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _fallbackArt(String name) {
    return Container(
      width: 48,
      height: 48,
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Center(
        child: Text(
          name.isNotEmpty ? name[0].toUpperCase() : '?',
          style: const TextStyle(
            color: AppTheme.accent,
            fontWeight: FontWeight.w700,
            fontSize: 18,
          ),
        ),
      ),
    );
  }
}

class _SongDownloadButton extends StatelessWidget {
  final Song song;
  const _SongDownloadButton({required this.song});

  @override
  Widget build(BuildContext context) {
    final ds = DownloadService();
    return ValueListenableBuilder<Set<String>>(
      valueListenable: ds.downloadedSongIdsNotifier,
      builder: (context, downloadedIds, _) {
        final isDownloaded = downloadedIds.contains(song.id);
        if (isDownloaded) {
          return IconButton(
            icon: const Icon(Icons.check_rounded, color: Color(0xFFD97757), size: 20),
            onPressed: () {
              showDialog(
                context: context,
                builder: (context) => AlertDialog(
                  backgroundColor: AppTheme.surface,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  title: const Text('Delete Download', style: TextStyle(color: AppTheme.textPrimary)),
                  content: Text('Delete "${song.name}" from your local storage?', style: const TextStyle(color: AppTheme.textSecondary)),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.pop(context),
                      child: const Text('Cancel', style: TextStyle(color: AppTheme.textSecondary)),
                    ),
                    TextButton(
                      onPressed: () {
                        Navigator.pop(context);
                        ds.deleteSong(song.id);
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
            final taskIndex = queue.indexWhere((t) => t.song.id == song.id);
            if (taskIndex != -1) {
              final task = queue[taskIndex];
              return ValueListenableBuilder<Map<String, double>>(
                valueListenable: ds.progressNotifier,
                builder: (context, progressMap, _) {
                  final progress = progressMap[song.id] ?? 0.0;
                  return GestureDetector(
                    onTap: () => ds.cancelSong(song.id),
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

class _DownloadProgressCard extends StatelessWidget {
  final String batchId;
  const _DownloadProgressCard({required this.batchId});

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
                        color: const Color(0xFF0E0D0C),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: const Color(0xFFD97757).withValues(alpha: 0.2),
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
                                  color: const Color(0xFFD97757),
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
                                Color(0xFFD97757),
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
