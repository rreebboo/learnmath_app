import 'package:cloud_firestore/cloud_firestore.dart';
import 'firestore_service.dart';

class LeaderboardService {
  final FirestoreService _firestoreService = FirestoreService();
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // Get leaderboard with different time periods
  Stream<List<LeaderboardUser>> getLeaderboardStream({
    String period = 'all-time',
    String grade = 'all',
    int limit = 50,
  }) {
    Query query = _firestore.collection('users');

    // Apply grade filter if specified
    if (grade != 'all' && grade.isNotEmpty) {
      // For now, we'll assume grade is stored in user preferences
      // You might want to add a 'grade' field to user documents
      query = query.where('preferences.grade', isEqualTo: grade);
    }

    // Apply time-based filtering for different periods
    if (period == 'weekly') {
      final weekAgo = DateTime.now().subtract(const Duration(days: 7));
      query = query.where('lastLoginDate', isGreaterThanOrEqualTo: Timestamp.fromDate(weekAgo));
    } else if (period == 'monthly') {
      final monthAgo = DateTime.now().subtract(const Duration(days: 30));
      query = query.where('lastLoginDate', isGreaterThanOrEqualTo: Timestamp.fromDate(monthAgo));
    }

    // Order by total score descending
    query = query.orderBy('totalScore', descending: true).limit(limit);

    return query.snapshots().map((snapshot) {
      List<LeaderboardUser> users = [];
      int rank = 1;
      
      for (var doc in snapshot.docs) {
        final data = doc.data() as Map<String, dynamic>;
        final user = LeaderboardUser(
          id: doc.id,
          rank: rank++,
          name: data['name'] ?? 'Unknown',
          avatar: data['avatar'] ?? '🦊',
          points: data['totalScore'] ?? 0,
          streak: data['currentStreak'] ?? 0,
          lessonsCompleted: data['lessonsCompleted'] ?? 0,
          isCurrentUser: doc.id == _firestoreService.currentUserId,
          lastActive: (data['lastLoginDate'] as Timestamp?)?.toDate(),
        );
        users.add(user);
      }
      
      return users;
    });
  }

  // Get current user's rank and surrounding users
  Future<UserRankInfo> getCurrentUserRankInfo({
    String period = 'all-time',
    String grade = 'all',
  }) async {
    try {
      final currentUserId = _firestoreService.currentUserId;
      if (currentUserId == null) {
        return UserRankInfo(
          currentUserRank: 0,
          totalUsers: 0,
          currentUserScore: 0,
          surroundingUsers: [],
        );
      }

      // Get current user data
      final currentUserData = await _firestoreService.getCurrentUserData();
      final currentUserScore = currentUserData?['totalScore'] ?? 0;

      // Count users with higher scores to determine rank
      Query higherScoreQuery = _firestore.collection('users')
          .where('totalScore', isGreaterThan: currentUserScore);

      // Apply the same filters as the main leaderboard
      if (grade != 'all' && grade.isNotEmpty) {
        higherScoreQuery = higherScoreQuery.where('preferences.grade', isEqualTo: grade);
      }

      if (period == 'weekly') {
        final weekAgo = DateTime.now().subtract(const Duration(days: 7));
        higherScoreQuery = higherScoreQuery.where('lastLoginDate', 
            isGreaterThanOrEqualTo: Timestamp.fromDate(weekAgo));
      } else if (period == 'monthly') {
        final monthAgo = DateTime.now().subtract(const Duration(days: 30));
        higherScoreQuery = higherScoreQuery.where('lastLoginDate', 
            isGreaterThanOrEqualTo: Timestamp.fromDate(monthAgo));
      }

      final higherScoreSnapshot = await higherScoreQuery.get();
      final currentUserRank = higherScoreSnapshot.docs.length + 1;

      // Get total user count
      Query totalUsersQuery = _firestore.collection('users');
      if (grade != 'all' && grade.isNotEmpty) {
        totalUsersQuery = totalUsersQuery.where('preferences.grade', isEqualTo: grade);
      }
      
      final totalUsersSnapshot = await totalUsersQuery.get();
      final totalUsers = totalUsersSnapshot.docs.length;

      // Get surrounding users (few above and below current user)
      final leaderboardStream = getLeaderboardStream(
        period: period,
        grade: grade,
        limit: 50,
      );
      
      final leaderboardUsers = await leaderboardStream.first;
      final currentUserIndex = leaderboardUsers.indexWhere((user) => user.isCurrentUser);
      
      List<LeaderboardUser> surroundingUsers = [];
      if (currentUserIndex != -1) {
        final start = (currentUserIndex - 2).clamp(0, leaderboardUsers.length);
        final end = (currentUserIndex + 3).clamp(0, leaderboardUsers.length);
        surroundingUsers = leaderboardUsers.sublist(start, end);
      }

      return UserRankInfo(
        currentUserRank: currentUserRank,
        totalUsers: totalUsers,
        currentUserScore: currentUserScore,
        surroundingUsers: surroundingUsers,
      );
    } catch (e) {
      return UserRankInfo(
        currentUserRank: 0,
        totalUsers: 0,
        currentUserScore: 0,
        surroundingUsers: [],
      );
    }
  }

  // Get weekly leaderboard based on practice sessions
  Stream<List<LeaderboardUser>> getWeeklyLeaderboardStream({
    String grade = 'all',
    int limit = 50,
  }) {
    final weekAgo = Timestamp.fromDate(DateTime.now().subtract(const Duration(days: 7)));

    return _firestore.collectionGroup('practice_sessions')
        .where('completedAt', isGreaterThanOrEqualTo: weekAgo)
        .snapshots()
        .asyncMap((snapshot) async {
          // Group by user ID and calculate weekly scores
          Map<String, int> weeklyScores = {};
          Map<String, Map<String, dynamic>> userDataCache = {};

          for (var doc in snapshot.docs) {
            final data = doc.data();
            final userId = doc.reference.parent.parent?.id;
            if (userId != null) {
              final score = data['score'] as int? ?? 0;
              weeklyScores[userId] = (weeklyScores[userId] ?? 0) + score;
            }
          }

          // Get user data for each user in the weekly scores
          List<LeaderboardUser> users = [];
          int rank = 1;

          // Sort users by weekly score
          final sortedEntries = weeklyScores.entries.toList()
            ..sort((a, b) => b.value.compareTo(a.value));

          for (var entry in sortedEntries.take(limit)) {
            final userId = entry.key;
            final weeklyScore = entry.value;

            // Get user data (cache to avoid repeated requests)
            if (!userDataCache.containsKey(userId)) {
              try {
                userDataCache[userId] = await _firestoreService.getUserData(userId) ?? {};
              } catch (e) {
                userDataCache[userId] = {};
              }
            }

            final userData = userDataCache[userId]!;
            users.add(LeaderboardUser(
              id: userId,
              rank: rank++,
              name: userData['name'] ?? 'Unknown',
              avatar: userData['avatar'] ?? '🦊',
              points: weeklyScore, // Use weekly score instead of total
              streak: userData['currentStreak'] ?? 0,
              lessonsCompleted: userData['lessonsCompleted'] ?? 0,
              isCurrentUser: userId == _firestoreService.currentUserId,
              lastActive: (userData['lastLoginDate'] as Timestamp?)?.toDate(),
            ));
          }

          return users;
        });
  }

  // Get monthly leaderboard based on practice sessions
  Stream<List<LeaderboardUser>> getMonthlyLeaderboardStream({
    String grade = 'all',
    int limit = 50,
  }) {
    final monthAgo = Timestamp.fromDate(DateTime.now().subtract(const Duration(days: 30)));

    return _firestore.collectionGroup('practice_sessions')
        .where('completedAt', isGreaterThanOrEqualTo: monthAgo)
        .snapshots()
        .asyncMap((snapshot) async {
          Map<String, int> monthlyScores = {};
          Map<String, Map<String, dynamic>> userDataCache = {};

          for (var doc in snapshot.docs) {
            final data = doc.data();
            final userId = doc.reference.parent.parent?.id;
            if (userId != null) {
              final score = data['score'] as int? ?? 0;
              monthlyScores[userId] = (monthlyScores[userId] ?? 0) + score;
            }
          }

          List<LeaderboardUser> users = [];
          int rank = 1;

          final sortedEntries = monthlyScores.entries.toList()
            ..sort((a, b) => b.value.compareTo(a.value));

          for (var entry in sortedEntries.take(limit)) {
            final userId = entry.key;
            final monthlyScore = entry.value;

            if (!userDataCache.containsKey(userId)) {
              try {
                userDataCache[userId] = await _firestoreService.getUserData(userId) ?? {};
              } catch (e) {
                userDataCache[userId] = {};
              }
            }

            final userData = userDataCache[userId]!;
            users.add(LeaderboardUser(
              id: userId,
              rank: rank++,
              name: userData['name'] ?? 'Unknown',
              avatar: userData['avatar'] ?? '🦊',
              points: monthlyScore,
              streak: userData['currentStreak'] ?? 0,
              lessonsCompleted: userData['lessonsCompleted'] ?? 0,
              isCurrentUser: userId == _firestoreService.currentUserId,
              lastActive: (userData['lastLoginDate'] as Timestamp?)?.toDate(),
            ));
          }

          return users;
        });
  }
}

class LeaderboardUser {
  final String id;
  final int rank;
  final String name;
  final String avatar;
  final int points;
  final int streak;
  final int lessonsCompleted;
  final bool isCurrentUser;
  final DateTime? lastActive;

  LeaderboardUser({
    required this.id,
    required this.rank,
    required this.name,
    required this.avatar,
    required this.points,
    required this.streak,
    required this.lessonsCompleted,
    required this.isCurrentUser,
    this.lastActive,
  });

  @override
  String toString() {
    return 'LeaderboardUser(rank: $rank, name: $name, points: $points, isCurrentUser: $isCurrentUser)';
  }
}

class UserRankInfo {
  final int currentUserRank;
  final int totalUsers;
  final int currentUserScore;
  final List<LeaderboardUser> surroundingUsers;

  UserRankInfo({
    required this.currentUserRank,
    required this.totalUsers,
    required this.currentUserScore,
    required this.surroundingUsers,
  });
}