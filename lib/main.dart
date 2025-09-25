import 'package:flutter/material.dart';
import 'screens/screens.dart';
import 'services/auth_service.dart';
import 'services/user_statistics_service.dart';
import 'services/app_initialization_service.dart';
import 'services/friends_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  try {
    // Initialize Firebase and database
    final appInitService = AppInitializationService();
    await appInitService.initializeApp();
    print('LearnMath app initialized successfully');
  } catch (e) {
    print('App initialization error: $e');
  }

  runApp(const LearnMathApp());
}

class LearnMathApp extends StatefulWidget {
  const LearnMathApp({super.key});

  @override
  State<LearnMathApp> createState() => _LearnMathAppState();
}

class _LearnMathAppState extends State<LearnMathApp> with WidgetsBindingObserver {
  FriendsService? _friendsService;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    // Initialize FriendsService after Firebase is ready
    _initializeFriendsService();
  }

  void _initializeFriendsService() {
    // Only initialize if not already done and Firebase is ready
    if (_friendsService == null) {
      _friendsService = FriendsService();
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);

    switch (state) {
      case AppLifecycleState.resumed:
        // App resumed, reinitialize presence if user is logged in
        print('App resumed - reinitializing presence');
        _initializeFriendsService();
        _friendsService?.initializePresence();
        break;
      case AppLifecycleState.paused:
      case AppLifecycleState.inactive:
      case AppLifecycleState.detached:
        // App going to background or being closed
        print('App paused/inactive - setting user offline');
        _friendsService?.setUserOffline();
        break;
      case AppLifecycleState.hidden:
        break;
    }
  }

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
  final AppInitializationService _appInitService = AppInitializationService();
  final FriendsService _friendsService = FriendsService();

  AuthWrapper({super.key});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder(
      stream: _authService.authStateChanges,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const SplashScreen();
        } else if (snapshot.hasData) {
          // User is signed in, load their data and initialize user-specific features
          WidgetsBinding.instance.addPostFrameCallback((_) async {
            try {
              await _userStatsService.loadStatistics();

              // Initialize user-specific data including leaderboard positioning
              final userId = _authService.getUserId();
              if (userId != null) {
                await _appInitService.initializeUserData(userId);

                // Initialize presence system for online/offline status
                await _friendsService.initializePresence();
                print('Presence system initialized for user: $userId');
              }
            } catch (e) {
              print('Error initializing user data: $e');
            }
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