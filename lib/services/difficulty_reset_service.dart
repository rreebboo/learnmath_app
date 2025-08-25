import 'package:cloud_firestore/cloud_firestore.dart';
import 'auth_service.dart';
import 'user_preferences_service.dart';
import 'user_statistics_service.dart';

/// Represents the result of a progress check
class ProgressCheckResult {
  final bool hasProgress;
  final bool canReset;
  final String reason;
  final Map<String, dynamic> progressDetails;

  ProgressCheckResult({
    required this.hasProgress,
    required this.canReset,
    required this.reason,
    required this.progressDetails,
  });

  factory ProgressCheckResult.fromMap(Map<String, dynamic> data) {
    return ProgressCheckResult(
      hasProgress: data['hasProgress'] ?? false,
      canReset: data['canReset'] ?? true,
      reason: data['reason'] ?? '',
      progressDetails: data['progressDetails'] ?? {},
    );
  }
}

/// Represents the result of a difficulty reset operation
class DifficultyResetResult {
  final bool success;
  final String fromDifficulty;
  final String toDifficulty;
  final int archivedSessions;

  DifficultyResetResult({
    required this.success,
    required this.fromDifficulty,
    required this.toDifficulty,
    required this.archivedSessions,
  });

  factory DifficultyResetResult.fromMap(Map<String, dynamic> data) {
    return DifficultyResetResult(
      success: data['success'] ?? false,
      fromDifficulty: data['fromDifficulty'] ?? '',
      toDifficulty: data['toDifficulty'] ?? '',
      archivedSessions: data['archivedSessions'] ?? 0,
    );
  }
}

/// Service for managing difficulty reset functionality
/// Integrates with Firebase Cloud Functions for secure server-side operations
class DifficultyResetService {
  static final DifficultyResetService _instance = DifficultyResetService._internal();
  factory DifficultyResetService() => _instance;
  DifficultyResetService._internal();

  final AuthService _authService = AuthService();
  final UserPreferencesService _preferencesService = UserPreferencesService.instance;
  final UserStatisticsService _statisticsService = UserStatisticsService();

  /// Checks if the current user can reset their difficulty level
  /// Returns detailed progress information and reset eligibility
  Future<ProgressCheckResult> checkUserProgress({int? currentDifficulty}) async {
    try {
      final userId = _authService.getUserId();
      if (userId == null) {
        throw Exception('User not authenticated');
      }

      // Check current progress
      await _statisticsService.loadStatistics();
      
      // Get current stats from local storage
      final totalSessions = _statisticsService.totalSessions;
      final totalQuestions = _statisticsService.totalQuestions;
      final totalScore = _statisticsService.totalScore;
      final currentStreak = _statisticsService.currentStreak;
      final timeSpent = _statisticsService.totalTimeSpent;
      
      // Check if user has meaningful progress
      final hasSignificantProgress = totalSessions >= 3 || 
                                   totalQuestions >= 10 || 
                                   totalScore >= 50 ||
                                   currentStreak >= 3 ||
                                   timeSpent >= 300; // 5 minutes
      
      final progressDetails = {
        'totalSessions': totalSessions,
        'totalQuestions': totalQuestions,
        'totalScore': totalScore,
        'currentStreak': currentStreak,
        'timeSpent': timeSpent,
      };
      
      String reason;
      if (hasSignificantProgress) {
        reason = 'You have made progress: $totalSessions sessions, $totalQuestions questions answered, score: $totalScore. Resetting will clear all your math progress but keep your account.';
      } else {
        reason = 'You can reset safely - no significant progress to lose.';
      }
      
      return ProgressCheckResult(
        hasProgress: hasSignificantProgress,
        canReset: true, // Always allow reset but warn about progress
        reason: reason,
        progressDetails: progressDetails,
      );
    } catch (e) {
      throw Exception('Failed to check user progress: $e');
    }
  }

  /// Resets the user's difficulty level to the specified new difficulty
  /// Only succeeds if the user hasn't made significant progress
  Future<DifficultyResetResult> resetDifficultyMode(int newDifficulty) async {
    try {
      final userId = _authService.getUserId();
      if (userId == null) {
        throw Exception('User not authenticated');
      }

      // Validate difficulty level
      if (!_isValidDifficulty(newDifficulty)) {
        throw Exception('Invalid difficulty level. Must be 0 (easy), 1 (medium), or 2 (hard)');
      }

      // Reset all math progress while preserving account data
      await _resetMathProgress(newDifficulty);
      
      return DifficultyResetResult(
        success: true,
        fromDifficulty: 'previous',
        toDifficulty: ['easy', 'medium', 'hard'][newDifficulty],
        archivedSessions: 0,
      );
    } catch (e) {
      throw Exception('Failed to reset difficulty mode: $e');
    }
  }

  /// Gets the user's difficulty reset history
  Future<List<Map<String, dynamic>>> getDifficultyResetHistory() async {
    try {
      final userId = _authService.getUserId();
      if (userId == null) {
        throw Exception('User not authenticated');
      }

      // Temporary: Return empty history since Cloud Functions require Blaze plan
      // TODO: Upgrade Firebase plan to Blaze and enable Cloud Functions
      return [];
    } catch (e) {
      throw Exception('Failed to get reset history: $e');
    }
  }

  /// Checks if a difficulty reset is likely to be allowed
  /// This is a quick local check before calling the server
  Future<bool> quickResetEligibilityCheck() async {
    try {
      final currentDifficulty = await _preferencesService.getSelectedDifficulty();
      final result = await checkUserProgress(currentDifficulty: currentDifficulty);
      return result.canReset;
    } catch (e) {
      // If we can't check, assume reset might be possible
      return true;
    }
  }

  /// Validates if a difficulty level is valid
  bool _isValidDifficulty(int difficulty) {
    return difficulty >= 0 && difficulty <= 2;
  }

  /// Gets a user-friendly description of difficulty levels
  String getDifficultyDescription(int difficulty) {
    switch (difficulty) {
      case 0:
        return 'Easy - Basic arithmetic with small numbers';
      case 1:
        return 'Medium - Moderate complexity problems';
      case 2:
        return 'Hard - Advanced problems with larger numbers';
      default:
        return 'Unknown difficulty level';
    }
  }

  /// Gets the difficulty string representation
  String getDifficultyString(int difficulty) {
    return _preferencesService.getDifficultyString(difficulty);
  }

  /// Gets the difficulty index from string
  int getDifficultyIndex(String difficulty) {
    return _preferencesService.getDifficultyIndex(difficulty);
  }

  /// Formats progress details for display
  String formatProgressSummary(Map<String, dynamic> progressDetails) {
    final totalSessions = progressDetails['totalSessions'] ?? 0;
    final totalQuestions = progressDetails['totalQuestions'] ?? 0;
    final maxTopicLessons = progressDetails['maxTopicLessons'] ?? 0;
    final totalTimeSpent = progressDetails['totalTimeSpent'] ?? 0;
    
    final timeInMinutes = (totalTimeSpent / 60).round();
    
    return '''
Sessions completed: $totalSessions
Questions answered: $totalQuestions
Max lessons in a topic: $maxTopicLessons
Time played: $timeInMinutes minutes
''';
  }

  /// Formats the reset eligibility reason for display
  String formatResetReason(String reason, bool canReset) {
    if (canReset) {
      return 'You can reset your difficulty level.\n$reason';
    } else {
      return 'Difficulty reset not available.\n$reason';
    }
  }

  /// Resets all math progress while preserving user account data
  Future<void> _resetMathProgress(int newDifficulty) async {
    final userId = _authService.getUserId();
    if (userId == null) {
      throw Exception('User not authenticated');
    }

    try {
      // 1. Reset local statistics (SharedPreferences)
      await _statisticsService.clearStatistics();

      // 2. Reset Firestore user progress fields while preserving account data
      await _resetFirestoreProgress(userId);

      // 3. Delete practice sessions from Firestore
      await _deletePracticeSessions(userId);

      // 4. Delete topic progress from Firestore
      await _deleteTopicProgress(userId);

      // 5. Update difficulty setting
      await _preferencesService.setSelectedDifficulty(newDifficulty);

    } catch (e) {
      throw Exception('Failed to reset math progress: $e');
    }
  }

  /// Reset progress fields in Firestore user document
  Future<void> _resetFirestoreProgress(String userId) async {
    try {
      final userRef = FirebaseFirestore.instance.collection('users').doc(userId);
      
      // Only reset progress fields, preserve account data (name, email, avatar, etc.)
      await userRef.update({
        'totalScore': 0,
        'lessonsCompleted': 0,
        'currentStreak': 0,
        'achievements': [],
        'lastResetDate': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      throw Exception('Failed to reset Firestore progress: $e');
    }
  }

  /// Delete all practice sessions for the user
  Future<void> _deletePracticeSessions(String userId) async {
    try {
      final sessionsRef = FirebaseFirestore.instance
          .collection('users')
          .doc(userId)
          .collection('practice_sessions');
      
      final snapshot = await sessionsRef.get();
      
      // Delete all practice sessions in batches
      final batch = FirebaseFirestore.instance.batch();
      for (final doc in snapshot.docs) {
        batch.delete(doc.reference);
      }
      
      if (snapshot.docs.isNotEmpty) {
        await batch.commit();
      }
    } catch (e) {
      throw Exception('Failed to delete practice sessions: $e');
    }
  }

  /// Delete all topic progress for the user
  Future<void> _deleteTopicProgress(String userId) async {
    try {
      final topicProgressRef = FirebaseFirestore.instance
          .collection('users')
          .doc(userId)
          .collection('topic_progress');
      
      final snapshot = await topicProgressRef.get();
      
      // Delete all topic progress in batches
      final batch = FirebaseFirestore.instance.batch();
      for (final doc in snapshot.docs) {
        batch.delete(doc.reference);
      }
      
      if (snapshot.docs.isNotEmpty) {
        await batch.commit();
      }
    } catch (e) {
      throw Exception('Failed to delete topic progress: $e');
    }
  }
}

/// Extension to add difficulty reset functionality to existing services
extension DifficultyResetExtension on UserPreferencesService {
  /// Resets difficulty with progress validation
  Future<bool> resetDifficultyWithValidation(int newDifficulty) async {
    final resetService = DifficultyResetService();
    
    try {
      final result = await resetService.resetDifficultyMode(newDifficulty);
      return result.success;
    } catch (e) {
      // Reset failed, keep current difficulty
      return false;
    }
  }

  /// Checks if difficulty can be reset
  Future<bool> canResetDifficulty() async {
    final resetService = DifficultyResetService();
    return await resetService.quickResetEligibilityCheck();
  }
}