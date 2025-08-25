import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:learnmath_app/services/user_statistics_service.dart';
import 'package:learnmath_app/services/user_preferences_service.dart';

// Mock Firebase for testing
import 'package:firebase_core_platform_interface/firebase_core_platform_interface.dart';

class MockFirebasePlatform extends FirebasePlatform {
  @override
  FirebaseAppPlatform app([String name = defaultFirebaseAppName]) {
    return MockFirebaseApp();
  }

  @override
  Future<FirebaseAppPlatform> initializeApp({
    String? name,
    FirebaseOptions? options,
  }) async {
    return MockFirebaseApp();
  }

  @override
  List<FirebaseAppPlatform> get apps => [MockFirebaseApp()];
}

class MockFirebaseApp extends FirebaseAppPlatform {
  MockFirebaseApp() : super('[DEFAULT]', const FirebaseOptions(
    apiKey: 'test',
    appId: 'test',
    messagingSenderId: 'test',
    projectId: 'test',
  ));

  @override
  String get name => '[DEFAULT]';

  @override
  FirebaseOptions get options => const FirebaseOptions(
    apiKey: 'test',
    appId: 'test',
    messagingSenderId: 'test',
    projectId: 'test',
  );
}

void main() {
  group('User Data Isolation Tests', () {
    late UserStatisticsService statsService;
    late UserPreferencesService prefsService;

    setUpAll(() async {
      // Set up mock Firebase platform
      FirebasePlatform.instance = MockFirebasePlatform();
    });

    setUp(() async {
      // Initialize test environment
      SharedPreferences.setMockInitialValues({});
      statsService = UserStatisticsService();
      prefsService = UserPreferencesService.instance;
    });

    test('User statistics should be isolated per user ID', () async {
      // Simulate user 1 data
      await statsService.recordSession(
        topic: 'addition',
        difficulty: 'easy',
        questions: 10,
        correctAnswers: 8,
        timeSpent: 300,
        stars: 3,
        score: 100,
      );
      
      await prefsService.setSelectedDifficulty(2); // Hard difficulty

      // Store current stats for user 1
      final user1Stats = statsService.getFormattedStats();
      final user1Difficulty = await prefsService.getSelectedDifficulty();

      // Clear current user data (simulating logout)
      await statsService.resetCurrentUserData();
      await prefsService.resetCurrentUserPreferences();

      // Check that data is reset
      final resetStats = statsService.getFormattedStats();
      final resetDifficulty = await prefsService.getSelectedDifficulty();

      expect(resetStats['Sessions Completed'], '0');
      expect(resetStats['Total Questions'], '0');
      expect(resetDifficulty, 0); // Should default to Easy

      // Verify original user data was different
      expect(user1Stats['Sessions Completed'], '1');
      expect(user1Stats['Total Questions'], '10');
      expect(user1Difficulty, 2);
    });

    test('Statistics should persist correctly per user', () async {
      // Record some statistics
      await statsService.recordSession(
        topic: 'multiplication',
        difficulty: 'medium',
        questions: 15,
        correctAnswers: 12,
        timeSpent: 450,
        stars: 4,
        score: 150,
      );

      // Save and reload statistics
      await statsService.saveStatistics();
      
      // Create new instance to test persistence
      final newStatsService = UserStatisticsService();
      await newStatsService.loadStatistics();
      
      final stats = newStatsService.getFormattedStats();
      expect(stats['Sessions Completed'], '1');
      expect(stats['Total Questions'], '15');
    });

    test('Clearing all user data should work correctly', () async {
      // Set up some data
      await statsService.recordSession(
        topic: 'division',
        difficulty: 'hard',
        questions: 20,
        correctAnswers: 15,
        timeSpent: 600,
        stars: 3,
        score: 200,
      );
      await prefsService.setSelectedDifficulty(1);

      // Clear all user data
      await statsService.clearAllUserData();
      await prefsService.clearAllUserPreferences();

      // Verify everything is cleared
      final stats = statsService.getFormattedStats();
      final difficulty = await prefsService.getSelectedDifficulty();

      expect(stats['Sessions Completed'], '0');
      expect(stats['Total Questions'], '0');
      expect(difficulty, 0);
    });
  });
}