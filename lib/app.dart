import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:turtle_soup/screens/game_room_page.dart';
import 'package:turtle_soup/screens/home_screen_page.dart';
import 'package:turtle_soup/screens/login_page.dart';
import 'package:turtle_soup/screens/settings_page.dart';
import 'package:turtle_soup/theme/app_theme.dart';
import 'package:turtle_soup/screens/report_problem_page.dart';
import 'package:turtle_soup/screens/admin_page.dart';


// Provider for authentication state changes
final authStateProvider = StreamProvider<User?>((ref) {
  return FirebaseAuth.instance.authStateChanges();
});

class MyApp extends ConsumerWidget {
  final bool isLoggedIn;
  const MyApp({super.key, required this.isLoggedIn});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final authState = ref.watch(authStateProvider);

    return MaterialApp(
      title: '바거슾 온라인',
      theme: appTheme,
      debugShowCheckedModeBanner: false,
      home: isLoggedIn ? const HomeScreenPage() : authState.when(
        data: (user) => user != null ? const HomeScreenPage() : const LoginPage(),
        loading: () => const Scaffold(
          body: Center(child: CircularProgressIndicator()),
        ),
        error: (error, stackTrace) => Scaffold(
          body: Center(child: Text('Error: $error')),
        ),
      ),
      routes: {
        '/login': (context) => const LoginPage(),
        '/game_room': (context) {
          final args = ModalRoute.of(context)!.settings.arguments
              as Map<String, dynamic>;
          return GameRoomPage(
            roomId: args['roomId'],
            gameId: args['gameId'],
          );
        },
        '/settings': (context) => const SettingsPage(),
        '/report_problem': (context) => const ReportProblemPage(),
        '/admin': (context) => const AdminPage(),
      },
    );
  }
}
