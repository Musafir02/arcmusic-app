import 'package:flutter/material.dart';
import '../core/player_service.dart';
import '../core/notifications.dart';
import '../widgets/mini_player.dart';
import 'home_screen.dart';

class AppShell extends StatefulWidget {
  const AppShell({super.key});

  @override
  State<AppShell> createState() => _AppShellState();
}

class _AppShellState extends State<AppShell> {
  String? _activeError;

  @override
  void initState() {
    super.initState();
    audioHandler.playbackErrorNotifier.addListener(_onErrorChanged);
  }

  @override
  void dispose() {
    audioHandler.playbackErrorNotifier.removeListener(_onErrorChanged);
    super.dispose();
  }

  void _onErrorChanged() {
    setState(() {
      _activeError = audioHandler.playbackErrorNotifier.value;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          const HomeScreen(),
          if (_activeError != null)
            Positioned(
              top: 0,
              left: 0,
              right: 0,
              child: NotificationBanner(
                key: ValueKey('error_$_activeError'),
                message: _activeError!,
                isError: true,
                onDismiss: () => audioHandler.playbackErrorNotifier.value = null,
              ),
            ),
        ],
      ),
      bottomNavigationBar: const MiniPlayer(),
    );
  }
}
