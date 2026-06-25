import 'package:flutter/material.dart';
import 'package:package_info_plus/package_info_plus.dart';
import '../core/api_service.dart';
import '../core/auth_service.dart';
import '../core/theme.dart';
import '../models/song.dart';
import '../widgets/song_card.dart';
import '../widgets/song_tile.dart';
import '../widgets/section_header.dart';
import '../core/player_service.dart';
import '../core/taste_service.dart';
import 'search_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final ApiService _api = ApiService();
  final AuthService _auth = AuthService();
  final TasteService _taste = TasteService();

  final List<_SongSection> _sections = [];
  List<Song> _latestSongs = [];
  List<Song> _recentSongs = [];
  bool _isFirstLoad = true;

  @override
  void initState() {
    super.initState();
    _initAndFetch();
  }

  Future<void> _initAndFetch() async {
    await _taste.load();
    _restoreLastSong();
    _buildRecentSongs();
    await _fetchAll();
  }

  void _restoreLastSong() {
    if (audioHandler.currentSong != null) return;
    final lastSong = _taste.getLastSong();
    if (lastSong != null && lastSong.downloadUrl != null) {
      audioHandler.restoreSong(lastSong);
    }
  }

  void _buildRecentSongs() {
    final recent = _taste.recentlyPlayed;
    final songs = <Song>[];
    final seenIds = <String>{};
    for (final data in recent) {
      final id = data['songId'] as String? ?? '';
      if (id.isEmpty || seenIds.contains(id)) continue;
      if (data['downloadUrl'] == null) continue;
      seenIds.add(id);
      try {
        songs.add(Song(
          id: id,
          name: data['name'] as String? ?? '',
          year: data['year'] as String? ?? '',
          duration: data['duration'] as int? ?? 0,
          playCount: data['playCount'] as int? ?? 0,
          language: data['language'] as String? ?? '',
          albumName: data['albumName'] as String? ?? '',
          albumId: data['albumId'] as String? ?? '',
          artistNames: data['artist'] as String? ?? '',
          artistIds: List<String>.from(data['artistIds'] as List? ?? []),
          imageSmall: data['imageSmall'] as String? ?? '',
          imageMedium: data['image'] as String? ?? '',
          imageLarge: data['imageLarge'] as String? ?? '',
          downloadUrl: data['downloadUrl'] as String?,
        ));
      } catch (_) {}
      if (songs.length >= 15) break;
    }
    _recentSongs = songs;
  }

  Future<void> _fetchAll() async {
    _buildRecentSongs();
    final year = DateTime.now().year;
    final sections = <_SongSection>[];
    final futures = <Future<List<Song>>>[];
    final sectionNames = <String>[];

    if (_taste.hasProfile) {
      final topArtists = _taste.topArtistNames;
      if (topArtists.isNotEmpty) {
        sectionNames.add('Because you like ${topArtists.first}');
        futures.add(_api.searchSongs(topArtists.first, limit: 15));
      }

      final moods = _taste.topMoods;
      final moodTitles = {
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
      final moodSearches = {
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

      for (final mood in moods.take(2)) {
        final title = moodTitles[mood] ?? mood;
        final pool = moodSearches[mood];
        if (pool != null && pool.isNotEmpty) {
          final copy = List<String>.from(pool)..shuffle();
          sectionNames.add(title);
          futures.add(_api.searchSongs(copy.first, limit: 15));
        }
      }

      if (topArtists.length > 1) {
        sectionNames.add('More from ${topArtists[1]}');
        futures.add(_api.searchSongs(topArtists[1], limit: 15));
      }

      final personalQueries = _taste.getPersonalizedQueries();
      for (final q in personalQueries.take(1)) {
        sectionNames.add('Your Mix');
        futures.add(_api.searchSongs(q, limit: 15));
      }
    }

    final genericQueries = {
      'Trending Now': [
        'trending songs $year', 'viral songs', 'chartbusters', 'popular hits'
      ],
      'Top Songs': [
        'top hits $year', 'best songs $year', 'popular songs', 'hit songs'
      ],
    };

    for (final entry in genericQueries.entries) {
      final pool = List<String>.from(entry.value)..shuffle();
      sectionNames.add(entry.key);
      futures.add(_api.searchSongs(pool.first, limit: 15));
    }

    final latestPool = [
      'new releases $year', 'latest songs $year', 'new songs', 'fresh releases'
    ]..shuffle();

    futures.add(_api.searchSongs(latestPool.first, limit: 20));

    try {
      final results = await Future.wait(futures);

      for (int i = 0; i < sectionNames.length; i++) {
        if (results[i].isNotEmpty) {
          sections.add(_SongSection(sectionNames[i], results[i]));
        }
      }

      if (mounted) {
        setState(() {
          _sections
            ..clear()
            ..addAll(sections);
          _latestSongs = results.last;
          _isFirstLoad = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _isFirstLoad = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: _isFirstLoad ? _buildFirstLoad() : _buildContent(),
      ),
    );
  }

  Widget _buildFirstLoad() {
    return Column(
      children: [
        _buildHeader(),
        const Expanded(
          child: Center(
            child: CircularProgressIndicator(
              color: AppTheme.accent,
              strokeWidth: 2.5,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildContent() {
    return RefreshIndicator(
      color: AppTheme.accent,
      backgroundColor: AppTheme.surface,
      onRefresh: _fetchAll,
      child: CustomScrollView(
        physics: const AlwaysScrollableScrollPhysics(
          parent: BouncingScrollPhysics(),
        ),
        slivers: [
          SliverToBoxAdapter(child: _buildHeader()),
          if (_recentSongs.isNotEmpty) ...[
            const SliverToBoxAdapter(
              child: SectionHeader(title: 'Recently Played'),
            ),
            SliverToBoxAdapter(child: _buildHorizontalList(_recentSongs)),
          ],
          for (final section in _sections) ...[
            SliverToBoxAdapter(
              child: SectionHeader(title: section.title),
            ),
            SliverToBoxAdapter(child: _buildHorizontalList(section.songs)),
          ],
          if (_latestSongs.isNotEmpty) ...[
            const SliverToBoxAdapter(
              child: SectionHeader(title: 'Latest Releases'),
            ),
            SliverList(
              delegate: SliverChildBuilderDelegate(
                (context, index) => Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: SongTile(
                    song: _latestSongs[index],
                    index: index,
                    onTap: () => audioHandler.playSong(
                      _latestSongs[index],
                      playlist: _latestSongs,
                    ),
                  ),
                ),
                childCount: _latestSongs.length,
              ),
            ),
          ],
          const SliverToBoxAdapter(child: SizedBox(height: 40)),
        ],
      ),
    );
  }

  Widget _buildHeader() {
    final user = _auth.currentUser;
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 16, 16, 0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          const Text(
            'ArcMusic',
            style: TextStyle(
              fontSize: 26,
              fontWeight: FontWeight.w800,
              color: AppTheme.textPrimary,
              letterSpacing: -0.8,
            ),
          ),
          Row(
            children: [
              GestureDetector(
                onTap: () {
                  Navigator.push(
                    context,
                    PageRouteBuilder(
                      pageBuilder: (_, __, ___) => const SearchScreen(),
                      transitionsBuilder: (_, anim, __, child) {
                        return FadeTransition(opacity: anim, child: child);
                      },
                      transitionDuration: const Duration(milliseconds: 200),
                    ),
                  );
                },
                child: Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: AppTheme.surface,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(
                    Icons.search_rounded,
                    color: AppTheme.textPrimary,
                    size: 22,
                  ),
                ),
              ),
              const SizedBox(width: 10),
              GestureDetector(
                onTap: () => _showProfileSheet(context),
                child: user?.photoURL != null
                    ? CircleAvatar(
                        radius: 20,
                        backgroundImage: NetworkImage(user!.photoURL!),
                        backgroundColor: AppTheme.surface,
                      )
                    : CircleAvatar(
                        radius: 20,
                        backgroundColor: AppTheme.surface,
                        child: Text(
                          (user?.displayName ?? 'U')[0].toUpperCase(),
                          style: const TextStyle(
                            color: AppTheme.accent,
                            fontWeight: FontWeight.w700,
                            fontSize: 16,
                          ),
                        ),
                      ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildHorizontalList(List<Song> songs) {
    return SizedBox(
      height: 210,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 20),
        physics: const BouncingScrollPhysics(),
        itemCount: songs.length,
        itemBuilder: (context, index) => SongCard(
          song: songs[index],
          onTap: () => audioHandler.playSong(songs[index], playlist: songs),
        ),
      ),
    );
  }

  void _showProfileSheet(BuildContext context) async {
    final user = _auth.currentUser;
    final info = await PackageInfo.fromPlatform();

    if (!mounted) return;

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (ctx) => Container(
        decoration: const BoxDecoration(
          color: AppTheme.surface,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        padding: const EdgeInsets.fromLTRB(24, 12, 24, 40),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: AppTheme.textSecondary.withValues(alpha: 0.3),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 28),
            if (user?.photoURL != null)
              CircleAvatar(
                radius: 40,
                backgroundImage: NetworkImage(user!.photoURL!),
                backgroundColor: AppTheme.background,
              )
            else
              CircleAvatar(
                radius: 40,
                backgroundColor: AppTheme.accent.withValues(alpha: 0.15),
                child: Text(
                  (user?.displayName ?? 'U')[0].toUpperCase(),
                  style: const TextStyle(
                    fontSize: 32,
                    fontWeight: FontWeight.w700,
                    color: AppTheme.accent,
                  ),
                ),
              ),
            const SizedBox(height: 18),
            Text(
              user?.displayName ?? 'User',
              style: const TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w700,
                color: AppTheme.textPrimary,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              user?.email ?? '',
              style: const TextStyle(
                fontSize: 14,
                color: AppTheme.textSecondary,
              ),
            ),
            const SizedBox(height: 10),
            Text(
              'v${info.version} (${info.buildNumber})',
              style: TextStyle(
                fontSize: 12,
                color: AppTheme.textSecondary.withValues(alpha: 0.6),
              ),
            ),
            const SizedBox(height: 32),
            SizedBox(
              width: double.infinity,
              height: 50,
              child: ElevatedButton(
                onPressed: () {
                  Navigator.pop(ctx);
                  _auth.signOut();
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.accent.withValues(alpha: 0.12),
                  foregroundColor: AppTheme.accent,
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
                child: const Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.logout_rounded, size: 20),
                    SizedBox(width: 10),
                    Text(
                      'Sign Out',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SongSection {
  final String title;
  final List<Song> songs;
  _SongSection(this.title, this.songs);
}
