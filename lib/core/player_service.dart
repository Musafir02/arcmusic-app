import 'package:flutter/foundation.dart';
import 'package:just_audio/just_audio.dart';
import 'package:audio_service/audio_service.dart';
import 'package:audio_session/audio_session.dart';
import '../models/song.dart';
import 'api_service.dart';
import 'liked_service.dart';
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

  Song? _currentSong;
  List<Song>? _currentPlaylist;
  int _currentIndex = -1;
  bool _isPlaylistMode = false;
  bool _isRepeat = false;
  bool _isLiked = false;
  String? _preloadedSongId;

  final ValueNotifier<Song?> currentSongNotifier = ValueNotifier(null);
  final ValueNotifier<bool> isRepeatNotifier = ValueNotifier(false);
  final ValueNotifier<bool> isLikedNotifier = ValueNotifier(false);
  final ValueNotifier<String?> playbackErrorNotifier = ValueNotifier(null);

  Song? get currentSong => _currentSong;
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

    LikedService().likedNotifier.addListener(() {
      if (_currentSong != null) {
        final liked = LikedService().isLiked(_currentSong!.id);
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

  Future<void> _playSongInternal(Song song) async {
    if (song.downloadUrl == null || song.downloadUrl!.isEmpty) return;

    final oldSong = _currentSong;
    final oldStartTime = _songStartTime;
    final oldLiked = _isLiked;

    _currentSong = song;
    _songStartTime = DateTime.now();
    _isLiked = LikedService().isLiked(song.id);
    currentSongNotifier.value = song;
    isLikedNotifier.value = _isLiked;

    final artUri = song.imageLarge.isNotEmpty
        ? Uri.parse(song.imageLarge)
        : (song.imageMedium.isNotEmpty
            ? Uri.parse(song.imageMedium)
            : null);

    mediaItem.add(MediaItem(
      id: song.id,
      title: song.name,
      artist: song.artistNames,
      album: song.albumName,
      duration: Duration(seconds: song.duration),
      artUri: artUri,
    ));

    try {
      final localPath = await DownloadService().getDownloadedPath(song.id);
      if (localPath != null) {
        await _player.setAudioSource(AudioSource.file(localPath));
      } else {
        await _player.setUrl(song.downloadUrl!);
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

      _taste.onSongPlayed(song);
      if (_isPlaylistMode) {
        _preloadNextSong();
      } else {
        _loadSuggestions(song.id).then((_) {
          _preloadNextSong();
        });
      }
    } catch (e, s) {
      debugPrint('Playback error: $e\n$s');
      final isDownloaded = DownloadService().isSongDownloaded(song.id);
      if (!isDownloaded) {
        playbackErrorNotifier.value = 'Offline: This song is not downloaded.';
        playbackErrorNotifier.value = null;
      } else {
        playbackErrorNotifier.value = 'Failed to play downloaded song: $e';
        playbackErrorNotifier.value = null;
      }
      if (_currentSong?.id == song.id) {
        _currentSong = oldSong;
        _songStartTime = oldStartTime;
        _isLiked = oldLiked;
        currentSongNotifier.value = oldSong;
        isLikedNotifier.value = oldLiked;
        if (oldSong != null) {
          final oldArt = oldSong.imageLarge.isNotEmpty
              ? Uri.parse(oldSong.imageLarge)
              : (oldSong.imageMedium.isNotEmpty
                  ? Uri.parse(oldSong.imageMedium)
                  : null);
          mediaItem.add(MediaItem(
            id: oldSong.id,
            title: oldSong.name,
            artist: oldSong.artistNames,
            album: oldSong.albumName,
            duration: Duration(seconds: oldSong.duration),
            artUri: oldArt,
          ));
        } else {
          mediaItem.add(null);
        }
      }
    }
  }

  Future<void> playSong(Song song, {List<Song>? playlist}) async {
    if (playlist != null && playlist.isNotEmpty) {
      _currentPlaylist = List<Song>.from(playlist);
      _currentIndex = _currentPlaylist!.indexWhere((s) => s.id == song.id);
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

  void restoreSong(Song song) {
    _currentSong = song;
    _currentPlaylist = [song];
    _currentIndex = 0;
    _isPlaylistMode = false;
    _songStartTime = DateTime.now();
    _isLiked = LikedService().isLiked(song.id);
    currentSongNotifier.value = song;
    isLikedNotifier.value = _isLiked;

    final artUri = song.imageLarge.isNotEmpty
        ? Uri.parse(song.imageLarge)
        : (song.imageMedium.isNotEmpty
            ? Uri.parse(song.imageMedium)
            : null);

    mediaItem.add(MediaItem(
      id: song.id,
      title: song.name,
      artist: song.artistNames,
      album: song.albumName,
      duration: Duration(seconds: song.duration),
      artUri: artUri,
    ));

    if (song.downloadUrl != null && song.downloadUrl!.isNotEmpty) {
      DownloadService().getDownloadedPath(song.id).then((localPath) {
        if (localPath != null) {
          _player.setAudioSource(AudioSource.file(localPath)).catchError((e) {
            debugPrint('restoreSong preload error: $e');
            return null;
          });
        } else {
          _player.setUrl(song.downloadUrl!).catchError((e) {
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
      final valid = suggestions.where((s) => s.downloadUrl != null).toList();
      final ranked = _taste.rankSuggestions(valid);
      for (final s in ranked) {
        if (_currentPlaylist != null && !_currentPlaylist!.any((x) => x.id == s.id)) {
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

    if (_currentIndex < _currentPlaylist!.length - 1) {
      _currentIndex++;
      await _playSongInternal(_currentPlaylist![_currentIndex]);
    } else {
      if (_isPlaylistMode) {
        _currentIndex = 0;
        await _playSongInternal(_currentPlaylist![_currentIndex]);
      } else if (_currentSong != null) {
        await _loadSuggestions(_currentSong!.id);
        if (_currentIndex < _currentPlaylist!.length - 1) {
          _currentIndex++;
          await _playSongInternal(_currentPlaylist![_currentIndex]);
        }
      }
    }
  }

  @override
  Future<void> skipToPrevious() async {
    if (_currentPlaylist == null || _currentPlaylist!.isEmpty) return;

    if (_currentIndex > 0) {
      _currentIndex--;
      await _playSongInternal(_currentPlaylist![_currentIndex]);
    } else {
      if (_isPlaylistMode) {
        _currentIndex = _currentPlaylist!.length - 1;
        await _playSongInternal(_currentPlaylist![_currentIndex]);
      } else {
        await _player.seek(Duration.zero);
      }
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
      final wasLiked = LikedService().isLiked(_currentSong!.id);
      LikedService().toggleLike(_currentSong!);
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

  void _preloadSongAndDetails(Song nextSong) {
    if (_preloadedSongId == nextSong.id) return;
    _preloadedSongId = nextSong.id;

    _api.getLyrics(
      nextSong.id,
      trackName: nextSong.name,
      artistName: nextSong.artistNames,
      albumName: nextSong.albumName,
      durationSecs: nextSong.duration,
    ).catchError((e) => LyricsResult());

    if (nextSong.downloadUrl != null && nextSong.downloadUrl!.isNotEmpty) {
      _preloadPlayer.setUrl(nextSong.downloadUrl!).catchError((e) {
        debugPrint('Preload error for ${nextSong.id}: $e');
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
