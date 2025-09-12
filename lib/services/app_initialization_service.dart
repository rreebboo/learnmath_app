import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'database_service.dart';
import 'leaderboard_service.dart';
import '../firebase_options.dart';

class AppInitializationService {
  static final AppInitializationService _instance = AppInitializationService._internal();
  factory AppInitializationService() => _instance;
  AppInitializationService._internal();

  final DatabaseService _databaseService = DatabaseService();
  final LeaderboardService _leaderboardService = LeaderboardService();
  
  bool _isInitialized = false;
  bool get isInitialized => _isInitialized;

  // Initialize the entire application
  Future<void> initializeApp() async {
    try {
      print('AppInitializationService: Starting app initialization...');
      
      // Check if Firebase is already initialized
      if (Firebase.apps.isNotEmpty) {
        print('AppInitializationService: Firebase already initialized');
      } else {
        // Initialize Firebase
        await Firebase.initializeApp(
          options: DefaultFirebaseOptions.currentPlatform,
        );
        print('AppInitializationService: Firebase initialized successfully');
      }

      // Verify Firebase is working
      final app = Firebase.app();
      print('AppInitializationService: Firebase app name: ${app.name}');

      // Initialize basic database structure (without heavy leaderboard setup)
      await _databaseService.initializeDatabase();
      print('AppInitializationService: Basic database initialized');

      // Set up periodic leaderboard cache updates
      await _setupPeriodicUpdates();
      
      _isInitialized = true;
      print('AppInitializationService: App initialization completed successfully');
      
    } catch (e) {
      print('AppInitializationService: Error during initialization: $e');
      print('AppInitializationService: Error type: ${e.runtimeType}');
      
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
        print('AppInitializationService: Initial leaderboard cache updated');
      }
    } catch (e) {
      print('AppInitializationService: Error setting up periodic updates: $e');
    }
  }

  // Initialize user-specific data when user logs in
  Future<void> initializeUserData(String userId) async {
    try {
      print('AppInitializationService: Initializing user data for: $userId');
      
      // Check and award any pending achievements
      await _databaseService.checkAndAwardAchievements(userId);
      
      // Update leaderboard position
      await _leaderboardService.updateUserLeaderboardPosition(userId);
      
      print('AppInitializationService: User data initialization completed');
    } catch (e) {
      print('AppInitializationService: Error initializing user data: $e');
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

  // Reset initialization state (for testing or troubleshooting)
  void resetInitialization() {
    _isInitialized = false;
    print('AppInitializationService: Initialization state reset');
  }

}