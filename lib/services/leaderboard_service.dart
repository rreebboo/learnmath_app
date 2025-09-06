import 'package:cloud_firestore/cloud_firestore.dart';
import 'firestore_service.dart';

class LeaderboardService {
  final FirestoreService _firestoreService = FirestoreService();
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // Getter to access the firestore service
  FirestoreService get firestoreService => _firestoreService;

  // Get leaderboard with different time periods
  Stream<List<LeaderboardUser>> getLeaderboardStream({
    String period = 'all-time',
    String grade = 'all',
    int limit = 50,
  }) {
    try {
      Query query = _firestore.collection('users');

      // For all-time, just order by total score
      if (period == 'all-time') {
        query = query.orderBy('totalScore', descending: true).limit(limit);
      } else {
        // For weekly and monthly, we'll filter by lastLoginDate to get active users
        DateTime cutoffDate;
        if (period == 'weekly') {
          cutoffDate = DateTime.now().subtract(const Duration(days: 7));
        } else {
          cutoffDate = DateTime.now().subtract(const Duration(days: 30));
        }
        
        query = query
            .where('lastLoginDate', isGreaterThanOrEqualTo: Timestamp.fromDate(cutoffDate))
            .orderBy('lastLoginDate', descending: true)
            .orderBy('totalScore', descending: true)
            .limit(limit);
      }

      return query.snapshots().map((snapshot) {
        List<LeaderboardUser> users = [];
        int rank = 1;
        
        for (var doc in snapshot.docs) {
          final data = doc.data() as Map<String, dynamic>?;
          if (data != null) {
            final user = LeaderboardUser(
              id: doc.id,
              rank: rank++,
              name: data['name'] ?? 'User${rank - 1}',
              avatar: data['avatar'] ?? '🦊',
              points: (data['totalScore'] as num?)?.toInt() ?? 0,
              streak: (data['currentStreak'] as num?)?.toInt() ?? 0,
              lessonsCompleted: (data['lessonsCompleted'] as num?)?.toInt() ?? 0,
              isCurrentUser: doc.id == _firestoreService.currentUserId,
              lastActive: (data['lastLoginDate'] as Timestamp?)?.toDate(),
            );
            users.add(user);
          }
        }
        
        return users;
      });
    } catch (e) {
      // Return empty stream on error
      return Stream.value(<LeaderboardUser>[]);
    }
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
      final currentUserScore = (currentUserData?['totalScore'] as num?)?.toInt() ?? 0;

      // Get total user count
      final totalUsersSnapshot = await _firestore.collection('users').get();
      final totalUsers = totalUsersSnapshot.docs.length;

      // Get the leaderboard to find current user's rank
      Stream<List<LeaderboardUser>> leaderboardStream;
      if (period == 'weekly') {
        leaderboardStream = getWeeklyLeaderboardStream(limit: 100);
      } else if (period == 'monthly') {
        leaderboardStream = getMonthlyLeaderboardStream(limit: 100);
      } else {
        leaderboardStream = getLeaderboardStream(period: period, limit: 100);
      }
      
      final leaderboardUsers = await leaderboardStream.first;
      final currentUserIndex = leaderboardUsers.indexWhere((user) => user.isCurrentUser);
      final currentUserRank = currentUserIndex >= 0 ? currentUserIndex + 1 : totalUsers;
      
      List<LeaderboardUser> surroundingUsers = [];
      if (currentUserIndex >= 0) {
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
        totalUsers: 1,
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
    try {
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
              if (userId != null && data['score'] != null) {
                final score = (data['score'] as num).toInt();
                weeklyScores[userId] = (weeklyScores[userId] ?? 0) + score;
              }
            }

            // If no weekly data, fall back to regular leaderboard
            if (weeklyScores.isEmpty) {
              return await getLeaderboardStream(period: 'all-time', limit: limit).first;
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
                  final userData = await _firestoreService.getUserData(userId);
                  userDataCache[userId] = userData ?? {};
                } catch (e) {
                  userDataCache[userId] = {};
                }
              }

              final userData = userDataCache[userId]!;
              users.add(LeaderboardUser(
                id: userId,
                rank: rank++,
                name: userData['name'] ?? 'User${rank - 1}',
                avatar: userData['avatar'] ?? '🦊',
                points: weeklyScore,
                streak: (userData['currentStreak'] as num?)?.toInt() ?? 0,
                lessonsCompleted: (userData['lessonsCompleted'] as num?)?.toInt() ?? 0,
                isCurrentUser: userId == _firestoreService.currentUserId,
                lastActive: (userData['lastLoginDate'] as Timestamp?)?.toDate(),
              ));
            }

            return users;
          });
    } catch (e) {
      // Fallback to all-time leaderboard on error
      return getLeaderboardStream(period: 'all-time', limit: limit);
    }
  }

  // Get monthly leaderboard based on practice sessions
  Stream<List<LeaderboardUser>> getMonthlyLeaderboardStream({
    String grade = 'all',
    int limit = 50,
  }) {
    try {
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
              if (userId != null && data['score'] != null) {
                final score = (data['score'] as num).toInt();
                monthlyScores[userId] = (monthlyScores[userId] ?? 0) + score;
              }
            }

            // If no monthly data, fall back to regular leaderboard
            if (monthlyScores.isEmpty) {
              return await getLeaderboardStream(period: 'all-time', limit: limit).first;
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
                  final userData = await _firestoreService.getUserData(userId);
                  userDataCache[userId] = userData ?? {};
                } catch (e) {
                  userDataCache[userId] = {};
                }
              }

              final userData = userDataCache[userId]!;
              users.add(LeaderboardUser(
                id: userId,
                rank: rank++,
                name: userData['name'] ?? 'User${rank - 1}',
                avatar: userData['avatar'] ?? '🦊',
                points: monthlyScore,
                streak: (userData['currentStreak'] as num?)?.toInt() ?? 0,
                lessonsCompleted: (userData['lessonsCompleted'] as num?)?.toInt() ?? 0,
                isCurrentUser: userId == _firestoreService.currentUserId,
                lastActive: (userData['lastLoginDate'] as Timestamp?)?.toDate(),
              ));
            }

            return users;
          });
    } catch (e) {
      // Fallback to all-time leaderboard on error
      return getLeaderboardStream(period: 'all-time', limit: limit);
    }
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