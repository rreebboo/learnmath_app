import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';

class DatabaseService {
  // Use lazy initialization to avoid accessing Firebase before it's initialized
  FirebaseFirestore get _firestore => FirebaseFirestore.instance;
  FirebaseAuth get _auth => FirebaseAuth.instance;

  static final DatabaseService _instance = DatabaseService._internal();
  factory DatabaseService() => _instance;
  DatabaseService._internal();

  // Get current user ID
  String? get currentUserId => _auth.currentUser?.uid;

  // Initialize database collections and indexes
  Future<void> initializeDatabase() async {
    try {
      // Check if Firebase is available
      try {
        await _firestore.settings;
      } catch (e) {
        if (kDebugMode) {
          print('Firestore not available: $e');
        }
        return; // Skip database initialization if Firestore is not available
      }
      
      // Check if app configuration exists, create if not
      await _initializeAppConfig();
      
      // Initialize sample achievements if none exist
      await _initializeAchievements();
      
      if (kDebugMode) {
        print('Database initialized successfully');
      }
    } catch (e) {
      if (kDebugMode) {
        print('Database initialization error: $e');
      }
      // Don't rethrow - allow app to continue without database features
    }
  }

  // Initialize app configuration
  Future<void> _initializeAppConfig() async {
    try {
      final configDoc = await _firestore.collection('app_config').doc('settings').get();
      
      if (!configDoc.exists) {
        await _firestore.collection('app_config').doc('settings').set({
          'appVersion': '1.0.0',
          'minAppVersion': '1.0.0',
          'maintenanceMode': false,
          'leaderboardSettings': {
            'maxUsersShown': 100,
            'refreshInterval': 300, // 5 minutes in seconds
            'enableWeeklyReset': true,
            'enableMonthlyReset': true,
          },
          'gameSettings': {
            'maxQuestionsPerSession': 20,
            'minQuestionsPerSession': 5,
            'timePerQuestion': 30, // seconds
            'pointsPerCorrectAnswer': 10,
            'bonusStreakMultiplier': 1.5,
          },
          'socialSettings': {
            'enableFriends': true,
            'enableChallenges': true,
            'maxFriends': 50,
          },
          'createdAt': FieldValue.serverTimestamp(),
          'updatedAt': FieldValue.serverTimestamp(),
        });
        print('DatabaseService: App configuration created');
      }
    } catch (e) {
      if (kDebugMode) {
        print('Error initializing app config: $e');
      }
    }
  }

  // Initialize achievement definitions
  Future<void> _initializeAchievements() async {
    try {
      final achievementsSnapshot = await _firestore.collection('achievements').limit(1).get();
      
      if (achievementsSnapshot.docs.isEmpty) {
        final achievements = [
          {
            'id': 'first_steps',
            'title': 'First Steps!',
            'description': 'Complete your first math problem',
            'icon': '🎯',
            'category': 'beginner',
            'points': 10,
            'requirements': {'practiceSessionsCompleted': 1},
            'isActive': true,
            'createdAt': FieldValue.serverTimestamp(),
          },
          {
            'id': 'streak_master',
            'title': 'Streak Master',
            'description': 'Maintain a 7-day learning streak',
            'icon': '🔥',
            'category': 'consistency',
            'points': 50,
            'requirements': {'dailyStreak': 7},
            'isActive': true,
            'createdAt': FieldValue.serverTimestamp(),
          },
          {
            'id': 'math_champion',
            'title': 'Math Champion',
            'description': 'Score 1000 total points',
            'icon': '👑',
            'category': 'achievement',
            'points': 100,
            'requirements': {'totalScore': 1000},
            'isActive': true,
            'createdAt': FieldValue.serverTimestamp(),
          },
          {
            'id': 'perfect_score',
            'title': 'Perfect Score!',
            'description': 'Get 100% accuracy in a session',
            'icon': '⭐',
            'category': 'accuracy',
            'points': 25,
            'requirements': {'perfectAccuracy': 1},
            'isActive': true,
            'createdAt': FieldValue.serverTimestamp(),
          },
          {
            'id': 'speed_demon',
            'title': 'Speed Demon',
            'description': 'Complete 10 problems in under 5 minutes',
            'icon': '⚡',
            'category': 'speed',
            'points': 30,
            'requirements': {'fastCompletion': 1},
            'isActive': true,
            'createdAt': FieldValue.serverTimestamp(),
          },
          {
            'id': 'social_butterfly',
            'title': 'Social Butterfly',
            'description': 'Add 5 friends',
            'icon': '🦋',
            'category': 'social',
            'points': 20,
            'requirements': {'friendsCount': 5},
            'isActive': true,
            'createdAt': FieldValue.serverTimestamp(),
          },
        ];

        // Create achievements in batch
        final batch = _firestore.batch();
        for (final achievement in achievements) {
          final docRef = _firestore.collection('achievements').doc(achievement['id'] as String);
          batch.set(docRef, achievement);
        }
        await batch.commit();
        
        print('DatabaseService: ${achievements.length} achievements created');
      }
    } catch (e) {
      if (kDebugMode) {
        print('Error initializing achievements: $e');
      }
    }
  }

  // Enhanced user creation with proper leaderboard setup
  Future<void> createUserWithLeaderboardData({
    required String userId,
    required String name,
    required String email,
    required String avatar,
    bool isAnonymous = false,
  }) async {
    try {
      final userData = {
        'uid': userId,
        'name': name.trim(),
        'email': email,
        'avatar': avatar,
        'isAnonymous': isAnonymous,
        'createdAt': FieldValue.serverTimestamp(),
        'lastLoginDate': FieldValue.serverTimestamp(),
        
        // Leaderboard-relevant fields
        'totalScore': 0,
        'lessonsCompleted': 0,
        'currentStreak': 0,
        'bestStreak': 0,
        'totalTimeSpent': 0, // in seconds
        'totalProblemsAttempted': 0,
        'totalProblemsCorrect': 0,
        'accuracyRate': 0.0,
        
        // Social features
        'friendsCount': 0,
        'challengesWon': 0,
        'challengesLost': 0,
        
        // Achievements
        'achievements': [],
        'achievementPoints': 0,
        
        // Settings
        'preferences': {
          'soundEnabled': true,
          'difficulty': 'beginner',
          'notifications': true,
          'shareProgress': true,
        },
        
        // Metadata
        'updatedAt': FieldValue.serverTimestamp(),
        'version': 1,
      };

      await _firestore.collection('users').doc(userId).set(userData);
      print('DatabaseService: User created with leaderboard data: $userId');
    } catch (e) {
      if (kDebugMode) {
        print('Error creating user: $e');
      }
      rethrow;
    }
  }

  // Enhanced practice session saving with leaderboard updates
  Future<void> savePracticeSessionWithLeaderboardUpdate({
    required String userId,
    required String topic,
    required int score,
    required int totalQuestions,
    required int correctAnswers,
    required Duration timeSpent,
    required String difficulty,
  }) async {
    try {
      final sessionData = {
        'topic': topic,
        'difficulty': difficulty,
        'score': score,
        'totalQuestions': totalQuestions,
        'correctAnswers': correctAnswers,
        'accuracy': (correctAnswers / totalQuestions * 100).round(),
        'timeSpent': timeSpent.inSeconds,
        'completedAt': FieldValue.serverTimestamp(),
        'weekOf': _getWeekOfYear(DateTime.now()),
        'monthOf': DateTime.now().month,
        'yearOf': DateTime.now().year,
      };

      // Save practice session
      await _firestore
          .collection('users')
          .doc(userId)
          .collection('practice_sessions')
          .add(sessionData);

      // Update user stats for leaderboard
      final userRef = _firestore.collection('users').doc(userId);
      await userRef.update({
        'totalScore': FieldValue.increment(score),
        'totalProblemsAttempted': FieldValue.increment(totalQuestions),
        'totalProblemsCorrect': FieldValue.increment(correctAnswers),
        'totalTimeSpent': FieldValue.increment(timeSpent.inSeconds),
        'lastLoginDate': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      });

      // Update accuracy rate
      await _updateUserAccuracyRate(userId);

      // Check for perfect score and update lessons completed
      if (correctAnswers == totalQuestions) {
        await userRef.update({
          'lessonsCompleted': FieldValue.increment(1),
        });
      }

      print('DatabaseService: Practice session saved with leaderboard update');
    } catch (e) {
      if (kDebugMode) {
        print('Error saving practice session: $e');
      }
      rethrow;
    }
  }

  // Update user accuracy rate
  Future<void> _updateUserAccuracyRate(String userId) async {
    try {
      final userDoc = await _firestore.collection('users').doc(userId).get();
      if (!userDoc.exists) return;

      final userData = userDoc.data()!;
      final totalAttempted = userData['totalProblemsAttempted'] ?? 0;
      final totalCorrect = userData['totalProblemsCorrect'] ?? 0;

      if (totalAttempted > 0) {
        final accuracyRate = (totalCorrect / totalAttempted * 100).round();
        await _firestore.collection('users').doc(userId).update({
          'accuracyRate': accuracyRate,
        });
      }
    } catch (e) {
      if (kDebugMode) {
        print('Error updating accuracy rate: $e');
      }
    }
  }

  // Get week of year for weekly leaderboards
  int _getWeekOfYear(DateTime date) {
    final firstDayOfYear = DateTime(date.year, 1, 1);
    final daysSinceFirstDay = date.difference(firstDayOfYear).inDays;
    return (daysSinceFirstDay / 7).ceil() + 1;
  }

  // Create cached leaderboard entries for performance
  Future<void> updateLeaderboardCache() async {
    try {
      // Get top 100 users for all-time leaderboard
      final topUsers = await _firestore
          .collection('users')
          .orderBy('totalScore', descending: true)
          .limit(100)
          .get();

      final leaderboardData = topUsers.docs.map((doc) {
        final data = doc.data();
        return {
          'userId': doc.id,
          'name': data['name'] ?? 'User',
          'avatar': data['avatar'] ?? '🦊',
          'totalScore': data['totalScore'] ?? 0,
          'currentStreak': data['currentStreak'] ?? 0,
          'lessonsCompleted': data['lessonsCompleted'] ?? 0,
          'accuracyRate': data['accuracyRate'] ?? 0,
          'lastActive': data['lastLoginDate'],
        };
      }).toList();

      // Cache the leaderboard data (without serverTimestamp in nested objects)
      final cacheData = leaderboardData.map((user) {
        // Remove FieldValue.serverTimestamp() from user data since it can't be in arrays
        final cleanUser = Map<String, dynamic>.from(user);
        cleanUser['updatedAt'] = DateTime.now().toIso8601String();
        return cleanUser;
      }).toList();

      await _firestore.collection('leaderboards').doc('all_time').set({
        'type': 'all_time',
        'users': cacheData,
        'lastUpdated': FieldValue.serverTimestamp(),
        'totalUsers': cacheData.length,
      });

      print('DatabaseService: Leaderboard cache updated with ${leaderboardData.length} users');
    } catch (e) {
      if (kDebugMode) {
        print('Error updating leaderboard cache: $e');
      }
    }
  }

  // Get app configuration
  Future<Map<String, dynamic>?> getAppConfig() async {
    try {
      final doc = await _firestore.collection('app_config').doc('settings').get();
      return doc.data();
    } catch (e) {
      print('DatabaseService: Error getting app config: $e');
      return null;
    }
  }

  // Get all achievements
  Future<List<Map<String, dynamic>>> getAchievements() async {
    try {
      final snapshot = await _firestore
          .collection('achievements')
          .where('isActive', isEqualTo: true)
          .orderBy('category')
          .get();

      return snapshot.docs
          .map((doc) => {
                'id': doc.id,
                ...doc.data(),
              })
          .toList();
    } catch (e) {
      print('DatabaseService: Error getting achievements: $e');
      return [];
    }
  }

  // Award achievement to user
  Future<void> awardAchievement({
    required String userId,
    required String achievementId,
  }) async {
    try {
      final userRef = _firestore.collection('users').doc(userId);
      final achievementRef = _firestore.collection('achievements').doc(achievementId);
      
      final achievementDoc = await achievementRef.get();
      if (!achievementDoc.exists) return;
      
      final achievementData = achievementDoc.data()!;
      final points = achievementData['points'] ?? 0;

      // Add achievement to user's achievements array
      await userRef.update({
        'achievements': FieldValue.arrayUnion([{
          'id': achievementId,
          'title': achievementData['title'],
          'earnedAt': FieldValue.serverTimestamp(),
          'points': points,
        }]),
        'achievementPoints': FieldValue.increment(points),
        'totalScore': FieldValue.increment(points),
      });

      print('DatabaseService: Achievement $achievementId awarded to user $userId');
    } catch (e) {
      print('DatabaseService: Error awarding achievement: $e');
    }
  }

  // Check and award achievements based on user stats
  Future<void> checkAndAwardAchievements(String userId) async {
    try {
      final userDoc = await _firestore.collection('users').doc(userId).get();
      if (!userDoc.exists) return;

      final userData = userDoc.data()!;
      final userAchievements = List<Map<String, dynamic>>.from(userData['achievements'] ?? []);
      final earnedAchievementIds = userAchievements.map((a) => a['id'] as String).toSet();

      final availableAchievements = await getAchievements();

      for (final achievement in availableAchievements) {
        final achievementId = achievement['id'] as String;
        
        // Skip if already earned
        if (earnedAchievementIds.contains(achievementId)) continue;

        final requirements = achievement['requirements'] as Map<String, dynamic>;
        bool meetsRequirements = true;

        // Check each requirement
        for (final entry in requirements.entries) {
          final requiredValue = entry.value;
          final userValue = userData[entry.key] ?? 0;

          if (userValue < requiredValue) {
            meetsRequirements = false;
            break;
          }
        }

        // Award achievement if requirements are met
        if (meetsRequirements) {
          await awardAchievement(userId: userId, achievementId: achievementId);
        }
      }
    } catch (e) {
      if (kDebugMode) {
        print('Error checking achievements: $e');
      }
    }
  }

  // Cleanup old data (for maintenance)
  Future<void> cleanupOldData() async {
    try {
      final cutoffDate = DateTime.now().subtract(const Duration(days: 90));
      
      // Clean up old practice sessions (keep only last 90 days)
      final oldSessions = await _firestore
          .collectionGroup('practice_sessions')
          .where('completedAt', isLessThan: Timestamp.fromDate(cutoffDate))
          .get();

      final batch = _firestore.batch();
      for (final doc in oldSessions.docs) {
        batch.delete(doc.reference);
      }
      
      if (oldSessions.docs.isNotEmpty) {
        await batch.commit();
        print('DatabaseService: Cleaned up ${oldSessions.docs.length} old practice sessions');
      }
    } catch (e) {
      print('DatabaseService: Error during cleanup: $e');
    }
  }
}