class Song {
  final String id;
  final String name;
  final String year;
  final int duration;
  final int playCount;
  final String language;
  final String albumName;
  final String albumId;
  final String artistNames;
  final List<String> artistIds;
  final String imageSmall;
  final String imageMedium;
  final String imageLarge;
  final String? downloadUrl;

  Song({
    required this.id,
    required this.name,
    required this.year,
    required this.duration,
    required this.playCount,
    required this.language,
    required this.albumName,
    required this.albumId,
    required this.artistNames,
    required this.artistIds,
    required this.imageSmall,
    required this.imageMedium,
    required this.imageLarge,
    this.downloadUrl,
  });

  factory Song.fromJson(Map<String, dynamic> json) {
    final images = json['image'] as List? ?? [];
    final artists = json['artists']?['primary'] as List? ?? [];
    final artistNamesList =
        artists.map((a) => a['name'] as String).toList();
    final downloadUrls = json['downloadUrl'] as List? ?? [];

    String? bestDownload;
    for (final dl in downloadUrls.reversed) {
      if (dl['url'] != null) {
        bestDownload = dl['url'] as String;
        break;
      }
    }

    return Song(
      id: json['id'] as String? ?? '',
      name: _cleanHtml(json['name'] as String? ?? ''),
      year: json['year'] as String? ?? '',
      duration: json['duration'] as int? ?? 0,
      playCount: json['playCount'] as int? ?? 0,
      language: json['language'] as String? ?? '',
      albumName: _cleanHtml(json['album']?['name'] as String? ?? ''),
      albumId: json['album']?['id'] as String? ?? '',
      artistNames: artistNamesList.join(', '),
      artistIds: artists.map((a) => a['id'] as String).toList(),
      imageSmall: images.isNotEmpty ? images[0]['url'] as String : '',
      imageMedium: images.length > 1 ? images[1]['url'] as String : '',
      imageLarge: images.length > 2 ? images[2]['url'] as String : '',
      downloadUrl: bestDownload,
    );
  }

  String get durationFormatted {
    final m = duration ~/ 60;
    final s = duration % 60;
    return '$m:${s.toString().padLeft(2, '0')}';
  }

  String get playCountFormatted {
    if (playCount >= 1000000000) {
      return '${(playCount / 1000000000).toStringAsFixed(1)}B';
    } else if (playCount >= 1000000) {
      return '${(playCount / 1000000).toStringAsFixed(1)}M';
    } else if (playCount >= 1000) {
      return '${(playCount / 1000).toStringAsFixed(1)}K';
    }
    return '$playCount';
  }

  static String _cleanHtml(String text) {
    return text
        .replaceAll('&quot;', '"')
        .replaceAll('&amp;', '&')
        .replaceAll('&lt;', '<')
        .replaceAll('&gt;', '>')
        .replaceAll('&#039;', "'");
  }
}
