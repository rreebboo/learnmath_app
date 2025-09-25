import '../models/math_topic.dart';
import 'firestore_service.dart';
import 'auth_service.dart';
import 'leaderboard_service.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class ProgressionService {
  static ProgressionService? _instance;
  static ProgressionService get instance {
    return _instance ??= ProgressionService._();
  }

  ProgressionService._();

  final FirestoreService _firestoreService = FirestoreService();
  final AuthService _authService = AuthService();
  
  // Check if a perfect score (100% accuracy) unlocks the next topic
  Future<bool> checkPerfectScore(String topicId, String difficulty, double accuracy) async {
    if (accuracy < 1.0) return false; // Must be perfect score

    final userId = _authService.getUserId();
    if (userId == null) return false;

    // Get perfect scores from Firebase
    final perfectScores = await getPerfectScoresForTopic(topicId);

    if (!perfectScores.contains(difficulty)) {
      // Store perfect score in Firebase
      await _savePerfectScore(userId, topicId, difficulty);
      return true; // New perfect score achieved
    }

    return false; // Already had perfect score
  }
  
  // Get perfect scores for a topic across all difficulties
  Future<Set<String>> getPerfectScoresForTopic(String topicId) async {
    final userId = _authService.getUserId();
    if (userId == null) return {};

    try {
      final userData = await _firestoreService.getUserData(userId);
      final perfectScores = userData?['perfectScores'] as Map<String, dynamic>? ?? {};
      final topicScores = perfectScores[topicId] as List<dynamic>? ?? [];

      return topicScores.cast<String>().toSet();
    } catch (e) {
      return {};
    }
  }
  
  // Check if a topic should be unlocked based on perfect scores in previous topic
  Future<bool> shouldUnlockTopic(String topicId, List<MathTopic> allTopics) async {
    // Find the current topic index
    int currentIndex = allTopics.indexWhere((t) => t.id == topicId);
    if (currentIndex <= 0) return true; // First topic is always unlocked
    
    // Check if previous topic has perfect scores in at least one difficulty
    String previousTopicId = allTopics[currentIndex - 1].id;
    Set<String> perfectScores = await getPerfectScoresForTopic(previousTopicId);
    
    return perfectScores.isNotEmpty; // Unlock if any perfect score exists
  }
  
  // Get unlocked topics
  Future<Set<String>> getUnlockedTopics() async {
    final userId = _authService.getUserId();
    if (userId == null) return {'addition'}; // Default first topic unlocked

    try {
      final userData = await _firestoreService.getUserData(userId);
      final unlockedList = userData?['unlockedTopics'] as List<dynamic>? ?? ['addition'];
      return unlockedList.cast<String>().toSet();
    } catch (e) {
      return {'addition'}; // Default first topic unlocked
    }
  }
  
  // Set unlocked topics
  Future<void> setUnlockedTopics(Set<String> unlockedTopics) async {
    final userId = _authService.getUserId();
    if (userId == null) return;

    try {
      await _updateUserData(userId, {
        'unlockedTopics': unlockedTopics.toList(),
      });
    } catch (e) {
      print('Error setting unlocked topics: $e');
    }
  }

  // Helper method to save perfect score using subcollection
  Future<void> _savePerfectScore(String userId, String topicId, String difficulty) async {
    try {
      final firestore = FirebaseFirestore.instance;
      final scoreId = '${topicId}_$difficulty';

      // Store in user's lesson_progress subcollection
      await firestore
          .collection('users')
          .doc(userId)
          .collection('lesson_progress')
          .doc(scoreId)
          .set({
        'topicId': topicId,
        'difficulty': difficulty,
        'isPerfectScore': true,
        'achievedAt': FieldValue.serverTimestamp(),
        'lastUpdated': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      // Also update the main user document for quick access
      final userData = await _firestoreService.getUserData(userId);
      final perfectScores = Map<String, dynamic>.from(userData?['perfectScores'] as Map<String, dynamic>? ?? {});

      if (perfectScores[topicId] == null) {
        perfectScores[topicId] = <String>[];
      }

      final topicScores = List<String>.from(perfectScores[topicId] as List<dynamic>? ?? []);
      if (!topicScores.contains(difficulty)) {
        topicScores.add(difficulty);
        perfectScores[topicId] = topicScores;

        await _updateUserData(userId, {
          'perfectScores': perfectScores,
        });
      }
    } catch (e) {
      print('Error saving perfect score: $e');
    }
  }

  // Helper method to update user data
  Future<void> _updateUserData(String userId, Map<String, dynamic> data) async {
    // Use a direct Firestore update for custom fields
    final firestore = FirebaseFirestore.instance;
    await firestore.collection('users').doc(userId).update(data);
  }

  // Save comprehensive lesson session data
  Future<void> saveLessonSession({
    required String topicId,
    required String difficulty,
    required double accuracy,
    required int score,
    required int totalQuestions,
    required int correctAnswers,
    required Duration timeSpent,
    Map<String, dynamic>? additionalData,
  }) async {
    final userId = _authService.getUserId();
    if (userId == null) return;

    try {
      final firestore = FirebaseFirestore.instance;
      final sessionId = DateTime.now().millisecondsSinceEpoch.toString();

      // Store detailed session in user's lesson_sessions subcollection
      await firestore
          .collection('users')
          .doc(userId)
          .collection('lesson_sessions')
          .doc(sessionId)
          .set({
        'topicId': topicId,
        'difficulty': difficulty,
        'accuracy': accuracy,
        'score': score,
        'totalQuestions': totalQuestions,
        'correctAnswers': correctAnswers,
        'timeSpentSeconds': timeSpent.inSeconds,
        'isPerfectScore': accuracy >= 1.0,
        'completedAt': FieldValue.serverTimestamp(),
        'userId': userId, // For easy querying
        ...?additionalData,
      });

      // Update or create progress record in lesson_progress subcollection
      final progressId = '${topicId}_$difficulty';
      await firestore
          .collection('users')
          .doc(userId)
          .collection('lesson_progress')
          .doc(progressId)
          .set({
        'topicId': topicId,
        'difficulty': difficulty,
        'bestScore': score,
        'bestAccuracy': accuracy,
        'totalAttempts': FieldValue.increment(1),
        'totalTimeSpent': FieldValue.increment(timeSpent.inSeconds),
        'isPerfectScore': accuracy >= 1.0,
        'lastPlayedAt': FieldValue.serverTimestamp(),
        'lastUpdated': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

    } catch (e) {
      print('Error saving lesson session: $e');
    }
  }

  // Get user's lesson progress for a specific topic
  Future<Map<String, dynamic>?> getLessonProgress(String topicId, String difficulty) async {
    final userId = _authService.getUserId();
    if (userId == null) return null;

    try {
      final firestore = FirebaseFirestore.instance;
      final progressId = '${topicId}_$difficulty';

      final doc = await firestore
          .collection('users')
          .doc(userId)
          .collection('lesson_progress')
          .doc(progressId)
          .get();

      return doc.exists ? doc.data() : null;
    } catch (e) {
      print('Error getting lesson progress: $e');
      return null;
    }
  }

  // Get all lesson progress for a user
  Future<List<Map<String, dynamic>>> getAllLessonProgress() async {
    final userId = _authService.getUserId();
    if (userId == null) return [];

    try {
      final firestore = FirebaseFirestore.instance;

      final snapshot = await firestore
          .collection('users')
          .doc(userId)
          .collection('lesson_progress')
          .orderBy('lastUpdated', descending: true)
          .get();

      return snapshot.docs.map((doc) => {
        'id': doc.id,
        ...doc.data(),
      }).toList();
    } catch (e) {
      print('Error getting all lesson progress: $e');
      return [];
    }
  }

  // Get recent lesson sessions for analytics
  Future<List<Map<String, dynamic>>> getRecentLessonSessions({int limit = 20}) async {
    final userId = _authService.getUserId();
    if (userId == null) return [];

    try {
      final firestore = FirebaseFirestore.instance;

      final snapshot = await firestore
          .collection('users')
          .doc(userId)
          .collection('lesson_sessions')
          .orderBy('completedAt', descending: true)
          .limit(limit)
          .get();

      return snapshot.docs.map((doc) => {
        'id': doc.id,
        ...doc.data(),
      }).toList();
    } catch (e) {
      print('Error getting recent lesson sessions: $e');
      return [];
    }
  }
  
  // Update progression after a session with comprehensive data saving
  Future<Map<String, dynamic>> updateProgression(
    String topicId,
    String difficulty,
    double accuracy,
    List<MathTopic> allTopics, {
    int? score,
    int? totalQuestions,
    int? correctAnswers,
    Duration? timeSpent,
    Map<String, dynamic>? additionalData,
  }) async {
    Map<String, dynamic> result = {
      'perfectScore': false,
      'newTopicUnlocked': false,
      'unlockedTopicId': null,
    };

    // Save comprehensive lesson session data if provided
    if (score != null && totalQuestions != null && correctAnswers != null && timeSpent != null) {
      await saveLessonSession(
        topicId: topicId,
        difficulty: difficulty,
        accuracy: accuracy,
        score: score,
        totalQuestions: totalQuestions,
        correctAnswers: correctAnswers,
        timeSpent: timeSpent,
        additionalData: additionalData,
      );

      // Update leaderboard with the new score
      final userId = _authService.getUserId();
      if (userId != null) {
        await LeaderboardService.instance.updateUserLeaderboardData(
          userId: userId,
          scoreToAdd: score,
          lessonCompleted: true,
        );
      }
    }

    // Check for perfect score
    bool newPerfectScore = await checkPerfectScore(topicId, difficulty, accuracy);
    result['perfectScore'] = newPerfectScore;

    // If perfect score, check if next topic should be unlocked
    if (newPerfectScore) {
      int currentIndex = allTopics.indexWhere((t) => t.id == topicId);
      if (currentIndex >= 0 && currentIndex < allTopics.length - 1) {
        String nextTopicId = allTopics[currentIndex + 1].id;

        // Check if next topic should be unlocked
        bool shouldUnlock = await shouldUnlockTopic(nextTopicId, allTopics);
        if (shouldUnlock) {
          Set<String> unlockedTopics = await getUnlockedTopics();
          if (!unlockedTopics.contains(nextTopicId)) {
            unlockedTopics.add(nextTopicId);
            await setUnlockedTopics(unlockedTopics);

            result['newTopicUnlocked'] = true;
            result['unlockedTopicId'] = nextTopicId;
          }
        }
      }
    }

    return result;
  }
  
  // Apply progression rules to topic list
  Future<List<MathTopic>> applyProgressionRules(List<MathTopic> topics) async {
    Set<String> unlockedTopics = await getUnlockedTopics();
    
    List<MathTopic> updatedTopics = [];
    
    for (int i = 0; i < topics.length; i++) {
      MathTopic topic = topics[i];
      bool isUnlocked = topic.isUnlocked;
      
      // First topic is always unlocked
      if (i == 0) {
        isUnlocked = true;
        unlockedTopics.add(topic.id);
      } else {
        // Check if this topic should be unlocked
        isUnlocked = unlockedTopics.contains(topic.id) || 
                    await shouldUnlockTopic(topic.id, topics);
      }
      
      // Get perfect scores for this topic to calculate stars
      Set<String> perfectScores = await getPerfectScoresForTopic(topic.id);
      int stars = perfectScores.length; // 1 star per difficulty with perfect score
      int completedLessons = perfectScores.isNotEmpty ? 1 : 0;
      
      updatedTopics.add(topic.copyWith(
        isUnlocked: isUnlocked,
        stars: stars,
        completedLessons: completedLessons,
      ));
    }
    
    // Update unlocked topics in storage
    await setUnlockedTopics(unlockedTopics);
    
    return updatedTopics;
  }
  
  // Reset all progression (for testing or new users)
  Future<void> resetProgression() async {
    final userId = _authService.getUserId();
    if (userId == null) return;

    try {
      final firestore = FirebaseFirestore.instance;

      // Clear lesson_progress subcollection
      final progressSnapshot = await firestore
          .collection('users')
          .doc(userId)
          .collection('lesson_progress')
          .get();

      for (var doc in progressSnapshot.docs) {
        await doc.reference.delete();
      }

      // Clear lesson_sessions subcollection
      final sessionsSnapshot = await firestore
          .collection('users')
          .doc(userId)
          .collection('lesson_sessions')
          .get();

      for (var doc in sessionsSnapshot.docs) {
        await doc.reference.delete();
      }

      // Reset main user document fields
      await _updateUserData(userId, {
        'unlockedTopics': ['addition'],
        'perfectScores': {},
      });
    } catch (e) {
      print('Error resetting progression: $e');
    }
  }

  // Reset progression and start fresh (only keeps first topic unlocked)
  Future<void> resetToBeginning() async {
    await resetProgression(); // Use the comprehensive reset method
  }

  // Check if user has any progress
  Future<bool> hasAnyProgress() async {
    final userId = _authService.getUserId();
    if (userId == null) return false;

    try {
      final userData = await _firestoreService.getUserData(userId);
      final perfectScores = userData?['perfectScores'] as Map<String, dynamic>? ?? {};
      final unlockedTopics = await getUnlockedTopics();

      // User has progress if they have perfect scores OR more than just the first topic unlocked
      return perfectScores.isNotEmpty || unlockedTopics.length > 1;
    } catch (e) {
      return false;
    }
  }

  // Get current progress summary
  Future<Map<String, dynamic>> getProgressSummary() async {
    final userId = _authService.getUserId();
    if (userId == null) {
      return {
        'unlockedTopicsCount': 1,
        'perfectScoresCount': 0,
        'hasProgress': false,
        'unlockedTopics': ['addition'],
        'perfectScores': {},
      };
    }

    try {
      final userData = await _firestoreService.getUserData(userId);
      final perfectScores = userData?['perfectScores'] as Map<String, dynamic>? ?? {};
      final unlockedTopics = await getUnlockedTopics();

      // Count total perfect scores across all topics
      int totalPerfectScores = 0;
      for (var topicScores in perfectScores.values) {
        if (topicScores is List) {
          totalPerfectScores += topicScores.length;
        }
      }

      return {
        'unlockedTopicsCount': unlockedTopics.length,
        'perfectScoresCount': totalPerfectScores,
        'hasProgress': await hasAnyProgress(),
        'unlockedTopics': unlockedTopics.toList(),
        'perfectScores': perfectScores,
      };
    } catch (e) {
      return {
        'unlockedTopicsCount': 1,
        'perfectScoresCount': 0,
        'hasProgress': false,
        'unlockedTopics': ['addition'],
        'perfectScores': {},
      };
    }
  }
}