import 'package:flutter/material.dart';
import '../core/player_service.dart';
import '../core/theme.dart';
import '../widgets/mini_player.dart';
import 'home_screen.dart';

class AppShell extends StatefulWidget {
  const AppShell({super.key});

  @override
  State<AppShell> createState() => _AppShellState();
}

class _AppShellState extends State<AppShell> {
  String? _activeMsg;

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
      _activeMsg = audioHandler.playbackErrorNotifier.value;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          const HomeScreen(),
          if (_activeMsg != null)
            Positioned(
              top: 0,
              left: 0,
              right: 0,
              child: _ErrorBanner(
                key: ValueKey(_activeMsg),
                message: _activeMsg!,
                onDismiss: () => audioHandler.playbackErrorNotifier.value = null,
              ),
            ),
        ],
      ),
      bottomNavigationBar: const MiniPlayer(),
    );
  }
}

class _ErrorBanner extends StatefulWidget {
  final String message;
  final VoidCallback onDismiss;
  const _ErrorBanner({super.key, required this.message, required this.onDismiss});

  @override
  State<_ErrorBanner> createState() => _ErrorBannerState();
}

class _ErrorBannerState extends State<_ErrorBanner>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<Offset> _slide;
  late Animation<double> _fade;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 350),
    );
    _slide = Tween<Offset>(
      begin: const Offset(0, -1),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeOutCubic));
    _fade = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeOut),
    );
    audioHandler.playbackErrorNotifier.addListener(_checkDismiss);
    _controller.forward();
  }

  void _checkDismiss() {
    if (audioHandler.playbackErrorNotifier.value == null && _controller.isCompleted) {
      _controller.reverse();
    }
  }

  @override
  void dispose() {
    audioHandler.playbackErrorNotifier.removeListener(_checkDismiss);
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SlideTransition(
      position: _slide,
      child: FadeTransition(
        opacity: _fade,
        child: GestureDetector(
          onTap: widget.onDismiss,
          child: Container(
            width: double.infinity,
            padding: EdgeInsets.only(
              top: MediaQuery.of(context).padding.top + 12,
              bottom: 14,
              left: 20,
              right: 20,
            ),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  AppTheme.accent.withValues(alpha: 0.15),
                  AppTheme.surface,
                ],
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
              ),
              border: Border(
                bottom: BorderSide(
                  color: AppTheme.accent.withValues(alpha: 0.25),
                ),
              ),
            ),
            child: Row(
              children: [
                Container(
                  width: 28,
                  height: 28,
                  decoration: BoxDecoration(
                    color: AppTheme.accent.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(Icons.warning_amber_rounded, color: AppTheme.accent, size: 16),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    widget.message,
                    style: const TextStyle(
                      color: AppTheme.textPrimary,
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
                GestureDetector(
                  onTap: widget.onDismiss,
                  child: const Icon(Icons.close_rounded, color: AppTheme.textSecondary, size: 18),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
