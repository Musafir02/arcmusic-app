import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../core/api_service.dart';
import '../core/playlist_service.dart';
import '../core/theme.dart';
import '../models/playlist.dart';
import '../models/song.dart';
import 'playlist_detail_screen.dart';
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
      await PlaylistService().createPlaylist(name);
    } catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Error creating playlist: $e',
            style: const TextStyle(
                color: AppTheme.background, fontWeight: FontWeight.bold),
          ),
          backgroundColor: AppTheme.accent,
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  void _showSpotifyImportFlow(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      isDismissible: true,
      builder: (_) => _SpotifyImportSheet(
        onImported: (playlistId) {
          if (!context.mounted) return;
          Navigator.push(
            context,
            PageRouteBuilder(
              pageBuilder: (_, __, ___) =>
                  PlaylistDetailScreen(playlistId: playlistId),
              transitionsBuilder: (_, anim, __, child) =>
                  FadeTransition(opacity: anim, child: child),
              transitionDuration: const Duration(milliseconds: 200),
            ),
          );
        },
      ),
    );
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
        title: const Text(
          'Playlists',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
        ),
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
                  color: const Color(0xFF1DB954).withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: const Color(0xFF1DB954).withValues(alpha: 0.3),
                    width: 1,
                  ),
                ),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.queue_music_rounded,
                        color: Color(0xFF1DB954), size: 16),
                    SizedBox(width: 6),
                    Text(
                      'Import',
                      style: TextStyle(
                        color: Color(0xFF1DB954),
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
      body: ValueListenableBuilder<List<Playlist>>(
        valueListenable: PlaylistService().playlistsNotifier,
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
                return _CreatePlaylistCard(
                  onTap: () => _showCreateDialog(context),
                );
              }
              final playlist = playlists[index - 1];
              return _PlaylistCard(
                playlist: playlist,
                onTap: () {
                  Navigator.push(
                    context,
                    PageRouteBuilder(
                      pageBuilder: (_, __, ___) =>
                          PlaylistDetailScreen(playlistId: playlist.id),
                      transitionsBuilder: (_, anim, __, child) =>
                          FadeTransition(opacity: anim, child: child),
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

enum _ImportStep { instructions, loading, done }

class _SpotifyImportSheet extends StatefulWidget {
  final void Function(String playlistId) onImported;
  const _SpotifyImportSheet({required this.onImported});

  @override
  State<_SpotifyImportSheet> createState() => _SpotifyImportSheetState();
}

class _SpotifyImportSheetState extends State<_SpotifyImportSheet> {
  final _urlController = TextEditingController();
  _ImportStep _step = _ImportStep.instructions;
  bool _cancelled = false;

  String _spotifyPlaylistName = '';
  String _spotifyOwner = '';
  int _totalTracks = 0;
  int _processedTracks = 0;
  int _matchedTracks = 0;
  final List<Song> _matchedSongs = [];
  String _currentTrackName = '';
  String? _errorMsg;
  String? _createdPlaylistId;

  @override
  void dispose() {
    _cancelled = true;
    _urlController.dispose();
    super.dispose();
  }

  bool _isValidSpotifyUrl(String url) =>
      url.contains('spotify.com/playlist/') ||
      url.contains('spotify:playlist:');

  Future<void> _startImport() async {
    final url = _urlController.text.trim();
    if (url.isEmpty) {
      setState(() => _errorMsg = 'Please paste a Spotify playlist link');
      return;
    }
    if (!_isValidSpotifyUrl(url)) {
      setState(
          () => _errorMsg = "That doesn't look like a Spotify playlist link");
      return;
    }

    setState(() {
      _step = _ImportStep.loading;
      _errorMsg = null;
      _cancelled = false;
      _matchedSongs.clear();
      _processedTracks = 0;
      _matchedTracks = 0;
      _currentTrackName = '';
    });

    final api = ApiService();

    SpotifyPlaylistResult result;
    try {
      result = (await api.fetchSpotifyPlaylist(url))!;
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _step = _ImportStep.instructions;
        _errorMsg = e.toString().replaceAll('Exception: ', '');
      });
      return;
    }

    if (!mounted || _cancelled) return;

    setState(() {
      _spotifyPlaylistName = result.name;
      _spotifyOwner = result.owner;
      _totalTracks = result.tracks.length;
    });

    Playlist playlist;
    try {
      playlist = await PlaylistService().createPlaylist(result.name);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _step = _ImportStep.instructions;
        _errorMsg = 'Could not create playlist: $e';
      });
      return;
    }

    _createdPlaylistId = playlist.id;

    for (final track in result.tracks) {
      if (_cancelled || !mounted) break;
      setState(
          () => _currentTrackName = '${track.name} — ${track.primaryArtist}');
      final song = await api.matchSpotifyTrack(track);
      if (!mounted || _cancelled) break;
      setState(() => _processedTracks++);
      if (song != null) {
        await PlaylistService().addSongToPlaylist(playlist.id, song);
        if (!mounted || _cancelled) break;
        setState(() {
          _matchedTracks++;
          _matchedSongs.insert(0, song);
          if (_matchedSongs.length > 60) _matchedSongs.removeLast();
        });
      }
    }

    if (!mounted) return;
    setState(() => _step = _ImportStep.done);
  }

  @override
  Widget build(BuildContext context) {
    final bottomPad = MediaQuery.of(context).viewInsets.bottom;
    return AnimatedPadding(
      padding: EdgeInsets.only(bottom: bottomPad),
      duration: const Duration(milliseconds: 200),
      child: Container(
        decoration: const BoxDecoration(
          color: AppTheme.surface,
          borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
        ),
        child: SafeArea(
          top: false,
          child: _step == _ImportStep.instructions
              ? _buildInstructions()
              : _step == _ImportStep.loading
                  ? _buildProgress()
                  : _buildDone(),
        ),
      ),
    );
  }

  Widget _handle() => Center(
        child: Container(
          width: 40,
          height: 4,
          margin: const EdgeInsets.only(top: 12, bottom: 4),
          decoration: BoxDecoration(
            color: AppTheme.textSecondary.withValues(alpha: 0.3),
            borderRadius: BorderRadius.circular(2),
          ),
        ),
      );

  Widget _buildInstructions() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 0, 24, 32),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _handle(),
          const SizedBox(height: 12),
          Row(
            children: [
              Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  color: const Color(0xFF1DB954).withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(Icons.queue_music_rounded,
                    color: Color(0xFF1DB954), size: 20),
              ),
              const SizedBox(width: 12),
              const Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Import from Spotify',
                    style: TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.w800,
                      color: AppTheme.textPrimary,
                    ),
                  ),
                  Text(
                    'Clone any public Spotify playlist',
                    style: TextStyle(
                        fontSize: 12, color: AppTheme.textSecondary),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 22),
          _stepRow('1', 'Open the playlist in Spotify'),
          const SizedBox(height: 12),
          _stepRow('2', 'Tap  ···  →  Share  →  Copy link to playlist'),
          const SizedBox(height: 12),
          _stepRow('3', 'Make sure the playlist is set to Public'),
          const SizedBox(height: 22),
          Container(
            decoration: BoxDecoration(
              color: AppTheme.background,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: _errorMsg != null
                    ? Colors.redAccent.withValues(alpha: 0.6)
                    : AppTheme.textSecondary.withValues(alpha: 0.2),
              ),
            ),
            child: Row(
              children: [
                const SizedBox(width: 14),
                const Icon(Icons.link_rounded,
                    color: AppTheme.textSecondary, size: 18),
                const SizedBox(width: 8),
                Expanded(
                  child: TextField(
                    controller: _urlController,
                    style: const TextStyle(
                        color: AppTheme.textPrimary, fontSize: 13),
                    cursorColor: const Color(0xFF1DB954),
                    onChanged: (_) {
                      if (_errorMsg != null) setState(() => _errorMsg = null);
                    },
                    decoration: InputDecoration(
                      hintText: 'Paste Spotify playlist link…',
                      hintStyle: TextStyle(
                        color: AppTheme.textSecondary.withValues(alpha: 0.5),
                        fontSize: 13,
                      ),
                      border: InputBorder.none,
                      contentPadding:
                          const EdgeInsets.symmetric(vertical: 14),
                    ),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.content_paste_rounded, size: 18),
                  color: AppTheme.textSecondary,
                  tooltip: 'Paste from clipboard',
                  onPressed: () async {
                    final data = await Clipboard.getData('text/plain');
                    if (data?.text != null) {
                      _urlController.text = data!.text!;
                      if (_errorMsg != null) setState(() => _errorMsg = null);
                    }
                  },
                ),
              ],
            ),
          ),
          if (_errorMsg != null) ...[
            const SizedBox(height: 8),
            Row(
              children: [
                const Icon(Icons.error_outline_rounded,
                    color: Colors.redAccent, size: 14),
                const SizedBox(width: 6),
                Text(
                  _errorMsg!,
                  style: const TextStyle(
                      color: Colors.redAccent, fontSize: 12),
                ),
              ],
            ),
          ],
          const SizedBox(height: 20),
          SizedBox(
            width: double.infinity,
            height: 50,
            child: ElevatedButton(
              onPressed: _startImport,
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF1DB954),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14)),
                elevation: 0,
              ),
              child: const Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.download_rounded, size: 20),
                  SizedBox(width: 8),
                  Text('Import Playlist',
                      style: TextStyle(
                          fontSize: 15, fontWeight: FontWeight.w700)),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _stepRow(String number, String text) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Container(
          width: 26,
          height: 26,
          decoration: BoxDecoration(
            color: const Color(0xFF1DB954).withValues(alpha: 0.15),
            shape: BoxShape.circle,
          ),
          child: Center(
            child: Text(
              number,
              style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w800,
                  color: Color(0xFF1DB954)),
            ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Text(text,
              style: const TextStyle(
                  fontSize: 14,
                  color: AppTheme.textSecondary,
                  height: 1.4)),
        ),
      ],
    );
  }

  Widget _buildProgress() {
    final progress =
        _totalTracks > 0 ? _processedTracks / _totalTracks : 0.0;
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 0, 24, 32),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _handle(),
          const SizedBox(height: 12),
          Row(
            children: [
              const SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(
                    color: Color(0xFF1DB954), strokeWidth: 2.5),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Text(
                  _spotifyPlaylistName.isEmpty
                      ? 'Fetching playlist…'
                      : _spotifyPlaylistName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.w800,
                      color: AppTheme.textPrimary),
                ),
              ),
            ],
          ),
          if (_spotifyOwner.isNotEmpty) ...[
            const SizedBox(height: 4),
            Padding(
              padding: const EdgeInsets.only(left: 34),
              child: Text('by $_spotifyOwner',
                  style: const TextStyle(
                      fontSize: 12, color: AppTheme.textSecondary)),
            ),
          ],
          const SizedBox(height: 16),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: progress,
              backgroundColor: AppTheme.background,
              color: const Color(0xFF1DB954),
              minHeight: 6,
            ),
          ),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('$_processedTracks / $_totalTracks tracks',
                  style: const TextStyle(
                      fontSize: 12, color: AppTheme.textSecondary)),
              Text('$_matchedTracks matched',
                  style: const TextStyle(
                      fontSize: 12,
                      color: Color(0xFF1DB954),
                      fontWeight: FontWeight.w600)),
            ],
          ),
          if (_currentTrackName.isNotEmpty) ...[
            const SizedBox(height: 6),
            Text(
              'Searching: $_currentTrackName',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                  fontSize: 11,
                  color: AppTheme.textSecondary.withValues(alpha: 0.55),
                  fontStyle: FontStyle.italic),
            ),
          ],
          if (_matchedSongs.isNotEmpty) ...[
            const SizedBox(height: 14),
            Container(
              height: 178,
              decoration: BoxDecoration(
                color: AppTheme.background,
                borderRadius: BorderRadius.circular(12),
              ),
              child: ListView.builder(
                padding: const EdgeInsets.symmetric(vertical: 6),
                itemCount: _matchedSongs.length,
                itemBuilder: (context, index) {
                  final song = _matchedSongs[index];
                  return ListTile(
                    dense: true,
                    visualDensity: VisualDensity.compact,
                    leading: ClipRRect(
                      borderRadius: BorderRadius.circular(6),
                      child: song.imageSmall.isNotEmpty
                          ? Image.network(song.imageSmall,
                              width: 34,
                              height: 34,
                              fit: BoxFit.cover,
                              errorBuilder: (_, __, ___) => _songFallback())
                          : _songFallback(),
                    ),
                    title: Text(song.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                            color: AppTheme.textPrimary,
                            fontSize: 13,
                            fontWeight: FontWeight.w600)),
                    subtitle: Text(song.artistNames,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                            color: AppTheme.textSecondary, fontSize: 11)),
                    trailing: const Icon(Icons.check_rounded,
                        color: Color(0xFF1DB954), size: 16),
                  );
                },
              ),
            ),
          ],
          const SizedBox(height: 18),
          SizedBox(
            width: double.infinity,
            height: 46,
            child: OutlinedButton(
              onPressed: () => setState(() => _cancelled = true),
              style: OutlinedButton.styleFrom(
                foregroundColor: AppTheme.textSecondary,
                side: BorderSide(
                    color: AppTheme.textSecondary.withValues(alpha: 0.3)),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
              ),
              child: const Text('Stop & Save',
                  style: TextStyle(fontWeight: FontWeight.w600)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _songFallback() => Container(
        width: 34,
        height: 34,
        color: AppTheme.surface,
        child: const Icon(Icons.music_note_rounded,
            color: AppTheme.accent, size: 16),
      );

  Widget _buildDone() {
    final skipped = _totalTracks - _matchedTracks;
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 0, 24, 40),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          _handle(),
          const SizedBox(height: 24),
          Container(
            width: 68,
            height: 68,
            decoration: BoxDecoration(
              color: const Color(0xFF1DB954).withValues(alpha: 0.15),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.check_rounded,
                color: Color(0xFF1DB954), size: 38),
          ),
          const SizedBox(height: 16),
          Text(
            _spotifyPlaylistName,
            textAlign: TextAlign.center,
            style: const TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w800,
                color: AppTheme.textPrimary),
          ),
          const SizedBox(height: 6),
          Text(
            'Import complete!',
            style: TextStyle(
                fontSize: 14,
                color: AppTheme.textSecondary.withValues(alpha: 0.7)),
          ),
          const SizedBox(height: 24),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _statChip('$_matchedTracks', 'matched', const Color(0xFF1DB954)),
              const SizedBox(width: 10),
              _statChip('$skipped', 'not found', AppTheme.textSecondary),
              const SizedBox(width: 10),
              _statChip('$_totalTracks', 'total', AppTheme.accent),
            ],
          ),
          const SizedBox(height: 28),
          SizedBox(
            width: double.infinity,
            height: 50,
            child: ElevatedButton(
              onPressed: () {
                Navigator.pop(context);
                if (_createdPlaylistId != null) {
                  widget.onImported(_createdPlaylistId!);
                }
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF1DB954),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14)),
                elevation: 0,
              ),
              child: const Text('Open Playlist',
                  style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700)),
            ),
          ),
          const SizedBox(height: 12),
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close',
                style: TextStyle(
                    color: AppTheme.textSecondary,
                    fontWeight: FontWeight.w600)),
          ),
        ],
      ),
    );
  }

  Widget _statChip(String value, String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(value,
              style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                  color: color)),
          const SizedBox(height: 2),
          Text(label,
              style: TextStyle(
                  fontSize: 11, color: color.withValues(alpha: 0.8))),
        ],
      ),
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
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: AppTheme.textSecondary.withValues(alpha: 0.15),
            width: 1.5,
          ),
        ),
        child: const Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.add_rounded, color: AppTheme.accent, size: 40),
            SizedBox(height: 12),
            Text('Create Playlist',
                style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: AppTheme.accent)),
            SizedBox(height: 4),
            Text('Add new folder',
                style:
                    TextStyle(fontSize: 12, color: AppTheme.textSecondary)),
          ],
        ),
      ),
    );
  }
}

class _PlaylistCard extends StatelessWidget {
  final Playlist playlist;
  final VoidCallback onTap;

  const _PlaylistCard({required this.playlist, required this.onTap});

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
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.15),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(16),
                child: playlist.coverUrl != null
                    ? Image.network(
                        playlist.coverUrl!,
                        fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) => _fallbackCover(),
                      )
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
                  playlist.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: AppTheme.textPrimary),
                ),
                const SizedBox(height: 2),
                Text(
                  '${playlist.songCount} song${playlist.songCount == 1 ? '' : 's'}',
                  style: const TextStyle(
                      fontSize: 12, color: AppTheme.textSecondary),
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
          child: Icon(Icons.music_note_rounded,
              color: AppTheme.accent, size: 44),
        ),
      );
}
