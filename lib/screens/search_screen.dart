import 'dart:async';
import 'package:flutter/material.dart';
import '../core/api_service.dart';
import '../core/theme.dart';
import '../widgets/song_tile.dart';
import '../core/player_service.dart';
import '../widgets/mini_player.dart';
import '../widgets/common_components.dart';
import '../models/song.dart';

class SearchScreen extends StatefulWidget {
  final String? initialQuery;
  const SearchScreen({super.key, this.initialQuery});

  @override
  State<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends State<SearchScreen> {
  final ApiService _api = ApiService();
  final TextEditingController _searchController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final FocusNode _focusNode = FocusNode();

  List<Song> _results = [];
  bool _isLoading = false;
  bool _isLoadingMore = false;
  bool _hasMore = true;
  int _currentPage = 1;
  String _currentQuery = '';
  Timer? _debounce;

  static const Map<String, String> _moodMap = {
    'sad': 'sad songs heartbreak emotional',
    'happy': 'happy upbeat feel good songs',
    'party': 'party dance club songs',
    'chill': 'chill relaxing calm songs',
    'lofi': 'lofi chill study beats',
    'romantic': 'romantic love songs',
    'workout': 'workout gym motivation songs',
    'devotional': 'devotional bhajan spiritual songs',
    'fun': 'fun party upbeat dance songs',
    'pop': 'pop hits popular songs',
    'rap': 'rap hip hop songs',
    'rock': 'rock band songs',
    'classical': 'classical instrumental raag',
    'sleep': 'sleep calm peaceful lullaby',
    'drive': 'driving road trip songs',
    'rain': 'rain monsoon romantic songs',
    'breakup': 'breakup heartbreak sad songs',
    'wedding': 'wedding sangeet celebration songs',
    'birthday': 'birthday celebration party songs',
    'sufi': 'sufi qawwali songs',
    'ghazal': 'ghazal poetry songs',
    'punjabi': 'punjabi bhangra songs',
    'old': 'old classic retro songs',
    'bollywood': 'bollywood hindi movie songs',
    'love': 'love romantic songs',
    'energetic': 'energetic high energy pump songs',
    'motivational': 'motivational inspirational songs',
    'melody': 'melody soulful melodious songs',
    'desi': 'desi indian songs',
    'edm': 'edm electronic dance music',
  };

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (widget.initialQuery != null && widget.initialQuery!.isNotEmpty) {
        _searchController.text = widget.initialQuery!;
        _performSearch(widget.initialQuery!);
      } else {
        _focusNode.requestFocus();
      }
    });
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _searchController.dispose();
    _scrollController.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (_scrollController.position.pixels >= _scrollController.position.maxScrollExtent - 300 &&
        !_isLoadingMore &&
        _hasMore &&
        _currentQuery.isNotEmpty) {
      _loadMore();
    }
  }

  String _resolveQuery(String input) {
    final lower = input.trim().toLowerCase();
    return _moodMap[lower] ?? input;
  }

  void _onSearchChanged(String value) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 400), () {
      if (value.trim().isEmpty) {
        setState(() {
          _results = [];
          _currentQuery = '';
          _currentPage = 1;
          _hasMore = true;
        });
        return;
      }
      _performSearch(value.trim());
    });
  }

  Future<void> _performSearch(String query) async {
    final resolved = _resolveQuery(query);
    if (_scrollController.hasClients) {
      _scrollController.jumpTo(0);
    }
    setState(() {
      _isLoading = true;
      _currentQuery = resolved;
      _currentPage = 1;
      _hasMore = true;
    });

    final songs = await _api.searchSongs(resolved, limit: 20);

    if (mounted) {
      setState(() {
        _results = songs;
        _isLoading = false;
        _hasMore = songs.length >= 20;
      });
    }
  }

  Future<void> _loadMore() async {
    if (_isLoadingMore || !_hasMore) return;
    setState(() => _isLoadingMore = true);
    _currentPage++;

    try {
      final response = await _api.searchSongs(_currentQuery, page: _currentPage, limit: 20);
      if (mounted) {
        setState(() {
          _results.addAll(response);
          _isLoadingMore = false;
          _hasMore = response.length >= 20;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _isLoadingMore = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.background,
      body: SafeArea(
        child: Column(
          children: [
            _buildSearchBar(),
            Expanded(child: _buildBody()),
          ],
        ),
      ),
      bottomNavigationBar: const MiniPlayer(),
    );
  }

  Widget _buildSearchBar() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(8, 12, 16, 8),
      child: Row(
        children: [
          IconButton(
            onPressed: () => Navigator.pop(context),
            icon: const Icon(Icons.arrow_back_rounded, color: AppTheme.textPrimary),
          ),
          Expanded(
            child: Container(
              height: 48,
              decoration: BoxDecoration(
                color: AppTheme.surface,
                borderRadius: BorderRadius.circular(AppTheme.radiusDefault),
              ),
              child: TextField(
                controller: _searchController,
                focusNode: _focusNode,
                onChanged: _onSearchChanged,
                style: const TextStyle(color: AppTheme.textPrimary, fontSize: 15),
                cursorColor: AppTheme.accent,
                decoration: InputDecoration(
                  hintText: 'Search songs, artists, moods...',
                  hintStyle: TextStyle(color: AppTheme.textSecondary.withValues(alpha: 0.6), fontSize: 15),
                  border: InputBorder.none,
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                  prefixIcon: const Icon(Icons.search_rounded, color: AppTheme.textSecondary, size: 22),
                  suffixIcon: _searchController.text.isNotEmpty
                      ? IconButton(
                          onPressed: () {
                            _searchController.clear();
                            _onSearchChanged('');
                            if (_scrollController.hasClients) {
                              _scrollController.jumpTo(0);
                            }
                          },
                          icon: const Icon(Icons.close_rounded, color: AppTheme.textSecondary, size: 20),
                        )
                      : null,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBody() {
    if (_isLoading) {
      return const CommonLoader();
    }

    if (_results.isEmpty && _currentQuery.isNotEmpty) {
      return const EmptyStateView(
        icon: Icons.search_off_rounded,
        message: 'No results found.\nTry a different search or mood.',
      );
    }

    if (_results.isEmpty) {
      return const SizedBox.shrink();
    }

    return ListView.builder(
      controller: _scrollController,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      physics: const BouncingScrollPhysics(),
      itemCount: _results.length + (_hasMore ? 1 : 0),
      itemBuilder: (context, index) {
        if (index == _results.length) {
          return const Padding(
            padding: EdgeInsets.symmetric(vertical: 24),
            child: Center(
              child: SizedBox(
                width: 24,
                height: 24,
                child: CircularProgressIndicator(strokeWidth: 2, color: AppTheme.accent),
              ),
            ),
          );
        }
        return SongTile(
          song: _results[index],
          index: index,
          onTap: () => audioHandler.playSong(_results[index], playlist: _results),
        );
      },
    );
  }
}
