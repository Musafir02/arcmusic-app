class SpotifyTrack {
  final String name;
  final List<String> artists;
  final int durationMs;
  final String album;

  const SpotifyTrack({
    required this.name,
    required this.artists,
    required this.durationMs,
    required this.album,
  });

  String get primaryArtist => artists.isNotEmpty ? artists.first : '';
}

class SpotifyPlaylistResult {
  final String name;
  final String owner;
  final List<SpotifyTrack> tracks;

  const SpotifyPlaylistResult({
    required this.name,
    required this.owner,
    required this.tracks,
  });
}
