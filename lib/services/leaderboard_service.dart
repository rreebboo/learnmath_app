import 'package:cloud_firestore/cloud_firestore.dart';
import 'firestore_service.dart';
import 'database_service.dart';

class LeaderboardService {
  static LeaderboardService? _instance;
  static LeaderboardService get instance {
    return _instance ??= LeaderboardService._();
  }

  LeaderboardService._();

  final FirestoreService _firestoreService = FirestoreService();
  // Use lazy initialization to avoid accessing Firebase before it's initialized
  FirebaseFirestore get _firestore => FirebaseFirestore.instance;
  final DatabaseService _databaseService = DatabaseService();

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

        // Simplified query to avoid composite index requirements
        query = query
            .where('lastLoginDate', isGreaterThanOrEqualTo: Timestamp.fromDate(cutoffDate))
            .orderBy('lastLoginDate', descending: true)
            .limit(limit);
      }

      return query.snapshots().map((snapshot) {
        List<LeaderboardUser> users = [];

        for (var doc in snapshot.docs) {
          final data = doc.data() as Map<String, dynamic>?;
          if (data != null && data['name'] != null) {
            // Filter out incomplete user profiles
            final totalScore = (data['totalScore'] as num?)?.toInt() ?? 0;
            final currentStreak = (data['currentStreak'] as num?)?.toInt() ?? 0;
            final lessonsCompleted = (data['lessonsCompleted'] as num?)?.toInt() ?? 0;

            final user = LeaderboardUser(
              id: doc.id,
              rank: 0, // Will be set after sorting
              name: data['name'] as String,
              avatar: data['avatar'] ?? '🦊',
              points: totalScore,
              streak: currentStreak,
              lessonsCompleted: lessonsCompleted,
              isCurrentUser: doc.id == _firestoreService.currentUserId,
              lastActive: (data['lastLoginDate'] as Timestamp?)?.toDate(),
            );
            users.add(user);
          }
        }

        // Sort by total score descending for non-all-time periods
        if (period != 'all-time') {
          users.sort((a, b) {
            int scoreComparison = b.points.compareTo(a.points);
            if (scoreComparison != 0) return scoreComparison;
            return a.name.compareTo(b.name);
          });
        }

        // Assign ranks after sorting
        List<LeaderboardUser> rankedUsers = [];
        for (int i = 0; i < users.length; i++) {
          rankedUsers.add(LeaderboardUser(
            id: users[i].id,
            rank: i + 1,
            name: users[i].name,
            avatar: users[i].avatar,
            points: users[i].points,
            streak: users[i].streak,
            lessonsCompleted: users[i].lessonsCompleted,
            isCurrentUser: users[i].isCurrentUser,
            lastActive: users[i].lastActive,
          ));
        }

        return rankedUsers;
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

  // Get weekly leaderboard - show only active users with points from the past week
  Stream<List<LeaderboardUser>> getWeeklyLeaderboardStream({
    String grade = 'all',
    int limit = 50,
  }) {
    try {
      print('🕐 WEEKLY LEADERBOARD: Starting weekly leaderboard stream');

      // Get users with points and filter for weekly activity
      return _firestore.collection('users')
          .orderBy('totalScore', descending: true)
          .limit(100) // Get more users to filter from
          .snapshots()
          .map((snapshot) {
            print('🕐 WEEKLY LEADERBOARD: Got ${snapshot.docs.length} users from Firestore');
            List<LeaderboardUser> users = [];
            final weekAgo = DateTime.now().subtract(const Duration(days: 7));

            for (var doc in snapshot.docs) {
              try {
                final data = doc.data();
                if (data['name'] != null) {
                  final totalScore = (data['totalScore'] as num?)?.toInt() ?? 0;
                  final lastLoginDate = (data['lastLoginDate'] as Timestamp?)?.toDate();

                  // Debug current user specifically
                  if (doc.id == _firestoreService.currentUserId) {
                    print('🕐 WEEKLY LEADERBOARD: Current user data - ${data['name']}: totalScore=$totalScore, lastLoginDate=$lastLoginDate');
                  }

                  // Only include users who:
                  // 1. Have points (totalScore > 0)
                  // 2. Have been active in the past week (lastLoginDate within 7 days) OR are the current user
                  final hasPoints = totalScore > 0;
                  final isActiveThisWeek = lastLoginDate != null && lastLoginDate.isAfter(weekAgo);
                  final isCurrentUser = doc.id == _firestoreService.currentUserId;

                  // Include users who:
                  // 1. Have points AND are active this week, OR
                  // 2. Are the current user (regardless of points or activity)
                  if ((hasPoints && isActiveThisWeek) || isCurrentUser) {
                    final user = LeaderboardUser(
                      id: doc.id,
                      rank: 0, // Will be set after sorting
                      name: data['name'] as String,
                      avatar: data['avatar'] ?? '🦊',
                      points: totalScore,
                      streak: (data['currentStreak'] as num?)?.toInt() ?? 0,
                      lessonsCompleted: (data['lessonsCompleted'] as num?)?.toInt() ?? 0,
                      isCurrentUser: doc.id == _firestoreService.currentUserId,
                      lastActive: lastLoginDate,
                    );
                    users.add(user);
                    print('🕐 WEEKLY LEADERBOARD: Added active user ${data['name']} with ${totalScore} points (last active: ${lastLoginDate?.toString().substring(0, 10)})');
                  } else {
                    print('🕐 WEEKLY LEADERBOARD: Skipped ${data['name']} - hasPoints: $hasPoints, isActiveThisWeek: $isActiveThisWeek');
                  }
                }
              } catch (e) {
                print('🕐 WEEKLY LEADERBOARD: Error processing user doc: $e');
                continue;
              }
            }

            // Sort by total score descending, then by name for tie-breaking
            users.sort((a, b) {
              int scoreComparison = b.points.compareTo(a.points);
              if (scoreComparison != 0) return scoreComparison;
              return a.name.compareTo(b.name);
            });

            // Assign ranks after sorting by creating new objects with updated rank
            List<LeaderboardUser> rankedUsers = [];
            for (int i = 0; i < users.length; i++) {
              rankedUsers.add(LeaderboardUser(
                id: users[i].id,
                rank: i + 1,
                name: users[i].name,
                avatar: users[i].avatar,
                points: users[i].points,
                streak: users[i].streak,
                lessonsCompleted: users[i].lessonsCompleted,
                isCurrentUser: users[i].isCurrentUser,
                lastActive: users[i].lastActive,
              ));
            }

            // If no users found, return current user as fallback
            if (rankedUsers.isEmpty) {
              print('🕐 WEEKLY LEADERBOARD: No users found, creating fallback with current user');
              rankedUsers.add(LeaderboardUser(
                id: _firestoreService.currentUserId ?? 'unknown',
                rank: 1,
                name: 'You',
                avatar: '👤',
                points: 0,
                streak: 0,
                lessonsCompleted: 0,
                isCurrentUser: true,
                lastActive: DateTime.now(),
              ));
            }

            print('🕐 WEEKLY LEADERBOARD: Returning ${rankedUsers.length} ranked users');
            return rankedUsers;
          }).handleError((error) {
            print('🕐 WEEKLY LEADERBOARD: Error in stream: $error');
            // Return empty list immediately to show popup
            return <LeaderboardUser>[];
          });
    } catch (e) {
      print('🕐 WEEKLY LEADERBOARD: Error setting up stream: $e');
      // Return empty stream to avoid infinite loading
      return Stream.value(<LeaderboardUser>[]);
    }
  }

  // Get monthly leaderboard - show only active users with points from the past month
  Stream<List<LeaderboardUser>> getMonthlyLeaderboardStream({
    String grade = 'all',
    int limit = 50,
  }) {
    try {
      print('📅 MONTHLY LEADERBOARD: Starting monthly leaderboard stream');

      // Get users with points and filter for monthly activity
      return _firestore.collection('users')
          .orderBy('totalScore', descending: true)
          .limit(100) // Get more users to filter from
          .snapshots()
          .map((snapshot) {
            print('📅 MONTHLY LEADERBOARD: Got ${snapshot.docs.length} users from Firestore');
            List<LeaderboardUser> users = [];
            final monthAgo = DateTime.now().subtract(const Duration(days: 30));

            for (var doc in snapshot.docs) {
              try {
                final data = doc.data();
                if (data['name'] != null) {
                  final totalScore = (data['totalScore'] as num?)?.toInt() ?? 0;
                  final lastLoginDate = (data['lastLoginDate'] as Timestamp?)?.toDate();

                  // Debug current user specifically
                  if (doc.id == _firestoreService.currentUserId) {
                    print('📅 MONTHLY LEADERBOARD: Current user data - ${data['name']}: totalScore=$totalScore, lastLoginDate=$lastLoginDate');
                  }

                  // Only include users who:
                  // 1. Have points (totalScore > 0)
                  // 2. Have been active in the past month (lastLoginDate within 30 days) OR are the current user
                  final hasPoints = totalScore > 0;
                  final isActiveThisMonth = lastLoginDate != null && lastLoginDate.isAfter(monthAgo);
                  final isCurrentUser = doc.id == _firestoreService.currentUserId;

                  // Include users who:
                  // 1. Have points AND are active this month, OR
                  // 2. Are the current user (regardless of points or activity)
                  if ((hasPoints && isActiveThisMonth) || isCurrentUser) {
                    final user = LeaderboardUser(
                      id: doc.id,
                      rank: 0, // Will be set after sorting
                      name: data['name'] as String,
                      avatar: data['avatar'] ?? '🦊',
                      points: totalScore,
                      streak: (data['currentStreak'] as num?)?.toInt() ?? 0,
                      lessonsCompleted: (data['lessonsCompleted'] as num?)?.toInt() ?? 0,
                      isCurrentUser: doc.id == _firestoreService.currentUserId,
                      lastActive: lastLoginDate,
                    );
                    users.add(user);
                    print('📅 MONTHLY LEADERBOARD: Added user ${data['name']} with ${totalScore} points (last active: ${lastLoginDate?.toString().substring(0, 10)}, current user: $isCurrentUser)');
                  } else {
                    print('📅 MONTHLY LEADERBOARD: Skipped ${data['name']} - hasPoints: $hasPoints, isActiveThisMonth: $isActiveThisMonth, isCurrentUser: $isCurrentUser');
                  }
                }
              } catch (e) {
                print('📅 MONTHLY LEADERBOARD: Error processing user doc: $e');
                continue;
              }
            }

            // Sort by total score descending, then by name for tie-breaking
            users.sort((a, b) {
              int scoreComparison = b.points.compareTo(a.points);
              if (scoreComparison != 0) return scoreComparison;
              return a.name.compareTo(b.name);
            });

            // Assign ranks after sorting by creating new objects with updated rank
            List<LeaderboardUser> rankedUsers = [];
            for (int i = 0; i < users.length; i++) {
              rankedUsers.add(LeaderboardUser(
                id: users[i].id,
                rank: i + 1,
                name: users[i].name,
                avatar: users[i].avatar,
                points: users[i].points,
                streak: users[i].streak,
                lessonsCompleted: users[i].lessonsCompleted,
                isCurrentUser: users[i].isCurrentUser,
                lastActive: users[i].lastActive,
              ));
            }

            // If no users found, return current user as fallback
            if (rankedUsers.isEmpty) {
              print('📅 MONTHLY LEADERBOARD: No users found, creating fallback with current user');
              rankedUsers.add(LeaderboardUser(
                id: _firestoreService.currentUserId ?? 'unknown',
                rank: 1,
                name: 'You',
                avatar: '👤',
                points: 0,
                streak: 0,
                lessonsCompleted: 0,
                isCurrentUser: true,
                lastActive: DateTime.now(),
              ));
            }

            print('📅 MONTHLY LEADERBOARD: Returning ${rankedUsers.length} ranked users');
            return rankedUsers;
          }).handleError((error) {
            print('📅 MONTHLY LEADERBOARD: Error in stream: $error');
            // Return empty list immediately to show popup
            return <LeaderboardUser>[];
          });
    } catch (e) {
      print('📅 MONTHLY LEADERBOARD: Error setting up stream: $e');
      // Return empty stream to avoid infinite loading
      return Stream.value(<LeaderboardUser>[]);
    }
  }

  // Get cached leaderboard for better performance
  Stream<List<LeaderboardUser>> getCachedLeaderboardStream({
    String period = 'all-time',
    int limit = 50,
  }) {
    try {
      return _firestore.collection('leaderboards').doc(period).snapshots().map((snapshot) {
        if (!snapshot.exists) {
          // Fallback to live data if cache doesn't exist
          return [];
        }

        final data = snapshot.data() as Map<String, dynamic>;
        final usersData = List<Map<String, dynamic>>.from(data['users'] ?? []);
        
        List<LeaderboardUser> users = [];
        int rank = 1;
        
        for (var userData in usersData.take(limit)) {
          final user = LeaderboardUser(
            id: userData['userId'] ?? '',
            rank: rank++,
            name: userData['name'] ?? 'User$rank',
            avatar: userData['avatar'] ?? '🦊',
            points: (userData['totalScore'] as num?)?.toInt() ?? 0,
            streak: (userData['currentStreak'] as num?)?.toInt() ?? 0,
            lessonsCompleted: (userData['lessonsCompleted'] as num?)?.toInt() ?? 0,
            isCurrentUser: userData['userId'] == _firestoreService.currentUserId,
            lastActive: (userData['lastActive'] as Timestamp?)?.toDate(),
          );
          users.add(user);
        }
        
        return users;
      });
    } catch (e) {
      // Return live leaderboard on error
      return getLeaderboardStream(period: period, limit: limit);
    }
  }

  // Update user's leaderboard position after score change
  Future<void> updateUserLeaderboardPosition(String userId) async {
    try {
      // Update the cached leaderboard
      await _databaseService.updateLeaderboardCache();
      
      // Check and award achievements
      await _databaseService.checkAndAwardAchievements(userId);
      
      print('LeaderboardService: Updated leaderboard position for user $userId');
    } catch (e) {
      print('LeaderboardService: Error updating leaderboard position: $e');
    }
  }

  // Get user's detailed stats for profile/leaderboard
  Future<Map<String, dynamic>> getUserDetailedStats(String userId) async {
    try {
      final userDoc = await _firestore.collection('users').doc(userId).get();
      if (!userDoc.exists) return {};

      final userData = userDoc.data()!;
      
      // Get practice session count for this week
      final weekAgo = DateTime.now().subtract(const Duration(days: 7));
      final weeklySessions = await _firestore
          .collection('users')
          .doc(userId)
          .collection('practice_sessions')
          .where('completedAt', isGreaterThanOrEqualTo: Timestamp.fromDate(weekAgo))
          .get();

      // Get monthly session count
      final monthAgo = DateTime.now().subtract(const Duration(days: 30));
      final monthlySessions = await _firestore
          .collection('users')
          .doc(userId)
          .collection('practice_sessions')
          .where('completedAt', isGreaterThanOrEqualTo: Timestamp.fromDate(monthAgo))
          .get();

      return {
        'totalScore': userData['totalScore'] ?? 0,
        'lessonsCompleted': userData['lessonsCompleted'] ?? 0,
        'currentStreak': userData['currentStreak'] ?? 0,
        'bestStreak': userData['bestStreak'] ?? 0,
        'accuracyRate': userData['accuracyRate'] ?? 0,
        'totalTimeSpent': userData['totalTimeSpent'] ?? 0,
        'friendsCount': userData['friendsCount'] ?? 0,
        'achievementsCount': (userData['achievements'] as List?)?.length ?? 0,
        'achievementPoints': userData['achievementPoints'] ?? 0,
        'weeklySessionsCount': weeklySessions.docs.length,
        'monthlySessionsCount': monthlySessions.docs.length,
        'joinedDate': userData['createdAt'],
        'lastActive': userData['lastLoginDate'],
      };
    } catch (e) {
      print('LeaderboardService: Error getting detailed stats: $e');
      return {};
    }
  }

  // Get leaderboard stats (total users, user's position, etc.)
  Future<LeaderboardStats> getLeaderboardStats() async {
    try {
      final totalUsersSnapshot = await _firestore.collection('users').get();
      final totalUsers = totalUsersSnapshot.docs.length;
      
      final currentUserId = _firestoreService.currentUserId;
      if (currentUserId == null) {
        return LeaderboardStats(
          totalUsers: totalUsers,
          currentUserRank: 0,
          activeUsersToday: 0,
          activeUsersWeek: 0,
        );
      }

      // Get current user's rank
      final userRankInfo = await getCurrentUserRankInfo();
      
      // Get active users today
      final todayStart = DateTime(
        DateTime.now().year,
        DateTime.now().month,
        DateTime.now().day,
      );
      final activeToday = await _firestore
          .collection('users')
          .where('lastLoginDate', isGreaterThanOrEqualTo: Timestamp.fromDate(todayStart))
          .get();

      // Get active users this week
      final weekAgo = DateTime.now().subtract(const Duration(days: 7));
      final activeWeek = await _firestore
          .collection('users')
          .where('lastLoginDate', isGreaterThanOrEqualTo: Timestamp.fromDate(weekAgo))
          .get();

      return LeaderboardStats(
        totalUsers: totalUsers,
        currentUserRank: userRankInfo.currentUserRank,
        activeUsersToday: activeToday.docs.length,
        activeUsersWeek: activeWeek.docs.length,
      );
    } catch (e) {
      print('LeaderboardService: Error getting leaderboard stats: $e');
      return LeaderboardStats(
        totalUsers: 0,
        currentUserRank: 0,
        activeUsersToday: 0,
        activeUsersWeek: 0,
      );
    }
  }

  // Get top performers by different criteria
  Future<Map<String, List<LeaderboardUser>>> getTopPerformers({int limit = 10}) async {
    try {
      Map<String, List<LeaderboardUser>> results = {};

      // Top by score
      final topByScore = await _firestore
          .collection('users')
          .orderBy('totalScore', descending: true)
          .limit(limit)
          .get();
      
      results['topScore'] = _convertToLeaderboardUsers(topByScore.docs);

      // Top by streak
      final topByStreak = await _firestore
          .collection('users')
          .orderBy('currentStreak', descending: true)
          .limit(limit)
          .get();
      
      results['topStreak'] = _convertToLeaderboardUsers(topByStreak.docs);

      // Top by lessons completed
      final topByLessons = await _firestore
          .collection('users')
          .orderBy('lessonsCompleted', descending: true)
          .limit(limit)
          .get();
      
      results['topLessons'] = _convertToLeaderboardUsers(topByLessons.docs);

      // Top by accuracy
      final topByAccuracy = await _firestore
          .collection('users')
          .orderBy('accuracyRate', descending: true)
          .limit(limit)
          .get();
      
      results['topAccuracy'] = _convertToLeaderboardUsers(topByAccuracy.docs);

      return results;
    } catch (e) {
      print('LeaderboardService: Error getting top performers: $e');
      return {};
    }
  }

  // Helper method to convert Firestore docs to LeaderboardUser objects
  List<LeaderboardUser> _convertToLeaderboardUsers(List<QueryDocumentSnapshot> docs) {
    List<LeaderboardUser> users = [];
    int rank = 1;
    
    for (var doc in docs) {
      final data = doc.data() as Map<String, dynamic>;
      final user = LeaderboardUser(
        id: doc.id,
        rank: rank++,
        name: data['name'] ?? 'User$rank',
        avatar: data['avatar'] ?? '🦊',
        points: (data['totalScore'] as num?)?.toInt() ?? 0,
        streak: (data['currentStreak'] as num?)?.toInt() ?? 0,
        lessonsCompleted: (data['lessonsCompleted'] as num?)?.toInt() ?? 0,
        isCurrentUser: doc.id == _firestoreService.currentUserId,
        lastActive: (data['lastLoginDate'] as Timestamp?)?.toDate(),
      );
      users.add(user);
    }
    
    return users;
  }


  // Method to ensure user has proper leaderboard data
  Future<void> updateUserLeaderboardData({
    required String userId,
    required int scoreToAdd,
    required bool lessonCompleted,
  }) async {
    try {
      final updates = <String, dynamic>{
        'totalScore': FieldValue.increment(scoreToAdd),
        'lastLoginDate': FieldValue.serverTimestamp(),
      };

      if (lessonCompleted) {
        updates['lessonsCompleted'] = FieldValue.increment(1);
      }

      await _firestore.collection('users').doc(userId).update(updates);
    } catch (e) {
      print('Error updating leaderboard data: $e');
    }
  }
}

// Additional model for leaderboard statistics
class LeaderboardStats {
  final int totalUsers;
  final int currentUserRank;
  final int activeUsersToday;
  final int activeUsersWeek;

  LeaderboardStats({
    required this.totalUsers,
    required this.currentUserRank,
    required this.activeUsersToday,
    required this.activeUsersWeek,
  });
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