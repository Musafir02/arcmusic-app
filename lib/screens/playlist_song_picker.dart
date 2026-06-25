import 'package:flutter/material.dart';
import '../core/playlist_service.dart';
import '../core/theme.dart';
import '../models/playlist.dart';
import '../models/song.dart';

Future<void> showSongPicker(BuildContext context, List<Song> songs) async {
  if (songs.isEmpty) return;

  await showModalBottomSheet(
    context: context,
    backgroundColor: Colors.transparent,
    isScrollControlled: true,
    builder: (context) {
      return _SongPickerSheet(songs: songs);
    },
  );
}

class _SongPickerSheet extends StatefulWidget {
  final List<Song> songs;
  const _SongPickerSheet({required this.songs});

  @override
  State<_SongPickerSheet> createState() => _SongPickerSheetState();
}

class _SongPickerSheetState extends State<_SongPickerSheet> {
  final TextEditingController _controller = TextEditingController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _createNewPlaylist(BuildContext context) async {
    final name = await showDialog<String>(
      context: context,
      builder: (context) {
        return AlertDialog(
          backgroundColor: AppTheme.surface,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          title: const Text(
            'New Playlist',
            style: TextStyle(color: AppTheme.textPrimary),
          ),
          content: TextField(
            controller: _controller,
            autofocus: true,
            style: const TextStyle(color: AppTheme.textPrimary),
            cursorColor: AppTheme.accent,
            decoration: InputDecoration(
              hintText: 'Enter playlist name',
              hintStyle: TextStyle(
                color: AppTheme.textSecondary.withValues(alpha: 0.5),
              ),
              enabledBorder: const UnderlineInputBorder(
                borderSide: BorderSide(color: AppTheme.textSecondary),
              ),
              focusedBorder: const UnderlineInputBorder(
                borderSide: BorderSide(color: AppTheme.accent),
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text(
                'Cancel',
                style: TextStyle(color: AppTheme.textSecondary),
              ),
            ),
            TextButton(
              onPressed: () {
                final val = _controller.text.trim();
                Navigator.pop(context, val.isNotEmpty ? val : null);
              },
              child: const Text(
                'Create',
                style: TextStyle(color: AppTheme.accent),
              ),
            ),
          ],
        );
      },
    );

    _controller.clear();

    if (name == null || !mounted) return;

    try {
      final playlist = await PlaylistService().createPlaylist(name);
      for (final song in widget.songs) {
        await PlaylistService().addSongToPlaylist(playlist.id, song);
      }
      if (!context.mounted) return;
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Added to $name',
            style: const TextStyle(color: AppTheme.background, fontWeight: FontWeight.bold),
          ),
          backgroundColor: AppTheme.accent,
          behavior: SnackBarBehavior.floating,
        ),
      );
    } catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Error: $e',
            style: const TextStyle(color: AppTheme.background, fontWeight: FontWeight.bold),
          ),
          backgroundColor: AppTheme.accent,
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      padding: EdgeInsets.fromLTRB(
        24,
        12,
        24,
        MediaQuery.of(context).viewInsets.bottom + 32,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Center(
            child: Container(
              width: 36,
              height: 4,
              margin: const EdgeInsets.only(bottom: 20),
              decoration: BoxDecoration(
                color: AppTheme.textSecondary.withValues(alpha: 0.3),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const Text(
            'Add to Playlist',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w700,
              color: AppTheme.textPrimary,
            ),
          ),
          const SizedBox(height: 16),
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: AppTheme.accent.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(Icons.add_rounded, color: AppTheme.accent),
            ),
            title: const Text(
              'Create Playlist',
              style: TextStyle(
                color: AppTheme.accent,
                fontWeight: FontWeight.w600,
              ),
            ),
            onTap: () => _createNewPlaylist(context),
          ),
          const Divider(color: AppTheme.background, height: 24),
          ConstrainedBox(
            constraints: const BoxConstraints(maxHeight: 300),
            child: ValueListenableBuilder<List<Playlist>>(
              valueListenable: PlaylistService().playlistsNotifier,
              builder: (context, playlists, _) {
                if (playlists.isEmpty) {
                  return const Padding(
                    padding: EdgeInsets.symmetric(vertical: 24),
                    child: Center(
                      child: Text(
                        'No playlists yet',
                        style: TextStyle(color: AppTheme.textSecondary),
                      ),
                    ),
                  );
                }
                return ListView.builder(
                  shrinkWrap: true,
                  itemCount: playlists.length,
                  itemBuilder: (context, index) {
                    final playlist = playlists[index];
                    return ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: playlist.coverUrl != null
                            ? Image.network(
                                playlist.coverUrl!,
                                width: 48,
                                height: 48,
                                fit: BoxFit.cover,
                              )
                            : Container(
                                width: 48,
                                height: 48,
                                color: AppTheme.background,
                                child: const Icon(
                                  Icons.music_note_rounded,
                                  color: AppTheme.textSecondary,
                                ),
                              ),
                      ),
                      title: Text(
                        playlist.name,
                        style: const TextStyle(
                          color: AppTheme.textPrimary,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      subtitle: Text(
                        '${playlist.songCount} song${playlist.songCount == 1 ? '' : 's'}',
                        style: const TextStyle(color: AppTheme.textSecondary),
                      ),
                      onTap: () async {
                        for (final song in widget.songs) {
                          await PlaylistService().addSongToPlaylist(
                            playlist.id,
                            song,
                          );
                        }
                        if (context.mounted) {
                          Navigator.pop(context);
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text(
                                'Added to ${playlist.name}',
                                style: const TextStyle(color: AppTheme.background, fontWeight: FontWeight.bold),
                              ),
                              backgroundColor: AppTheme.accent,
                              behavior: SnackBarBehavior.floating,
                            ),
                          );
                        }
                      },
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
