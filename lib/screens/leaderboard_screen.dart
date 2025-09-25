import 'package:flutter/material.dart';
import '../services/leaderboard_service.dart';
import '../widgets/user_avatar.dart';
import 'dart:async';

class LeaderboardScreen extends StatefulWidget {
  const LeaderboardScreen({super.key});

  @override
  State<LeaderboardScreen> createState() => _LeaderboardScreenState();
}

class _LeaderboardScreenState extends State<LeaderboardScreen> {
  String selectedPeriod = 'Weekly';
  String selectedGrade = 'Grade 1';

  final LeaderboardService _leaderboardService = LeaderboardService.instance;
  StreamSubscription<List<LeaderboardUser>>? _leaderboardSubscription;
  List<LeaderboardUser> _leaderboardData = [];
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    print('🎯 LEADERBOARD SCREEN: initState() called - initializing leaderboard screen');
    _loadLeaderboardData();
  }

  @override
  void dispose() {
    _leaderboardSubscription?.cancel();
    super.dispose();
  }

  void _loadLeaderboardData() {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    _leaderboardSubscription?.cancel();

    try {
      Stream<List<LeaderboardUser>> stream;

      if (selectedPeriod == 'Weekly') {
        print('📊 LEADERBOARD SCREEN: Loading WEEKLY leaderboard');
        stream = _leaderboardService.getWeeklyLeaderboardStream();
      } else if (selectedPeriod == 'Monthly') {
        print('📊 LEADERBOARD SCREEN: Loading MONTHLY leaderboard');
        stream = _leaderboardService.getMonthlyLeaderboardStream();
      } else {
        print('📊 LEADERBOARD SCREEN: Loading ALL-TIME leaderboard');
        stream = _leaderboardService.getLeaderboardStream(period: 'all-time');
      }


      _leaderboardSubscription = stream.listen(
        (data) {
          if (mounted) {
            print('LeaderboardScreen: Received $selectedPeriod data with ${data.length} users');
            for (var user in data) {
              print('  - ${user.name}: ${user.points} points (rank ${user.rank})');
            }
            setState(() {
              _leaderboardData = data;
              _isLoading = false;
              _error = null;
            });
          }
        },
        onError: (error) {
          if (mounted) {
            String errorMessage;
            if (error.toString().contains('permission-denied')) {
              errorMessage = 'Permission denied. Please try signing in again.';
            } else if (error.toString().contains('unavailable')) {
              errorMessage = 'Service temporarily unavailable. Please try again.';
            } else if (selectedPeriod != 'All-time') {
              // For weekly/monthly, show empty state
              setState(() {
                _leaderboardData = [];
                _isLoading = false;
                _error = null;
              });
              return;
            } else {
              errorMessage = 'Unable to load leaderboard data. Please check your connection.';
            }
            setState(() {
              _error = errorMessage;
              _isLoading = false;
            });
          }
        },
      );

    } catch (e) {
      if (mounted) {
        setState(() {
          _error = 'Connection error. Tap to retry or check your internet connection.';
          _isLoading = false;
        });
      }
    }
  }



  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FA),
      appBar: AppBar(
        backgroundColor: const Color(0xFF5B9EF7),
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: const Row(
          mainAxisAlignment: MainAxisAlignment.center,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              '👑 Math Champions 👑',
              style: TextStyle(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
        centerTitle: true,
      ),
      body: Column(
        children: [
          // Fixed top section with background gradient
          Container(
            height: MediaQuery.of(context).size.height * 0.15,
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Color(0xFF5B9EF7),
                  Color(0xFFFFF3DC),
                ],
              ),
            ),
            child: Column(
              children: [
                // Keep learning text
                Padding(
                  padding: const EdgeInsets.only(top: 8, bottom: 16),
                  child: Center(
                    child: Text(
                      'Keep learning, keep growing!',
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.9),
                        fontSize: 14,
                      ),
                    ),
                  ),
                ),
                
                // Period selection tabs
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: Container(
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(30),
                    ),
                    child: Row(
                      children: [
                        _buildPeriodTab('Weekly', selectedPeriod == 'Weekly'),
                        _buildPeriodTab('Monthly', selectedPeriod == 'Monthly'),
                        _buildPeriodTab('All-time', selectedPeriod == 'All-time'),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
          
          // Scrollable content
          Expanded(
            child: Container(
              color: const Color(0xFFF5F7FA),
              child: RefreshIndicator(
                onRefresh: () async {
                  _loadLeaderboardData();
                },
                child: ListView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  children: [
                const SizedBox(height: 16),
                
                // Grade selection
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: Row(
                    children: [
                      _buildGradeButton('Grade 1', selectedGrade == 'Grade 1'),
                      const SizedBox(width: 12),
                      _buildGradeButton('Grade 2', selectedGrade == 'Grade 2'),
                    ],
                  ),
                ),
                
                const SizedBox(height: 20),
                
                // Main content
                if (_isLoading)
                  const SizedBox(
                    height: 200,
                    child: Center(child: CircularProgressIndicator()),
                  )
                else if (_error != null && _leaderboardData.isEmpty)
                  _buildErrorSection()
                else if (_leaderboardData.isEmpty)
                  _buildEmptyState()
                else
                  // Show the leaderboard structure
                  Column(
                    children: [
                      if (_leaderboardData.length >= 3) ...[
                        // Top 3 Podium
                        _buildPodiumSection(),
                        const SizedBox(height: 20),
                      ],

                      // Leaderboard list card
                      _buildLeaderboardCard(),

                      // Motivational card at bottom
                      _buildMotivationalCard(),
                    ],
                  ),
                
                const SizedBox(height: 100),
              ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPeriodTab(String text, bool isSelected) {
    return Expanded(
      child: GestureDetector(
        onTap: () {
          setState(() {
            selectedPeriod = text;
          });
          _loadLeaderboardData();
        },
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(
            color: isSelected ? const Color(0xFF5B9EF7) : Colors.transparent,
            borderRadius: BorderRadius.circular(30),
          ),
          child: Text(
            text,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: isSelected ? Colors.white : Colors.grey,
              fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
              fontSize: 14,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildGradeButton(String text, bool isSelected) {
    return Expanded(
      child: GestureDetector(
        onTap: () => setState(() => selectedGrade = text),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 14),
          decoration: BoxDecoration(
            color: isSelected ? const Color(0xFF4CD964) : Colors.white,
            borderRadius: BorderRadius.circular(30),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.05),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.star,
                color: isSelected ? Colors.white : Colors.grey,
                size: 18,
              ),
              const SizedBox(width: 6),
              Text(
                text,
                style: TextStyle(
                  color: isSelected ? Colors.white : Colors.grey,
                  fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                  fontSize: 14,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPodiumSection() {
    final top3 = _leaderboardData.take(3).toList();
    if (top3.isEmpty) return const SizedBox.shrink();

    // Only show actual users on the podium, don't add empty placeholders
    if (top3.length < 3) {
      // If we have fewer than 3 users, just show the ones we have
      return _buildSimplifiedPodium(top3);
    }

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.08),
            blurRadius: 16,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          const Text(
            '🏆 Top Champions 🏆',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w700,
              color: Color(0xFF2C3E50),
            ),
          ),
          const SizedBox(height: 24),
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              // Second place
              _buildPodiumPlace(top3[1], 2, 85, const Color(0xFFC0C0C0)),
              const SizedBox(width: 8),
              // First place
              _buildPodiumPlace(top3[0], 1, 110, const Color(0xFFFFD700)),
              const SizedBox(width: 8),
              // Third place
              _buildPodiumPlace(top3[2], 3, 65, const Color(0xFFCD7F32)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSimplifiedPodium(List<LeaderboardUser> users) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.08),
            blurRadius: 16,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          const Text(
            '🏆 Top Champions 🏆',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w700,
              color: Color(0xFF2C3E50),
            ),
          ),
          const SizedBox(height: 24),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: users.asMap().entries.map((entry) {
              final index = entry.key;
              final user = entry.value;
              final colors = [
                const Color(0xFFFFD700), // Gold
                const Color(0xFFC0C0C0), // Silver
                const Color(0xFFCD7F32), // Bronze
              ];
              final heights = [110.0, 85.0, 65.0];
              return _buildPodiumPlace(
                user,
                index + 1,
                heights[index],
                colors[index]
              );
            }).toList(),
          ),
        ],
      ),
    );
  }

  Widget _buildPodiumPlace(LeaderboardUser user, int position, double height, Color color) {
    String medal = position == 1 ? '👑' : (position == 2 ? '🥈' : '🥉');

    return Expanded(
      child: Column(
        children: [
          // Medal emoji
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Colors.white,
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: color.withValues(alpha: 0.3),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Text(
              medal,
              style: const TextStyle(fontSize: 24),
            ),
          ),
          const SizedBox(height: 12),

          // User avatar
          Container(
            width: 64,
            height: 64,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(color: Colors.white, width: 4),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.15),
                  blurRadius: 12,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: UserAvatar(
              avatar: user.avatar,
              size: 60,
              backgroundColor: Colors.white,
              showBorder: false,
            ),
          ),
          const SizedBox(height: 12),

          // Podium bar
          Container(
            width: 90,
            height: height,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  color,
                  color.withValues(alpha: 0.8),
                ],
              ),
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(12),
                topRight: Radius.circular(12),
              ),
              boxShadow: [
                BoxShadow(
                  color: color.withValues(alpha: 0.4),
                  blurRadius: 8,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  user.name,
                  style: const TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 13,
                    color: Colors.white,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 4),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    '${user.points}',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLeaderboardCard() {
    final displayList = _leaderboardData.skip(3).take(7).toList();

    if (displayList.isEmpty) return const SizedBox.shrink();

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.08),
            blurRadius: 16,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(20),
            decoration: const BoxDecoration(
              border: Border(
                bottom: BorderSide(
                  color: Color(0xFFF0F0F0),
                  width: 1,
                ),
              ),
            ),
            child: Row(
              children: [
                const Icon(
                  Icons.leaderboard,
                  color: Color(0xFF5B9EF7),
                  size: 20,
                ),
                const SizedBox(width: 8),
                const Text(
                  'Rankings',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF2C3E50),
                  ),
                ),
                const Spacer(),
                Text(
                  '${displayList.length} players',
                  style: const TextStyle(
                    fontSize: 12,
                    color: Color(0xFF6B7280),
                  ),
                ),
              ],
            ),
          ),
          ...displayList.map((user) => _buildLeaderboardItem(user)),
          const SizedBox(height: 8),
        ],
      ),
    );
  }

  Widget _buildLeaderboardItem(LeaderboardUser user) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: user.isCurrentUser ? const Color(0xFFF0F8FF) : const Color(0xFFFAFAFA),
        borderRadius: BorderRadius.circular(12),
        border: user.isCurrentUser ? Border.all(
          color: const Color(0xFF5B9EF7).withValues(alpha: 0.3),
          width: 1.5,
        ) : null,
      ),
      child: Row(
        children: [
          // Rank badge
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              color: user.isCurrentUser ? const Color(0xFF5B9EF7) : const Color(0xFF6B7280),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Center(
              child: Text(
                '${user.rank}',
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: Colors.white,
                ),
              ),
            ),
          ),
          const SizedBox(width: 12),

          // Avatar
          UserAvatar(
            avatar: user.avatar,
            size: 44,
            backgroundColor: Colors.white,
            showBorder: true,
            borderColor: user.isCurrentUser ? const Color(0xFF5B9EF7) : const Color(0xFFE5E7EB),
            borderWidth: 2,
          ),
          const SizedBox(width: 12),

          // Name and points
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      user.isCurrentUser ? 'You!' : user.name,
                      style: TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 15,
                        color: user.isCurrentUser ? const Color(0xFF5B9EF7) : const Color(0xFF2C3E50),
                      ),
                    ),
                    if (user.isCurrentUser) ...[
                      const SizedBox(width: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: const Color(0xFF5B9EF7),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Text(
                          'YOU',
                          style: TextStyle(
                            fontSize: 8,
                            fontWeight: FontWeight.w600,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 2),
                Text(
                  '${user.points} points',
                  style: const TextStyle(
                    color: Color(0xFF6B7280),
                    fontSize: 13,
                  ),
                ),
              ],
            ),
          ),

          // Challenge button (simplified)
          if (!user.isCurrentUser)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: const Color(0xFF5B9EF7).withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: const Color(0xFF5B9EF7).withValues(alpha: 0.3),
                  width: 1,
                ),
              ),
              child: const Text(
                'Challenge',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF5B9EF7),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildMotivationalCard() {
    return Container(
      margin: const EdgeInsets.all(20),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0xFF4CD964),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF4CD964).withValues(alpha: 0.3),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        children: [
          const Text(
            '💚',
            style: TextStyle(fontSize: 32),
          ),
          const SizedBox(height: 8),
          const Text(
            'Keep up the great work!',
            style: TextStyle(
              color: Colors.white,
              fontSize: 16,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 4),
          const Text(
            'Every problem solved makes you stronger! 💪',
            style: TextStyle(
              color: Colors.white,
              fontSize: 13,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildErrorSection() {
    return Padding(
      padding: const EdgeInsets.all(20),
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(
              Icons.cloud_off,
              size: 48,
              color: Colors.orange,
            ),
            const SizedBox(height: 8),
            const Text(
              'Connection Issue',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: Colors.black87,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              _error!,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey.shade600,
              ),
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: _loadLeaderboardData,
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.orange,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(20),
                ),
              ),
              child: const Text('Try Again'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Container(
      height: 300,
      margin: const EdgeInsets.symmetric(horizontal: 20),
      decoration: BoxDecoration(
        color: Colors.grey.shade50,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.grey.shade200, width: 2),
      ),
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.leaderboard_outlined,
              size: 48,
              color: Colors.grey.shade400,
            ),
            const SizedBox(height: 12),
            Text(
              'No ${selectedPeriod.toLowerCase()} champions yet',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w500,
                color: Colors.grey.shade600,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Be the first to earn points!',
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey.shade500,
              ),
            ),
          ],
        ),
      ),
    );
  }

}