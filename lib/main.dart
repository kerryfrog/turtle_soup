import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:turtle_soup/theme/app_theme.dart';
import 'firebase_options.dart';
import 'screens/login_page.dart';
import 'screens/game_room_page.dart';
import 'screens/home_screen_page.dart'; // Import HomeScreenPage
import 'screens/settings_page.dart'; // Import SettingsPage

// Provider for authentication state changes
final authStateProvider = StreamProvider<User?>((ref) {
  return FirebaseAuth.instance.authStateChanges();
});

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  
  final prefs = await SharedPreferences.getInstance();
  final isLoggedIn = prefs.getBool('isLoggedIn') ?? false;

  runApp(ProviderScope(child: MyApp(isLoggedIn: isLoggedIn)));
}

class MyApp extends ConsumerWidget {
  final bool isLoggedIn;
  const MyApp({super.key, required this.isLoggedIn});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final authState = ref.watch(authStateProvider);

    return MaterialApp(
      title: '바다거북스프 온라인',
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
      },
    );
  }
}
