import 'package:flutter/foundation.dart';
import 'package:just_audio/just_audio.dart';
import 'package:audio_service/audio_service.dart';
import 'package:audio_session/audio_session.dart';
import 'api_service.dart';
import 'user_data_service.dart';
import 'taste_service.dart';
import 'download_service.dart';
import '../models/song.dart';
import '../models/lyrics.dart';

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
  final ApiService _api = ApiService();
  final TasteService _taste = TasteService();
  DateTime? _songStartTime;
  String? _prefetchedLyricsSongId;

  Song? _currentSong;
  List<Song>? _currentPlaylist;
  int _currentIndex = -1;
  bool _isPlaylistMode = false;
  bool _isRepeat = false;
  bool _isLiked = false;

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
          _loadLyricsForNextSong();
        }
      }
    });

    UserDataService().likedNotifier.addListener(() {
      if (_currentSong != null) {
        final liked = UserDataService().isLiked(_currentSong!.id);
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

  Future<bool> _playSongInternal(Song song, {bool showErrorMessage = true}) async {
    final id = song.id;
    if (id.isEmpty) return false;

    String downloadUrl = song.downloadUrl ?? '';
    Song resolvedSong = song;

    if (downloadUrl.isEmpty) {
      try {
        final fresh = await _api.getSongDetails(id);
        if (fresh != null && (fresh.downloadUrl ?? '').isNotEmpty) {
          downloadUrl = fresh.downloadUrl!;
          resolvedSong = fresh;
        }
      } catch (_) {}
    }

    if (downloadUrl.isEmpty) {
      if (showErrorMessage) {
        _showError('Cannot play: No stream URL available.');
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

    final imgLarge = resolvedSong.imageLarge ?? '';
    final imgMedium = resolvedSong.image ?? '';
    final artUri = imgLarge.isNotEmpty
        ? Uri.parse(imgLarge)
        : (imgMedium.isNotEmpty
            ? Uri.parse(imgMedium)
            : null);

    final duration = resolvedSong.duration;
    mediaItem.add(MediaItem(
      id: id,
      title: resolvedSong.name,
      artist: resolvedSong.artist,
      album: resolvedSong.album ?? '',
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

      if (oldSong != null && oldStartTime != null) {
        final playedSeconds = DateTime.now().difference(oldStartTime).inSeconds;
        if (playedSeconds >= 30) {
          _taste.onSongCompleted(oldSong);
        }
      }

      _taste.onSongPlayed(resolvedSong);
      if (!_isPlaylistMode) {
        _loadSuggestions(id);
      }
      return true;
    } catch (e, s) {
      debugPrint('Playback error: $e\n$s');
      if (showErrorMessage) {
        final isDownloaded = DownloadService().isSongDownloaded(id);
        if (!isDownloaded) {
          _showError('Offline: This song is not downloaded.');
        } else {
          _showError('Failed to play downloaded song: $e');
        }
      }
      if (_currentSong?.id == id) {
        _currentSong = oldSong;
        _songStartTime = oldStartTime;
        _isLiked = oldLiked;
        currentSongNotifier.value = oldSong;
        isLikedNotifier.value = oldLiked;
        if (oldSong != null) {
          final oldImgLarge = oldSong.imageLarge ?? '';
          final oldImgMedium = oldSong.image ?? '';
          final oldArt = oldImgLarge.isNotEmpty
              ? Uri.parse(oldImgLarge)
              : (oldImgMedium.isNotEmpty
                  ? Uri.parse(oldImgMedium)
                  : null);
          final oldDur = oldSong.duration;
          mediaItem.add(MediaItem(
            id: oldSong.id,
            title: oldSong.name,
            artist: oldSong.artist,
            album: oldSong.album ?? '',
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

  Future<void> playSong(Song song, {List<Song>? playlist}) async {
    final id = song.id;
    if (playlist != null && playlist.isNotEmpty) {
      _currentPlaylist = List<Song>.from(playlist);
      _currentIndex = _currentPlaylist!.indexWhere((s) => s.id == id);
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
    final id = song.id;
    _currentSong = song;
    _currentPlaylist = [song];
    _currentIndex = 0;
    _isPlaylistMode = false;
    _songStartTime = DateTime.now();
    _isLiked = UserDataService().isLiked(id);
    currentSongNotifier.value = song;
    isLikedNotifier.value = _isLiked;

    final imgLarge = song.imageLarge ?? '';
    final imgMedium = song.image ?? '';
    final artUri = imgLarge.isNotEmpty
        ? Uri.parse(imgLarge)
        : (imgMedium.isNotEmpty
            ? Uri.parse(imgMedium)
            : null);

    final duration = song.duration;
    mediaItem.add(MediaItem(
      id: id,
      title: song.name,
      artist: song.artist,
      album: song.album ?? '',
      duration: Duration(seconds: duration),
      artUri: artUri,
    ));

    final downloadUrl = song.downloadUrl ?? '';
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
      final valid = suggestions.where((s) => s.downloadUrl != null).toList();
      final ranked = _taste.rankSuggestions(valid);
      for (final song in ranked) {
        if (_currentPlaylist != null && !_currentPlaylist!.any((x) => x.id == song.id)) {
          _currentPlaylist!.add(song);
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

  void _showError(String message) {
    playbackErrorNotifier.value = message;
    Future.delayed(const Duration(seconds: 4), () {
      if (playbackErrorNotifier.value == message) {
        playbackErrorNotifier.value = null;
      }
    });
  }

  @override
  Future<void> stop() async {
    await _player.stop();
    return super.stop();
  }

  @override
  Future<void> skipToNext() async {
    if (_currentPlaylist == null || _currentPlaylist!.isEmpty) return;

    if (_currentIndex < _currentPlaylist!.length - 1) {
      _currentIndex++;
    } else {
      if (_isPlaylistMode) return;
      final currentId = _currentSong?.id ?? '';
      if (currentId.isEmpty) return;
      final oldLength = _currentPlaylist!.length;
      await _loadSuggestions(currentId);
      if (_currentPlaylist!.length <= oldLength) return;
      _currentIndex = oldLength;
    }

    final song = _currentPlaylist![_currentIndex];
    await _playSongInternal(song);
  }

  @override
  Future<void> skipToPrevious() async {
    if (_currentPlaylist == null || _currentPlaylist!.isEmpty) return;

    if (_currentIndex > 0) {
      _currentIndex--;
    } else {
      if (!_isPlaylistMode) {
        await _player.seek(Duration.zero);
      }
      return;
    }

    final song = _currentPlaylist![_currentIndex];
    await _playSongInternal(song);
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
      final id = _currentSong!.id;
      if (id.isEmpty) return;
      UserDataService().toggleLike(_currentSong!);
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

  void _loadLyricsForNextSong() {
    if (_currentPlaylist == null || _currentPlaylist!.isEmpty) return;
    int nextIdx = _currentIndex + 1;
    if (nextIdx >= _currentPlaylist!.length) return;
    final nextSong = _currentPlaylist![nextIdx];

    final id = nextSong.id;
    if (id.isEmpty) return;
    if (_prefetchedLyricsSongId == id) return;
    _prefetchedLyricsSongId = id;
    final name = nextSong.name;
    final artist = nextSong.artist;
    final album = nextSong.album ?? '';
    final duration = nextSong.duration;

    _api.getLyrics(id, trackName: name, artistName: artist, albumName: album, durationSecs: duration)
        .catchError((e) => LyricsResult());
  }

  void clear() {
    _player.stop();
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
