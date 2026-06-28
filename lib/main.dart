import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_patcher/flutter_patcher.dart';
import 'core/theme.dart';
import 'core/player_service.dart';
import 'core/notifications.dart';
import 'core/user_data_service.dart';
import 'core/download_service.dart';
import 'screens/login_screen.dart';
import 'screens/app_shell.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  try {
    await Firebase.initializeApp();
  } catch (e) {
    debugPrint('Firebase init failed: $e');
  }
  try {
    await initAudioService();
  } catch (e) {
    debugPrint('Audio init failed: $e');
    audioHandler = AudioPlayerHandler();
  }
  await FlutterPatcher.init();
  await DownloadService().load();
  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.light,
      systemNavigationBarColor: AppTheme.background,
      systemNavigationBarIconBrightness: Brightness.light,
    ),
  );
  runApp(const ArcMusicApp());
}

class ArcMusicApp extends StatefulWidget {
  const ArcMusicApp({super.key});

  @override
  State<ArcMusicApp> createState() => _ArcMusicAppState();
}

class _ArcMusicAppState extends State<ArcMusicApp>
    with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.detached) {
      audioHandler.stop();
    }
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'ArcMusic',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.darkTheme,
      home: const AuthGate(),
      builder: (context, child) {
        return _NotificationOverlay(child: child!);
      },
    );
  }
}

class _NotificationOverlay extends StatefulWidget {
  final Widget child;
  const _NotificationOverlay({required this.child});

  @override
  State<_NotificationOverlay> createState() => _NotificationOverlayState();
}

class _NotificationOverlayState extends State<_NotificationOverlay> {
  AppNotification? _active;

  @override
  void initState() {
    super.initState();
    AppNotifications.notifier.addListener(_onNotif);
  }

  @override
  void dispose() {
    AppNotifications.notifier.removeListener(_onNotif);
    super.dispose();
  }

  void _onNotif() {
    setState(() {
      _active = AppNotifications.notifier.value;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        widget.child,
        if (_active != null)
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: NotificationBanner(
              key: ValueKey('notif_${_active.hashCode}'),
              message: _active!.message,
              isError: _active!.isError,
              onDismiss: () => AppNotifications.dismiss(),
            ),
          ),
      ],
    );
  }
}

class AuthGate extends StatefulWidget {
  const AuthGate({super.key});

  @override
  State<AuthGate> createState() => _AuthGateState();
}

class _AuthGateState extends State<AuthGate> {
  String? _lastUid;

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
      stream: FirebaseAuth.instance.authStateChanges(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            body: Center(
              child: CircularProgressIndicator(
                color: AppTheme.accent,
                strokeWidth: 2.5,
              ),
            ),
          );
        }

        final user = snapshot.data;
        if (user != null) {
          if (_lastUid != user.uid) {
            _lastUid = user.uid;
            UserDataService().load().catchError((e) {
            debugPrint('UserDataService.load error in AuthGate: $e');
          });
          }
          return const AppShell();
        }

        _lastUid = null;
        return const LoginScreen();
      },
    );
  }
}
