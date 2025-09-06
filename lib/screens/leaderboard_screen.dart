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
            setState(() {
              _error = error.toString();
              _isLoading = false;
            });
          }
        },
      );

      // Load user rank info
      _loadUserRankInfo();
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = e.toString();
          _isLoading = false;
        });
      }
    }
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
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.black87),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: const Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('👑', style: TextStyle(fontSize: 20)),
            SizedBox(width: 8),
            Text(
              'Math Champions',
              style: TextStyle(
                color: Colors.black87,
                fontSize: 20,
                fontWeight: FontWeight.w600,
              ),
            ),
            SizedBox(width: 8),
            Text('👑', style: TextStyle(fontSize: 20)),
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
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          child: Column(
            children: [
              _buildHeaderSection(screenWidth),
              if (_isLoading)
                const Padding(
                  padding: EdgeInsets.all(50),
                  child: Center(
                    child: CircularProgressIndicator(),
                  ),
                )
              else if (_error != null)
                Padding(
                  padding: const EdgeInsets.all(20),
                  child: Center(
                    child: Column(
                      children: [
                        const Icon(
                          Icons.error_outline,
                          size: 48,
                          color: Colors.red,
                        ),
                        const SizedBox(height: 16),
                        Text(
                          'Failed to load leaderboard',
                          style: TextStyle(
                            fontSize: 16,
                            color: Colors.grey.shade700,
                          ),
                        ),
                        const SizedBox(height: 8),
                        ElevatedButton(
                          onPressed: _loadLeaderboardData,
                          child: const Text('Retry'),
                        ),
                      ],
                    ),
                  ),
                )
              else if (_leaderboardData.isEmpty)
                const Padding(
                  padding: EdgeInsets.all(50),
                  child: Center(
                    child: Text(
                      'No users found in leaderboard',
                      style: TextStyle(
                        fontSize: 16,
                        color: Colors.grey,
                      ),
                    ),
                  ),
                )
              else ...[
                _buildPodiumSection(screenWidth, screenHeight),
                _buildLeaderboardList(),
                if (_userRankInfo != null) _buildUserRankSection(),
                _buildMotivationalCard(),
              ],
              const SizedBox(height: 20),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeaderSection(double screenWidth) {
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.all(20),
      child: Column(
        children: [
          const Text(
            'Keep learning, keep growing!',
            style: TextStyle(
              color: Colors.grey,
              fontSize: 16,
            ),
          ),
          const SizedBox(height: 20),
          _buildToggleButtons(),
          const SizedBox(height: 16),
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
      child: Row(
        children: [
          _buildToggleButton('Weekly', selectedPeriod == 'weekly'),
          _buildToggleButton('Monthly', selectedPeriod == 'monthly'),
          _buildToggleButton('All-time', selectedPeriod == 'all-time'),
        ],
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
          padding: const EdgeInsets.symmetric(vertical: 12),
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
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildGradeButtons() {
    return Row(
      children: [
        Expanded(child: _buildGradeButton('Grade 1', selectedGrade == 'Grade 1')),
        const SizedBox(width: 12),
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
          children: [
            Icon(
              Icons.star,
              color: isSelected ? Colors.white : Colors.grey.shade600,
              size: 16,
            ),
            const SizedBox(width: 8),
            Text(
              text,
              style: TextStyle(
                color: isSelected ? Colors.white : Colors.grey.shade600,
                fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPodiumSection(double screenWidth, double screenHeight) {
    final top3 = _leaderboardData.take(3).toList();
    if (top3.length < 3) {
      return const SizedBox.shrink();
    }
    
    return Container(
      margin: const EdgeInsets.all(20),
      padding: const EdgeInsets.all(20),
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
          const SizedBox(height: 20),
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              if (top3.length > 1)
                _buildPodiumPosition(top3[1], 2, Colors.grey.shade300, false),
              if (top3.length > 1) const SizedBox(width: 12),
              _buildPodiumPosition(top3[0], 1, Colors.amber.shade200, true),
              if (top3.length > 2) const SizedBox(width: 12),
              if (top3.length > 2)
                _buildPodiumPosition(top3[2], 3, Colors.orange.shade200, false),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildPodiumPosition(LeaderboardUser user, int position, Color bgColor, bool isWinner) {
    String medal = position == 1 ? '👑' : (position == 2 ? '🥈' : '🥉');
    double height = isWinner ? 120 : 100;
    
    return Expanded(
      child: Container(
        height: height,
        decoration: BoxDecoration(
          color: bgColor,
          borderRadius: BorderRadius.circular(15),
          border: user.isCurrentUser 
              ? Border.all(color: Colors.green, width: 2)
              : null,
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(medal, style: const TextStyle(fontSize: 24)),
            const SizedBox(height: 8),
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
            const SizedBox(height: 8),
            Text(
              user.isCurrentUser ? 'You!' : user.name,
              style: TextStyle(
                fontWeight: FontWeight.w600,
                fontSize: 14,
                color: user.isCurrentUser ? Colors.green.shade700 : Colors.black87,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            Text(
              '${user.points} pts',
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
      margin: const EdgeInsets.symmetric(horizontal: 20),
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
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
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
                    Text(
                      '${user.points} points',
                      style: TextStyle(
                        color: Colors.grey.shade600,
                        fontSize: 12,
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
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                decoration: BoxDecoration(
                  color: Colors.orange.shade500,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: const Text(
                  'Challenge',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
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
      margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
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
          ),
          Text(
            '${_userRankInfo!.currentUserScore} points',
            style: TextStyle(
              fontSize: 14,
              color: Colors.blue.shade600,
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
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Keep up the great work!',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                SizedBox(height: 4),
                Text(
                  'Every problem solved makes you stronger! 💪',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 14,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}