import 'dart:math';
import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../core/user_data_service.dart';
import '../core/player_service.dart';
import '../core/theme.dart';
import '../core/download_service.dart';
import 'search_screen.dart';
import '../widgets/mini_player.dart';
import '../widgets/common_components.dart';
import '../widgets/download_progress_card.dart';
import '../widgets/song_tile.dart';
import '../models/song.dart';

class PlaylistDetailScreen extends StatefulWidget {
  final String playlistId;
  const PlaylistDetailScreen({super.key, required this.playlistId});

  @override
  State<PlaylistDetailScreen> createState() => _PlaylistDetailScreenState();
}

class _PlaylistDetailScreenState extends State<PlaylistDetailScreen> {
  Future<void> _deletePlaylist(BuildContext context) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppTheme.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Delete Playlist', style: TextStyle(color: AppTheme.textPrimary)),
        content: const Text('Are you sure you want to delete this playlist? This action cannot be undone.', style: TextStyle(color: AppTheme.textSecondary)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel', style: TextStyle(color: AppTheme.textSecondary)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Delete', style: TextStyle(color: Colors.redAccent)),
          ),
        ],
      ),
    );

    if (confirm == true) {
      await UserDataService().deletePlaylist(widget.playlistId);
      if (context.mounted) {
        Navigator.pop(context);
      }
    }
  }

  String? _getPlaylistCover(Map<String, dynamic> playlist) {
    final List songs = playlist['songs'] ?? [];
    for (final s in songs) {
      if (s is Map) {
        final img = s['imageLarge'] as String? ?? '';
        if (img.isNotEmpty) return img;
        final imgMed = s['image'] as String? ?? '';
        if (imgMed.isNotEmpty) return imgMed;
      }
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final uds = UserDataService();
    return Scaffold(
      backgroundColor: AppTheme.background,
      body: ValueListenableBuilder<List<Map<String, dynamic>>>(
        valueListenable: uds.playlistsNotifier,
        builder: (context, playlists, _) {
          final playlistIndex = playlists.indexWhere((p) => p['id'] == widget.playlistId);
          if (playlistIndex == -1) {
            return Scaffold(
              backgroundColor: AppTheme.background,
              appBar: AppBar(
                backgroundColor: AppTheme.background,
                leading: IconButton(
                  icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 20),
                  onPressed: () => Navigator.pop(context),
                ),
              ),
              body: const Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.playlist_remove_rounded, size: 64, color: AppTheme.textSecondary),
                    SizedBox(height: 16),
                    Text('Playlist not found', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600, color: AppTheme.textSecondary)),
                  ],
                ),
              ),
            );
          }

          final playlist = playlists[playlistIndex];
          final List songsRaw = playlist['songs'] ?? [];
          final songs = songsRaw.whereType<Map>().map((e) => Song.fromJson(Map<String, dynamic>.from(e))).toList();
          final cover = _getPlaylistCover(playlist);
          final pId = playlist['id'] as String;

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
                title: Text(playlist['name'] as String? ?? '', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
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
              if (songs.isEmpty)
                SliverFillRemaining(
                  child: Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.music_note_rounded, size: 72, color: AppTheme.textSecondary.withValues(alpha: 0.3)),
                        const SizedBox(height: 16),
                        const Text('No songs in this playlist', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600, color: AppTheme.textSecondary)),
                        const SizedBox(height: 8),
                        const Text('Add songs by searching', style: TextStyle(fontSize: 14, color: AppTheme.textSecondary)),
                        const SizedBox(height: 24),
                        ElevatedButton(
                          onPressed: () {
                            Navigator.push(context, MaterialPageRoute(builder: (_) => const SearchScreen()));
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
                          borderRadius: BorderRadius.circular(AppTheme.radiusCard),
                          boxShadow: [
                            BoxShadow(color: Colors.black.withValues(alpha: 0.3), blurRadius: 32, offset: const Offset(0, 12)),
                          ],
                        ),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(AppTheme.radiusCard),
                          child: cover != null
                              ? CachedNetworkImage(imageUrl: cover, fit: BoxFit.cover, errorWidget: (_, __, ___) => const Icon(Icons.music_note_rounded, color: AppTheme.accent, size: 80))
                              : const Icon(Icons.music_note_rounded, color: AppTheme.accent, size: 80),
                        ),
                      ),
                      const SizedBox(height: 20),
                      Text(
                        playlist['name'] as String? ?? '',
                        style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w800, color: AppTheme.textPrimary, letterSpacing: -0.5),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        '${songs.length} track${songs.length == 1 ? '' : 's'}',
                        style: const TextStyle(fontSize: 14, color: AppTheme.textSecondary, fontWeight: FontWeight.w500),
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
                          child: ActionButton(
                            label: 'Play All',
                            icon: Icons.play_arrow_rounded,
                            filled: true,
                            onTap: () {
                              audioHandler.playSong(songs.first, playlist: songs);
                            },
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: ActionButton(
                            label: 'Shuffle',
                            icon: Icons.shuffle_rounded,
                            filled: false,
                            onTap: () {
                              final shuffled = List<Song>.from(songs)..shuffle(Random());
                              audioHandler.playSong(shuffled.first, playlist: shuffled);
                            },
                          ),
                        ),
                        const SizedBox(width: 12),
                        GestureDetector(
                          onTap: () => DownloadService().downloadPlaylist(songs, pId),
                          child: Container(
                            width: AppTheme.actionButtonHeight,
                            height: AppTheme.actionButtonHeight,
                            decoration: BoxDecoration(
                              color: AppTheme.surface,
                              borderRadius: BorderRadius.circular(50),
                              border: Border.all(color: AppTheme.textSecondary.withValues(alpha: 0.3)),
                            ),
                            child: const Center(
                              child: Icon(Icons.download_rounded, color: AppTheme.accent, size: 22),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                SliverToBoxAdapter(child: DownloadProgressCard(batchId: pId)),
                SliverPadding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  sliver: SliverReorderableList(
                    itemBuilder: (context, index) {
                      final song = songs[index];
                      return SongTile(
                        key: ValueKey(song.id),
                        song: song,
                        index: index,
                        onTap: () => audioHandler.playSong(song, playlist: songs),
                        onRemove: () => uds.removeSongFromPlaylist(pId, song.id),
                      );
                    },
                    itemCount: songs.length,
                    onReorder: (oldIndex, newIndex) {
                      if (newIndex > oldIndex) newIndex -= 1;
                      final reorderedSongs = List<Song>.from(songs);
                      final item = reorderedSongs.removeAt(oldIndex);
                      reorderedSongs.insert(newIndex, item);
                      uds.reorderSongs(pId, reorderedSongs);
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
