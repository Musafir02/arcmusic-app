import 'dart:math';
import 'package:flutter/material.dart';
import '../core/liked_service.dart';
import '../core/player_service.dart';
import '../core/theme.dart';
import '../core/download_service.dart';
import '../models/song.dart';
import 'playlist_song_picker.dart';
import '../widgets/mini_player.dart';

class LikedScreen extends StatelessWidget {
  const LikedScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.background,
      body: ValueListenableBuilder<List<Song>>(
        valueListenable: LikedService().likedNotifier,
        builder: (context, songs, _) {
          return CustomScrollView(
            physics: const BouncingScrollPhysics(),
            slivers: [
              _LikedAppBar(songCount: songs.length, songs: songs),
              if (songs.isEmpty)
                const SliverFillRemaining(
                  child: _EmptyLikedState(),
                )
              else ...[
                _LikedHeroHeader(songs: songs),
                _LikedActionRow(songs: songs),
                const SliverToBoxAdapter(
                  child: _DownloadProgressCard(batchId: 'liked'),
                ),
                SliverPadding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  sliver: SliverList(
                    delegate: SliverChildBuilderDelegate(
                      (context, index) {
                        final song = songs[index];
                        return _LikedSongTile(
                          song: song,
                          index: index,
                          onTap: () => audioHandler.playSong(
                            song,
                            playlist: songs,
                          ),
                          onUnlike: () => LikedService().unlike(song.id),
                        );
                      },
                      childCount: songs.length,
                    ),
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

class _LikedAppBar extends StatelessWidget {
  final int songCount;
  final List<Song> songs;

  const _LikedAppBar({required this.songCount, required this.songs});

  @override
  Widget build(BuildContext context) {
    return SliverAppBar(
      backgroundColor: AppTheme.background,
      surfaceTintColor: Colors.transparent,
      leading: IconButton(
        icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 20),
        color: AppTheme.textPrimary,
        onPressed: () => Navigator.pop(context),
      ),
      title: const Text(
        'Liked Songs',
        style: TextStyle(
          color: AppTheme.textPrimary,
          fontWeight: FontWeight.w700,
          fontSize: 18,
        ),
      ),
      centerTitle: true,
      pinned: true,
      elevation: 0,
    );
  }
}

class _LikedHeroHeader extends StatelessWidget {
  final List<Song> songs;
  const _LikedHeroHeader({required this.songs});

  @override
  Widget build(BuildContext context) {
    return SliverToBoxAdapter(
      child: Column(
        children: [
          const SizedBox(height: 24),
          Container(
            width: 180,
            height: 180,
            decoration: BoxDecoration(
              color: AppTheme.accent,
              borderRadius: BorderRadius.circular(24),
              boxShadow: [
                BoxShadow(
                  color: AppTheme.accent.withValues(alpha: 0.4),
                  blurRadius: 32,
                  offset: const Offset(0, 12),
                ),
              ],
            ),
            child: const Icon(
              Icons.favorite_rounded,
              color: AppTheme.background,
              size: 80,
            ),
          ),
          const SizedBox(height: 20),
          const Text(
            'Your Liked Songs',
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.w800,
              color: AppTheme.textPrimary,
              letterSpacing: -0.5,
            ),
          ),
          const SizedBox(height: 6),
          ValueListenableBuilder<List<Song>>(
            valueListenable: LikedService().likedNotifier,
            builder: (_, s, __) => Text(
              '${s.length} track${s.length == 1 ? '' : 's'}',
              style: const TextStyle(
                fontSize: 14,
                color: AppTheme.textSecondary,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          const SizedBox(height: 24),
        ],
      ),
    );
  }
}

class _LikedActionRow extends StatelessWidget {
  final List<Song> songs;
  const _LikedActionRow({required this.songs});

  @override
  Widget build(BuildContext context) {
    return SliverToBoxAdapter(
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
                  if (songs.isNotEmpty) {
                    audioHandler.playSong(songs.first, playlist: songs);
                  }
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
                  if (songs.isNotEmpty) {
                    final shuffled = List<Song>.from(songs)..shuffle(Random());
                    audioHandler.playSong(shuffled.first, playlist: shuffled);
                  }
                },
              ),
            ),
            const SizedBox(width: 12),
            GestureDetector(
              onTap: () {
                DownloadService().downloadPlaylist(songs, 'liked');
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
    );
  }
}

class _LikedSongTile extends StatelessWidget {
  final Song song;
  final int index;
  final VoidCallback onTap;
  final VoidCallback onUnlike;

  const _LikedSongTile({
    required this.song,
    required this.index,
    required this.onTap,
    required this.onUnlike,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 2),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(12),
          onLongPress: () => _showContextMenu(context, song),
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
                          errorBuilder: (_, __, ___) =>
                              _fallbackArt(song.name),
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
                  onTap: onUnlike,
                  child: const Padding(
                    padding: EdgeInsets.all(8),
                    child: Icon(
                      Icons.favorite_rounded,
                      color: AppTheme.accent,
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

  void _showContextMenu(BuildContext context, Song song) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (_) => _SongContextSheet(song: song),
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

class _EmptyLikedState extends StatelessWidget {
  const _EmptyLikedState();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.favorite_border_rounded,
            size: 72,
            color: AppTheme.textSecondary.withValues(alpha: 0.3),
          ),
          const SizedBox(height: 16),
          const Text(
            'No liked songs yet',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w600,
              color: AppTheme.textSecondary,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'Tap ♡ on any song to save it here',
            style: TextStyle(
              fontSize: 14,
              color: AppTheme.textSecondary,
            ),
          ),
        ],
      ),
    );
  }
}

class _SongContextSheet extends StatelessWidget {
  final Song song;
  const _SongContextSheet({required this.song});

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
            leading: const Icon(Icons.play_arrow_rounded,
                color: AppTheme.accent),
            title: const Text('Play Now',
                style: TextStyle(color: AppTheme.textPrimary)),
            onTap: () {
              Navigator.pop(context);
              audioHandler.playSong(song);
            },
          ),
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: const Icon(Icons.playlist_add_rounded,
                color: AppTheme.textSecondary),
            title: const Text('Add to Playlist',
                style: TextStyle(color: AppTheme.textPrimary)),
            onTap: () async {
              Navigator.pop(context);
              await showSongPicker(context, [song]);
            },
          ),
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: const Icon(Icons.favorite_border_rounded,
                color: AppTheme.textSecondary),
            title: const Text('Remove from Liked',
                style: TextStyle(color: AppTheme.textPrimary)),
            onTap: () {
              Navigator.pop(context);
              LikedService().unlike(song.id);
            },
          ),
        ],
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
