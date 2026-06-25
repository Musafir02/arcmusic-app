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
  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(widget.song.name, style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.white)),
          const SizedBox(height: 8),
          Text(widget.song.artistNames, style: const TextStyle(fontSize: 16, color: Colors.grey)),
        ],
      ),
    );
  }
}
