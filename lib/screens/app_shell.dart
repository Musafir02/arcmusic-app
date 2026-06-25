import 'package:flutter/material.dart';
import '../widgets/mini_player.dart';
import 'home_screen.dart';

class AppShell extends StatelessWidget {
  const AppShell({super.key});

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      body: HomeScreen(),
      bottomNavigationBar: MiniPlayer(),
    );
  }
}
