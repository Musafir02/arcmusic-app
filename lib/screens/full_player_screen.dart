import 'dart:async';
import 'package:flutter/material.dart';
import '../core/api_service.dart';
import '../core/player_service.dart';
import '../core/theme.dart';
import '../models/song.dart';

class FullPlayerScreen extends StatelessWidget {
  const FullPlayerScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: ValueListenableBuilder<Song?>(
          valueListenable: audioHandler.currentSongNotifier,
          builder: (context, song, _) {
            if (song == null) {
              return const Center(
                child: Text('No song playing',
                    style: TextStyle(color: AppTheme.textSecondary)),
              );
            }
            return _PlayerBody(song: song);
          },
        ),
      ),
    );
  }
}

class _PlayerBody extends StatefulWidget {
  final Song song;
  const _PlayerBody({required this.song});

  @override
  State<_PlayerBody> createState() => _PlayerBodyState();
}

class _PlayerBodyState extends State<_PlayerBody> {
  final PageController _pageController = PageController();
  int _currentPage = 0;

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              GestureDetector(
                onTap: () => Navigator.pop(context),
                child: Container(
                  width: 40,
                  height: 5,
                  decoration: BoxDecoration(
                    color: AppTheme.textSecondary.withValues(alpha: 0.3),
                    borderRadius: BorderRadius.circular(3),
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 8),
        Expanded(
          child: PageView(
            controller: _pageController,
            onPageChanged: (i) => setState(() => _currentPage = i),
            children: [
              _buildArtworkPage(),
              const Center(child: Text('Lyrics loading...', style: TextStyle(color: Colors.white))),
            ],
          ),
        ),
        const SizedBox(height: 12),
        _buildSongInfo(),
        const SizedBox(height: 24),
        _buildSeekBar(),
        const SizedBox(height: 4),
        _buildTimeRow(),
        const SizedBox(height: 16),
        _buildControls(),
        const SizedBox(height: 24),
      ],
    );
  }

  Widget _buildArtworkPage() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 40),
      child: Center(
        child: ClipRRect(
          borderRadius: BorderRadius.circular(20),
          child: AspectRatio(
            aspectRatio: 1,
            child: Image.network(
              widget.song.imageLarge,
              fit: BoxFit.cover,
              errorBuilder: (_, __, ___) => Container(
                color: AppTheme.surface,
                child: const Icon(
                  Icons.music_note_rounded,
                  color: AppTheme.accent,
                  size: 80,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSongInfo() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 40),
      child: Column(
        children: [
          Text(
            widget.song.name,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.w800,
              color: AppTheme.textPrimary,
              letterSpacing: -0.5,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            widget.song.artistNames,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 14,
              color: AppTheme.textSecondary,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSeekBar() {
    return StreamBuilder<Duration>(
      stream: audioHandler.positionStream,
      builder: (context, snapshot) {
        final pos = snapshot.data ?? Duration.zero;
        final dur = audioHandler.duration;
        final total = dur.inMilliseconds.toDouble();
        final current =
            pos.inMilliseconds.toDouble().clamp(0.0, total > 0 ? total : 1.0);

        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 36),
          child: SliderTheme(
            data: SliderThemeData(
              trackHeight: 4,
              activeTrackColor: AppTheme.accent,
              inactiveTrackColor: AppTheme.surface,
              thumbColor: AppTheme.accent,
              thumbShape:
                  const RoundSliderThumbShape(enabledThumbRadius: 7),
              overlayShape:
                  const RoundSliderOverlayShape(overlayRadius: 16),
              overlayColor: AppTheme.accent.withValues(alpha: 0.15),
            ),
            child: Slider(
              value: current,
              max: total > 0 ? total : 1.0,
              onChanged: (value) {
                audioHandler.seek(Duration(milliseconds: value.toInt()));
              },
            ),
          ),
        );
      },
    );
  }

  Widget _buildTimeRow() {
    return StreamBuilder<Duration>(
      stream: audioHandler.positionStream,
      builder: (context, snapshot) {
        final pos = snapshot.data ?? Duration.zero;
        final dur = audioHandler.duration;
        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 40),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                audioHandler.formatDuration(pos),
                style: const TextStyle(
                    fontSize: 12, color: AppTheme.textSecondary),
              ),
              Text(
                audioHandler.formatDuration(dur),
                style: const TextStyle(
                    fontSize: 12, color: AppTheme.textSecondary),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildControls() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 28),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          ValueListenableBuilder<bool>(
            valueListenable: audioHandler.isLikedNotifier,
            builder: (_, liked, __) => GestureDetector(
              onTap: audioHandler.toggleLike,
              child: Icon(
                liked
                    ? Icons.favorite_rounded
                    : Icons.favorite_border_rounded,
                color: liked ? AppTheme.accent : AppTheme.textSecondary,
                size: 26,
              ),
            ),
          ),
          GestureDetector(
            onTap: audioHandler.skipToPrevious,
            child: const Icon(
              Icons.skip_previous_rounded,
              color: AppTheme.textPrimary,
              size: 40,
            ),
          ),
          StreamBuilder<bool>(
            stream: audioHandler.playingStream,
            builder: (_, snap) {
              final playing = snap.data ?? false;
              return GestureDetector(
                onTap: audioHandler.togglePlay,
                child: Container(
                  width: 68,
                  height: 68,
                  decoration: const BoxDecoration(
                    color: AppTheme.accent,
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    playing
                        ? Icons.pause_rounded
                        : Icons.play_arrow_rounded,
                    color: AppTheme.background,
                    size: 36,
                  ),
                ),
              );
            },
          ),
          GestureDetector(
            onTap: audioHandler.skipToNext,
            child: const Icon(
              Icons.skip_next_rounded,
              color: AppTheme.textPrimary,
              size: 40,
            ),
          ),
          ValueListenableBuilder<bool>(
            valueListenable: audioHandler.isRepeatNotifier,
            builder: (_, repeat, __) => GestureDetector(
              onTap: audioHandler.toggleRepeat,
              child: Icon(
                Icons.repeat_one_rounded,
                color: repeat ? AppTheme.accent : AppTheme.textSecondary,
                size: 26,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
