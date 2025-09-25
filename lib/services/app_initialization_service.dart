import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'database_service.dart';
import 'leaderboard_service.dart';
import 'friends_service.dart';
import '../firebase_options.dart';

class AppInitializationService {
  static final AppInitializationService _instance = AppInitializationService._internal();
  factory AppInitializationService() => _instance;
  AppInitializationService._internal();

  final DatabaseService _databaseService = DatabaseService();
  final LeaderboardService _leaderboardService = LeaderboardService.instance;
  final FriendsService _friendsService = FriendsService();
  
  bool _isInitialized = false;
  bool get isInitialized => _isInitialized;

  // Initialize the entire application
  Future<void> initializeApp() async {
    try {
      // Check if Firebase is already initialized
      if (Firebase.apps.isEmpty) {
        // Initialize Firebase
        await Firebase.initializeApp(
          options: DefaultFirebaseOptions.currentPlatform,
        );
      }

      // Initialize basic database structure (without heavy leaderboard setup)
      await _databaseService.initializeDatabase();

      // Set up periodic leaderboard cache updates
      await _setupPeriodicUpdates();

      // Set up authentication state listener for presence system
      await _setupAuthStateListener();

      _isInitialized = true;
      print('LearnMath app initialized successfully');
      
    } catch (e) {
      if (kDebugMode) {
        print('App initialization error: $e');
      }
      // Don't rethrow - allow app to continue with fallback behavior
      _isInitialized = false;
    }
  }

  // Set up periodic background updates
  Future<void> _setupPeriodicUpdates() async {
    try {
      // Update leaderboard cache immediately if user is authenticated
      final currentUser = FirebaseAuth.instance.currentUser;
      if (currentUser != null) {
        await _databaseService.updateLeaderboardCache();
      }
    } catch (e) {
      if (kDebugMode) {
        print('Periodic updates error: $e');
      }
    }
  }

  // Initialize user-specific data when user logs in
  Future<void> initializeUserData(String userId) async {
    try {
      // Check and award any pending achievements
      await _databaseService.checkAndAwardAchievements(userId);

      // Update leaderboard position
      await _leaderboardService.updateUserLeaderboardPosition(userId);
    } catch (e) {
      if (kDebugMode) {
        print('User data initialization error: $e');
      }
    }
  }

  // Perform maintenance tasks
  Future<void> performMaintenance() async {
    try {
      print('AppInitializationService: Starting maintenance tasks...');
      
      // Update leaderboard cache
      await _databaseService.updateLeaderboardCache();
      
      // Clean up old data (optional)
      await _databaseService.cleanupOldData();
      
      print('AppInitializationService: Maintenance completed');
    } catch (e) {
      print('AppInitializationService: Error during maintenance: $e');
    }
  }

  // Get initialization status and app health
  Future<Map<String, dynamic>> getAppStatus() async {
    try {
      final config = await _databaseService.getAppConfig();
      final stats = await _leaderboardService.getLeaderboardStats();
      
      return {
        'initialized': _isInitialized,
        'maintenanceMode': config?['maintenanceMode'] ?? false,
        'appVersion': config?['appVersion'] ?? '1.0.0',
        'totalUsers': stats.totalUsers,
        'activeUsersToday': stats.activeUsersToday,
        'activeUsersWeek': stats.activeUsersWeek,
        'lastUpdated': DateTime.now().toIso8601String(),
      };
    } catch (e) {
      return {
        'initialized': _isInitialized,
        'error': e.toString(),
        'lastUpdated': DateTime.now().toIso8601String(),
      };
    }
  }

  // Set up authentication state listener for presence system
  Future<void> _setupAuthStateListener() async {
    FirebaseAuth.instance.authStateChanges().listen((User? user) {
      if (user != null) {
        // User signed in, initialize presence
        print('AppInitializationService: User signed in, initializing presence for ${user.uid}');
        _initializeUserPresence();
      } else {
        // User signed out, clean up presence
        print('AppInitializationService: User signed out, cleaning up presence');
        _cleanupUserPresence();
      }
    });
  }

  // Initialize user presence when user signs in
  Future<void> _initializeUserPresence() async {
    try {
      await _friendsService.initializePresence();
      print('AppInitializationService: User presence initialized');
    } catch (e) {
      print('AppInitializationService: Error initializing user presence: $e');
    }
  }

  // Cleanup user presence when user signs out
  Future<void> _cleanupUserPresence() async {
    try {
      await _friendsService.setUserOffline();
      _friendsService.dispose();
      print('AppInitializationService: User presence cleaned up');
    } catch (e) {
      print('AppInitializationService: Error cleaning up user presence: $e');
    }
  }

  // Reset initialization state (for testing or troubleshooting)
  void resetInitialization() {
    _isInitialized = false;
    print('AppInitializationService: Initialization state reset');
  }

}