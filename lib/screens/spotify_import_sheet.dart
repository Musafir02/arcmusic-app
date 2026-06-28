import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../core/api_service.dart';
import '../core/user_data_service.dart';
import '../core/theme.dart';
import '../models/song.dart';
import '../models/spotify.dart';

enum ImportStep { instructions, loading, done }

class SpotifyImportSheet extends StatefulWidget {
  final void Function(String playlistId) onImported;
  const SpotifyImportSheet({required this.onImported, super.key});

  @override
  State<SpotifyImportSheet> createState() => _SpotifyImportSheetState();
}

class _SpotifyImportSheetState extends State<SpotifyImportSheet> {
  final _urlController = TextEditingController();
  ImportStep _step = ImportStep.instructions;
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
      url.contains('spotify.com/playlist/') || url.contains('spotify:playlist:');

  Future<void> _startImport() async {
    final url = _urlController.text.trim();
    if (url.isEmpty) {
      setState(() => _errorMsg = 'Please paste a Spotify playlist link');
      return;
    }
    if (!_isValidSpotifyUrl(url)) {
      setState(() => _errorMsg = "That doesn't look like a Spotify playlist link");
      return;
    }

    setState(() {
      _step = ImportStep.loading;
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
        _step = ImportStep.instructions;
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

    Map<String, dynamic> playlist;
    try {
      playlist = await UserDataService().createPlaylist(result.name);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _step = ImportStep.instructions;
        _errorMsg = 'Could not create playlist: $e';
      });
      return;
    }

    _createdPlaylistId = playlist['id'] as String;

    const batchSize = 5;
    final tracks = result.tracks;
    for (int batchStart = 0; batchStart < tracks.length; batchStart += batchSize) {
      if (_cancelled || !mounted) break;

      final batchEnd = (batchStart + batchSize).clamp(0, tracks.length);
      final batch = tracks.sublist(batchStart, batchEnd);

      if (batch.isNotEmpty && mounted && !_cancelled) {
        setState(() => _currentTrackName = '${batch.first.name} — ${batch.first.primaryArtist}');
      }

      final batchResults = await Future.wait(
        batch.map((track) => api.matchSpotifyTrack(track)),
      );

      if (!mounted || _cancelled) break;

      final matchedInBatch = batchResults.whereType<Song>().toList();
      setState(() {
        _processedTracks += batchResults.length;
        _matchedTracks += matchedInBatch.length;
        for (final song in matchedInBatch) {
          _matchedSongs.add(song);
          if (_matchedSongs.length > 60) _matchedSongs.removeAt(0);
        }
      });

      for (final song in matchedInBatch) {
        if (!mounted || _cancelled) break;
        await UserDataService().addSongToPlaylist(playlist['id'] as String, song);
      }
    }

    if (!mounted) return;
    setState(() => _step = ImportStep.done);
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
          child: _step == ImportStep.instructions
              ? _buildInstructions()
              : _step == ImportStep.loading
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
          decoration: BoxDecoration(color: AppTheme.textSecondary.withValues(alpha: 0.3), borderRadius: BorderRadius.circular(2)),
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
                  color: AppTheme.accent.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(Icons.queue_music_rounded, color: AppTheme.accent, size: 20),
              ),
              const SizedBox(width: 12),
              const Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Import from Spotify', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800, color: AppTheme.textPrimary)),
                  Text('Clone any public Spotify playlist', style: TextStyle(fontSize: 12, color: AppTheme.textSecondary)),
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
                color: _errorMsg != null ? Colors.redAccent.withValues(alpha: 0.6) : AppTheme.textSecondary.withValues(alpha: 0.2),
              ),
            ),
            child: Row(
              children: [
                const SizedBox(width: 14),
                const Icon(Icons.link_rounded, color: AppTheme.textSecondary, size: 18),
                const SizedBox(width: 8),
                Expanded(
                  child: TextField(
                    controller: _urlController,
                    style: const TextStyle(color: AppTheme.textPrimary, fontSize: 13),
                    cursorColor: AppTheme.accent,
                    onChanged: (_) {
                      if (_errorMsg != null) setState(() => _errorMsg = null);
                    },
                    decoration: InputDecoration(
                      hintText: 'Paste Spotify playlist link…',
                      hintStyle: TextStyle(color: AppTheme.textSecondary.withValues(alpha: 0.5), fontSize: 13),
                      border: InputBorder.none,
                      contentPadding: const EdgeInsets.symmetric(vertical: 14),
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
                const Icon(Icons.error_outline_rounded, color: Colors.redAccent, size: 14),
                const SizedBox(width: 6),
                Text(_errorMsg!, style: const TextStyle(color: Colors.redAccent, fontSize: 12)),
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
                backgroundColor: AppTheme.accent,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                elevation: 0,
              ),
              child: const Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.download_rounded, size: 20),
                  SizedBox(width: 8),
                  Text('Import Playlist', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700)),
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
          decoration: BoxDecoration(color: AppTheme.accent.withValues(alpha: 0.15), shape: BoxShape.circle),
          child: Center(
            child: Text(number, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: AppTheme.accent)),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Text(text, style: const TextStyle(fontSize: 14, color: AppTheme.textSecondary, height: 1.4)),
        ),
      ],
    );
  }

  Widget _buildProgress() {
    final progress = _totalTracks > 0 ? _processedTracks / _totalTracks : 0.0;
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
              const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: AppTheme.accent, strokeWidth: 2.5)),
              const SizedBox(width: 14),
              Expanded(
                child: Text(
                  _spotifyPlaylistName.isEmpty ? 'Fetching playlist…' : _spotifyPlaylistName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w800, color: AppTheme.textPrimary),
                ),
              ),
            ],
          ),
          if (_spotifyOwner.isNotEmpty) ...[
            const SizedBox(height: 4),
            Padding(
              padding: const EdgeInsets.only(left: 34),
              child: Text('by $_spotifyOwner', style: const TextStyle(fontSize: 12, color: AppTheme.textSecondary)),
            ),
          ],
          const SizedBox(height: 16),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: progress,
              backgroundColor: AppTheme.background,
              color: AppTheme.accent,
              minHeight: 6,
            ),
          ),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('$_processedTracks / $_totalTracks tracks', style: const TextStyle(fontSize: 12, color: AppTheme.textSecondary)),
              Text('$_matchedTracks matched', style: const TextStyle(fontSize: 12, color: AppTheme.accent, fontWeight: FontWeight.w600)),
            ],
          ),
          if (_currentTrackName.isNotEmpty) ...[
            const SizedBox(height: 6),
            Text(
              'Searching: $_currentTrackName',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(fontSize: 11, color: AppTheme.textSecondary.withValues(alpha: 0.55), fontStyle: FontStyle.italic),
            ),
          ],
          if (_matchedSongs.isNotEmpty) ...[
            const SizedBox(height: 14),
            Container(
              height: 178,
              decoration: BoxDecoration(color: AppTheme.background, borderRadius: BorderRadius.circular(12)),
              child: ListView.builder(
                padding: const EdgeInsets.symmetric(vertical: 6),
                itemCount: _matchedSongs.length,
                itemBuilder: (context, index) {
                  final song = _matchedSongs[index];
                  final imgSmall = song.imageSmall ?? '';

                  return ListTile(
                    dense: true,
                    visualDensity: VisualDensity.compact,
                    leading: ClipRRect(
                      borderRadius: BorderRadius.circular(6),
                      child: imgSmall.isNotEmpty
                          ? Image.network(imgSmall, width: 34, height: 34, fit: BoxFit.cover, errorBuilder: (_, __, ___) => _songFallback())
                          : _songFallback(),
                    ),
                    title: Text(song.name, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: AppTheme.textPrimary, fontSize: 13, fontWeight: FontWeight.w600)),
                    subtitle: Text(song.artist, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: AppTheme.textSecondary, fontSize: 11)),
                    trailing: const Icon(Icons.check_rounded, color: AppTheme.accent, size: 16),
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
                side: BorderSide(color: AppTheme.textSecondary.withValues(alpha: 0.3)),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              child: const Text('Stop & Save', style: TextStyle(fontWeight: FontWeight.w600)),
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
        child: const Icon(Icons.music_note_rounded, color: AppTheme.accent, size: 16),
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
            decoration: BoxDecoration(color: AppTheme.accent.withValues(alpha: 0.15), shape: BoxShape.circle),
            child: const Icon(Icons.check_rounded, color: AppTheme.accent, size: 38),
          ),
          const SizedBox(height: 16),
          Text(
            _spotifyPlaylistName,
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800, color: AppTheme.textPrimary),
          ),
          const SizedBox(height: 6),
          Text('Import complete!', style: TextStyle(fontSize: 14, color: AppTheme.textSecondary.withValues(alpha: 0.7))),
          const SizedBox(height: 24),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _statChip('$_matchedTracks', 'matched', AppTheme.accent),
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
                backgroundColor: AppTheme.accent,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                elevation: 0,
              ),
              child: const Text('Open Playlist', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700)),
            ),
          ),
          const SizedBox(height: 12),
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close', style: TextStyle(color: AppTheme.textSecondary, fontWeight: FontWeight.w600)),
          ),
        ],
      ),
    );
  }

  Widget _statChip(String value, String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(color: color.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(12)),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(value, style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: color)),
          const SizedBox(height: 2),
          Text(label, style: TextStyle(fontSize: 11, color: color.withValues(alpha: 0.8))),
        ],
      ),
    );
  }
}
