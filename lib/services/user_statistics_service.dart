import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'auth_service.dart';
import 'achievement_service.dart';

class UserStatisticsService {
  static const String _statsKeyPrefix = 'user_statistics_';

  // Singleton pattern
  static final UserStatisticsService _instance = UserStatisticsService._internal();
  factory UserStatisticsService() => _instance;
  UserStatisticsService._internal();

  final AuthService _authService = AuthService();
  final AchievementService _achievementService = AchievementService();

  // Real-time statistics
  int totalSessions = 0;
  int totalQuestions = 0;
  int totalCorrectAnswers = 0;
  int totalTimeSpent = 0; // in seconds
  int currentStreak = 0;
  int bestStreak = 0;
  int totalStars = 0;
  int totalScore = 0;
  Map<String, TopicStats> topicStats = {};
  Map<String, DifficultyStats> difficultyStats = {};

  String get _currentUserStatsKey {
    final userId = _authService.getUserId();
    return userId != null ? '$_statsKeyPrefix$userId' : '${_statsKeyPrefix}anonymous';
  }

  Future<void> loadStatistics() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final statsString = prefs.getString(_currentUserStatsKey);
      
      if (statsString != null) {
        final stats = jsonDecode(statsString) as Map<String, dynamic>;
        totalSessions = stats['totalSessions'] ?? 0;
        totalQuestions = stats['totalQuestions'] ?? 0;
        totalCorrectAnswers = stats['totalCorrectAnswers'] ?? 0;
        totalTimeSpent = stats['totalTimeSpent'] ?? 0;
        currentStreak = stats['currentStreak'] ?? 0;
        bestStreak = stats['bestStreak'] ?? 0;
        totalStars = stats['totalStars'] ?? 0;
        totalScore = stats['totalScore'] ?? 0;
        
        // Load topic stats
        final topicStatsMap = stats['topicStats'] as Map<String, dynamic>? ?? {};
        topicStats = topicStatsMap.map((key, value) => 
          MapEntry(key, TopicStats.fromMap(value as Map<String, dynamic>))
        );
        
        // Load difficulty stats
        final difficultyStatsMap = stats['difficultyStats'] as Map<String, dynamic>? ?? {};
        difficultyStats = difficultyStatsMap.map((key, value) => 
          MapEntry(key, DifficultyStats.fromMap(value as Map<String, dynamic>))
        );
      }
    } catch (e) {
      // If loading fails, start with fresh stats
      _initializeDefaultStats();
    }
  }

  Future<void> saveStatistics() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final stats = {
        'totalSessions': totalSessions,
        'totalQuestions': totalQuestions,
        'totalCorrectAnswers': totalCorrectAnswers,
        'totalTimeSpent': totalTimeSpent,
        'currentStreak': currentStreak,
        'bestStreak': bestStreak,
        'totalStars': totalStars,
        'totalScore': totalScore,
        'topicStats': topicStats.map((key, value) => MapEntry(key, value.toMap())),
        'difficultyStats': difficultyStats.map((key, value) => MapEntry(key, value.toMap())),
      };
      
      await prefs.setString(_currentUserStatsKey, jsonEncode(stats));
    } catch (e) {
      // Error saving statistics: $e
    }
  }

  Future<void> recordSession({
    required String topic,
    required String difficulty,
    required int questions,
    required int correctAnswers,
    required int timeSpent,
    required int stars,
    required int score,
  }) async {
    // Update global stats
    totalSessions++;
    totalQuestions += questions;
    totalCorrectAnswers += correctAnswers;
    totalTimeSpent += timeSpent;
    totalStars += stars;
    totalScore += score;

    // Update streak
    final accuracy = correctAnswers / questions;
    if (accuracy >= 0.7) { // Good performance continues streak
      currentStreak++;
      if (currentStreak > bestStreak) {
        bestStreak = currentStreak;
      }
    } else {
      currentStreak = 0; // Reset streak on poor performance
    }

    // Update topic stats
    final topicKey = topic.toLowerCase();
    if (!topicStats.containsKey(topicKey)) {
      topicStats[topicKey] = TopicStats(topic: topic);
    }
    topicStats[topicKey]!.addSession(questions, correctAnswers, timeSpent, stars, score);

    // Update difficulty stats
    final difficultyKey = difficulty.toLowerCase();
    if (!difficultyStats.containsKey(difficultyKey)) {
      difficultyStats[difficultyKey] = DifficultyStats(difficulty: difficulty);
    }
    difficultyStats[difficultyKey]!.addSession(questions, correctAnswers, timeSpent, stars, score);

    // Save to persistent storage
    await saveStatistics();

    // Check for achievements
    await _achievementService.checkAchievements(
      correctAnswers: correctAnswers,
      streak: currentStreak,
      totalScore: totalScore,
      perfectQuiz: questions > 0 && correctAnswers == questions,
    );
  }

  // Getters for common statistics
  double get overallAccuracy => totalQuestions > 0 ? totalCorrectAnswers / totalQuestions : 0.0;
  double get averageSessionTime => totalSessions > 0 ? totalTimeSpent / totalSessions : 0.0;
  double get averageScore => totalSessions > 0 ? totalScore / totalSessions : 0.0;
  double get averageStars => totalSessions > 0 ? totalStars / totalSessions : 0.0;

  void _initializeDefaultStats() {
    totalSessions = 0;
    totalQuestions = 0;
    totalCorrectAnswers = 0;
    totalTimeSpent = 0;
    currentStreak = 0;
    bestStreak = 0;
    totalStars = 0;
    totalScore = 0;
    topicStats.clear();
    difficultyStats.clear();
  }

  // Get formatted statistics for display
  Map<String, String> getFormattedStats() {
    return {
      'Sessions Completed': totalSessions.toString(),
      'Total Questions': totalQuestions.toString(),
      'Overall Accuracy': '${(overallAccuracy * 100).round()}%',
      'Current Streak': currentStreak.toString(),
      'Best Streak': bestStreak.toString(),
      'Total Score': totalScore.toString(),
      'Average Stars': averageStars.toStringAsFixed(1),
      'Time Played': _formatDuration(Duration(seconds: totalTimeSpent)),
    };
  }

  String _formatDuration(Duration duration) {
    final hours = duration.inHours;
    final minutes = duration.inMinutes.remainder(60);
    
    if (hours > 0) {
      return '${hours}h ${minutes}m';
    } else {
      return '${minutes}m';
    }
  }

  // Clear all statistics (for testing or reset)
  Future<void> clearStatistics() async {
    _initializeDefaultStats();
    await saveStatistics();
  }

  // Clear statistics for current user and reset to defaults
  Future<void> resetCurrentUserData() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_currentUserStatsKey);
      _initializeDefaultStats();
    } catch (e) {
      _initializeDefaultStats();
    }
  }

  // Clear all user data from device (for complete app reset)
  Future<void> clearAllUserData() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final keys = prefs.getKeys().where((key) => key.startsWith(_statsKeyPrefix));
      for (final key in keys) {
        await prefs.remove(key);
      }
      _initializeDefaultStats();
    } catch (e) {
      _initializeDefaultStats();
    }
  }
}

class TopicStats {
  String topic;
  int sessions;
  int questions;
  int correctAnswers;
  int timeSpent;
  int totalStars;
  int totalScore;
  int bestStars;
  int bestScore;

  TopicStats({
    required this.topic,
    this.sessions = 0,
    this.questions = 0,
    this.correctAnswers = 0,
    this.timeSpent = 0,
    this.totalStars = 0,
    this.totalScore = 0,
    this.bestStars = 0,
    this.bestScore = 0,
  });

  void addSession(int qs, int correct, int time, int stars, int score) {
    sessions++;
    questions += qs;
    correctAnswers += correct;
    timeSpent += time;
    totalStars += stars;
    totalScore += score;
    
    if (stars > bestStars) bestStars = stars;
    if (score > bestScore) bestScore = score;
  }

  double get accuracy => questions > 0 ? correctAnswers / questions : 0.0;
  double get averageScore => sessions > 0 ? totalScore / sessions : 0.0;
  double get averageStars => sessions > 0 ? totalStars / sessions : 0.0;

  Map<String, dynamic> toMap() {
    return {
      'topic': topic,
      'sessions': sessions,
      'questions': questions,
      'correctAnswers': correctAnswers,
      'timeSpent': timeSpent,
      'totalStars': totalStars,
      'totalScore': totalScore,
      'bestStars': bestStars,
      'bestScore': bestScore,
    };
  }

  factory TopicStats.fromMap(Map<String, dynamic> map) {
    return TopicStats(
      topic: map['topic'] ?? '',
      sessions: map['sessions'] ?? 0,
      questions: map['questions'] ?? 0,
      correctAnswers: map['correctAnswers'] ?? 0,
      timeSpent: map['timeSpent'] ?? 0,
      totalStars: map['totalStars'] ?? 0,
      totalScore: map['totalScore'] ?? 0,
      bestStars: map['bestStars'] ?? 0,
      bestScore: map['bestScore'] ?? 0,
    );
  }
}

class DifficultyStats {
  String difficulty;
  int sessions;
  int questions;
  int correctAnswers;
  int timeSpent;
  int totalStars;
  int totalScore;

  DifficultyStats({
    required this.difficulty,
    this.sessions = 0,
    this.questions = 0,
    this.correctAnswers = 0,
    this.timeSpent = 0,
    this.totalStars = 0,
    this.totalScore = 0,
  });

  void addSession(int qs, int correct, int time, int stars, int score) {
    sessions++;
    questions += qs;
    correctAnswers += correct;
    timeSpent += time;
    totalStars += stars;
    totalScore += score;
  }

  double get accuracy => questions > 0 ? correctAnswers / questions : 0.0;
  double get averageScore => sessions > 0 ? totalScore / sessions : 0.0;

  Map<String, dynamic> toMap() {
    return {
      'difficulty': difficulty,
      'sessions': sessions,
      'questions': questions,
      'correctAnswers': correctAnswers,
      'timeSpent': timeSpent,
      'totalStars': totalStars,
      'totalScore': totalScore,
    };
  }

  factory DifficultyStats.fromMap(Map<String, dynamic> map) {
    return DifficultyStats(
      difficulty: map['difficulty'] ?? '',
      sessions: map['sessions'] ?? 0,
      questions: map['questions'] ?? 0,
      correctAnswers: map['correctAnswers'] ?? 0,
      timeSpent: map['timeSpent'] ?? 0,
      totalStars: map['totalStars'] ?? 0,
      totalScore: map['totalScore'] ?? 0,
    );
  }
}