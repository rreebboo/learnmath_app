import 'package:flutter/material.dart';
import 'dart:async';
import '../services/user_statistics_service.dart';
import '../services/firestore_service.dart';
import '../widgets/user_avatar.dart';
import 'achievements_screen.dart';
import 'leaderboard_screen.dart';

class ProgressScreen extends StatefulWidget {
  const ProgressScreen({super.key});

  @override
  State<ProgressScreen> createState() => _ProgressScreenState();
}

class _ProgressScreenState extends State<ProgressScreen> with TickerProviderStateMixin {
  final UserStatisticsService _statsService = UserStatisticsService();
  final FirestoreService _firestoreService = FirestoreService();
  
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;
  
  StreamSubscription? _userDataSubscription;
  Map<String, dynamic>? _userData;
  // List<Map<String, dynamic>> _recentSessions = [];
  Map<String, Map<String, dynamic>> _topicProgress = {};
  List<bool> _weeklyProgress = List.filled(7, false);
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );
    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeOut),
    );
    _initializeRealTimeData();
  }

  @override
  void dispose() {
    _userDataSubscription?.cancel();
    _animationController.dispose();
    super.dispose();
  }

  void _initializeRealTimeData() async {
    try {
      setState(() {
        _isLoading = true;
        _error = null;
      });

      await _statsService.loadStatistics();
      
      final currentUserId = _firestoreService.currentUserId;
      if (currentUserId != null) {
        // Load initial data
        await _loadAllData(currentUserId);
        
        // Set up real-time listening to user data changes
        _userDataSubscription = _firestoreService.streamUserData(currentUserId).listen(
          (snapshot) async {
            if (snapshot.exists && mounted) {
              setState(() {
                _userData = snapshot.data() as Map<String, dynamic>?;
              });
              
              // Reload related data when user data changes
              await _loadAllData(currentUserId);
              
              if (mounted) {
                setState(() {
                  _isLoading = false;
                  _error = null;
                });
                _animationController.forward();
              }
            }
          },
          onError: (error) {
            if (mounted) {
              setState(() {
                _error = error.toString();
                _isLoading = false;
              });
            }
          },
        );
      } else {
        setState(() {
          _error = 'No user logged in';
          _isLoading = false;
        });
      }
    } catch (e) {
      setState(() {
        _error = e.toString();
        _isLoading = false;
      });
    }
  }

  Future<void> _loadAllData(String userId) async {
    try {
      // Load recent practice sessions
      // final sessions = await _firestoreService.getPracticeHistory(userId);
      
      // Load topic progress
      final allTopicProgress = await _firestoreService.getAllTopicProgress(userId);
      Map<String, Map<String, dynamic>> topicProgressMap = {};
      for (var progress in allTopicProgress) {
        topicProgressMap[progress['topicId']] = progress;
      }
      
      // Calculate weekly progress
      final weeklyData = await _calculateWeeklyProgress(userId);
      
      if (mounted) {
        setState(() {
          // _recentSessions = sessions;
          _topicProgress = topicProgressMap;
          _weeklyProgress = weeklyData;
        });
      }
    } catch (e) {
      // Handle errors silently to not disrupt the UI
    }
  }

  Future<List<bool>> _calculateWeeklyProgress(String userId) async {
    try {
      final now = DateTime.now();
      final startOfWeek = now.subtract(Duration(days: now.weekday - 1));
      List<bool> weekData = List.filled(7, false);

      // Get practice sessions from the last 7 days
      final sessions = await _firestoreService.getPracticeHistory(userId);

      // Also check user statistics service for session data
      await _statsService.loadStatistics();

      // Process Firestore sessions
      for (var session in sessions) {
        final completedAt = session['completedAt'];
        if (completedAt != null) {
          DateTime sessionDate;
          if (completedAt is DateTime) {
            sessionDate = completedAt;
          } else {
            sessionDate = completedAt.toDate();
          }

          // Normalize dates to midnight for comparison
          final sessionDateNormalized = DateTime(sessionDate.year, sessionDate.month, sessionDate.day);
          final startOfWeekNormalized = DateTime(startOfWeek.year, startOfWeek.month, startOfWeek.day);

          final daysDiff = sessionDateNormalized.difference(startOfWeekNormalized).inDays;
          if (daysDiff >= 0 && daysDiff < 7) {
            weekData[daysDiff] = true;
          }
        }
      }

      // Mark today as completed if user has any statistics data (fallback)
      if (_statsService.totalSessions > 0) {
        final todayIndex = now.weekday - 1;
        if (todayIndex >= 0 && todayIndex < 7) {
          weekData[todayIndex] = true;
        }
      }

      return weekData;
    } catch (e) {
      // Return a pattern that shows some activity for demo purposes
      final now = DateTime.now();
      final todayIndex = now.weekday - 1;
      List<bool> demoData = List.filled(7, false);

      // Mark today and a few previous days as completed if we have any stats
      if (_statsService.totalSessions > 0) {
        for (int i = 0; i <= todayIndex && i < 7; i++) {
          demoData[i] = true;
        }
      }

      return demoData;
    }
  }

  Map<String, dynamic> _getTopicStatistics(String topicId) {
    final topicStats = _statsService.topicStats[topicId.toLowerCase()];
    final firestoreProgress = _topicProgress[topicId];
    
    if (topicStats != null) {
      return {
        'accuracy': topicStats.accuracy,
        'sessions': topicStats.sessions,
        'averageScore': topicStats.averageScore,
        'bestScore': topicStats.bestScore,
        'totalTimeSpent': topicStats.timeSpent,
        'stars': firestoreProgress?['stars'] ?? 0,
        'lessonsCompleted': firestoreProgress?['lessonsCompleted'] ?? 0,
      };
    }
    
    return {
      'accuracy': 0.0,
      'sessions': 0,
      'averageScore': 0.0,
      'bestScore': 0,
      'totalTimeSpent': 0,
      'stars': firestoreProgress?['stars'] ?? 0,
      'lessonsCompleted': firestoreProgress?['lessonsCompleted'] ?? 0,
    };
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Scaffold(
        backgroundColor: const Color(0xFFF5F7FA),
        body: const Center(
          child: CircularProgressIndicator(
            valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF4169E1)),
          ),
        ),
      );
    }

    if (_error != null) {
      return Scaffold(
        backgroundColor: const Color(0xFFF5F7FA),
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(
                Icons.error_outline,
                size: 64,
                color: Colors.grey,
              ),
              const SizedBox(height: 16),
              Text(
                'Unable to load progress',
                style: Theme.of(context).textTheme.headlineSmall,
              ),
              const SizedBox(height: 8),
              Text(
                _error!,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: Colors.grey[600],
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 24),
              ElevatedButton(
                onPressed: () => _initializeRealTimeData(),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF4169E1),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: const Text('Retry', style: TextStyle(color: Colors.white)),
              ),
            ],
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FA),
      body: FadeTransition(
        opacity: _fadeAnimation,
        child: RefreshIndicator(
          onRefresh: () async {
            await _statsService.loadStatistics();
            final userId = _firestoreService.currentUserId;
            if (userId != null) {
              await _loadAllData(userId);
            }
          },
          color: const Color(0xFF4169E1),
          child: SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            child: SafeArea(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildHeader(),
                    const SizedBox(height: 20),
                    _buildStreakCard(),
                    const SizedBox(height: 16),
                    _buildWeeklyProgressCard(),
                    const SizedBox(height: 16),
                    _buildSubjectProgressCard(),
                    const SizedBox(height: 16),
                    _buildStatsRow(),
                    const SizedBox(height: 16),
                    _buildRecentAchievements(),
                    const SizedBox(height: 16),
                    _buildWeeklyGoals(),
                    const SizedBox(height: 16),
                    _buildQuickActionsCard(),
                    const SizedBox(height: 16),
                    _buildShareCard(),
                    const SizedBox(height: 20),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Row(
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: const Color(0xFF4169E1).withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: const Color(0xFF4169E1).withValues(alpha: 0.2),
                width: 2,
              ),
            ),
            child: const Icon(
              Icons.trending_up,
              color: Color(0xFF4169E1),
              size: 24,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'My Progress',
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF1A1A2E),
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  'Keep learning, ${_userData?['name']?.split(' ')[0] ?? 'Learner'}!',
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.grey[600],
                  ),
                ),
              ],
            ),
          ),
          // Leaderboard Button
          Container(
            margin: const EdgeInsets.only(right: 12),
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => const LeaderboardScreen(),
                    ),
                  );
                },
                borderRadius: BorderRadius.circular(16),
                child: Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: const Color(0xFF4169E1).withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: const Color(0xFF4169E1).withValues(alpha: 0.2),
                      width: 2,
                    ),
                  ),
                  child: const Center(
                    child: Icon(
                      Icons.leaderboard,
                      color: Color(0xFF4169E1),
                      size: 24,
                    ),
                  ),
                ),
              ),
            ),
          ),
          UserAvatar(
            avatar: _userData?['avatar'] ?? '🦊',
            size: 48,
            backgroundColor: Colors.white,
            showBorder: true,
            borderColor: const Color(0xFF4169E1),
            borderWidth: 2,
            gradientColors: const [Color(0xFF7ED321), Color(0xFF9ACD32)],
          ),
        ],
      ),
    );
  }

  Widget _buildStreakCard() {
    final streak = _userData?['currentStreak'] ?? _statsService.currentStreak;
    final bestStreak = _userData?['bestStreak'] ?? _statsService.bestStreak;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Container(
            width: 80,
            height: 80,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  const Color(0xFFFFA500).withValues(alpha: 0.2),
                  const Color(0xFFFF6B35).withValues(alpha: 0.1),
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFFFFA500).withValues(alpha: 0.3),
                  blurRadius: 12,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: const Icon(
              Icons.local_fire_department,
              color: Color(0xFFFFA500),
              size: 40,
            ),
          ),
          const SizedBox(height: 16),
          Text(
            '$streak Day Streak!',
            style: const TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: Color(0xFF1A1A2E),
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 6),
          Text(
            _getStreakMessage(streak),
            style: TextStyle(
              fontSize: 14,
              color: Colors.grey[600],
            ),
            textAlign: TextAlign.center,
          ),
          if (bestStreak > streak && bestStreak > 0) ...[
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
              decoration: BoxDecoration(
                color: const Color(0xFFFFA500).withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: const Color(0xFFFFA500).withValues(alpha: 0.3),
                  width: 1,
                ),
              ),
              child: Text(
                'Best: $bestStreak days',
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFFFFA500),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  String _getStreakMessage(int streak) {
    if (streak >= 30) {
      return 'Incredible dedication! You\'re unstoppable! 🏆';
    } else if (streak >= 14) {
      return 'Amazing consistency! You\'re on fire! 🔥';
    } else if (streak >= 7) {
      return 'Great job! Building strong habits! 💪';
    } else if (streak >= 3) {
      return 'Nice streak! Keep it going! 🌟';
    } else if (streak >= 1) {
      return 'Good start! Build your streak! 🚀';
    } else {
      return 'Start your learning streak today! 🌱';
    }
  }

  Widget _buildWeeklyProgressCard() {
    final days = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
    final now = DateTime.now();
    final completedDays = _weeklyProgress.where((completed) => completed).length;

    return GestureDetector(
      onTap: () => _showFullCalendarPopup(context),
      child: Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(
                Icons.calendar_today,
                size: 18,
                color: Color(0xFF4169E1),
              ),
              const SizedBox(width: 8),
              const Text(
                'Weekly Progress',
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF1A1A2E),
                ),
              ),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: completedDays >= 5
                      ? const Color(0xFF90EE90).withValues(alpha: 0.2)
                      : const Color(0xFFFFA500).withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: completedDays >= 5
                        ? const Color(0xFF90EE90).withValues(alpha: 0.5)
                        : const Color(0xFFFFA500).withValues(alpha: 0.5),
                    width: 1,
                  ),
                ),
                child: Text(
                  '$completedDays/7 days',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: completedDays >= 5
                        ? const Color(0xFF4A7C59)
                        : const Color(0xFFCC8400),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            _getProgressMessage(completedDays),
            style: TextStyle(
              fontSize: 12,
              color: Colors.grey[600],
            ),
          ),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: List.generate(7, (index) {
              final isCompleted = _weeklyProgress[index];
              final isToday = index == now.weekday - 1;
              final isPastDay = index < now.weekday - 1;

              // Calculate the correct date for each day of the week
              // Monday is index 0, so we need to calculate from start of week
              final startOfWeek = now.subtract(Duration(days: now.weekday - 1));
              final dayDate = startOfWeek.add(Duration(days: index));

              return Expanded(
                child: Container(
                  margin: const EdgeInsets.symmetric(horizontal: 2),
                  child: Column(
                    children: [
                      Text(
                        days[index].substring(0, 1),
                        style: TextStyle(
                          fontSize: 10,
                          color: isToday ? const Color(0xFF4169E1) : Colors.grey[600],
                          fontWeight: isToday ? FontWeight.w700 : FontWeight.w500,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Container(
                        padding: isToday ? const EdgeInsets.symmetric(horizontal: 6, vertical: 2) : null,
                        decoration: isToday ? BoxDecoration(
                          color: const Color(0xFF4169E1).withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                            color: const Color(0xFF4169E1).withValues(alpha: 0.3),
                            width: 1,
                          ),
                        ) : null,
                        child: Text(
                          '${dayDate.day}',
                          style: TextStyle(
                            fontSize: 9,
                            color: isToday ? const Color(0xFF4169E1) : Colors.grey[500],
                            fontWeight: isToday ? FontWeight.w600 : FontWeight.normal,
                          ),
                        ),
                      ),
                      const SizedBox(height: 6),
                      Container(
                        width: 32,
                        height: 32,
                        decoration: BoxDecoration(
                          color: isCompleted
                              ? const Color(0xFF4CAF50)
                              : isToday
                                  ? const Color(0xFF4169E1)
                                  : isPastDay
                                      ? const Color(0xFFFFCDD2)
                                      : const Color(0xFFF5F5F5),
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: isCompleted
                                ? const Color(0xFF4CAF50)
                                : isToday
                                    ? const Color(0xFF4169E1)
                                    : isPastDay && !isCompleted
                                        ? const Color(0xFFE57373)
                                        : const Color(0xFFE0E0E0),
                            width: isToday ? 3 : 1,
                          ),
                          boxShadow: isToday ? [
                            BoxShadow(
                              color: const Color(0xFF4169E1).withValues(alpha: 0.4),
                              blurRadius: 8,
                              offset: const Offset(0, 2),
                              spreadRadius: 1,
                            ),
                            BoxShadow(
                              color: const Color(0xFF4169E1).withValues(alpha: 0.2),
                              blurRadius: 16,
                              offset: const Offset(0, 0),
                              spreadRadius: 2,
                            ),
                          ] : null,
                        ),
                        child: Stack(
                          children: [
                            Center(
                              child: isCompleted
                                  ? const Icon(
                                      Icons.check,
                                      color: Colors.white,
                                      size: 16,
                                    )
                                  : isToday
                                      ? const Icon(
                                          Icons.today,
                                          color: Colors.white,
                                          size: 14,
                                        )
                                      : isPastDay && !isCompleted
                                          ? Icon(
                                              Icons.close,
                                              color: Colors.grey[400],
                                              size: 14,
                                            )
                                          : Icon(
                                              Icons.circle,
                                              color: Colors.grey[300],
                                              size: 8,
                                            ),
                            ),
                            // Add "TODAY" label for current day
                            if (isToday)
                              Positioned(
                                bottom: -18,
                                left: 0,
                                right: 0,
                                child: Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFF4169E1),
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                  child: const Text(
                                    'TODAY',
                                    style: TextStyle(
                                      fontSize: 6,
                                      fontWeight: FontWeight.w600,
                                      color: Colors.white,
                                    ),
                                    textAlign: TextAlign.center,
                                  ),
                                ),
                              ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              );
            }),
          ),
          const SizedBox(height: 20), // Extra space for TODAY label
          // Progress bar
          Container(
            height: 6,
            decoration: BoxDecoration(
              color: const Color(0xFFF0F0F0),
              borderRadius: BorderRadius.circular(3),
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(3),
              child: LinearProgressIndicator(
                value: completedDays / 7,
                backgroundColor: Colors.transparent,
                valueColor: AlwaysStoppedAnimation<Color>(
                  completedDays >= 5
                      ? const Color(0xFF4CAF50)
                      : completedDays >= 3
                          ? const Color(0xFFFFA500)
                          : const Color(0xFF4169E1),
                ),
              ),
            ),
          ),
        ],
      ),
      ),
    );
  }

  void _showFullCalendarPopup(BuildContext context) {
    showDialog(
      context: context,
      barrierDismissible: true,
      builder: (BuildContext context) {
        return Dialog(
          backgroundColor: Colors.transparent,
          insetPadding: const EdgeInsets.all(20),
          child: Container(
            width: MediaQuery.of(context).size.width * 0.9,
            height: MediaQuery.of(context).size.height * 0.7,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(24),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.15),
                  blurRadius: 20,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            child: Column(
              children: [
                // Header
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: const BoxDecoration(
                    gradient: LinearGradient(
                      colors: [Color(0xFF4169E1), Color(0xFF6495ED)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.only(
                      topLeft: Radius.circular(24),
                      topRight: Radius.circular(24),
                    ),
                  ),
                  child: Row(
                    children: [
                      const Icon(
                        Icons.calendar_month,
                        color: Colors.white,
                        size: 24,
                      ),
                      const SizedBox(width: 12),
                      const Expanded(
                        child: Text(
                          'Learning Calendar',
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                      ),
                      IconButton(
                        onPressed: () => Navigator.of(context).pop(),
                        icon: const Icon(
                          Icons.close,
                          color: Colors.white,
                          size: 24,
                        ),
                      ),
                    ],
                  ),
                ),

                // Calendar Content
                Expanded(
                  child: _buildFullCalendarContent(),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildFullCalendarContent() {
    final now = DateTime.now();
    final currentMonth = now.month;
    final currentYear = now.year;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        children: [
          // Month/Year Header
          Container(
            padding: const EdgeInsets.symmetric(vertical: 16),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                IconButton(
                  onPressed: () {
                    // Navigate to previous month (can be implemented later)
                  },
                  icon: const Icon(Icons.chevron_left, color: Color(0xFF4169E1)),
                ),
                Text(
                  '${_getMonthName(currentMonth)} $currentYear',
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF2C3E50),
                  ),
                ),
                IconButton(
                  onPressed: () {
                    // Navigate to next month (can be implemented later)
                  },
                  icon: const Icon(Icons.chevron_right, color: Color(0xFF4169E1)),
                ),
              ],
            ),
          ),

          // Days of week header
          _buildDaysOfWeekHeader(),

          const SizedBox(height: 12),

          // Calendar grid
          _buildCalendarGrid(currentYear, currentMonth),

          const SizedBox(height: 20),

          // Legend
          _buildCalendarLegend(),

          const SizedBox(height: 20),

          // Statistics summary
          _buildCalendarStats(),
        ],
      ),
    );
  }

  Widget _buildDaysOfWeekHeader() {
    final days = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];

    return Row(
      children: days.map((day) => Expanded(
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Text(
            day,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: Colors.grey[600],
            ),
          ),
        ),
      )).toList(),
    );
  }

  Widget _buildCalendarGrid(int year, int month) {
    final daysInMonth = DateTime(year, month + 1, 0).day;
    final firstDayOfMonth = DateTime(year, month, 1);
    final firstWeekday = firstDayOfMonth.weekday; // 1 = Monday, 7 = Sunday

    List<Widget> calendarDays = [];

    // Add empty cells for days before the first day of the month
    for (int i = 1; i < firstWeekday; i++) {
      calendarDays.add(Container());
    }

    // Add cells for each day of the month
    for (int day = 1; day <= daysInMonth; day++) {
      final date = DateTime(year, month, day);
      final now = DateTime.now();
      final today = DateTime(now.year, now.month, now.day);
      final isToday = _isSameDay(date, today);
      final hasActivity = _hasActivityOnDate(date);

      calendarDays.add(_buildCalendarDay(day, isToday, hasActivity, date));
    }

    return GridView.count(
      crossAxisCount: 7,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      children: calendarDays,
    );
  }

  Widget _buildCalendarDay(int day, bool isToday, bool hasActivity, DateTime date) {
    final isPastDay = date.isBefore(DateTime.now()) && !isToday;

    return Container(
      margin: const EdgeInsets.all(2),
      child: Container(
        decoration: BoxDecoration(
          color: hasActivity
              ? const Color(0xFF4CAF50).withValues(alpha: 0.1)
              : isToday
                  ? const Color(0xFF4169E1).withValues(alpha: 0.1)
                  : Colors.transparent,
          borderRadius: BorderRadius.circular(8),
          border: isToday ? Border.all(
            color: const Color(0xFF4169E1),
            width: 2,
          ) : null,
        ),
        child: Stack(
          children: [
            Center(
              child: Text(
                '$day',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: isToday ? FontWeight.bold : FontWeight.normal,
                  color: isToday
                      ? const Color(0xFF4169E1)
                      : hasActivity
                          ? const Color(0xFF4CAF50)
                          : isPastDay
                              ? Colors.grey[400]
                              : const Color(0xFF2C3E50),
                ),
              ),
            ),
            if (hasActivity)
              Positioned(
                top: 4,
                right: 4,
                child: Container(
                  width: 6,
                  height: 6,
                  decoration: const BoxDecoration(
                    color: Color(0xFF4CAF50),
                    shape: BoxShape.circle,
                  ),
                ),
              ),
            if (isToday)
              Positioned(
                bottom: 2,
                left: 0,
                right: 0,
                child: Container(
                  height: 2,
                  decoration: BoxDecoration(
                    color: const Color(0xFF4169E1),
                    borderRadius: BorderRadius.circular(1),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildCalendarLegend() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFF8F9FA),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Legend',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: Color(0xFF2C3E50),
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              _buildLegendItem(
                const Color(0xFF4CAF50),
                'Practice completed',
              ),
              const SizedBox(width: 20),
              _buildLegendItem(
                const Color(0xFF4169E1),
                'Today',
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildLegendItem(Color color, String label) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 12,
          height: 12,
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.3),
            border: Border.all(color: color, width: 1),
            borderRadius: BorderRadius.circular(3),
          ),
        ),
        const SizedBox(width: 8),
        Text(
          label,
          style: TextStyle(
            fontSize: 12,
            color: Colors.grey[600],
          ),
        ),
      ],
    );
  }

  Widget _buildCalendarStats() {
    final now = DateTime.now();
    final thisMonthDays = _getThisMonthActivityDays();
    final totalDaysThisMonth = DateTime(now.year, now.month + 1, 0).day;
    final completionRate = thisMonthDays / totalDaysThisMonth;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: const Color(0xFF4169E1).withValues(alpha: 0.2),
          width: 1,
        ),
      ),
      child: Column(
        children: [
          Row(
            children: [
              const Icon(
                Icons.analytics,
                color: Color(0xFF4169E1),
                size: 20,
              ),
              const SizedBox(width: 8),
              const Text(
                'This Month\'s Progress',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF2C3E50),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: _buildStatItem(
                  '${thisMonthDays.toInt()}',
                  'Active Days',
                  const Color(0xFF4CAF50),
                ),
              ),
              Expanded(
                child: _buildStatItem(
                  '${(completionRate * 100).toInt()}%',
                  'Completion',
                  const Color(0xFF4169E1),
                ),
              ),
              Expanded(
                child: _buildStatItem(
                  '${_statsService.currentStreak}',
                  'Current Streak',
                  const Color(0xFFFFA500),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStatItem(String value, String label, Color color) {
    return Column(
      children: [
        Text(
          value,
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: TextStyle(
            fontSize: 12,
            color: Colors.grey[600],
          ),
          textAlign: TextAlign.center,
        ),
      ],
    );
  }

  String _getMonthName(int month) {
    const months = [
      'January', 'February', 'March', 'April', 'May', 'June',
      'July', 'August', 'September', 'October', 'November', 'December'
    ];
    return months[month - 1];
  }

  bool _isSameDay(DateTime date1, DateTime date2) {
    // Normalize both dates to midnight for comparison
    final normalizedDate1 = DateTime(date1.year, date1.month, date1.day);
    final normalizedDate2 = DateTime(date2.year, date2.month, date2.day);

    return normalizedDate1.isAtSameMomentAs(normalizedDate2);
  }

  bool _hasActivityOnDate(DateTime date) {
    // For now, we'll simulate activity data
    // In a real app, you would check your practice history
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);

    // Mark today as having activity if user has any sessions
    if (_isSameDay(date, today)) {
      return _statsService.totalSessions > 0;
    }

    // Use weekly progress data for recent days
    final startOfWeek = today.subtract(Duration(days: today.weekday - 1));
    final daysDiff = date.difference(startOfWeek).inDays;
    if (daysDiff >= 0 && daysDiff < 7 && daysDiff < _weeklyProgress.length) {
      return _weeklyProgress[daysDiff];
    }

    // Simulate some activity for demonstration
    return date.day % 3 == 0 && date.isBefore(today);
  }

  double _getThisMonthActivityDays() {
    final now = DateTime.now();
    double activeDays = 0;

    // Count active days this month up to today
    for (int day = 1; day <= now.day; day++) {
      final date = DateTime(now.year, now.month, day);
      if (_hasActivityOnDate(date)) {
        activeDays++;
      }
    }

    return activeDays;
  }

  String _getProgressMessage(int completedDays) {
    if (completedDays >= 7) {
      return 'Perfect week! You\'re on fire! 🔥';
    } else if (completedDays >= 5) {
      return 'Great consistency! Keep it up! 💪';
    } else if (completedDays >= 3) {
      return 'Good progress! Try to practice more! 📈';
    } else if (completedDays >= 1) {
      return 'Good start! Build your habit! 🌱';
    } else {
      return 'Let\'s start your learning journey! 🚀';
    }
  }

  Widget _buildSubjectProgressCard() {
    // Get all topics from both statistics service and Firestore progress
    final allTopics = <String>{};
    allTopics.addAll(_statsService.topicStats.keys);
    allTopics.addAll(_topicProgress.keys.map((k) => k.toLowerCase()));
    
    // Create subject data
    final subjects = [
      {'name': 'Addition', 'percentage': 95, 'color': const Color(0xFF4169E1)},
      {'name': 'Subtraction', 'percentage': 70, 'color': const Color(0xFF90EE90)},
      {'name': 'Shapes', 'percentage': 82, 'color': const Color(0xFFFFA500)},
    ];
    
    // Update with real data if available
    for (var topic in allTopics.take(3)) {
      final stats = _getTopicStatistics(topic);
      final accuracy = (stats['accuracy'] as double) * 100;
      final index = allTopics.toList().indexOf(topic);
      if (index < subjects.length) {
        subjects[index]['name'] = topic.substring(0, 1).toUpperCase() + topic.substring(1);
        subjects[index]['percentage'] = accuracy.toInt();
      }
    }
    
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(
                Icons.school,
                size: 18,
                color: Color(0xFF4169E1),
              ),
              const SizedBox(width: 8),
              const Text(
                'Subject Progress',
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF1A1A2E),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          ...subjects.map((subject) => _buildSubjectItem(
            subject['name'] as String,
            subject['percentage'] as int,
            subject['color'] as Color,
          )),
        ],
      ),
    );
  }

  Widget _buildSubjectItem(String name, int percentage, Color color) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Row(
        children: [
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.15),
              shape: BoxShape.circle,
            ),
            child: Center(
              child: Text(
                name.substring(0, 1).toUpperCase(),
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  color: color,
                ),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      name,
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                        color: Color(0xFF1A1A2E),
                      ),
                    ),
                    Text(
                      '$percentage%',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey[600],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: LinearProgressIndicator(
                    value: percentage / 100,
                    backgroundColor: const Color(0xFFF0F0F0),
                    valueColor: AlwaysStoppedAnimation<Color>(color),
                    minHeight: 6,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatsRow() {
    final accuracy = (_statsService.overallAccuracy * 100).toInt();
    final totalTimeMinutes = _statsService.totalTimeSpent ~/ 60;
    final hours = totalTimeMinutes ~/ 60;
    final minutes = totalTimeMinutes % 60;

    String timeText;
    if (hours > 0) {
      timeText = '${hours}h ${minutes}m';
    } else if (minutes > 0) {
      timeText = '${minutes}m';
    } else {
      timeText = '0m';
    }

    return Row(
      children: [
        Expanded(
          child: _buildStatCard(
            timeText,
            'Time Learned',
            const Color(0xFF8A2BE2),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _buildStatCard(
            '$accuracy%',
            'Accuracy',
            const Color(0xFF90EE90),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _buildStatCard(
            '${_statsService.totalSessions}',
            'Sessions',
            const Color(0xFF4169E1),
          ),
        ),
      ],
    );
  }

  Widget _buildStatCard(String value, String label, Color color) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.15),
              shape: BoxShape.circle,
            ),
            child: Icon(
              value.contains('h') ? Icons.access_time : Icons.trending_up,
              color: color,
              size: 16,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            value,
            style: const TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: Color(0xFF1A1A2E),
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              color: Colors.grey[600],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRecentAchievements() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(
                Icons.emoji_events,
                size: 18,
                color: Color(0xFFFFA500),
              ),
              const SizedBox(width: 8),
              const Text(
                'Recent Achievements',
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF1A1A2E),
                ),
              ),
              const Spacer(),
              GestureDetector(
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => const AchievementsScreen()),
                ),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFFA500).withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: const Color(0xFFFFA500).withValues(alpha: 0.3),
                      width: 1,
                    ),
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        'View All',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFFFFA500),
                        ),
                      ),
                      SizedBox(width: 4),
                      Icon(
                        Icons.arrow_forward_ios,
                        size: 12,
                        color: Color(0xFFFFA500),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          _buildAchievementItem(
            'Addition Master',
            'Completed 10 additions',
            const Color(0xFFFFA500),
          ),
          const SizedBox(height: 12),
          _buildAchievementItem(
            'Perfect Week',
            '7 days in a row',
            const Color(0xFF90EE90),
          ),
        ],
      ),
    );
  }

  Widget _buildAchievementItem(String title, String subtitle, Color color) {
    return GestureDetector(
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute(builder: (context) => const AchievementsScreen()),
      ),
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.15),
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.emoji_events,
              color: color,
              size: 18,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                    color: Color(0xFF1A1A2E),
                  ),
                ),
                Text(
                  subtitle,
                  style: TextStyle(
                    fontSize: 11,
                    color: Colors.grey[600],
                  ),
                ),
              ],
            ),
          ),
          Icon(
            Icons.chevron_right,
            color: Colors.grey[400],
            size: 20,
          ),
        ],
      ),
    );
  }

  Widget _buildWeeklyGoals() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(
                Icons.flag,
                size: 18,
                color: Color(0xFF4169E1),
              ),
              const SizedBox(width: 8),
              const Text(
                'This Week\'s Goals',
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF1A1A2E),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          _buildGoalItem('Practice 30 minutes daily', 0.8, true),
          const SizedBox(height: 12),
          _buildGoalItem('Complete 5 subtraction levels', 0.52, false),
        ],
      ),
    );
  }

  Widget _buildGoalItem(String title, double progress, bool isCompleted) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(
              isCompleted ? Icons.check_circle : Icons.circle_outlined,
              color: isCompleted ? const Color(0xFF90EE90) : Colors.grey[400],
              size: 18,
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                title,
                style: TextStyle(
                  fontSize: 13,
                  color: isCompleted ? Colors.grey[600] : const Color(0xFF1A1A2E),
                  decoration: isCompleted ? TextDecoration.lineThrough : null,
                ),
              ),
            ),
            Text(
              '${(progress * 100).toInt()}%',
              style: TextStyle(
                fontSize: 12,
                color: Colors.grey[600],
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: LinearProgressIndicator(
            value: progress,
            backgroundColor: const Color(0xFFF0F0F0),
            valueColor: AlwaysStoppedAnimation<Color>(
              isCompleted ? const Color(0xFF90EE90) : const Color(0xFF4169E1),
            ),
            minHeight: 4,
          ),
        ),
      ],
    );
  }

  Widget _buildQuickActionsCard() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(
                Icons.dashboard,
                size: 18,
                color: Color(0xFF8A2BE2),
              ),
              const SizedBox(width: 8),
              const Text(
                'Quick Actions',
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF1A1A2E),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: _buildActionButton(
                  'View Achievements',
                  'See all your badges',
                  Icons.emoji_events,
                  const Color(0xFFFFA500),
                  () => Navigator.push(
                    context,
                    MaterialPageRoute(builder: (context) => const AchievementsScreen()),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildActionButton(
                  'Leaderboard',
                  'Compare with friends',
                  Icons.leaderboard,
                  const Color(0xFF4169E1),
                  () => Navigator.push(
                    context,
                    MaterialPageRoute(builder: (context) => const LeaderboardScreen()),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildActionButton(
    String title,
    String subtitle,
    IconData icon,
    Color color,
    VoidCallback onTap,
  ) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: color.withValues(alpha: 0.2),
            width: 1,
          ),
        ),
        child: Column(
          children: [
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: color,
                borderRadius: BorderRadius.circular(12),
                boxShadow: [
                  BoxShadow(
                    color: color.withValues(alpha: 0.3),
                    blurRadius: 8,
                    offset: const Offset(0, 3),
                  ),
                ],
              ),
              child: Icon(
                icon,
                color: Colors.white,
                size: 24,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              title,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.bold,
                color: color,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 4),
            Text(
              subtitle,
              style: TextStyle(
                fontSize: 11,
                color: Colors.grey[600],
              ),
              textAlign: TextAlign.center,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildShareCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF4169E1), Color(0xFF6495ED)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF4169E1).withValues(alpha: 0.3),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Container(
            width: 64,
            height: 64,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.2),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.share,
              color: Colors.white,
              size: 32,
            ),
          ),
          const SizedBox(height: 16),
          const Text(
            'Share with Parents',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8),
          Text(
            'Show mom and dad your amazing progress!',
            style: TextStyle(
              fontSize: 14,
              color: Colors.white.withValues(alpha: 0.9),
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 20),
          ElevatedButton(
            onPressed: () {
              // Handle share action
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.white,
              foregroundColor: const Color(0xFF4169E1),
              padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 12),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(25),
              ),
              elevation: 0,
            ),
            child: const Text(
              'Share Report',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}