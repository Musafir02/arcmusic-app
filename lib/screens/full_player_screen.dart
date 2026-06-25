import 'dart:async';
import 'package:flutter/material.dart';
import '../core/api_service.dart';
import '../core/player_service.dart';
import '../core/theme.dart';
import '../models/song.dart';

class FullPlayerScreen extends StatelessWidget {
  const FullPlayerScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: ValueListenableBuilder<Song?>(
          valueListenable: audioHandler.currentSongNotifier,
          builder: (context, song, _) {
            if (song == null) {
              return const Center(
                child: Text('No song playing',
                    style: TextStyle(color: AppTheme.textSecondary)),
              );
            }
            return _PlayerBody(song: song);
          },
        ),
      ),
    );
  }
}

class _PlayerBody extends StatefulWidget {
  final Song song;
  const _PlayerBody({required this.song});

  @override
  State<_PlayerBody> createState() => _PlayerBodyState();
}

class _PlayerBodyState extends State<_PlayerBody> {
  final PageController _pageController = PageController();
  int _currentPage = 0;

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              GestureDetector(
                onTap: () => Navigator.pop(context),
                child: Container(
                  width: 40,
                  height: 5,
                  decoration: BoxDecoration(
                    color: AppTheme.textSecondary.withValues(alpha: 0.3),
                    borderRadius: BorderRadius.circular(3),
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 8),
        Expanded(
          child: PageView(
            controller: _pageController,
            onPageChanged: (i) => setState(() => _currentPage = i),
            children: [
              _buildArtworkPage(),
              const Center(child: Text('Lyrics loading...', style: TextStyle(color: Colors.white))),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildArtworkPage() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 40),
      child: Center(
        child: ClipRRect(
          borderRadius: BorderRadius.circular(20),
          child: AspectRatio(
            aspectRatio: 1,
            child: Image.network(
              widget.song.imageLarge,
              fit: BoxFit.cover,
              errorBuilder: (_, __, ___) => Container(
                color: AppTheme.surface,
                child: const Icon(
                  Icons.music_note_rounded,
                  color: AppTheme.accent,
                  size: 80,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
