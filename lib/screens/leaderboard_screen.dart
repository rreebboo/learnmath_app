import 'package:flutter/material.dart';
import '../services/leaderboard_service.dart';
import 'dart:async';

class LeaderboardScreen extends StatefulWidget {
  const LeaderboardScreen({super.key});

  @override
  State<LeaderboardScreen> createState() => _LeaderboardScreenState();
}

class _LeaderboardScreenState extends State<LeaderboardScreen> {
  String selectedPeriod = 'Weekly';
  String selectedGrade = 'Grade 1';
  
  final LeaderboardService _leaderboardService = LeaderboardService();
  StreamSubscription<List<LeaderboardUser>>? _leaderboardSubscription;
  List<LeaderboardUser> _leaderboardData = [];
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
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
        stream = _leaderboardService.getWeeklyLeaderboardStream();
      } else if (selectedPeriod == 'Monthly') {
        stream = _leaderboardService.getMonthlyLeaderboardStream();
      } else {
        stream = _leaderboardService.getLeaderboardStream(period: 'all-time');
      }

      _leaderboardSubscription = stream.listen(
        (data) {
          if (mounted) {
            setState(() {
              _leaderboardData = data;
              _isLoading = false;
              _error = null;
            });
          }
        },
        onError: (error) {
          if (mounted) {
            // Show fallback data on error
            _loadFallbackData();
            setState(() {
              _error = 'Unable to load latest data. Showing sample leaderboard.';
              _isLoading = false;
            });
          }
        },
      );

    } catch (e) {
      if (mounted) {
        _loadFallbackData();
        setState(() {
          _error = 'Connection error. Showing sample leaderboard.';
          _isLoading = false;
        });
      }
    }
  }

  void _loadFallbackData() {
    // Provide sample data when Firebase is not available
    final currentUserId = _leaderboardService.firestoreService.currentUserId;
    
    _leaderboardData = [
      LeaderboardUser(
        id: 'sample1',
        rank: 1,
        name: 'Alex',
        avatar: '👨‍🎓',
        points: 1200,
        streak: 15,
        lessonsCompleted: 45,
        isCurrentUser: false,
      ),
      LeaderboardUser(
        id: 'sample2',
        rank: 2,
        name: 'Emma',
        avatar: '👩‍🎓',
        points: 850,
        streak: 12,
        lessonsCompleted: 38,
        isCurrentUser: false,
      ),
      LeaderboardUser(
        id: 'sample3',
        rank: 3,
        name: 'Sam',
        avatar: '👨',
        points: 750,
        streak: 8,
        lessonsCompleted: 32,
        isCurrentUser: false,
      ),
      LeaderboardUser(
        id: 'sample4',
        rank: 4,
        name: 'Mia',
        avatar: '👧',
        points: 650,
        streak: 10,
        lessonsCompleted: 30,
        isCurrentUser: false,
      ),
      LeaderboardUser(
        id: 'sample5',
        rank: 5,
        name: 'Jake',
        avatar: '👦',
        points: 620,
        streak: 7,
        lessonsCompleted: 28,
        isCurrentUser: false,
      ),
      LeaderboardUser(
        id: 'sample6',
        rank: 6,
        name: 'Lily',
        avatar: '👩',
        points: 600,
        streak: 5,
        lessonsCompleted: 25,
        isCurrentUser: false,
      ),
      LeaderboardUser(
        id: currentUserId ?? 'you',
        rank: 7,
        name: 'You!',
        avatar: '⭐',
        points: 580,
        streak: 4,
        lessonsCompleted: 22,
        isCurrentUser: true,
      ),
      LeaderboardUser(
        id: 'sample8',
        rank: 8,
        name: 'Ben',
        avatar: '👦',
        points: 520,
        streak: 3,
        lessonsCompleted: 20,
        isCurrentUser: false,
      ),
      LeaderboardUser(
        id: 'sample9',
        rank: 9,
        name: 'Max',
        avatar: '👨',
        points: 480,
        streak: 2,
        lessonsCompleted: 18,
        isCurrentUser: false,
      ),
      LeaderboardUser(
        id: 'sample10',
        rank: 10,
        name: 'Zoe',
        avatar: '👧',
        points: 450,
        streak: 1,
        lessonsCompleted: 16,
        isCurrentUser: false,
      ),
    ];

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
        title: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              '👑 ',
              style: TextStyle(fontSize: 20),
            ),
            const Text(
              'Math Champions',
              style: TextStyle(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.w600,
              ),
            ),
            const Text(
              ' 👑',
              style: TextStyle(fontSize: 20),
            ),
          ],
        ),
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.emoji_events, color: Colors.white),
            onPressed: () {},
          ),
        ],
      ),
      body: Stack(
        children: [
          // Background gradient
          Container(
            height: MediaQuery.of(context).size.height * 0.35,
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
          ),
          
          RefreshIndicator(
            onRefresh: () async {
              _loadLeaderboardData();
            },
            child: ListView(
              physics: const AlwaysScrollableScrollPhysics(),
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
                  _buildEmptySection()
                else ...[
                  // Top 3 Podium
                  _buildPodiumSection(),
                  
                  const SizedBox(height: 20),
                  
                  // Leaderboard list card
                  _buildLeaderboardCard(),
                  
                  // Motivational card at bottom
                  _buildMotivationalCard(),
                ],
                
                const SizedBox(height: 100),
              ],
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
    
    while (top3.length < 3) {
      top3.add(LeaderboardUser(
        id: 'placeholder_${top3.length}',
        rank: top3.length + 1,
        name: 'Empty',
        avatar: '🎯',
        points: 0,
        streak: 0,
        lessonsCompleted: 0,
        isCurrentUser: false,
      ));
    }
    
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 40),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          // Second place
          _buildPodiumPlace(top3[1], 2, 80, const Color(0xFFE5E5EA)),
          const SizedBox(width: 8),
          // First place
          _buildPodiumPlace(top3[0], 1, 100, const Color(0xFFFFD700)),
          const SizedBox(width: 8),
          // Third place
          _buildPodiumPlace(top3[2], 3, 60, const Color(0xFFFF9500)),
        ],
      ),
    );
  }

  Widget _buildPodiumPlace(LeaderboardUser user, int position, double height, Color color) {
    String medal = position == 1 ? '👑' : (position == 2 ? '🥈' : '🥉');
    bool isPlaceholder = user.name == 'Empty';
    
    return Column(
      children: [
        Text(
          medal,
          style: const TextStyle(fontSize: 24),
        ),
        const SizedBox(height: 8),
        Container(
          width: 60,
          height: 60,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(color: Colors.white, width: 3),
            color: Colors.white,
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.1),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Center(
            child: isPlaceholder
                ? Icon(Icons.person_outline, color: Colors.grey.shade400)
                : Text(user.avatar, style: const TextStyle(fontSize: 28)),
          ),
        ),
        const SizedBox(height: 8),
        Container(
          width: 80,
          height: height,
          decoration: BoxDecoration(
            color: color,
            borderRadius: const BorderRadius.only(
              topLeft: Radius.circular(8),
              topRight: Radius.circular(8),
            ),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                isPlaceholder ? '' : user.name,
                style: const TextStyle(
                  fontWeight: FontWeight.w600,
                  fontSize: 12,
                  color: Colors.black87,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              Text(
                '${user.points} pts',
                style: TextStyle(
                  color: Colors.grey.shade700,
                  fontSize: 11,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildLeaderboardCard() {
    final displayList = _leaderboardData.skip(3).take(7).toList();
    
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20),
      padding: const EdgeInsets.symmetric(vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        children: displayList.map((user) => _buildLeaderboardItem(user)).toList(),
      ),
    );
  }

  Widget _buildLeaderboardItem(LeaderboardUser user) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: user.isCurrentUser ? const Color(0xFFE3F2FD) : Colors.transparent,
      ),
      child: Row(
        children: [
          // Rank
          Container(
            width: 28,
            alignment: Alignment.center,
            child: Text(
              '${user.rank}',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: user.isCurrentUser ? const Color(0xFF5B9EF7) : Colors.grey.shade700,
              ),
            ),
          ),
          const SizedBox(width: 12),
          
          // Avatar
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: const Color(0xFFFFF3DC),
              border: Border.all(
                color: user.isCurrentUser ? const Color(0xFF5B9EF7) : const Color(0xFFFFD700),
                width: 2,
              ),
            ),
            child: Center(
              child: Text(
                user.avatar,
                style: const TextStyle(fontSize: 24),
              ),
            ),
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
                        fontSize: 14,
                        color: user.isCurrentUser ? const Color(0xFF5B9EF7) : Colors.black87,
                      ),
                    ),
                    if (user.isCurrentUser) ...[
                      const SizedBox(width: 8),
                      const Text('✨⭐', style: TextStyle(fontSize: 12)),
                    ],
                  ],
                ),
                Text(
                  '${user.points} points',
                  style: TextStyle(
                    color: Colors.grey.shade600,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
          
          // Challenge button
          if (!user.isCurrentUser)
            ElevatedButton(
              onPressed: () {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Challenge feature coming soon!'),
                    duration: Duration(seconds: 2),
                  ),
                );
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFFF9500),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(20),
                ),
                elevation: 0,
              ),
              child: const Text(
                'Challenge',
                style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
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

  Widget _buildEmptySection() {
    return Padding(
      padding: const EdgeInsets.all(20),
      child: Center(
        child: Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(20),
            boxShadow: [
              BoxShadow(
                color: Colors.grey.withValues(alpha: 0.1),
                spreadRadius: 1,
                blurRadius: 10,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(
                Icons.emoji_events_outlined,
                size: 64,
                color: Colors.grey,
              ),
              const SizedBox(height: 16),
              const Text(
                'Be the first champion!',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                  color: Colors.black87,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Complete some math exercises to appear on the leaderboard',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 14,
                  color: Colors.grey.shade600,
                ),
              ),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: () => Navigator.of(context).pop(),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF5B9EF7),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(20),
                  ),
                ),
                child: const Text('Start Practicing'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}