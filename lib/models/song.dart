class Song {
  final String id;
  final String name;
  final String artist;
  final String? album;
  final String? downloadUrl;
  final String? image;
  final String? imageLarge;
  final String? imageSmall;
  final int duration;
  final String? timestamp;
  final bool? completed;

  const Song({
    required this.id,
    required this.name,
    required this.artist,
    this.album,
    this.downloadUrl,
    this.image,
    this.imageLarge,
    this.imageSmall,
    this.duration = 0,
    this.timestamp,
    this.completed,
  });

  factory Song.fromJson(Map<String, dynamic> json) {
    return Song(
      id: json['id']?.toString() ?? '',
      name: json['name'] as String? ?? '',
      artist: json['artist'] as String? ?? '',
      album: json['album'] as String?,
      downloadUrl: json['downloadUrl'] as String?,
      image: json['image'] as String?,
      imageLarge: json['imageLarge'] as String?,
      imageSmall: json['imageSmall'] as String?,
      duration: (json['duration'] as num?)?.toInt() ?? 0,
      timestamp: json['timestamp'] as String?,
      completed: json['completed'] as bool?,
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'artist': artist,
    'album': album,
    'downloadUrl': downloadUrl,
    'image': image,
    'imageLarge': imageLarge,
    'imageSmall': imageSmall,
    'duration': duration,
    if (timestamp != null) 'timestamp': timestamp,
    if (completed != null) 'completed': completed,
  };

  Song copyWith({
    String? id,
    String? name,
    String? artist,
    String? album,
    String? downloadUrl,
    String? image,
    String? imageLarge,
    String? imageSmall,
    int? duration,
    String? timestamp,
    bool? completed,
  }) {
    return Song(
      id: id ?? this.id,
      name: name ?? this.name,
      artist: artist ?? this.artist,
      album: album ?? this.album,
      downloadUrl: downloadUrl ?? this.downloadUrl,
      image: image ?? this.image,
      imageLarge: imageLarge ?? this.imageLarge,
      imageSmall: imageSmall ?? this.imageSmall,
      duration: duration ?? this.duration,
      timestamp: timestamp ?? this.timestamp,
      completed: completed ?? this.completed,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) || other is Song && id == other.id;

  @override
  int get hashCode => id.hashCode;
}
