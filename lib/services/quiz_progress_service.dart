import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'quiz_engine.dart';

class QuizProgressService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  Future<void> saveQuizAttempt(QuizAttempt attempt) async {
    try {
      final user = _auth.currentUser;
      if (user == null) return;

      await _firestore
          .collection('users')
          .doc(user.uid)
          .collection('quiz_attempts')
          .add(attempt.toMap());
    } catch (e) {
      print('Error saving quiz attempt: $e');
    }
  }

  Future<void> saveQuizSession(List<QuizAttempt> attempts, Map<String, dynamic> stats) async {
    try {
      final user = _auth.currentUser;
      if (user == null) return;

      final sessionData = {
        'attempts': attempts.map((a) => a.toMap()).toList(),
        'stats': stats,
        'sessionEnd': Timestamp.now(),
        'totalQuestions': attempts.length,
        'correctAnswers': attempts.where((a) => a.isCorrect).length,
        'accuracy': attempts.isEmpty ? 0.0 : attempts.where((a) => a.isCorrect).length / attempts.length,
      };

      await _firestore
          .collection('users')
          .doc(user.uid)
          .collection('quiz_sessions')
          .add(sessionData);

      await _updateUserProgress(stats);
    } catch (e) {
      print('Error saving quiz session: $e');
    }
  }

  Future<void> _updateUserProgress(Map<String, dynamic> stats) async {
    try {
      final user = _auth.currentUser;
      if (user == null) return;

      final userRef = _firestore.collection('users').doc(user.uid);
      
      await _firestore.runTransaction((transaction) async {
        final userDoc = await transaction.get(userRef);
        final userData = userDoc.data() ?? {};

        final currentScore = userData['totalScore'] ?? 0;
        final currentQuestionsAnswered = userData['totalQuestionsAnswered'] ?? 0;
        final currentCorrectAnswers = userData['totalCorrectAnswers'] ?? 0;

        final newQuestionsAnswered = currentQuestionsAnswered + stats['totalQuestions'];
        final newCorrectAnswers = currentCorrectAnswers + stats['correctAnswers'];
        final scoreToAdd = _calculateSessionScore(stats);

        transaction.update(userRef, {
          'totalScore': currentScore + scoreToAdd,
          'totalQuestionsAnswered': newQuestionsAnswered,
          'totalCorrectAnswers': newCorrectAnswers,
          'lastQuizDate': Timestamp.now(),
          'adaptiveQuizStats': {
            'bestStreak': stats['currentStreak'] > (userData['adaptiveQuizStats']?['bestStreak'] ?? 0)
                ? stats['currentStreak']
                : userData['adaptiveQuizStats']?['bestStreak'] ?? 0,
            'difficultyDistribution': stats['difficultyDistribution'],
            'averageAccuracy': newQuestionsAnswered > 0 ? newCorrectAnswers / newQuestionsAnswered : 0.0,
          },
        });
      });
    } catch (e) {
      print('Error updating user progress: $e');
    }
  }

  int _calculateSessionScore(Map<String, dynamic> stats) {
    final correctAnswers = stats['correctAnswers'] as int;
    final accuracy = stats['accuracy'] as double;
    final difficultyDistribution = stats['difficultyDistribution'] as Map<String, int>;

    int baseScore = correctAnswers * 10;

    int difficultyBonus = 0;
    difficultyBonus += (difficultyDistribution['easy'] ?? 0) * 5;
    difficultyBonus += (difficultyDistribution['medium'] ?? 0) * 10;
    difficultyBonus += (difficultyDistribution['hard'] ?? 0) * 20;

    int accuracyBonus = (accuracy * 100).round();
    int streakBonus = (stats['currentStreak'] as int) * 5;

    return baseScore + difficultyBonus + accuracyBonus + streakBonus;
  }

  Future<List<Map<String, dynamic>>> getQuizHistory({int limit = 10}) async {
    try {
      final user = _auth.currentUser;
      if (user == null) return [];

      final querySnapshot = await _firestore
          .collection('users')
          .doc(user.uid)
          .collection('quiz_sessions')
          .orderBy('sessionEnd', descending: true)
          .limit(limit)
          .get();

      return querySnapshot.docs.map((doc) => {
        'id': doc.id,
        ...doc.data(),
      }).toList();
    } catch (e) {
      print('Error getting quiz history: $e');
      return [];
    }
  }

  Future<Map<String, dynamic>?> getUserQuizStats() async {
    try {
      final user = _auth.currentUser;
      if (user == null) return null;

      final userDoc = await _firestore.collection('users').doc(user.uid).get();
      final userData = userDoc.data();
      
      if (userData == null) return null;

      return {
        'totalQuestionsAnswered': userData['totalQuestionsAnswered'] ?? 0,
        'totalCorrectAnswers': userData['totalCorrectAnswers'] ?? 0,
        'totalScore': userData['totalScore'] ?? 0,
        'adaptiveQuizStats': userData['adaptiveQuizStats'] ?? {},
        'lastQuizDate': userData['lastQuizDate'],
      };
    } catch (e) {
      print('Error getting user quiz stats: $e');
      return null;
    }
  }

  Stream<List<Map<String, dynamic>>> getRecentQuizAttempts({int limit = 20}) {
    final user = _auth.currentUser;
    if (user == null) {
      return Stream.value([]);
    }

    return _firestore
        .collection('users')
        .doc(user.uid)
        .collection('quiz_attempts')
        .orderBy('timestamp', descending: true)
        .limit(limit)
        .snapshots()
        .map((snapshot) => snapshot.docs.map((doc) => {
              'id': doc.id,
              ...doc.data(),
            }).toList());
  }
}