import 'package:flutter/foundation.dart';
import 'package:just_audio/just_audio.dart';
import 'package:audio_service/audio_service.dart';
import 'package:audio_session/audio_session.dart';
import 'api_service.dart';
import 'user_data_service.dart';
import 'taste_service.dart';
import 'download_service.dart';

late AudioPlayerHandler audioHandler;

Future<void> initAudioService() async {
  audioHandler = await AudioService.init(
    builder: () => AudioPlayerHandler(),
    config: const AudioServiceConfig(
      androidNotificationChannelId: 'com.arcmusic.arcmusic.audio',
      androidNotificationChannelName: 'ArcMusic',
      androidNotificationOngoing: false,
      androidStopForegroundOnPause: false,
      androidNotificationIcon: 'mipmap/ic_launcher',
    ),
  );
}

class AudioPlayerHandler extends BaseAudioHandler
    with QueueHandler, SeekHandler {
  final AudioPlayer _player = AudioPlayer();
  final AudioPlayer _preloadPlayer = AudioPlayer();
  final ApiService _api = ApiService();
  final TasteService _taste = TasteService();
  DateTime? _songStartTime;

  Map<String, dynamic>? _currentSong;
  List<Map<String, dynamic>>? _currentPlaylist;
  int _currentIndex = -1;
  bool _isPlaylistMode = false;
  bool _isRepeat = false;
  bool _isLiked = false;
  String? _preloadedSongId;

  final ValueNotifier<Map<String, dynamic>?> currentSongNotifier = ValueNotifier(null);
  final ValueNotifier<bool> isRepeatNotifier = ValueNotifier(false);
  final ValueNotifier<bool> isLikedNotifier = ValueNotifier(false);
  final ValueNotifier<String?> playbackErrorNotifier = ValueNotifier(null);

  Map<String, dynamic>? get currentSong => _currentSong;
  bool get isRepeat => _isRepeat;
  bool get isLiked => _isLiked;

  AudioPlayerHandler() {
    _player.playbackEventStream.listen(_broadcastState);
    _initAudioSession();

    _player.processingStateStream.listen((state) {
      if (state == ProcessingState.completed) {
        if (_currentSong != null) {
          _taste.onSongCompleted(_currentSong!);
        }
        if (_isRepeat) {
          _player.seek(Duration.zero);
          _player.play();
        } else {
          skipToNext();
        }
      }
    });

    _player.positionStream.listen((pos) {
      final dur = _player.duration;
      if (dur != null && dur.inSeconds > 0) {
        final remaining = dur.inSeconds - pos.inSeconds;
        if (remaining <= 15 || pos.inSeconds > (dur.inSeconds * 0.8)) {
          _preloadNextSong();
        }
      }
    });

    UserDataService().likedNotifier.addListener(() {
      if (_currentSong != null) {
        final liked = UserDataService().isLiked(_currentSong!['id'] as String);
        _isLiked = liked;
        isLikedNotifier.value = liked;
      }
    });
  }

  Future<void> _initAudioSession() async {
    final session = await AudioSession.instance;
    await session.configure(const AudioSessionConfiguration(
      avAudioSessionCategory: AVAudioSessionCategory.playback,
      avAudioSessionMode: AVAudioSessionMode.defaultMode,
      androidAudioAttributes: AndroidAudioAttributes(
        contentType: AndroidAudioContentType.music,
        usage: AndroidAudioUsage.media,
      ),
      androidAudioFocusGainType: AndroidAudioFocusGainType.gain,
      androidWillPauseWhenDucked: false,
    ));

    session.interruptionEventStream.listen((event) {
      if (event.begin) {
        if (_player.playing) {
          pause();
        }
      } else {
        if (event.type == AudioInterruptionType.pause) {
          play();
        }
      }
    });

    session.becomingNoisyEventStream.listen((_) {
      if (_player.playing) pause();
    });
  }

  void _broadcastState(PlaybackEvent event) {
    final playing = _player.playing;
    playbackState.add(playbackState.value.copyWith(
      controls: [
        MediaControl.skipToPrevious,
        if (playing) MediaControl.pause else MediaControl.play,
        MediaControl.skipToNext,
      ],
      systemActions: const {
        MediaAction.seek,
        MediaAction.seekForward,
        MediaAction.seekBackward,
      },
      androidCompactActionIndices: const [0, 1, 2],
      processingState: const {
        ProcessingState.idle: AudioProcessingState.idle,
        ProcessingState.loading: AudioProcessingState.loading,
        ProcessingState.buffering: AudioProcessingState.buffering,
        ProcessingState.ready: AudioProcessingState.ready,
        ProcessingState.completed: AudioProcessingState.completed,
      }[_player.processingState]!,
      playing: playing,
      updatePosition: _player.position,
      bufferedPosition: _player.bufferedPosition,
      speed: _player.speed,
      queueIndex: event.currentIndex,
    ));
  }

  Future<bool> _playSongInternal(Map<String, dynamic> song, {bool showErrorMessage = true}) async {
    final id = song['id'] as String? ?? '';
    if (id.isEmpty) return false;

    String downloadUrl = song['downloadUrl'] as String? ?? '';
    Map<String, dynamic> resolvedSong = song;

    if (downloadUrl.isEmpty) {
      try {
        final fresh = await _api.getSongDetails(id);
        if (fresh != null && (fresh['downloadUrl'] as String? ?? '').isNotEmpty) {
          downloadUrl = fresh['downloadUrl'] as String;
          resolvedSong = fresh;
        }
      } catch (_) {}
    }

    if (downloadUrl.isEmpty) {
      if (showErrorMessage) {
        playbackErrorNotifier.value = 'Cannot play: No stream URL available.';
        playbackErrorNotifier.value = null;
      }
      return false;
    }

    final oldSong = _currentSong;
    final oldStartTime = _songStartTime;
    final oldLiked = _isLiked;

    _currentSong = resolvedSong;
    _songStartTime = DateTime.now();
    _isLiked = UserDataService().isLiked(id);
    currentSongNotifier.value = resolvedSong;
    isLikedNotifier.value = _isLiked;

    final imgLarge = resolvedSong['imageLarge'] as String? ?? '';
    final imgMedium = resolvedSong['image'] as String? ?? '';
    final artUri = imgLarge.isNotEmpty
        ? Uri.parse(imgLarge)
        : (imgMedium.isNotEmpty
            ? Uri.parse(imgMedium)
            : null);

    final duration = resolvedSong['duration'] as int? ?? 0;
    mediaItem.add(MediaItem(
      id: id,
      title: resolvedSong['name'] as String? ?? '',
      artist: resolvedSong['artist'] as String? ?? '',
      album: resolvedSong['album'] as String? ?? '',
      duration: Duration(seconds: duration),
      artUri: artUri,
    ));

    try {
      final localPath = await DownloadService().getDownloadedPath(id);
      if (localPath != null) {
        await _player.setAudioSource(AudioSource.file(localPath));
      } else {
        await _player.setUrl(downloadUrl);
      }
      await _player.play();

      if (oldSong != null) {
        final playedSeconds = oldStartTime != null
            ? DateTime.now().difference(oldStartTime).inSeconds
            : 0;
        if (playedSeconds < 30 && playedSeconds > 0) {
          _taste.onSongSkipped(oldSong);
        }
      }

      _taste.onSongPlayed(resolvedSong);
      if (_isPlaylistMode) {
        _preloadNextSong();
      } else {
        _loadSuggestions(id).then((_) {
          _preloadNextSong();
        });
      }
      return true;
    } catch (e, s) {
      debugPrint('Playback error: $e\n$s');
      if (showErrorMessage) {
        final isDownloaded = DownloadService().isSongDownloaded(id);
        if (!isDownloaded) {
          playbackErrorNotifier.value = 'Offline: This song is not downloaded.';
          playbackErrorNotifier.value = null;
        } else {
          playbackErrorNotifier.value = 'Failed to play downloaded song: $e';
          playbackErrorNotifier.value = null;
        }
      }
      if (_currentSong?['id'] == id) {
        _currentSong = oldSong;
        _songStartTime = oldStartTime;
        _isLiked = oldLiked;
        currentSongNotifier.value = oldSong;
        isLikedNotifier.value = oldLiked;
        if (oldSong != null) {
          final oldImgLarge = oldSong['imageLarge'] as String? ?? '';
          final oldImgMedium = oldSong['image'] as String? ?? '';
          final oldArt = oldImgLarge.isNotEmpty
              ? Uri.parse(oldImgLarge)
              : (oldImgMedium.isNotEmpty
                  ? Uri.parse(oldImgMedium)
                  : null);
          final oldDur = oldSong['duration'] as int? ?? 0;
          mediaItem.add(MediaItem(
            id: oldSong['id'] as String? ?? '',
            title: oldSong['name'] as String? ?? '',
            artist: oldSong['artist'] as String? ?? '',
            album: oldSong['album'] as String? ?? '',
            duration: Duration(seconds: oldDur),
            artUri: oldArt,
          ));
        } else {
          mediaItem.add(null);
        }
      }
      return false;
    }
  }

  Future<void> playSong(Map<String, dynamic> song, {List<Map<String, dynamic>>? playlist}) async {
    final id = song['id'] as String? ?? '';
    if (playlist != null && playlist.isNotEmpty) {
      _currentPlaylist = List<Map<String, dynamic>>.from(playlist);
      _currentIndex = _currentPlaylist!.indexWhere((s) => s['id'] == id);
      if (_currentIndex == -1) {
        _currentPlaylist!.insert(0, song);
        _currentIndex = 0;
      }
      _isPlaylistMode = true;
    } else {
      _currentPlaylist = [song];
      _currentIndex = 0;
      _isPlaylistMode = false;
    }
    await _playSongInternal(song);
  }

  void restoreSong(Map<String, dynamic> song) {
    final id = song['id'] as String? ?? '';
    _currentSong = song;
    _currentPlaylist = [song];
    _currentIndex = 0;
    _isPlaylistMode = false;
    _songStartTime = DateTime.now();
    _isLiked = UserDataService().isLiked(id);
    currentSongNotifier.value = song;
    isLikedNotifier.value = _isLiked;

    final imgLarge = song['imageLarge'] as String? ?? '';
    final imgMedium = song['image'] as String? ?? '';
    final artUri = imgLarge.isNotEmpty
        ? Uri.parse(imgLarge)
        : (imgMedium.isNotEmpty
            ? Uri.parse(imgMedium)
            : null);

    final duration = song['duration'] as int? ?? 0;
    mediaItem.add(MediaItem(
      id: id,
      title: song['name'] as String? ?? '',
      artist: song['artist'] as String? ?? '',
      album: song['album'] as String? ?? '',
      duration: Duration(seconds: duration),
      artUri: artUri,
    ));

    final downloadUrl = song['downloadUrl'] as String? ?? '';
    if (downloadUrl.isNotEmpty) {
      DownloadService().getDownloadedPath(id).then((localPath) {
        if (localPath != null) {
          _player.setAudioSource(AudioSource.file(localPath)).catchError((e) {
            debugPrint('restoreSong preload error: $e');
            return null;
          });
        } else {
          _player.setUrl(downloadUrl).catchError((e) {
            debugPrint('restoreSong preload error: $e');
            return null;
          });
        }
      });
    }
  }

  Future<void> _loadSuggestions(String songId) async {
    if (_isPlaylistMode) return;
    try {
      final suggestions = await _api.getSongSuggestions(songId, limit: 10);
      final valid = suggestions.where((s) => s['downloadUrl'] != null).toList();
      final ranked = _taste.rankSuggestions(valid);
      for (final s in ranked) {
        if (_currentPlaylist != null && !_currentPlaylist!.any((x) => x['id'] == s['id'])) {
          _currentPlaylist!.add(s);
        }
      }
    } catch (e, s) {
      debugPrint('_loadSuggestions error: $e\n$s');
    }
  }

  @override
  Future<void> play() async => _player.play();

  @override
  Future<void> pause() async => _player.pause();

  @override
  Future<void> seek(Duration position) async => _player.seek(position);

  @override
  Future<void> stop() async {
    await _player.stop();
    await _preloadPlayer.stop();
    return super.stop();
  }

  @override
  Future<void> skipToNext() async {
    if (_currentPlaylist == null || _currentPlaylist!.isEmpty) return;

    final startIndex = _currentIndex;
    bool wrappedOnce = false;

    while (true) {
      if (_currentIndex < _currentPlaylist!.length - 1) {
        _currentIndex++;
      } else {
        if (_isPlaylistMode) {
          _currentIndex = 0;
          wrappedOnce = true;
        } else if (_currentSong != null) {
          final oldLength = _currentPlaylist!.length;
          final currentId = _currentSong!['id'] as String? ?? '';
          if (currentId.isNotEmpty) {
            await _loadSuggestions(currentId);
          }
          if (_currentPlaylist!.length > oldLength) {
            _currentIndex++;
          } else {
            break;
          }
        } else {
          break;
        }
      }

      if (wrappedOnce && _currentIndex == startIndex) {
        playbackErrorNotifier.value = 'Offline: No playable songs found.';
        playbackErrorNotifier.value = null;
        break;
      }

      final song = _currentPlaylist![_currentIndex];
      final success = await _playSongInternal(song, showErrorMessage: false);
      if (success) return;
    }
  }

  @override
  Future<void> skipToPrevious() async {
    if (_currentPlaylist == null || _currentPlaylist!.isEmpty) return;

    final startIndex = _currentIndex;
    bool wrappedOnce = false;

    while (true) {
      if (_currentIndex > 0) {
        _currentIndex--;
      } else {
        if (_isPlaylistMode) {
          _currentIndex = _currentPlaylist!.length - 1;
          wrappedOnce = true;
        } else {
          await _player.seek(Duration.zero);
          return;
        }
      }

      if (wrappedOnce && _currentIndex == startIndex) {
        break;
      }

      final song = _currentPlaylist![_currentIndex];
      final success = await _playSongInternal(song, showErrorMessage: false);
      if (success) return;
    }
  }

  void togglePlay() {
    if (_player.playing) {
      pause();
    } else {
      play();
    }
  }

  void toggleRepeat() {
    _isRepeat = !_isRepeat;
    _player.setLoopMode(_isRepeat ? LoopMode.one : LoopMode.off);
    isRepeatNotifier.value = _isRepeat;
  }

  void toggleLike() {
    if (_currentSong != null) {
      final id = _currentSong!['id'] as String? ?? '';
      if (id.isEmpty) return;
      final wasLiked = UserDataService().isLiked(id);
      UserDataService().toggleLike(_currentSong!);
      if (!wasLiked) {
        _taste.onSongLiked(_currentSong!);
      }
    }
  }

  Stream<Duration> get positionStream => _player.positionStream;
  Stream<bool> get playingStream => _player.playingStream;
  Duration get position => _player.position;
  Duration get duration => _player.duration ?? Duration.zero;

  String formatDuration(Duration d) {
    final m = d.inMinutes;
    final s = d.inSeconds % 60;
    return '$m:${s.toString().padLeft(2, '0')}';
  }

  void _preloadNextSong() {
    if (_currentPlaylist == null || _currentPlaylist!.isEmpty) return;
    int nextIdx = _currentIndex + 1;
    if (nextIdx >= _currentPlaylist!.length) {
      if (_isPlaylistMode) {
        nextIdx = 0;
      } else {
        return;
      }
    }
    final nextSong = _currentPlaylist![nextIdx];
    _preloadSongAndDetails(nextSong);
  }

  void _preloadSongAndDetails(Map<String, dynamic> nextSong) {
    final id = nextSong['id'] as String? ?? '';
    if (id.isEmpty || _preloadedSongId == id) return;
    _preloadedSongId = id;

    final name = nextSong['name'] as String? ?? '';
    final artist = nextSong['artist'] as String? ?? '';
    final album = nextSong['album'] as String? ?? '';
    final duration = nextSong['duration'] as int? ?? 0;

    _api.getLyrics(
      id,
      trackName: name,
      artistName: artist,
      albumName: album,
      durationSecs: duration,
    ).catchError((e) => LyricsResult());

    final downloadUrl = nextSong['downloadUrl'] as String? ?? '';
    if (downloadUrl.isNotEmpty) {
      _preloadPlayer.setUrl(downloadUrl).catchError((e) {
        debugPrint('Preload error for $id: $e');
        return null;
      });
    }
  }

  void clear() {
    _player.stop();
    _preloadPlayer.stop();
    _preloadedSongId = null;
    _currentSong = null;
    _songStartTime = null;
    _currentPlaylist = null;
    _currentIndex = -1;
    _isPlaylistMode = false;
    _isRepeat = false;
    _isLiked = false;
    currentSongNotifier.value = null;
    isRepeatNotifier.value = false;
    isLikedNotifier.value = false;
    mediaItem.add(null);
  }
}
