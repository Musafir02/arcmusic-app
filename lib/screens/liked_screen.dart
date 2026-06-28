import 'dart:math';
import 'package:flutter/material.dart';
import '../core/player_service.dart';
import '../core/theme.dart';
import '../core/download_service.dart';
import '../core/user_data_service.dart';
import '../widgets/mini_player.dart';
import '../widgets/song_tile.dart';
import '../widgets/common_components.dart';
import '../widgets/download_progress_card.dart';
import '../models/song.dart';

class LikedScreen extends StatelessWidget {
  const LikedScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.background,
      body: ValueListenableBuilder<List<Song>>(
        valueListenable: UserDataService().likedNotifier,
        builder: (context, songs, _) {
          return CustomScrollView(
            physics: const BouncingScrollPhysics(),
            slivers: [
              _LikedAppBar(songs: songs),
              if (songs.isEmpty)
                const SliverFillRemaining(
                  child: EmptyStateView(
                    icon: Icons.favorite_border_rounded,
                    message: 'No liked songs yet.\nTap ♡ on any song to save it here.',
                  ),
                )
              else ...[
                _LikedHeroHeader(songs: songs),
                _LikedActionRow(songs: songs),
                const SliverToBoxAdapter(
                  child: DownloadProgressCard(batchId: 'liked'),
                ),
                SliverPadding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  sliver: SliverList(
                    delegate: SliverChildBuilderDelegate(
                      (context, index) {
                        final song = songs[index];
                        return SongTile(
                          song: song,
                          index: index,
                          onTap: () => audioHandler.playSong(song, playlist: songs),
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
  final List<Song> songs;
  const _LikedAppBar({required this.songs});

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
        style: TextStyle(color: AppTheme.textPrimary, fontWeight: FontWeight.w700, fontSize: 18),
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
              borderRadius: BorderRadius.circular(AppTheme.radiusCard),
              boxShadow: [
                BoxShadow(
                  color: AppTheme.accent.withValues(alpha: 0.4),
                  blurRadius: 32,
                  offset: const Offset(0, 12),
                ),
              ],
            ),
            child: const Icon(Icons.favorite_rounded, color: AppTheme.background, size: 80),
          ),
          const SizedBox(height: 20),
          const Text(
            'Your Liked Songs',
            style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800, color: AppTheme.textPrimary, letterSpacing: -0.5),
          ),
          const SizedBox(height: 6),
          Text(
            '${songs.length} track${songs.length == 1 ? '' : 's'}',
            style: const TextStyle(fontSize: 14, color: AppTheme.textSecondary, fontWeight: FontWeight.w500),
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
              child: ActionButton(
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
              child: ActionButton(
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
              onTap: () => DownloadService().downloadPlaylist(songs, 'liked'),
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
    );
  }
}
