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
    final imageRaw = json['image'];
    final images = imageRaw is List ? imageRaw : const [];

    final artistsRaw = json['artists']?['primary'];
    final artists = artistsRaw is List ? artistsRaw : const [];

    final artistNamesList = artists
        .map((a) => (a is Map && a['name'] != null) ? a['name'].toString() : '')
        .where((n) => n.isNotEmpty)
        .toList();

    final dlRaw = json['downloadUrl'];
    final downloadUrls = dlRaw is List ? dlRaw : const [];

    String? bestDownload;
    for (final dl in downloadUrls.reversed) {
      if (dl is Map && dl['url'] != null) {
        bestDownload = dl['url'].toString();
        break;
      }
    }

    String getImageUrl(int index) {
      if (index >= 0 && index < images.length) {
        final item = images[index];
        if (item is Map && item['url'] != null) {
          return item['url'].toString();
        }
      }
      return '';
    }

    return Song(
      id: json['id']?.toString() ?? '',
      name: _cleanHtml(json['name']?.toString() ?? ''),
      year: json['year']?.toString() ?? '',
      duration: json['duration'] as int? ?? 0,
      playCount: json['playCount'] as int? ?? 0,
      language: json['language']?.toString() ?? '',
      albumName: _cleanHtml(json['album']?['name']?.toString() ?? ''),
      albumId: json['album']?['id']?.toString() ?? '',
      artistNames: artistNamesList.join(', '),
      artistIds: artists
          .map((a) => (a is Map && a['id'] != null) ? a['id'].toString() : '')
          .where((id) => id.isNotEmpty)
          .toList(),
      imageSmall: getImageUrl(0),
      imageMedium: getImageUrl(1),
      imageLarge: getImageUrl(2),
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
