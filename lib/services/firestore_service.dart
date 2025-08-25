import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/math_topic.dart';

class FirestoreService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  // Get current user ID
  String? get currentUserId => _auth.currentUser?.uid;

  // Get user data
  Future<Map<String, dynamic>?> getUserData(String userId) async {
    try {
      // print('FirestoreService: Fetching user data for: $userId');
      DocumentSnapshot doc = await _firestore.collection('users').doc(userId).get();
      
      if (doc.exists) {
        // print('FirestoreService: User document found');
        return doc.data() as Map<String, dynamic>?;
      } else {
        // print('FirestoreService: User document does not exist, creating default user');
        // Create a default user document if it doesn't exist
        await _createDefaultUserDocument(userId);
        // Try to get the data again
        doc = await _firestore.collection('users').doc(userId).get();
        return doc.data() as Map<String, dynamic>?;
      }
    } catch (e) {
      // print('FirestoreService: Error getting user data: $e');
      throw 'Error getting user data: $e';
    }
  }

  // Create default user document
  Future<void> _createDefaultUserDocument(String userId) async {
    try {
      final user = _auth.currentUser;
      await _firestore.collection('users').doc(userId).set({
        'uid': userId,
        'name': user?.displayName ?? 'User',
        'email': user?.email,
        'avatar': '🦊',
        'isAnonymous': user?.isAnonymous ?? false,
        'createdAt': FieldValue.serverTimestamp(),
        'totalScore': 0,
        'lessonsCompleted': 0,
        'currentStreak': 0,
        'lastLoginDate': FieldValue.serverTimestamp(),
        'achievements': [],
        'preferences': {
          'soundEnabled': true,
          'difficulty': 'beginner',
        },
      });
      // print('FirestoreService: Default user document created');
    } catch (e) {
      // print('FirestoreService: Error creating default user document: $e');
      rethrow;
    }
  }

  // Get current user data
  Future<Map<String, dynamic>?> getCurrentUserData() async {
    try {
      if (currentUserId == null) {
        // print('FirestoreService: No current user ID');
        return null;
      }
      
      // print('FirestoreService: Getting data for user: $currentUserId');
      final data = await getUserData(currentUserId!);
      // print('FirestoreService: User data retrieved: ${data != null ? 'Success' : 'Not found'}');
      return data;
    } catch (e) {
      // print('FirestoreService: Error getting current user data: $e');
      return null;
    }
  }

  // Update user profile
  Future<void> updateUserProfile({
    required String userId,
    String? name,
    String? avatar,
    String? email,
  }) async {
    try {
      Map<String, dynamic> updateData = {
        'updatedAt': FieldValue.serverTimestamp(),
      };

      if (name != null) updateData['name'] = name;
      if (avatar != null) updateData['avatar'] = avatar;
      if (email != null) updateData['email'] = email;

      await _firestore.collection('users').doc(userId).update(updateData);
    } catch (e) {
      throw 'Error updating user profile: $e';
    }
  }

  // Update user score
  Future<void> updateUserScore({
    required String userId,
    required int scoreToAdd,
  }) async {
    try {
      await _firestore.collection('users').doc(userId).update({
        'totalScore': FieldValue.increment(scoreToAdd),
        'updatedAt': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      throw 'Error updating user score: $e';
    }
  }

  // Increment lessons completed
  Future<void> incrementLessonsCompleted(String userId) async {
    try {
      await _firestore.collection('users').doc(userId).update({
        'lessonsCompleted': FieldValue.increment(1),
        'updatedAt': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      throw 'Error updating lessons completed: $e';
    }
  }

  // Update user streak
  Future<void> updateUserStreak({
    required String userId,
    required int newStreak,
  }) async {
    try {
      await _firestore.collection('users').doc(userId).update({
        'currentStreak': newStreak,
        'updatedAt': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      throw 'Error updating user streak: $e';
    }
  }

  // Add achievement
  Future<void> addAchievement({
    required String userId,
    required String achievementId,
    required String achievementName,
  }) async {
    try {
      await _firestore.collection('users').doc(userId).update({
        'achievements': FieldValue.arrayUnion([
          {
            'id': achievementId,
            'name': achievementName,
            'earnedAt': FieldValue.serverTimestamp(),
          }
        ]),
        'updatedAt': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      throw 'Error adding achievement: $e';
    }
  }

  // Save practice session result
  Future<void> savePracticeSession({
    required String userId,
    required String topic,
    required int score,
    required int totalQuestions,
    required int correctAnswers,
    required Duration timeSpent,
  }) async {
    try {
      // Save to practice_sessions subcollection
      await _firestore
          .collection('users')
          .doc(userId)
          .collection('practice_sessions')
          .add({
        'topic': topic,
        'score': score,
        'totalQuestions': totalQuestions,
        'correctAnswers': correctAnswers,
        'accuracy': (correctAnswers / totalQuestions * 100).round(),
        'timeSpent': timeSpent.inSeconds,
        'completedAt': FieldValue.serverTimestamp(),
      });

      // Update user's total score
      await updateUserScore(userId: userId, scoreToAdd: score);

      // If score is perfect, increment lessons completed
      if (correctAnswers == totalQuestions) {
        await incrementLessonsCompleted(userId);
      }
    } catch (e) {
      throw 'Error saving practice session: $e';
    }
  }

  // Get practice history
  Future<List<Map<String, dynamic>>> getPracticeHistory(String userId) async {
    try {
      QuerySnapshot snapshot = await _firestore
          .collection('users')
          .doc(userId)
          .collection('practice_sessions')
          .orderBy('completedAt', descending: true)
          .limit(20)
          .get();

      return snapshot.docs
          .map((doc) => {
                'id': doc.id,
                ...doc.data() as Map<String, dynamic>,
              })
          .toList();
    } catch (e) {
      throw 'Error getting practice history: $e';
    }
  }

  // Get topic statistics
  Future<Map<String, dynamic>> getTopicStatistics(String userId, String topic) async {
    try {
      QuerySnapshot snapshot = await _firestore
          .collection('users')
          .doc(userId)
          .collection('practice_sessions')
          .where('topic', isEqualTo: topic)
          .get();

      if (snapshot.docs.isEmpty) {
        return {
          'totalSessions': 0,
          'averageAccuracy': 0,
          'totalTimeSpent': 0,
          'bestScore': 0,
        };
      }

      int totalSessions = snapshot.docs.length;
      int totalCorrect = 0;
      int totalQuestions = 0;
      int totalTimeSpent = 0;
      int bestScore = 0;

      for (var doc in snapshot.docs) {
        var data = doc.data() as Map<String, dynamic>;
        totalCorrect += (data['correctAnswers'] as int? ?? 0);
        totalQuestions += (data['totalQuestions'] as int? ?? 0);
        totalTimeSpent += (data['timeSpent'] as int? ?? 0);
        bestScore = bestScore < (data['score'] as int? ?? 0) ? (data['score'] as int? ?? 0) : bestScore;
      }

      return {
        'totalSessions': totalSessions,
        'averageAccuracy': totalQuestions > 0 ? (totalCorrect / totalQuestions * 100).round() : 0,
        'totalTimeSpent': totalTimeSpent,
        'bestScore': bestScore,
      };
    } catch (e) {
      throw 'Error getting topic statistics: $e';
    }
  }

  // Update user preferences
  Future<void> updateUserPreferences({
    required String userId,
    bool? soundEnabled,
    String? difficulty,
  }) async {
    try {
      Map<String, dynamic> preferences = {};
      if (soundEnabled != null) preferences['soundEnabled'] = soundEnabled;
      if (difficulty != null) preferences['difficulty'] = difficulty;

      await _firestore.collection('users').doc(userId).update({
        'preferences': preferences,
        'updatedAt': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      throw 'Error updating preferences: $e';
    }
  }

  // Stream user data changes
  Stream<DocumentSnapshot> streamUserData(String userId) {
    return _firestore.collection('users').doc(userId).snapshots();
  }

  // Stream current user data changes
  Stream<DocumentSnapshot>? streamCurrentUserData() {
    if (currentUserId == null) return null;
    return streamUserData(currentUserId!);
  }

  // Get leaderboard (top users by score)
  Future<List<Map<String, dynamic>>> getLeaderboard({int limit = 10}) async {
    try {
      QuerySnapshot snapshot = await _firestore
          .collection('users')
          .orderBy('totalScore', descending: true)
          .limit(limit)
          .get();

      return snapshot.docs
          .map((doc) => {
                'id': doc.id,
                ...doc.data() as Map<String, dynamic>,
              })
          .toList();
    } catch (e) {
      throw 'Error getting leaderboard: $e';
    }
  }

  // Check if user exists
  Future<bool> userExists(String userId) async {
    try {
      DocumentSnapshot doc = await _firestore.collection('users').doc(userId).get();
      return doc.exists;
    } catch (e) {
      return false;
    }
  }

  // Calculate daily streak
  Future<int> calculateDailyStreak(String userId) async {
    try {
      final now = DateTime.now();
      final yesterday = DateTime(now.year, now.month, now.day - 1);
      final todayStart = DateTime(now.year, now.month, now.day);

      QuerySnapshot todaySession = await _firestore
          .collection('users')
          .doc(userId)
          .collection('practice_sessions')
          .where('completedAt', isGreaterThanOrEqualTo: Timestamp.fromDate(todayStart))
          .limit(1)
          .get();

      if (todaySession.docs.isEmpty) {
        // No session today, check yesterday
        QuerySnapshot yesterdaySession = await _firestore
            .collection('users')
            .doc(userId)
            .collection('practice_sessions')
            .where('completedAt', isGreaterThanOrEqualTo: Timestamp.fromDate(yesterday))
            .where('completedAt', isLessThan: Timestamp.fromDate(todayStart))
            .limit(1)
            .get();

        if (yesterdaySession.docs.isEmpty) {
          return 0; // No streak
        } else {
          // Had session yesterday but not today, need to continue from where we left off
          var userData = await getCurrentUserData();
          return userData?['currentStreak'] ?? 0;
        }
      } else {
        // Has session today, increment streak
        var userData = await getCurrentUserData();
        int currentStreak = userData?['currentStreak'] ?? 0;
        return currentStreak + 1;
      }
    } catch (e) {
      return 0;
    }
  }

  // Topic Progress Management
  Future<void> updateTopicProgress({
    required String userId,
    required String topicId,
    required int lessonsCompleted,
    required int stars,
  }) async {
    try {
      await _firestore
          .collection('users')
          .doc(userId)
          .collection('topic_progress')
          .doc(topicId)
          .set({
        'topicId': topicId,
        'lessonsCompleted': lessonsCompleted,
        'stars': stars,
        'lastUpdated': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
    } catch (e) {
      throw 'Error updating topic progress: $e';
    }
  }

  // Get user's topic progress
  Future<Map<String, dynamic>?> getTopicProgress({
    required String userId,
    required String topicId,
  }) async {
    try {
      DocumentSnapshot doc = await _firestore
          .collection('users')
          .doc(userId)
          .collection('topic_progress')
          .doc(topicId)
          .get();
      
      if (doc.exists) {
        return doc.data() as Map<String, dynamic>?;
      }
      return null;
    } catch (e) {
      throw 'Error getting topic progress: $e';
    }
  }

  // Get all topic progress for user
  Future<List<Map<String, dynamic>>> getAllTopicProgress(String userId) async {
    try {
      QuerySnapshot snapshot = await _firestore
          .collection('users')
          .doc(userId)
          .collection('topic_progress')
          .get();

      return snapshot.docs
          .map((doc) => {
                'id': doc.id,
                ...doc.data() as Map<String, dynamic>,
              })
          .toList();
    } catch (e) {
      throw 'Error getting all topic progress: $e';
    }
  }

  // Update topics unlock status based on progress
  Future<List<MathTopic>> getUpdatedTopicsWithProgress(
    String userId,
    List<MathTopic> defaultTopics,
  ) async {
    try {
      final progressData = await getAllTopicProgress(userId);
      final Map<String, Map<String, dynamic>> progressMap = {
        for (var progress in progressData) 
          progress['topicId']: progress
      };

      List<MathTopic> updatedTopics = [];
      
      for (int i = 0; i < defaultTopics.length; i++) {
        final topic = defaultTopics[i];
        final progress = progressMap[topic.id];
        
        bool isUnlocked = topic.isUnlocked; // First topic should be unlocked
        
        // Check if previous topic qualifies for unlocking this one
        if (!isUnlocked && i > 0) {
          final previousTopic = defaultTopics[i - 1];
          final previousProgress = progressMap[previousTopic.id];
          
          if (previousProgress != null) {
            final previousCompleted = previousProgress['lessonsCompleted'] ?? 0;
            final previousTotal = previousTopic.totalLessons;
            // Unlock if previous topic is 70% complete
            if (previousCompleted / previousTotal >= 0.7) {
              isUnlocked = true;
            }
          }
        }

        updatedTopics.add(topic.copyWith(
          completedLessons: progress?['lessonsCompleted'] ?? 0,
          stars: progress?['stars'] ?? 0,
          isUnlocked: isUnlocked,
        ));
      }

      return updatedTopics;
    } catch (e) {
      throw 'Error updating topics with progress: $e';
    }
  }

  // Complete a lesson and update progress
  Future<void> completeLessonAndUpdateProgress({
    required String userId,
    required String topicId,
    required int newStars,
    required int score,
    required int totalQuestions,
    required int correctAnswers,
    required Duration timeSpent,
  }) async {
    try {
      // Get current progress
      final currentProgress = await getTopicProgress(userId: userId, topicId: topicId);
      final currentLessons = currentProgress?['lessonsCompleted'] ?? 0;
      final currentStars = currentProgress?['stars'] ?? 0;
      
      // Update lesson count and stars (take the max stars)
      final updatedLessons = currentLessons + 1;
      final updatedStars = currentStars > newStars ? currentStars : newStars;

      // Save practice session
      await savePracticeSession(
        userId: userId,
        topic: topicId,
        score: score,
        totalQuestions: totalQuestions,
        correctAnswers: correctAnswers,
        timeSpent: timeSpent,
      );

      // Update topic progress
      await updateTopicProgress(
        userId: userId,
        topicId: topicId,
        lessonsCompleted: updatedLessons,
        stars: updatedStars,
      );
    } catch (e) {
      throw 'Error completing lesson: $e';
    }
  }
}