import 'package:flutter/material.dart';
import '../core/player_service.dart';
import '../widgets/mini_player.dart';
import 'home_screen.dart';

class AppShell extends StatefulWidget {
  const AppShell({super.key});

  @override
  State<AppShell> createState() => _AppShellState();
}

class _AppShellState extends State<AppShell> {
  @override
  void initState() {
    super.initState();
    audioHandler.playbackErrorNotifier.addListener(_onError);
  }

  @override
  void dispose() {
    audioHandler.playbackErrorNotifier.removeListener(_onError);
    super.dispose();
  }

  void _onError() {
    final msg = audioHandler.playbackErrorNotifier.value;
    if (msg != null && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            msg,
            style: const TextStyle(
              color: Color(0xFFD97757),
              fontWeight: FontWeight.w600,
            ),
          ),
          backgroundColor: const Color(0xFF0E0D0C),
          behavior: SnackBarBehavior.floating,
          duration: const Duration(seconds: 3),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      body: HomeScreen(),
      bottomNavigationBar: MiniPlayer(),
    );
  }
}
