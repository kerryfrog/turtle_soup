import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:turtle_soup/app.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

// Import prod firebase options
import 'firebase_options_prod.dart' as prod_options;

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(
    options: prod_options.DefaultFirebaseOptions.currentPlatform,
  );
  
  final prefs = await SharedPreferences.getInstance();
  final isLoggedIn = prefs.getBool('isLoggedIn') ?? false;

  runApp(ProviderScope(child: MyApp(isLoggedIn: isLoggedIn)));
}
