import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'notification_service.dart';

class AchievementService {
  static final AchievementService _instance = AchievementService._internal();
  factory AchievementService() => _instance;
  AchievementService._internal();

  FirebaseFirestore? _firestoreInstance;
  FirebaseAuth? _authInstance;
  final NotificationService _notificationService = NotificationService();

  FirebaseFirestore get _firestore => _firestoreInstance ??= FirebaseFirestore.instance;
  FirebaseAuth get _auth => _authInstance ??= FirebaseAuth.instance;

  String? get currentUserId => _auth.currentUser?.uid;

  // Check and unlock achievements
  Future<void> checkAchievements({
    int? correctAnswers,
    int? streak,
    int? totalScore,
    bool? perfectQuiz,
    String? difficulty,
  }) async {
    if (currentUserId == null) return;

    try {
      // Get user data
      final userDoc = await _firestore.collection('users').doc(currentUserId!).get();
      if (!userDoc.exists) return;

      final userData = userDoc.data()!;
      final unlockedAchievements = List<String>.from(userData['achievements'] ?? []);

      // Check various achievements
      await _checkScoreAchievements(totalScore ?? userData['totalScore'] ?? 0, unlockedAchievements);
      await _checkStreakAchievements(streak ?? userData['currentStreak'] ?? 0, unlockedAchievements);
      await _checkPerfectQuizAchievements(perfectQuiz, unlockedAchievements);
      await _checkFirstWinAchievement(correctAnswers, unlockedAchievements);

    } catch (e) {
      print('Error checking achievements: $e');
    }
  }

  Future<void> _checkScoreAchievements(int totalScore, List<String> unlockedAchievements) async {
    final achievements = [
      {'id': 'score_100', 'threshold': 100, 'title': '🎯 First Century!', 'message': 'You scored 100 points! Keep it up!'},
      {'id': 'score_500', 'threshold': 500, 'title': '🚀 Math Rocket!', 'message': 'Amazing! You reached 500 points!'},
      {'id': 'score_1000', 'threshold': 1000, 'title': '🏆 Math Champion!', 'message': 'Incredible! 1000 points unlocked!'},
      {'id': 'score_2500', 'threshold': 2500, 'title': '⭐ Math Superstar!', 'message': 'Outstanding! 2500 points achieved!'},
    ];

    for (final achievement in achievements) {
      final threshold = achievement['threshold'] as int;
      final id = achievement['id'] as String;
      final title = achievement['title'] as String;
      final message = achievement['message'] as String;

      if (totalScore >= threshold && !unlockedAchievements.contains(id)) {
        await _unlockAchievement(id, title, message);
      }
    }
  }

  Future<void> _checkStreakAchievements(int streak, List<String> unlockedAchievements) async {
    final achievements = [
      {'id': 'streak_3', 'threshold': 3, 'title': '🔥 On Fire!', 'message': '3-day streak! You\'re building momentum!'},
      {'id': 'streak_7', 'threshold': 7, 'title': '⚡ Lightning Bolt!', 'message': '7-day streak! Unstoppable!'},
      {'id': 'streak_14', 'threshold': 14, 'title': '💪 Math Warrior!', 'message': '2-week streak! You\'re dedicated!'},
      {'id': 'streak_30', 'threshold': 30, 'title': '👑 Math Royalty!', 'message': '30-day streak! You\'re a legend!'},
    ];

    for (final achievement in achievements) {
      final threshold = achievement['threshold'] as int;
      final id = achievement['id'] as String;
      final title = achievement['title'] as String;
      final message = achievement['message'] as String;

      if (streak >= threshold && !unlockedAchievements.contains(id)) {
        await _unlockAchievement(id, title, message);
      }
    }
  }

  Future<void> _checkPerfectQuizAchievements(bool? perfectQuiz, List<String> unlockedAchievements) async {
    if (perfectQuiz == true && !unlockedAchievements.contains('perfect_quiz')) {
      await _unlockAchievement(
        'perfect_quiz',
        '🎯 Perfect Score!',
        'Flawless! You answered every question correctly!',
      );
    }
  }

  Future<void> _checkFirstWinAchievement(int? correctAnswers, List<String> unlockedAchievements) async {
    if (correctAnswers != null && correctAnswers > 0 && !unlockedAchievements.contains('first_win')) {
      await _unlockAchievement(
        'first_win',
        '🥇 First Victory!',
        'Congratulations on your first correct answer!',
      );
    }
  }

  Future<void> _unlockAchievement(String achievementId, String title, String message) async {
    if (currentUserId == null) return;

    try {
      // Add achievement to user's collection
      await _firestore.collection('users').doc(currentUserId!).update({
        'achievements': FieldValue.arrayUnion([achievementId]),
      });

      // Note: User data can be retrieved if needed for future notification customization

      // Send achievement notification
      await _notificationService.sendGeneralNotification(
        toUserId: currentUserId!,
        title: title,
        message: message,
        data: {
          'type': 'achievement',
          'achievementId': achievementId,
        },
      );

      print('Achievement unlocked: $achievementId');

    } catch (e) {
      print('Error unlocking achievement $achievementId: $e');
    }
  }

  // Get user's achievements
  Future<List<String>> getUserAchievements() async {
    if (currentUserId == null) return [];

    try {
      final userDoc = await _firestore.collection('users').doc(currentUserId!).get();
      if (userDoc.exists) {
        final userData = userDoc.data()!;
        return List<String>.from(userData['achievements'] ?? []);
      }
    } catch (e) {
      print('Error getting user achievements: $e');
    }

    return [];
  }
}