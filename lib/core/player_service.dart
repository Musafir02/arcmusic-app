import 'package:flutter/foundation.dart';
import 'package:just_audio/just_audio.dart';
import 'package:audio_service/audio_service.dart';
import 'package:audio_session/audio_session.dart';
import '../models/song.dart';
import 'api_service.dart';
import 'taste_service.dart';

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

  Song? _currentSong;
  List<Song> _songQueue = [];
  final List<Song> _history = [];
  bool _isRepeat = false;
  bool _isLiked = false;

  final ValueNotifier<Song?> currentSongNotifier = ValueNotifier(null);
  final ValueNotifier<bool> isRepeatNotifier = ValueNotifier(false);
  final ValueNotifier<bool> isLikedNotifier = ValueNotifier(false);

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

  Future<void> playSong(Song song, {List<Song>? playlist}) async {
    if (song.downloadUrl == null || song.downloadUrl!.isEmpty) return;

    final oldSong = _currentSong;
    final oldStartTime = _songStartTime;
    final oldLiked = _isLiked;

    _currentSong = song;
    _songStartTime = DateTime.now();
    _isLiked = false;
    currentSongNotifier.value = song;
    isLikedNotifier.value = false;

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
      await _player.setUrl(song.downloadUrl!);
      await _player.play();

      if (oldSong != null) {
        final playedSeconds = oldStartTime != null
            ? DateTime.now().difference(oldStartTime).inSeconds
            : 0;
        if (playedSeconds < 30 && playedSeconds > 0) {
          _taste.onSongSkipped(oldSong);
        }
        _history.add(oldSong);
      }

      _taste.onSongPlayed(song);
      _loadSuggestions(song.id);
    } catch (e, s) {
      debugPrint('Playback error: $e\n$s');
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

  void restoreSong(Song song) {
    _currentSong = song;
    _songStartTime = DateTime.now();
    currentSongNotifier.value = song;
    isLikedNotifier.value = false;
    _isLiked = false;

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
      _player.setUrl(song.downloadUrl!).catchError((e) {
        debugPrint('restoreSong preload error: $e');
      });
    }
  }

  Future<void> _loadSuggestions(String songId) async {
    try {
      final suggestions = await _api.getSongSuggestions(songId, limit: 20);
      final valid = suggestions.where((s) => s.downloadUrl != null).toList();
      _songQueue = _taste.rankSuggestions(valid);
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
    return super.stop();
  }

  @override
  Future<void> skipToNext() async {
    if (_songQueue.isNotEmpty) {
      final next = _songQueue.removeAt(0);
      await playSong(next);
    }
  }

  @override
  Future<void> skipToPrevious() async {
    if (_player.position.inSeconds > 3) {
      await _player.seek(Duration.zero);
      return;
    }

    final skipped = <Song>[];
    while (_history.isNotEmpty) {
      final prev = _history.removeLast();
      if (prev.downloadUrl != null && prev.downloadUrl!.isNotEmpty) {
        if (_currentSong != null) _songQueue.insert(0, _currentSong!);
        await playSong(prev);
        return;
      }
      skipped.add(prev);
    }

    if (skipped.isNotEmpty) {
      debugPrint(
          'skipToPrevious: skipped ${skipped.length} unplayable history entries');
    }

    await _player.seek(Duration.zero);
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
    _isLiked = !_isLiked;
    isLikedNotifier.value = _isLiked;
    if (_isLiked && _currentSong != null) {
      _taste.onSongLiked(_currentSong!);
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

  void clear() {
    _player.stop();
    _currentSong = null;
    _songStartTime = null;
    _songQueue.clear();
    _history.clear();
    _isRepeat = false;
    _isLiked = false;
    currentSongNotifier.value = null;
    isRepeatNotifier.value = false;
    isLikedNotifier.value = false;
    mediaItem.add(null);
  }
}
