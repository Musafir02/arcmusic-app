import 'package:flutter/material.dart';
import '../core/user_data_service.dart';
import '../core/theme.dart';

Future<void> showSongPicker(BuildContext context, List<Map<String, dynamic>> songs) async {
  if (songs.isEmpty) return;
  await showModalBottomSheet(
    context: context,
    backgroundColor: Colors.transparent,
    isScrollControlled: true,
    builder: (context) => _SongPickerSheet(songs: songs),
  );
}

class _SongPickerSheet extends StatefulWidget {
  final List<Map<String, dynamic>> songs;
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
      builder: (context) => AlertDialog(
        backgroundColor: AppTheme.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppTheme.radiusCard)),
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
      final playlist = await UserDataService().createPlaylist(name);
      for (final song in widget.songs) {
        await UserDataService().addSongToPlaylist(playlist['id'] as String, song);
      }
      if (mounted && context.mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Added to $name', style: const TextStyle(color: AppTheme.background, fontWeight: FontWeight.bold)),
            backgroundColor: AppTheme.accent,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (e) {
      if (mounted && context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: $e', style: const TextStyle(color: AppTheme.background, fontWeight: FontWeight.bold)),
            backgroundColor: AppTheme.accent,
            behavior: SnackBarBehavior.floating,
          ),
        );
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
    return Container(
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.vertical(top: Radius.circular(AppTheme.radiusSheet)),
      ),
      padding: EdgeInsets.fromLTRB(24, 12, 24, MediaQuery.of(context).viewInsets.bottom + 32),
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
          const Text('Add to Playlist', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: AppTheme.textPrimary)),
          const SizedBox(height: 16),
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: AppTheme.accent.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(AppTheme.radiusDefault),
              ),
              child: const Icon(Icons.add_rounded, color: AppTheme.accent),
            ),
            title: const Text('Create Playlist', style: TextStyle(color: AppTheme.accent, fontWeight: FontWeight.w600)),
            onTap: () => _createNewPlaylist(context),
          ),
          const Divider(color: AppTheme.background, height: 24),
          ConstrainedBox(
            constraints: const BoxConstraints(maxHeight: 300),
            child: ValueListenableBuilder<List<Map<String, dynamic>>>(
              valueListenable: UserDataService().playlistsNotifier,
              builder: (context, playlists, _) {
                if (playlists.isEmpty) {
                  return const Padding(
                    padding: EdgeInsets.symmetric(vertical: 24),
                    child: Center(child: Text('No playlists yet', style: TextStyle(color: AppTheme.textSecondary))),
                  );
                }

                return ListView.builder(
                  shrinkWrap: true,
                  itemCount: playlists.length,
                  itemBuilder: (context, index) {
                    final playlist = playlists[index];
                    final List playlistSongs = playlist['songs'] ?? [];
                    final cover = _getPlaylistCover(playlist);

                    return ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: cover != null
                            ? Image.network(cover, width: 48, height: 48, fit: BoxFit.cover)
                            : Container(
                                width: 48,
                                height: 48,
                                color: AppTheme.background,
                                child: const Icon(Icons.music_note_rounded, color: AppTheme.textSecondary),
                              ),
                      ),
                      title: Text(
                        playlist['name'] as String? ?? '',
                        style: const TextStyle(color: AppTheme.textPrimary, fontWeight: FontWeight.w600),
                      ),
                      subtitle: Text(
                        '${playlistSongs.length} song${playlistSongs.length == 1 ? '' : 's'}',
                        style: const TextStyle(color: AppTheme.textSecondary),
                      ),
                      onTap: () async {
                        for (final song in widget.songs) {
                          await UserDataService().addSongToPlaylist(playlist['id'] as String, song);
                        }
                        if (context.mounted) {
                          Navigator.pop(context);
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text('Added to ${playlist['name']}', style: const TextStyle(color: AppTheme.background, fontWeight: FontWeight.bold)),
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
