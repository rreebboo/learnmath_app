import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'firebase_options.dart';
import 'screens/screens.dart';
import 'services/auth_service.dart';
import 'services/user_statistics_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  try {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
    // print('Firebase initialized successfully');
  } catch (e) {
    // print('Firebase initialization error: $e');
  }
  
  runApp(const LearnMathApp());
}

class LearnMathApp extends StatelessWidget {
  const LearnMathApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'LearnMath',
      theme: ThemeData(
        primarySwatch: Colors.blue,
        fontFamily: 'SF Pro Display',
      ),
      debugShowCheckedModeBanner: false,
      home: AuthWrapper(),
      routes: {
        '/home': (context) => const HomeScreen(),
        '/practice': (context) => const SoloPracticeScreen(),
        '/profile': (context) => const ProfileScreen(),
      },
    );
  }
}

class AuthWrapper extends StatelessWidget {
  final AuthService _authService = AuthService();
  final UserStatisticsService _userStatsService = UserStatisticsService();

  AuthWrapper({super.key});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder(
      stream: _authService.authStateChanges,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const SplashScreen();
        } else if (snapshot.hasData) {
          // User is signed in, load their data
          WidgetsBinding.instance.addPostFrameCallback((_) async {
            await _userStatsService.loadStatistics();
          });
          return const HomeScreen();
        } else {
          // User is not signed in
          return const SplashScreen();
        }
      },
    );
  }
}