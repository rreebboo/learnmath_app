import 'package:flutter/material.dart';
import '../services/leaderboard_service.dart';
import 'dart:async';

class LeaderboardScreen extends StatefulWidget {
  const LeaderboardScreen({super.key});

  @override
  State<LeaderboardScreen> createState() => _LeaderboardScreenState();
}

class _LeaderboardScreenState extends State<LeaderboardScreen> {
  String selectedPeriod = 'weekly';
  String selectedGrade = 'Grade 1';
  
  final LeaderboardService _leaderboardService = LeaderboardService();
  StreamSubscription<List<LeaderboardUser>>? _leaderboardSubscription;
  List<LeaderboardUser> _leaderboardData = [];
  bool _isLoading = true;
  String? _error;
  UserRankInfo? _userRankInfo;

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
      
      if (selectedPeriod == 'weekly') {
        stream = _leaderboardService.getWeeklyLeaderboardStream();
      } else if (selectedPeriod == 'monthly') {
        stream = _leaderboardService.getMonthlyLeaderboardStream();
      } else {
        stream = _leaderboardService.getLeaderboardStream(period: selectedPeriod);
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

      // Load user rank info
      _loadUserRankInfo();
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
        points: 980,
        streak: 12,
        lessonsCompleted: 38,
        isCurrentUser: false,
      ),
      LeaderboardUser(
        id: 'sample3',
        rank: 3,
        name: 'Sam',
        avatar: '👨',
        points: 850,
        streak: 8,
        lessonsCompleted: 32,
        isCurrentUser: false,
      ),
      LeaderboardUser(
        id: currentUserId ?? 'you',
        rank: 4,
        name: 'You!',
        avatar: '⭐',
        points: 720,
        streak: 5,
        lessonsCompleted: 28,
        isCurrentUser: true,
      ),
      LeaderboardUser(
        id: 'sample5',
        rank: 5,
        name: 'Maya',
        avatar: '👧',
        points: 650,
        streak: 3,
        lessonsCompleted: 25,
        isCurrentUser: false,
      ),
    ];

    _userRankInfo = UserRankInfo(
      currentUserRank: 4,
      totalUsers: 50,
      currentUserScore: 720,
      surroundingUsers: _leaderboardData.where((user) => 
        user.rank >= 2 && user.rank <= 6).toList(),
    );
  }

  Future<void> _loadUserRankInfo() async {
    try {
      final rankInfo = await _leaderboardService.getCurrentUserRankInfo(
        period: selectedPeriod,
      );
      if (mounted) {
        setState(() {
          _userRankInfo = rankInfo;
        });
      }
    } catch (e) {
      // Handle error silently for rank info
    }
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final screenHeight = MediaQuery.of(context).size.height;

    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FA),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 1,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.black87),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: const Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('👑', style: TextStyle(fontSize: 18)),
            SizedBox(width: 4),
            Flexible(
              child: Text(
                'Math Champions',
                style: TextStyle(
                  color: Colors.black87,
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                ),
                overflow: TextOverflow.ellipsis,
                maxLines: 1,
              ),
            ),
            SizedBox(width: 4),
            Text('👑', style: TextStyle(fontSize: 18)),
          ],
        ),
        centerTitle: true,
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 16),
            child: Icon(
              Icons.emoji_events,
              color: Colors.orange.shade600,
              size: 24,
            ),
          ),
        ],
      ),
body: RefreshIndicator(
        onRefresh: () async {
          _loadLeaderboardData();
        },
        child: CustomScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          slivers: [
            SliverToBoxAdapter(
              child: _buildHeaderSection(screenWidth),
            ),
            if (_isLoading)
              const SliverToBoxAdapter(
                child: Padding(
                  padding: EdgeInsets.all(50),
                  child: Center(
                    child: CircularProgressIndicator(),
                  ),
                ),
              )
            else if (_error != null && _leaderboardData.isEmpty)
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: Center(
                    child: Column(
                      children: [
                        const Icon(
                          Icons.cloud_off,
                          size: 48,
                          color: Colors.orange,
                        ),
                        const SizedBox(height: 16),
                        Text(
                          'Connection Issue',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                            color: Colors.grey.shade700,
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
                          ),
                          child: const Text('Try Again'),
                        ),
                      ],
                    ),
                  ),
                ),
              )
            else if (_leaderboardData.isEmpty)
              SliverToBoxAdapter(
                child: Container(
                  margin: EdgeInsets.all(screenWidth * 0.05),
                  padding: EdgeInsets.all(screenWidth * 0.075),
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
                    children: [
                      Icon(
                        Icons.emoji_events_outlined,
                        size: 64,
                        color: Colors.grey.shade400,
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'Be the first champion!',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w600,
                          color: Colors.grey.shade700,
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
                          backgroundColor: Colors.blue,
                          foregroundColor: Colors.white,
                        ),
                        child: const Text('Start Practicing'),
                      ),
                    ],
                  ),
                ),
              )
            else ...[
              if (_error != null)
                SliverToBoxAdapter(child: _buildConnectionBanner()),
              SliverToBoxAdapter(
                child: _buildPodiumSection(screenWidth, screenHeight),
              ),
              SliverToBoxAdapter(
                child: _buildLeaderboardList(),
              ),
              if (_userRankInfo != null)
                SliverToBoxAdapter(child: _buildUserRankSection()),
              SliverToBoxAdapter(
                child: _buildMotivationalCard(),
              ),
            ],
            SliverToBoxAdapter(
              child: SizedBox(
                height: MediaQuery.of(context).padding.bottom + 80,
              ),
            ),
          ],
        ),
      ),
    );
  }

Widget _buildHeaderSection(double screenWidth) {
    return Container(
      color: Colors.white,
      padding: EdgeInsets.fromLTRB(
        screenWidth * 0.05, 
        10, 
        screenWidth * 0.05, 
        20
      ),
      child: Column(
        children: [
          const Text(
            'Keep learning, keep growing!',
            style: TextStyle(
              color: Colors.grey,
              fontSize: 16,
            ),
            textAlign: TextAlign.center,
            overflow: TextOverflow.ellipsis,
            maxLines: 1,
          ),
          const SizedBox(height: 16),
          _buildToggleButtons(),
          const SizedBox(height: 12),
          _buildGradeButtons(),
        ],
      ),
    );
  }

  Widget _buildToggleButtons() {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFFF0F0F0),
        borderRadius: BorderRadius.circular(25),
      ),
      child: IntrinsicHeight(
        child: Row(
          children: [
            _buildToggleButton('Weekly', selectedPeriod == 'weekly'),
            _buildToggleButton('Monthly', selectedPeriod == 'monthly'),
            _buildToggleButton('All-time', selectedPeriod == 'all-time'),
          ],
        ),
      ),
    );
  }

  Widget _buildToggleButton(String text, bool isSelected) {
    final periodMap = {
      'Weekly': 'weekly',
      'Monthly': 'monthly',
      'All-time': 'all-time',
    };
    
    return Expanded(
      child: GestureDetector(
        onTap: () {
          final newPeriod = periodMap[text] ?? 'all-time';
          if (newPeriod != selectedPeriod) {
            setState(() {
              selectedPeriod = newPeriod;
            });
            _loadLeaderboardData();
          }
        },
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 4),
          decoration: BoxDecoration(
            color: isSelected ? Colors.blue : Colors.transparent,
            borderRadius: BorderRadius.circular(25),
          ),
          child: Text(
            text,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: isSelected ? Colors.white : Colors.grey.shade600,
              fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
              fontSize: 14,
            ),
            overflow: TextOverflow.ellipsis,
            maxLines: 1,
          ),
        ),
      ),
    );
  }

  Widget _buildGradeButtons() {
    return Row(
      children: [
        Expanded(child: _buildGradeButton('Grade 1', selectedGrade == 'Grade 1')),
        const SizedBox(width: 8),
        Expanded(child: _buildGradeButton('Grade 2', selectedGrade == 'Grade 2')),
      ],
    );
  }

  Widget _buildGradeButton(String text, bool isSelected) {
    return GestureDetector(
      onTap: () => setState(() => selectedGrade = text),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          color: isSelected ? Colors.green : Colors.grey.shade300,
          borderRadius: BorderRadius.circular(25),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.star,
              color: isSelected ? Colors.white : Colors.grey.shade600,
              size: 16,
            ),
            const SizedBox(width: 4),
            Flexible(
              child: Text(
                text,
                style: TextStyle(
                  color: isSelected ? Colors.white : Colors.grey.shade600,
                  fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                  fontSize: 14,
                ),
                overflow: TextOverflow.ellipsis,
                maxLines: 1,
              ),
            ),
          ],
        ),
      ),
    );
  }

Widget _buildPodiumSection(double screenWidth, double screenHeight) {
    final top3 = _leaderboardData.take(3).toList();
    if (top3.isEmpty) {
      return const SizedBox.shrink();
    }
    
    // Fill empty spots with placeholder users if needed
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
    
return Container(
      margin: EdgeInsets.fromLTRB(
        screenWidth * 0.05, 
        10, 
        screenWidth * 0.05, 
        10
      ),
      padding: const EdgeInsets.all(16),
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
        children: [
          const Text(
            'Top Champions',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w600,
              color: Colors.black87,
            ),
          ),
          const SizedBox(height: 16),
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              _buildPodiumPosition(top3[1], 2, Colors.grey.shade300, false),
              const SizedBox(width: 8),
              _buildPodiumPosition(top3[0], 1, Colors.amber.shade200, true),
              const SizedBox(width: 8),
              _buildPodiumPosition(top3[2], 3, Colors.orange.shade200, false),
            ],
          ),
        ],
      ),
    );
  }

Widget _buildPodiumPosition(LeaderboardUser user, int position, Color bgColor, bool isWinner) {
    String medal = position == 1 ? '👑' : (position == 2 ? '🥈' : '🥉');
    double height = isWinner ? 100 : 85;
    
    // Handle placeholder users
    bool isPlaceholder = user.name == 'Empty';
    
    return Expanded(
      child: Container(
        height: height,
        decoration: BoxDecoration(
          color: isPlaceholder ? Colors.grey.shade100 : bgColor,
          borderRadius: BorderRadius.circular(15),
          border: user.isCurrentUser 
              ? Border.all(color: Colors.green, width: 2)
              : isPlaceholder 
                ? Border.all(color: Colors.grey.shade300, width: 1)
                : null,
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              isPlaceholder ? '?' : medal, 
              style: TextStyle(
                fontSize: 24,
                color: isPlaceholder ? Colors.grey.shade400 : null,
              ),
            ),
            const SizedBox(height: 8),
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: isPlaceholder 
                    ? Colors.grey.shade200
                    : user.isCurrentUser 
                      ? Colors.green.shade100 
                      : Colors.white,
                shape: BoxShape.circle,
                border: user.isCurrentUser 
                    ? Border.all(color: Colors.green.shade300)
                    : null,
              ),
              child: Center(
                child: isPlaceholder
                    ? Icon(Icons.person_outline, color: Colors.grey.shade400, size: 20)
                    : user.isCurrentUser
                      ? Icon(Icons.star, color: Colors.green.shade600, size: 20)
                      : Text(user.avatar, style: const TextStyle(fontSize: 20)),
              ),
            ),
            const SizedBox(height: 8),
            ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 80),
              child: Text(
                isPlaceholder 
                    ? 'Available'
                    : user.isCurrentUser 
                      ? 'You!' 
                      : user.name,
                style: TextStyle(
                  fontWeight: FontWeight.w600,
                  fontSize: 12,
                  color: isPlaceholder 
                      ? Colors.grey.shade500
                      : user.isCurrentUser 
                        ? Colors.green.shade700 
                        : Colors.black87,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.center,
              ),
            ),
            Text(
              isPlaceholder ? '0 pts' : '${user.points} pts',
              style: TextStyle(
                color: Colors.grey.shade600,
                fontSize: 12,
              ),
            ),
          ],
        ),
      ),
    );
  }

Widget _buildLeaderboardList() {
    final remainingEntries = _leaderboardData.skip(3).toList();
    
    if (remainingEntries.isEmpty) {
      return const SizedBox.shrink();
    }
    
    return Container(
      margin: EdgeInsets.fromLTRB(
        MediaQuery.of(context).size.width * 0.05, 
        10, 
        MediaQuery.of(context).size.width * 0.05, 
        10
      ),
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
        children: remainingEntries.asMap().entries.map((entry) {
          int index = entry.key;
          LeaderboardUser user = entry.value;
          bool isEven = index % 2 == 0;
          
          return Container(
            decoration: BoxDecoration(
              color: isEven ? Colors.grey.shade50 : Colors.white,
              borderRadius: index == 0 
                ? const BorderRadius.only(
                    topLeft: Radius.circular(20),
                    topRight: Radius.circular(20),
                  )
                : index == remainingEntries.length - 1
                  ? const BorderRadius.only(
                      bottomLeft: Radius.circular(20),
                      bottomRight: Radius.circular(20),
                    )
                  : BorderRadius.zero,
            ),
            child: _buildLeaderboardRow(user),
          );
        }).toList(),
      ),
    );
  }

Widget _buildLeaderboardRow(LeaderboardUser user) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        children: [
          Container(
            width: 30,
            height: 30,
            decoration: BoxDecoration(
              color: user.isCurrentUser ? Colors.green.shade100 : Colors.grey.shade200,
              shape: BoxShape.circle,
            ),
            child: Center(
              child: Text(
                '${user.rank}',
                style: TextStyle(
                  fontWeight: FontWeight.w600,
                  color: user.isCurrentUser ? Colors.green.shade700 : Colors.grey.shade700,
                  fontSize: 12,
                ),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: user.isCurrentUser ? Colors.green.shade100 : Colors.white,
              shape: BoxShape.circle,
              border: user.isCurrentUser 
                  ? Border.all(color: Colors.green.shade300)
                  : null,
            ),
            child: Center(
              child: user.isCurrentUser
                ? Icon(Icons.star, color: Colors.green.shade600, size: 20)
                : Text(user.avatar, style: const TextStyle(fontSize: 20)),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  user.isCurrentUser ? 'You!' : user.name,
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    color: user.isCurrentUser ? Colors.green.shade700 : Colors.black87,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                Row(
                  children: [
                    Flexible(
                      child: Text(
                        '${user.points} points',
                        style: TextStyle(
                          color: Colors.grey.shade600,
                          fontSize: 12,
                        ),
                        overflow: TextOverflow.ellipsis,
                        maxLines: 1,
                      ),
                    ),
                    if (user.streak > 0) ...[
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: Colors.orange.shade100,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.local_fire_department,
                              size: 10,
                              color: Colors.orange.shade600,
                            ),
                            const SizedBox(width: 2),
                            Text(
                              '${user.streak}',
                              style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.w600,
                                color: Colors.orange.shade600,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ],
                ),
              ],
            ),
          ),
          if (!user.isCurrentUser)
            GestureDetector(
              onTap: () {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('Challenge ${user.name} - Coming soon!'),
                    duration: const Duration(seconds: 2),
                  ),
                );
              },
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: Colors.orange.shade500,
                  borderRadius: BorderRadius.circular(15),
                ),
                child: const Text(
                  'Challenge',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                  ),
                  overflow: TextOverflow.ellipsis,
                  maxLines: 1,
                ),
              ),
            ),
        ],
      ),
    );
  }

Widget _buildUserRankSection() {
    if (_userRankInfo == null) return const SizedBox.shrink();
    
    return Container(
      margin: EdgeInsets.fromLTRB(
        MediaQuery.of(context).size.width * 0.05, 
        10, 
        MediaQuery.of(context).size.width * 0.05, 
        10
      ),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.blue.shade50,
        borderRadius: BorderRadius.circular(15),
        border: Border.all(color: Colors.blue.shade200),
      ),
      child: Column(
        children: [
          Text(
            'Your Ranking',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: Colors.blue.shade700,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Rank #${_userRankInfo!.currentUserRank} of ${_userRankInfo!.totalUsers}',
            style: TextStyle(
              fontSize: 14,
              color: Colors.blue.shade600,
            ),
            overflow: TextOverflow.ellipsis,
            maxLines: 1,
            textAlign: TextAlign.center,
          ),
          Text(
            '${_userRankInfo!.currentUserScore} points',
            style: TextStyle(
              fontSize: 14,
              color: Colors.blue.shade600,
            ),
            overflow: TextOverflow.ellipsis,
            maxLines: 1,
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

Widget _buildConnectionBanner() {
    return Container(
      margin: EdgeInsets.fromLTRB(
        MediaQuery.of(context).size.width * 0.05, 
        5, 
        MediaQuery.of(context).size.width * 0.05, 
        5
      ),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: Colors.orange.shade100,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.orange.shade300),
      ),
      child: Row(
        children: [
          Icon(
            Icons.info_outline,
            color: Colors.orange.shade600,
            size: 20,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              _error!,
              style: TextStyle(
                color: Colors.orange.shade800,
                fontSize: 12,
              ),
            ),
          ),
          GestureDetector(
            onTap: _loadLeaderboardData,
            child: Icon(
              Icons.refresh,
              color: Colors.orange.shade600,
              size: 20,
            ),
          ),
        ],
      ),
    );
  }

Widget _buildMotivationalCard() {
    return Container(
      margin: EdgeInsets.fromLTRB(
        MediaQuery.of(context).size.width * 0.05, 
        10, 
        MediaQuery.of(context).size.width * 0.05, 
        10
      ),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.green.shade400,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.green.withValues(alpha: 0.3),
            spreadRadius: 1,
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 50,
            height: 50,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.2),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.favorite,
              color: Colors.white,
              size: 24,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Keep up the great work!',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                  overflow: TextOverflow.ellipsis,
                  maxLines: 1,
                ),
                const SizedBox(height: 4),
                Text(
                  'Every problem solved makes you stronger! 💪',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 13,
                  ),
                  overflow: TextOverflow.ellipsis,
                  maxLines: 2,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}