import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
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
  
  runApp(const ProviderScope(child: MyApp()));
}

class MyApp extends ConsumerWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final authState = ref.watch(authStateProvider);

    return MaterialApp(
      title: 'Turtle Soup',
      theme: appTheme,
      debugShowCheckedModeBanner: false,
      home: authState.when(
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
