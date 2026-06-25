import 'dart:async';
import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../core/api_service.dart';
import '../core/player_service.dart';
import '../core/theme.dart';
import '../models/song.dart';
import 'playlist_song_picker.dart';

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

class _LrcLine {
  final Duration timestamp;
  final String text;
  _LrcLine(this.timestamp, this.text);
}

List<_LrcLine> _parseLrc(String lrc) {
  final lines = <_LrcLine>[];
  final regex = RegExp(r'\[(\d{2}):(\d{2})(?:\.(\d+))?\]\s*(.*)');

  for (final line in lrc.split('\n')) {
    final match = regex.firstMatch(line.trim());
    if (match != null) {
      final min = int.parse(match.group(1)!);
      final sec = int.parse(match.group(2)!);
      final msStr = match.group(3);
      int ms = 0;
      if (msStr != null) {
        if (msStr.length == 1) {
          ms = int.parse(msStr) * 100;
        } else if (msStr.length == 2) {
          ms = int.parse(msStr) * 10;
        } else {
          ms = int.parse(msStr.substring(0, 3));
        }
      }
      final text = match.group(4)?.trim() ?? '';
      if (text.isNotEmpty) {
        lines.add(_LrcLine(
          Duration(minutes: min, seconds: sec, milliseconds: ms),
          text,
        ));
      }
    }
  }

  lines.sort((a, b) => a.timestamp.compareTo(b.timestamp));
  return lines;
}

class _PlayerBody extends StatefulWidget {
  final Song song;
  const _PlayerBody({required this.song});

  @override
  State<_PlayerBody> createState() => _PlayerBodyState();
}

class _PlayerBodyState extends State<_PlayerBody> {
  final PageController _pageController = PageController();
  final ApiService _api = ApiService();
  int _currentPage = 0;

  LyricsResult? _lyricsResult;
  List<_LrcLine> _syncedLines = [];
  bool _lyricsLoading = false;
  String? _cachedSongId;

  @override
  void initState() {
    super.initState();
    _fetchLyrics();
  }

  @override
  void didUpdateWidget(covariant _PlayerBody oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.song.id != widget.song.id) {
      _fetchLyrics();
    }
  }

  void _fetchLyrics() {
    if (_cachedSongId == widget.song.id && _lyricsResult != null) return;
    _cachedSongId = widget.song.id;
    setState(() {
      _lyricsLoading = true;
      _lyricsResult = null;
      _syncedLines = [];
    });

    _api
        .getLyrics(
      widget.song.id,
      trackName: widget.song.name,
      artistName: widget.song.artistNames,
      albumName: widget.song.albumName,
      durationSecs: widget.song.duration,
    )
        .then((result) {
      if (mounted && _cachedSongId == widget.song.id) {
        List<_LrcLine> lines = [];

        if (result.hasSynced) {
          lines = _parseLrc(result.syncedLrc!);
        } else if (result.plainText != null && result.plainText!.isNotEmpty) {
          final textLines = result.plainText!
              .split('\n')
              .where((l) => l.trim().isNotEmpty)
              .toList();

          if (textLines.isNotEmpty) {
            final totalMs = widget.song.duration * 1000;
            final perLine = totalMs / textLines.length;
            for (int i = 0; i < textLines.length; i++) {
              lines.add(_LrcLine(
                Duration(milliseconds: (perLine * i).round()),
                textLines[i].trim(),
              ));
            }
          }
        }

        setState(() {
          _lyricsResult = result;
          _lyricsLoading = false;
          _syncedLines = lines;
        });
      }
    });
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onVerticalDragEnd: (details) {
        if (details.primaryVelocity != null &&
            details.primaryVelocity! > 300) {
          Navigator.pop(context);
        }
      },
      child: Column(
        children: [
          _buildTopBar(context),
          const SizedBox(height: 8),
          Expanded(
            child: PageView(
              controller: _pageController,
              onPageChanged: (i) => setState(() => _currentPage = i),
              children: [
                _buildArtworkPage(),
                _buildLyricsPage(),
              ],
            ),
          ),
          _buildPageIndicator(),
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
      ),
    );
  }

  Widget _buildTopBar(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          const SizedBox(width: 48),
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
          IconButton(
            icon: const Icon(Icons.playlist_add_rounded, size: 26),
            color: AppTheme.textPrimary,
            onPressed: () async {
              await showSongPicker(context, [widget.song]);
            },
          ),
        ],
      ),
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
            child: CachedNetworkImage(
              imageUrl: widget.song.imageLarge,
              fit: BoxFit.cover,
              errorWidget: (_, __, ___) => Container(
                color: AppTheme.surface,
                child: const Icon(
                  Icons.music_note_rounded,
                  color: AppTheme.accent,
                  size: 80,
                ),
              ),
              placeholder: (_, __) => Container(
                color: AppTheme.surface,
                child: const Center(
                  child: SizedBox(
                    width: 40,
                    height: 40,
                    child: CircularProgressIndicator(
                      strokeWidth: 3,
                      color: AppTheme.accent,
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildLyricsPage() {
    if (_lyricsLoading) {
      return const Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(
              width: 28,
              height: 28,
              child: CircularProgressIndicator(
                strokeWidth: 2.5,
                color: AppTheme.accent,
              ),
            ),
            SizedBox(height: 16),
            Text(
              'Loading lyrics...',
              style: TextStyle(color: AppTheme.textSecondary, fontSize: 14),
            ),
          ],
        ),
      );
    }

    if (_lyricsResult == null || _lyricsResult!.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.lyrics_outlined,
              color: AppTheme.textSecondary.withValues(alpha: 0.4),
              size: 56,
            ),
            const SizedBox(height: 16),
            const Text(
              'Lyrics not available',
              style: TextStyle(
                color: AppTheme.textSecondary,
                fontSize: 16,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      );
    }

    if (_syncedLines.isNotEmpty) {
      return _SyncedLyricsView(lines: _syncedLines);
    }

    if (_lyricsResult!.plainText != null &&
        _lyricsResult!.plainText!.isNotEmpty) {
      return SingleChildScrollView(
        physics: const BouncingScrollPhysics(),
        padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 16),
        child: Text(
          _lyricsResult!.plainText!,
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 15,
            color: AppTheme.textSecondary.withValues(alpha: 0.85),
            height: 1.8,
          ),
        ),
      );
    }

    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.lyrics_outlined,
            color: AppTheme.textSecondary.withValues(alpha: 0.4),
            size: 56,
          ),
          const SizedBox(height: 16),
          const Text(
            'Lyrics not available',
            style: TextStyle(
              color: AppTheme.textSecondary,
              fontSize: 16,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPageIndicator() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: List.generate(2, (i) {
        final active = i == _currentPage;
        return AnimatedContainer(
          duration: const Duration(milliseconds: 250),
          margin: const EdgeInsets.symmetric(horizontal: 4),
          width: active ? 20 : 7,
          height: 7,
          decoration: BoxDecoration(
            color: active
                ? AppTheme.accent
                : AppTheme.textSecondary.withValues(alpha: 0.3),
            borderRadius: BorderRadius.circular(4),
          ),
        );
      }),
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

class _SyncedLyricsView extends StatefulWidget {
  final List<_LrcLine> lines;
  const _SyncedLyricsView({required this.lines});

  @override
  State<_SyncedLyricsView> createState() => _SyncedLyricsViewState();
}

class _SyncedLyricsViewState extends State<_SyncedLyricsView> {
  final ScrollController _scrollController = ScrollController();
  StreamSubscription<Duration>? _positionSub;
  int _activeIndex = -1;
  bool _userScrolling = false;
  Timer? _scrollResetTimer;

  @override
  void initState() {
    super.initState();
    _positionSub = audioHandler.positionStream.listen(_onPosition);
  }

  void _onPosition(Duration pos) {
    int lo = 0;
    int hi = widget.lines.length - 1;
    int newIndex = -1;

    while (lo <= hi) {
      final mid = (lo + hi) >> 1;
      if (widget.lines[mid].timestamp <= pos) {
        newIndex = mid;
        lo = mid + 1;
      } else {
        hi = mid - 1;
      }
    }

    if (newIndex != _activeIndex) {
      setState(() => _activeIndex = newIndex);
      if (!_userScrolling && newIndex >= 0 && _scrollController.hasClients) {
        final targetOffset = (newIndex * 48.0);
        _scrollController.animateTo(
          targetOffset.clamp(0.0, _scrollController.position.maxScrollExtent),
          duration: const Duration(milliseconds: 350),
          curve: Curves.easeInOutCubic,
        );
      }
    }
  }

  @override
  void dispose() {
    _positionSub?.cancel();
    _scrollController.dispose();
    _scrollResetTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ShaderMask(
      shaderCallback: (bounds) => LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [
          Colors.transparent,
          Colors.white,
          Colors.white,
          Colors.transparent,
        ],
        stops: const [0.0, 0.1, 0.88, 1.0],
      ).createShader(bounds),
      blendMode: BlendMode.dstIn,
      child: NotificationListener<ScrollNotification>(
        onNotification: (notif) {
          if (notif is UserScrollNotification) {
            _userScrolling = true;
            _scrollResetTimer?.cancel();
            _scrollResetTimer = Timer(const Duration(seconds: 3), () {
              _userScrolling = false;
            });
          }
          return false;
        },
        child: LayoutBuilder(
          builder: (context, constraints) {
            final viewportHeight = constraints.maxHeight;
            return ListView.builder(
              controller: _scrollController,
              padding: EdgeInsets.symmetric(
                vertical: viewportHeight / 2 - 24.0,
                horizontal: 24,
              ),
              itemCount: widget.lines.length,
              itemExtent: 48.0,
              itemBuilder: (context, index) {
                final isActive = index == _activeIndex;
                final isPast = index < _activeIndex;

                return GestureDetector(
                  onTap: () {
                    audioHandler.seek(widget.lines[index].timestamp);
                  },
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 350),
                    curve: Curves.easeInOutCubic,
                    alignment: Alignment.center,
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                    child: AnimatedDefaultTextStyle(
                      duration: const Duration(milliseconds: 350),
                      curve: Curves.easeInOutCubic,
                      style: TextStyle(
                        fontSize: isActive ? 20 : 16,
                        fontWeight: isActive ? FontWeight.w700 : FontWeight.w500,
                        color: isActive
                            ? AppTheme.accent
                            : isPast
                                ? AppTheme.textSecondary.withValues(alpha: 0.35)
                                : AppTheme.textSecondary.withValues(alpha: 0.6),
                        height: 1.2,
                      ),
                      textAlign: TextAlign.center,
                      child: Text(
                        widget.lines[index].text,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ),
                );
              },
            );
          },
        ),
      ),
    );
  }
}


