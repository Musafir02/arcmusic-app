import 'dart:math';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:package_info_plus/package_info_plus.dart';
import '../core/api_service.dart';
import '../core/theme.dart';
import '../core/config.dart';
import '../core/player_service.dart';
import '../core/taste_service.dart';
import 'search_screen.dart';
import 'liked_screen.dart';
import 'playlists_screen.dart';
import '../widgets/song_card.dart';
import '../widgets/song_tile.dart';
import '../widgets/common_components.dart';
import '../core/update_service.dart';
import 'update_dialog.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final ApiService _api = ApiService();
  final TasteService _taste = TasteService();
  final List<_SongSection> _sections = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _initData();
  }

  Future<void> _initData() async {
    await _taste.load();
    _restoreLastSong();
    await _fetchHomeData();
    _checkUpdate();
  }

  Future<void> _checkUpdate() async {
    await UpdateService().checkForUpdate();
    if (!mounted) return;
    final info = UpdateService().updateAvailableNotifier.value;
    if (info != null) {
      await Future.delayed(const Duration(milliseconds: 800));
      if (mounted) UpdateDialog.show(context, info);
    }
  }

  Future<void> _showProfileSheet(BuildContext context, User? user) async {
    final info = await PackageInfo.fromPlatform();
    if (!context.mounted) return;
    final appVersion = info.version;

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (ctx) => Container(
        decoration: const BoxDecoration(
          color: AppTheme.surface,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        padding: EdgeInsets.fromLTRB(24, 20, 24, MediaQuery.of(ctx).viewInsets.bottom + 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Center(
              child: Container(
                width: 40, height: 4,
                decoration: BoxDecoration(
                  color: AppTheme.textSecondary.withValues(alpha: 0.3),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 24),
            CircleAvatar(
              radius: 40,
              backgroundColor: AppTheme.background,
              backgroundImage: user?.photoURL != null ? NetworkImage(user!.photoURL!) : null,
              child: user?.photoURL == null ? const Icon(Icons.person_rounded, size: 40, color: AppTheme.accent) : null,
            ),
            const SizedBox(height: 16),
            Text(
              user?.displayName ?? 'Listener',
              style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800, color: AppTheme.textPrimary),
            ),
            const SizedBox(height: 4),
            Text(
              user?.email ?? 'No email',
              style: const TextStyle(fontSize: 14, color: AppTheme.textSecondary),
            ),
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
              decoration: BoxDecoration(
                color: AppTheme.background,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                'v$appVersion',
                style: const TextStyle(fontSize: 12, color: AppTheme.accent, fontWeight: FontWeight.w600),
              ),
            ),
            const SizedBox(height: 28),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: () async {
                  Navigator.pop(ctx);
                  await FirebaseAuth.instance.signOut();
                },
                icon: const Icon(Icons.logout_rounded, size: 18),
                label: const Text('Sign Out', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
                style: OutlinedButton.styleFrom(
                  foregroundColor: Colors.redAccent,
                  side: const BorderSide(color: Colors.redAccent),
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _restoreLastSong() {
    if (audioHandler.currentSong != null) return;
    final lastSong = _taste.getLastSong();
    if (lastSong != null && lastSong['downloadUrl'] != null) {
      audioHandler.restoreSong(lastSong);
    }
  }

  Future<void> _fetchHomeData() async {
    final year = DateTime.now().year;
    final futures = <Future<List<Map<String, dynamic>>>>[];
    final names = <String>[];

    final topArtists = _taste.topArtistNames;
    if (topArtists.isNotEmpty) {
      names.add('For You: ${topArtists.first}');
      futures.add(_api.searchSongs(topArtists.first, limit: 10));
    }

    final topMoods = _taste.topMoods;
    if (topMoods.isNotEmpty) {
      final mood = topMoods.first;
      names.add(MoodConstants.titles[mood] ?? mood);
      final queries = MoodConstants.getSearchQueries(mood, year);
      futures.add(_api.searchSongs(queries.isNotEmpty ? queries.first : mood, limit: 10));
    }

    names.addAll(['Trending Now', 'Top Hits']);
    futures.add(_api.searchSongs('trending songs $year', limit: 10));
    futures.add(_api.searchSongs('top hindi hits $year', limit: 10));

    try {
      final results = await Future.wait(futures);
      _sections.clear();
      for (int i = 0; i < names.length; i++) {
        if (results[i].isNotEmpty) {
          _sections.add(_SongSection(names[i], results[i]));
        }
      }
    } catch (_) {}

    if (mounted) {
      setState(() => _isLoading = false);
    }
  }

  String _getGreeting() {
    final hour = DateTime.now().hour;
    if (hour < 12) return 'Good Morning';
    if (hour < 17) return 'Good Afternoon';
    return 'Good Evening';
  }

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    final name = user?.displayName ?? 'Listener';
    final recents = _taste.recentlyPlayed;

    return Scaffold(
      backgroundColor: AppTheme.background,
      body: SafeArea(
        child: RefreshIndicator(
          color: AppTheme.accent,
          backgroundColor: AppTheme.surface,
          onRefresh: _fetchHomeData,
          child: CustomScrollView(
            physics: const BouncingScrollPhysics(),
            slivers: [
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(20, 24, 20, 16),
                sliver: SliverToBoxAdapter(
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(_getGreeting(), style: const TextStyle(fontSize: 14, color: AppTheme.textSecondary, fontWeight: FontWeight.w500)),
                          const SizedBox(height: 4),
                          Text(name, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w800, color: AppTheme.textPrimary)),
                        ],
                      ),
                      GestureDetector(
                        onTap: () => _showProfileSheet(context, user),
                        child: CircleAvatar(
                          radius: 20,
                          backgroundColor: AppTheme.surface,
                          backgroundImage: user?.photoURL != null ? NetworkImage(user!.photoURL!) : null,
                          child: user?.photoURL == null ? const Icon(Icons.person_rounded, color: AppTheme.accent) : null,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              SliverPadding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                sliver: SliverToBoxAdapter(
                  child: GestureDetector(
                    onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const SearchScreen())),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      decoration: BoxDecoration(
                        color: AppTheme.surface,
                        borderRadius: BorderRadius.circular(50),
                        border: Border.all(color: AppTheme.textSecondary.withValues(alpha: 0.1)),
                      ),
                      child: const Row(
                        children: [
                          Icon(Icons.search_rounded, color: AppTheme.textSecondary, size: 20),
                          SizedBox(width: 12),
                          Text('Search songs, artists, moods...', style: TextStyle(color: AppTheme.textSecondary, fontSize: 14)),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(20, 24, 20, 0),
                sliver: SliverToBoxAdapter(
                  child: Row(
                    children: [
                      Expanded(
                        child: ActionButton(
                          label: 'Liked Songs',
                          icon: Icons.favorite_rounded,
                          filled: false,
                          onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const LikedScreen())),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: ActionButton(
                          label: 'Playlists',
                          icon: Icons.playlist_play_rounded,
                          filled: false,
                          onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const PlaylistsScreen())),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              if (_isLoading)
                const SliverFillRemaining(child: CommonLoader())
              else ...[
                if (recents.isNotEmpty) ...[
                  const SliverPadding(
                    padding: EdgeInsets.fromLTRB(20, 28, 20, 12),
                    sliver: SliverToBoxAdapter(child: SectionHeader(title: 'Recently Played')),
                  ),
                  SliverPadding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    sliver: SliverList(
                      delegate: SliverChildBuilderDelegate(
                        (context, index) {
                          final song = recents[index];
                          return SongTile(
                            song: song,
                            index: index,
                            onTap: () => audioHandler.playSong(song, playlist: recents),
                          );
                        },
                        childCount: min(recents.length, 5),
                      ),
                    ),
                  ),
                ],
                const SliverPadding(
                  padding: EdgeInsets.fromLTRB(20, 24, 20, 12),
                  sliver: SliverToBoxAdapter(child: SectionHeader(title: 'Browse Moods')),
                ),
                SliverPadding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  sliver: SliverToBoxAdapter(
                    child: SizedBox(
                      height: 40,
                      child: ListView(
                        scrollDirection: Axis.horizontal,
                        physics: const BouncingScrollPhysics(),
                        children: MoodConstants.keywords.keys.map((mood) {
                          final title = MoodConstants.titles[mood] ?? mood;
                          return Padding(
                            padding: const EdgeInsets.only(right: 8),
                            child: FilterChip(
                              label: Text(title, style: const TextStyle(fontSize: 12)),
                              backgroundColor: AppTheme.surface,
                              side: BorderSide(color: AppTheme.textSecondary.withValues(alpha: 0.1)),
                              onSelected: (_) {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(builder: (_) => SearchScreen(initialQuery: mood)),
                                );
                              },
                            ),
                          );
                        }).toList(),
                      ),
                    ),
                  ),
                ),
                ..._sections.map((sec) {
                  return SliverMainAxisGroup(
                    slivers: [
                      SliverPadding(
                        padding: const EdgeInsets.fromLTRB(20, 28, 20, 12),
                        sliver: SliverToBoxAdapter(child: SectionHeader(title: sec.title)),
                      ),
                      SliverPadding(
                        padding: const EdgeInsets.symmetric(horizontal: 20),
                        sliver: SliverToBoxAdapter(
                          child: SizedBox(
                            height: 220,
                            child: ListView.builder(
                              scrollDirection: Axis.horizontal,
                              physics: const BouncingScrollPhysics(),
                              itemCount: sec.songs.length,
                              itemBuilder: (context, index) {
                                final song = sec.songs[index];
                                return SongCard(
                                  song: song,
                                  onTap: () => audioHandler.playSong(song, playlist: sec.songs),
                                );
                              },
                            ),
                          ),
                        ),
                      ),
                    ],
                  );
                }),
                const SliverToBoxAdapter(child: SizedBox(height: 100)),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _SongSection {
  final String title;
  final List<Map<String, dynamic>> songs;
  const _SongSection(this.title, this.songs);
}
