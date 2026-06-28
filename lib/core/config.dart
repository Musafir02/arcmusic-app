class AppConfig {
  static const String apiBaseUrl = 'https://arcmusic-api.vercel.app';
  static const String spotifyApiUrl = 'https://arcmusic-spotify.vercel.app';
  static const String githubReleasesUrl = 'https://api.github.com/repos/Musafir02/arcmusic-app/releases/latest';

  static const int lyricsCacheMaxSize = 50;
  static const int maxRecentSongs = 15;

  static const Duration httpTimeout = Duration(seconds: 10);
  static const Duration spotifyTimeout = Duration(seconds: 30);

  static const String keyDownloadedSongIds = 'downloaded_song_ids';
  static const String keyDownloadedSongsList = 'downloaded_songs_list';
}

class MoodConstants {
  static const Map<String, List<String>> keywords = {
    'romantic': ['love', 'romance', 'pyaar', 'ishq', 'dil', 'heart', 'mohabbat', 'prem'],
    'sad': ['sad', 'broken', 'pain', 'dard', 'judai', 'tanha', 'alone', 'cry', 'rona', 'bewafa'],
    'party': ['party', 'dance', 'club', 'dj', 'bass', 'beat', 'nach', 'garba'],
    'chill': ['lofi', 'chill', 'relax', 'calm', 'sleep', 'peace', 'soothing', 'acoustic'],
    'devotional': ['bhajan', 'aarti', 'mantra', 'prayer', 'devotional', 'kirtan', 'hanuman', 'ram', 'krishna', 'shiv'],
    'rap': ['rap', 'hip hop', 'hiphop', 'freestyle', 'bars'],
    'pop': ['pop', 'viral', 'trending'],
    'folk': ['folk', 'sufi', 'qawwali', 'classical', 'ghazal'],
    'workout': ['gym', 'workout', 'pump', 'energy', 'motivation', 'power'],
    'retro': ['old', 'classic', 'retro', '90s', '80s', '70s', 'purane', 'evergreen'],
  };

  static const Map<String, String> titles = {
    'romantic': 'Your Vibe: Romantic 💕',
    'sad': 'In Your Feels 🥀',
    'party': 'Party Mode 🎉',
    'chill': 'Chill Zone ✨',
    'devotional': 'Spiritual 🙏',
    'rap': 'Rap & Bars 🎤',
    'pop': 'Pop Hits 🔥',
    'folk': 'Folk & Sufi 🎶',
    'workout': 'Pump It Up 💪',
    'retro': 'Retro Classics 🕰️',
  };

  static List<String> getSearchQueries(String mood, int year) {
    final Map<String, List<String>> templates = {
      'romantic': ['romantic songs', 'love songs $year', 'romantic hits'],
      'sad': ['sad songs', 'heartbreak songs', 'emotional hits'],
      'party': ['party songs $year', 'dance hits', 'club bangers'],
      'chill': ['lofi songs', 'chill music', 'relaxing vibes'],
      'devotional': ['bhajan', 'devotional hits', 'aarti'],
      'rap': ['rap songs', 'hip hop $year', 'desi hip hop'],
      'pop': ['pop hits $year', 'viral songs', 'trending pop'],
      'folk': ['sufi songs', 'ghazals', 'folk hits'],
      'workout': ['workout songs', 'gym motivation', 'high energy'],
      'retro': ['old hindi songs', 'retro hits', 'evergreen songs'],
    };
    return templates[mood] ?? [];
  }
}
