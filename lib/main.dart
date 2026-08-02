import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';

import 'dashboard_screen.dart';
import 'firebase_options.dart';
import 'firebase_service.dart';
import 'login_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  bool firebaseInitialized = false;

  try {
    // 1. Initialize Firebase
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );

    debugPrint("✅ Firebase Initialized");
    debugPrint("Project ID: ${Firebase.app().options.projectId}");

    // 2. Configure Firestore Settings
    FirebaseFirestore.instance.settings = const Settings(
      persistenceEnabled: true,
      cacheSizeBytes: Settings.CACHE_SIZE_UNLIMITED,
    );
    debugPrint('✅ Firestore: Offline persistence enabled.');

    firebaseInitialized = true;
  } catch (e) {
    debugPrint('❌ Firebase Initialization Error: $e');
    // We still continue to show the app, but some features might be disabled
  }

  // Check for existing session
  final firebaseService = FirebaseService();
  bool isLoggedIn = false;

  if (firebaseInitialized) {
    try {
      final userData = await firebaseService.getUserData();
      isLoggedIn = userData != null && userData['uid'] != null;
    } catch (e) {
      debugPrint('Error fetching user data: $e');
    }
  }

  runApp(MyApp(isLoggedIn: isLoggedIn));
}

class MyApp extends StatelessWidget {
  final bool isLoggedIn;

  const MyApp({super.key, required this.isLoggedIn});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Movie Hub',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: Colors.white,
          brightness: Brightness.dark,
        ),
        useMaterial3: true,
        scaffoldBackgroundColor: Colors.black,
      ),
      home: isLoggedIn ? const DashboardScreen() : const LoginScreen(),
    );
  }
}
