import 'dart:async';
import 'package:flutter/material.dart';
import 'theme.dart';

class AppNotification {
  final String message;
  final bool isError;
  const AppNotification({required this.message, this.isError = false});
}

class AppNotifications {
  static final ValueNotifier<AppNotification?> notifier = ValueNotifier(null);

  static void show(String message) {
    notifier.value = AppNotification(message: message);
  }

  static void showError(String message) {
    notifier.value = AppNotification(message: message, isError: true);
  }

  static void dismiss() {
    notifier.value = null;
  }
}

class NotificationBanner extends StatefulWidget {
  final String message;
  final bool isError;
  final VoidCallback onDismiss;
  const NotificationBanner({super.key, required this.message, required this.isError, required this.onDismiss});

  @override
  State<NotificationBanner> createState() => _NotificationBannerState();
}

class _NotificationBannerState extends State<NotificationBanner>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scale;
  late Animation<double> _fade;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 400),
    );
    _scale = Tween<double>(begin: 0.6, end: 1.0).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeOutBack),
    );
    _fade = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeOut),
    );
    _controller.forward();

    _timer = Timer(const Duration(seconds: 3), _onDismiss);
  }

  void _onDismiss() {
    if (_controller.isCompleted) {
      _controller.reverse().then((_) {
        if (mounted) widget.onDismiss();
      });
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final topPadding = MediaQuery.of(context).padding.top;
    final accentColor = widget.isError ? const Color(0xFFE53935) : AppTheme.accent;

    return Padding(
      padding: EdgeInsets.only(top: topPadding + 8),
      child: Center(
        child: ScaleTransition(
          scale: _scale,
          child: FadeTransition(
            opacity: _fade,
            child: GestureDetector(
              onTap: _onDismiss,
              onVerticalDragEnd: (details) {
                if (details.primaryVelocity != null && details.primaryVelocity! < -100) {
                  _onDismiss();
                }
              },
              child: Container(
                constraints: const BoxConstraints(maxWidth: 320),
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                decoration: BoxDecoration(
                  color: AppTheme.surface,
                  borderRadius: BorderRadius.circular(50),
                  border: Border.all(
                    color: accentColor.withValues(alpha: 0.15),
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.35),
                      blurRadius: 20,
                      offset: const Offset(0, 6),
                    ),
                    BoxShadow(
                      color: accentColor.withValues(alpha: 0.08),
                      blurRadius: 12,
                    ),
                  ],
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 26,
                      height: 26,
                      decoration: BoxDecoration(
                        color: accentColor.withValues(alpha: 0.15),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        widget.isError ? Icons.close_rounded : Icons.check_rounded,
                        color: accentColor,
                        size: 14,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Flexible(
                      child: Text(
                        widget.message,
                        style: const TextStyle(
                          color: AppTheme.textPrimary,
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
