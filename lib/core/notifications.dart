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
    _controller.forward();

    if (!widget.isError) {
      Future.delayed(const Duration(seconds: 3), () {
        if (mounted) _onDismiss();
      });
    }
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
          onTap: _onDismiss,
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
                colors: widget.isError
                    ? [
                        const Color(0xFFE53935).withValues(alpha: 0.15),
                        AppTheme.surface,
                      ]
                    : [
                        AppTheme.accent.withValues(alpha: 0.15),
                        AppTheme.surface,
                      ],
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
              ),
              border: Border(
                bottom: BorderSide(
                  color: widget.isError
                      ? const Color(0xFFE53935).withValues(alpha: 0.25)
                      : AppTheme.accent.withValues(alpha: 0.25),
                ),
              ),
            ),
            child: Row(
              children: [
                Container(
                  width: 28,
                  height: 28,
                  decoration: BoxDecoration(
                    color: widget.isError
                        ? const Color(0xFFE53935).withValues(alpha: 0.2)
                        : AppTheme.accent.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(
                    widget.isError ? Icons.warning_amber_rounded : Icons.check_rounded,
                    color: widget.isError ? const Color(0xFFE53935) : AppTheme.accent,
                    size: 16,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    widget.message,
                    style: TextStyle(
                      color: widget.isError ? const Color(0xFFE53935) : AppTheme.textPrimary,
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
                GestureDetector(
                  onTap: _onDismiss,
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
