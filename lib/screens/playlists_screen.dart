import 'package:flutter/material.dart';
import '../core/user_data_service.dart';
import '../core/theme.dart';
import '../core/notifications.dart';
import 'playlist_detail_screen.dart';
import 'spotify_import_sheet.dart';
import '../widgets/mini_player.dart';

class PlaylistsScreen extends StatefulWidget {
  const PlaylistsScreen({super.key});

  @override
  State<PlaylistsScreen> createState() => _PlaylistsScreenState();
}

class _PlaylistsScreenState extends State<PlaylistsScreen> {
  final TextEditingController _controller = TextEditingController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _showCreateDialog(BuildContext context) async {
    final name = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppTheme.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('New Playlist', style: TextStyle(color: AppTheme.textPrimary)),
        content: TextField(
          controller: _controller,
          autofocus: true,
          style: const TextStyle(color: AppTheme.textPrimary),
          cursorColor: AppTheme.accent,
          decoration: InputDecoration(
            hintText: 'Enter playlist name',
            hintStyle: TextStyle(color: AppTheme.textSecondary.withValues(alpha: 0.5)),
            enabledBorder: const UnderlineInputBorder(borderSide: BorderSide(color: AppTheme.textSecondary)),
            focusedBorder: const UnderlineInputBorder(borderSide: BorderSide(color: AppTheme.accent)),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel', style: TextStyle(color: AppTheme.textSecondary)),
          ),
          TextButton(
            onPressed: () {
              final val = _controller.text.trim();
              Navigator.pop(context, val.isNotEmpty ? val : null);
            },
            child: const Text('Create', style: TextStyle(color: AppTheme.accent)),
          ),
        ],
      ),
    );

    _controller.clear();
    if (name == null) return;

    try {
      await UserDataService().createPlaylist(name);
    } catch (e) {
      if (!context.mounted) return;
      AppNotifications.show('Error creating playlist: $e');
    }
  }

  void _showSpotifyImportFlow(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      isDismissible: true,
      builder: (_) => SpotifyImportSheet(
        onImported: (playlistId) {
          if (context.mounted) {
            Navigator.push(
              context,
              PageRouteBuilder(
                pageBuilder: (_, __, ___) => PlaylistDetailScreen(playlistId: playlistId),
                transitionsBuilder: (_, anim, __, child) => FadeTransition(opacity: anim, child: child),
                transitionDuration: const Duration(milliseconds: 200),
              ),
            );
          }
        },
      ),
    );
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
    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        backgroundColor: AppTheme.background,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 20),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text('Playlists', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
        centerTitle: true,
        actions: [
          Tooltip(
            message: 'Import from Spotify',
            child: GestureDetector(
              onTap: () => _showSpotifyImportFlow(context),
              child: Container(
                margin: const EdgeInsets.only(right: 16),
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: AppTheme.accent.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: AppTheme.accent.withValues(alpha: 0.3), width: 1),
                ),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.queue_music_rounded, color: AppTheme.accent, size: 16),
                    SizedBox(width: 6),
                    Text('Import', style: TextStyle(color: AppTheme.accent, fontSize: 13, fontWeight: FontWeight.w700)),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
      body: ValueListenableBuilder<List<Map<String, dynamic>>>(
        valueListenable: UserDataService().playlistsNotifier,
        builder: (context, playlists, _) {
          return GridView.builder(
            padding: const EdgeInsets.all(16),
            physics: const BouncingScrollPhysics(),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              crossAxisSpacing: 14,
              mainAxisSpacing: 16,
              childAspectRatio: 0.78,
            ),
            itemCount: playlists.length + 1,
            itemBuilder: (context, index) {
              if (index == 0) {
                return _CreatePlaylistCard(onTap: () => _showCreateDialog(context));
              }
              final playlist = playlists[index - 1];
              final cover = _getPlaylistCover(playlist);
              final List songs = playlist['songs'] ?? [];

              return _PlaylistCard(
                playlist: playlist,
                cover: cover,
                songCount: songs.length,
                onTap: () {
                  Navigator.push(
                    context,
                    PageRouteBuilder(
                      pageBuilder: (_, __, ___) => PlaylistDetailScreen(playlistId: playlist['id'] as String),
                      transitionsBuilder: (_, anim, __, child) => FadeTransition(opacity: anim, child: child),
                      transitionDuration: const Duration(milliseconds: 200),
                    ),
                  );
                },
              );
            },
          );
        },
      ),
      bottomNavigationBar: const MiniPlayer(),
    );
  }
}

class _CreatePlaylistCard extends StatelessWidget {
  final VoidCallback onTap;
  const _CreatePlaylistCard({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          color: AppTheme.surface.withValues(alpha: 0.3),
          borderRadius: BorderRadius.circular(AppTheme.radiusCard),
          border: Border.all(color: AppTheme.textSecondary.withValues(alpha: 0.15), width: 1.5),
        ),
        child: const Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.add_rounded, color: AppTheme.accent, size: 40),
            SizedBox(height: 12),
            Text('Create Playlist', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: AppTheme.accent)),
            SizedBox(height: 4),
            Text('Add new folder', style: TextStyle(fontSize: 12, color: AppTheme.textSecondary)),
          ],
        ),
      ),
    );
  }
}

class _PlaylistCard extends StatelessWidget {
  final Map<String, dynamic> playlist;
  final String? cover;
  final int songCount;
  final VoidCallback onTap;

  const _PlaylistCard({required this.playlist, this.cover, required this.songCount, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Container(
              width: double.infinity,
              decoration: BoxDecoration(
                color: AppTheme.surface,
                borderRadius: BorderRadius.circular(AppTheme.radiusCard),
                boxShadow: [AppTheme.cardShadow],
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(AppTheme.radiusCard),
                child: cover != null
                    ? Image.network(cover!, fit: BoxFit.cover, errorBuilder: (_, __, ___) => _fallbackCover())
                    : _fallbackCover(),
              ),
            ),
          ),
          const SizedBox(height: 10),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  playlist['name'] as String? ?? '',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: AppTheme.textPrimary),
                ),
                const SizedBox(height: 2),
                Text(
                  '$songCount song${songCount == 1 ? '' : 's'}',
                  style: const TextStyle(fontSize: 12, color: AppTheme.textSecondary),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _fallbackCover() => Container(
        color: AppTheme.surface,
        child: const Center(
          child: Icon(Icons.music_note_rounded, color: AppTheme.accent, size: 44),
        ),
      );
}
