import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../services/database_service.dart';
import '../services/firestore_service.dart';
import '../widgets/user_avatar.dart';
import 'dart:async';

class AchievementsScreen extends StatefulWidget {
  const AchievementsScreen({super.key});

  @override
  State<AchievementsScreen> createState() => _AchievementsScreenState();
}

class _AchievementsScreenState extends State<AchievementsScreen> {
  final DatabaseService _databaseService = DatabaseService();
  final FirestoreService _firestoreService = FirestoreService();

  List<Map<String, dynamic>> _allAchievements = [];
  List<String> _userAchievements = [];
  Map<String, dynamic>? _userStats;
  bool _isLoading = true;
  String? _error;

  // Real-time stream subscriptions
  StreamSubscription<DocumentSnapshot>? _userDataSubscription;

  @override
  void initState() {
    super.initState();
    _loadAchievements();
    _setupRealTimeUpdates();
  }

  @override
  void dispose() {
    _userDataSubscription?.cancel();
    super.dispose();
  }

  void _setupRealTimeUpdates() {
    final currentUserId = _firestoreService.currentUserId;
    if (currentUserId != null) {
      _userDataSubscription = _firestoreService.getUserDataStream(currentUserId).listen(
        (userDataDoc) {
          if (userDataDoc.exists && mounted) {
            final userData = userDataDoc.data() as Map<String, dynamic>?;
            final achievementsData = userData?['achievements'] as List<dynamic>? ?? [];
            final newUserAchievements = achievementsData
                .map((achievement) => achievement is String ? achievement : achievement['id'] as String)
                .toList();

            setState(() {
              _userStats = userData;
              _userAchievements = newUserAchievements;
            });
          }
        },
        onError: (error) {
          if (mounted) {
            setState(() {
              _error = 'Error loading real-time updates: $error';
            });
          }
        },
      );
    }
  }


  Future<void> _loadAchievements() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      // Load all available achievements
      final achievements = await _databaseService.getAchievements();

      // Initial load of user data (real-time updates will be handled by stream)
      final currentUserId = _firestoreService.currentUserId;
      if (currentUserId != null) {
        final userData = await _firestoreService.getUserData(currentUserId);
        final achievementsData = userData?['achievements'] as List<dynamic>? ?? [];
        final userAchievements = achievementsData
            .map((achievement) => achievement is String ? achievement : achievement['id'] as String)
            .toList();

        setState(() {
          _allAchievements = achievements;
          _userAchievements = userAchievements;
          _userStats = userData;
          _isLoading = false;
        });
      } else {
        setState(() {
          _allAchievements = achievements;
          _isLoading = false;
        });
      }
    } catch (e) {
      setState(() {
        _error = 'Failed to load achievements: $e';
        _isLoading = false;
      });
    }
  }

  IconData _getIconFromString(String iconString) {
    // Convert emoji/string to IconData
    switch (iconString) {
      case '🎯':
        return Icons.track_changes;
      case '🔥':
        return Icons.local_fire_department;
      case '👑':
        return Icons.emoji_events;
      case '⭐':
        return Icons.star;
      default:
        return Icons.emoji_events;
    }
  }

  Color _getCategoryColor(String category) {
    switch (category.toLowerCase()) {
      case 'beginner':
        return Colors.green;
      case 'consistency':
        return Colors.orange;
      case 'achievement':
        return Colors.purple;
      case 'accuracy':
        return Colors.blue;
      case 'learning streaks':
        return Colors.green;
      case 'subject heroes':
        return Colors.blue;
      case 'special awards':
        return Colors.red;
      case 'social butterfly':
        return Colors.pink;
      case 'speed demon':
        return Colors.deepOrange;
      default:
        return Colors.grey;
    }
  }

  IconData _getCategoryIcon(String category) {
    switch (category.toLowerCase()) {
      case 'learning streaks':
        return Icons.local_fire_department;
      case 'subject heroes':
        return Icons.school;
      case 'special awards':
        return Icons.emoji_events;
      case 'social butterfly':
        return Icons.share;
      case 'speed demon':
        return Icons.speed;
      default:
        return Icons.star;
    }
  }

  bool _isAchievementUnlocked(String achievementId) {
    return _userAchievements.contains(achievementId);
  }

  String _getProgressText(Map<String, dynamic> achievement) {
    if (_isAchievementUnlocked(achievement['id'])) {
      return 'Unlocked!';
    }

    if (_userStats == null) return 'Locked';

    final requirements = achievement['requirements'] as Map<String, dynamic>;
    
    // Calculate progress based on requirements
    for (final requirement in requirements.entries) {
      final requiredValue = requirement.value as num;
      final currentValue = (_userStats![requirement.key] as num?) ?? 0;
      
      if (currentValue >= requiredValue) {
        return 'Unlocked!';
      }
      
      return '$currentValue/$requiredValue';
    }
    
    return 'Locked';
  }

  Map<String, List<Map<String, dynamic>>> _groupAchievementsByCategory() {
    Map<String, List<Map<String, dynamic>>> grouped = {};
    
    for (var achievement in _allAchievements) {
      String category = achievement['category'] ?? 'Other';
      if (!grouped.containsKey(category)) {
        grouped[category] = [];
      }
      grouped[category]!.add(achievement);
    }
    
    return grouped;
  }

  int _calculateTotalXP() {
    // Use user's totalScore from Firestore as the primary XP source
    int baseXP = (_userStats?['totalScore'] as int?) ?? 0;

    // Add bonus XP from achievements
    int achievementXP = 0;
    for (var achievementId in _userAchievements) {
      var achievement = _allAchievements.firstWhere(
        (a) => a['id'] == achievementId,
        orElse: () => {'points': 0},
      );
      achievementXP += (achievement['points'] as int?) ?? 0;
    }

    return baseXP + achievementXP;
  }

  @override
  Widget build(BuildContext context) {
    final groupedAchievements = _groupAchievementsByCategory();
    final totalXP = _calculateTotalXP();

    return Scaffold(
      backgroundColor: const Color(0xFFF3F4F6),
      body: SafeArea(
        child: Column(
          children: [
            // Header with gradient background
            Container(
              width: double.infinity,
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  colors: [Color(0xFF6366F1), Color(0xFF8B5CF6)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
              ),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      IconButton(
                        icon: const Icon(Icons.arrow_back, color: Colors.white),
                        onPressed: () => Navigator.pop(context),
                      ),
                      const Text(
                        'Achievements',
                        style: TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.share, color: Colors.white),
                        onPressed: () {
                          // Share functionality
                        },
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  // Enhanced Trophy Logo
                  Container(
                    width: 80,
                    height: 80,
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [Color(0xFFFFD700), Color(0xFFFFA500)],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(30),
                      boxShadow: [
                        BoxShadow(
                          color: const Color(0xFFFFD700).withValues(alpha: 0.4),
                          blurRadius: 20,
                          offset: const Offset(0, 8),
                          spreadRadius: 2,
                        ),
                        BoxShadow(
                          color: Colors.white.withValues(alpha: 0.1),
                          blurRadius: 10,
                          offset: const Offset(0, -4),
                          spreadRadius: 1,
                        ),
                      ],
                    ),
                    child: Stack(
                      children: [
                        // Main trophy icon
                        const Center(
                          child: Icon(
                            Icons.emoji_events,
                            color: Colors.white,
                            size: 40,
                          ),
                        ),
                        // Sparkle effects
                        Positioned(
                          top: 15,
                          right: 20,
                          child: Container(
                            width: 12,
                            height: 12,
                            decoration: const BoxDecoration(
                              color: Colors.white,
                              shape: BoxShape.circle,
                            ),
                          ),
                        ),
                        Positioned(
                          bottom: 20,
                          left: 15,
                          child: Container(
                            width: 8,
                            height: 8,
                            decoration: BoxDecoration(
                              color: Colors.white.withValues(alpha: 0.8),
                              shape: BoxShape.circle,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  // Level and XP Display
                  _buildLevelCard(totalXP),
                ],
              ),
            ),
            
            // Ultra Compact Stats Row
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 6),
              child: Row(
                children: [
                  Expanded(
                    child: _buildMiniStatCard(
                      'Won',
                      '${_userAchievements.length}',
                      const Color(0xFFFFD700),
                    ),
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    child: _buildMiniStatCard(
                      'All',
                      '${_allAchievements.length}',
                      const Color(0xFF6366F1),
                    ),
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    child: _buildMiniStatCard(
                      'Done',
                      '${_allAchievements.isEmpty ? 0 : ((_userAchievements.length / _allAchievements.length) * 100).round()}%',
                      const Color(0xFF10B981),
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 8),

            // Achievements Content
            Expanded(
              child: Container(
                decoration: const BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.only(
                    topLeft: Radius.circular(30),
                    topRight: Radius.circular(30),
                  ),
                ),
                child: _isLoading
                    ? const Center(child: CircularProgressIndicator())
                    : _error != null
                        ? Center(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(
                                  Icons.error_outline,
                                  size: 64,
                                  color: Colors.grey[400],
                                ),
                                const SizedBox(height: 16),
                                Text(
                                  _error!,
                                  style: TextStyle(
                                    color: Colors.grey[600],
                                    fontSize: 16,
                                  ),
                                  textAlign: TextAlign.center,
                                ),
                                const SizedBox(height: 16),
                                ElevatedButton(
                                  onPressed: _loadAchievements,
                                  child: const Text('Retry'),
                                ),
                              ],
                            ),
                          )
                        : Column(
                            children: [
                              Container(
                                width: double.infinity,
                                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                                child: Column(
                                  children: [
                                    Row(
                                      mainAxisAlignment: MainAxisAlignment.center,
                                      children: [
                                        Container(
                                          padding: const EdgeInsets.all(8),
                                          decoration: BoxDecoration(
                                            gradient: const LinearGradient(
                                              colors: [Color(0xFF6366F1), Color(0xFF8B5CF6)],
                                              begin: Alignment.topLeft,
                                              end: Alignment.bottomRight,
                                            ),
                                            shape: BoxShape.circle,
                                            boxShadow: [
                                              BoxShadow(
                                                color: const Color(0xFF6366F1).withValues(alpha: 0.3),
                                                blurRadius: 8,
                                                offset: const Offset(0, 2),
                                              ),
                                            ],
                                          ),
                                          child: const Icon(
                                            Icons.emoji_events,
                                            color: Colors.white,
                                            size: 20,
                                          ),
                                        ),
                                        const SizedBox(width: 12),
                                        const Text(
                                          'My Achievement Collection',
                                          style: TextStyle(
                                            fontSize: 20,
                                            fontWeight: FontWeight.bold,
                                            color: Color(0xFF2C3E50),
                                          ),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 8),
                                    Text(
                                      'Tap any badge to learn how to unlock it',
                                      style: TextStyle(
                                        fontSize: 14,
                                        color: Colors.grey[600],
                                        fontWeight: FontWeight.w500,
                                      ),
                                      textAlign: TextAlign.center,
                                    ),
                                  ],
                                ),
                              ),
                              Expanded(
                                child: ListView(
                                  padding: const EdgeInsets.symmetric(horizontal: 20),
                                  children: [
                                    ...groupedAchievements.entries.map((entry) => _buildCategorySection(
                                        entry.key,
                                        entry.value,
                                      )),
                                    const SizedBox(height: 90), // Space for bottom buttons
                                  ],
                                ),
                              ),
                            ],
                          ),
              ),
            ),
          ],
        ),
      ),
      // Bottom Action Buttons
      bottomSheet: Container(
        padding: const EdgeInsets.all(20),
        decoration: const BoxDecoration(
          color: Colors.white,
          boxShadow: [
            BoxShadow(
              color: Colors.black12,
              blurRadius: 10,
              offset: Offset(0, -2),
            ),
          ],
        ),
        child: SafeArea(
          child: Row(
            children: [
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: () {
                    Navigator.pop(context);
                    // Navigate to learning screen or main screen
                  },
                  icon: const Icon(Icons.play_arrow, color: Colors.white),
                  label: const Text(
                    'Continue Learning',
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF10B981),
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    elevation: 3,
                    shadowColor: const Color(0xFF10B981).withValues(alpha: 0.3),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: () {
                    // Share progress functionality
                    // You can implement sharing logic here
                  },
                  icon: const Icon(Icons.share, color: Colors.white),
                  label: const Text(
                    'Share My Progress',
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF6366F1),
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    elevation: 3,
                    shadowColor: const Color(0xFF6366F1).withValues(alpha: 0.3),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildLevelCard(int totalXP) {
    final currentLevel = (totalXP / 1000).floor() + 1;
    final xpInCurrentLevel = totalXP % 1000;
    final xpForNextLevel = 1000;
    final levelProgress = xpInCurrentLevel / xpForNextLevel;
    
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.08),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        children: [
          // Level and XP Row
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  // User Avatar
                  UserAvatar(
                    avatar: _userStats?['avatar'] ?? '🦊',
                    size: 40,
                    backgroundColor: Colors.white,
                    gradientColors: const [Color(0xFF6366F1), Color(0xFF8B5CF6)],
                    showBorder: false,
                  ),
                  const SizedBox(width: 12),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Level $currentLevel',
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF2C3E50),
                        ),
                      ),
                      Text(
                        'Math Explorer',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey[600],
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFFFFD700), Color(0xFFFFA500)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(
                      Icons.star,
                      size: 14,
                      color: Colors.white,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      '$totalXP XP',
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          // Progress Bar
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    '$xpInCurrentLevel / $xpForNextLevel XP to next level',
                    style: TextStyle(
                      fontSize: 11,
                      color: Colors.grey[600],
                    ),
                  ),
                  Text(
                    '${(levelProgress * 100).round()}%',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: Colors.grey[600],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              ClipRRect(
                borderRadius: BorderRadius.circular(6),
                child: LinearProgressIndicator(
                  value: levelProgress,
                  minHeight: 5,
                  backgroundColor: Colors.grey[200],
                  valueColor: const AlwaysStoppedAnimation<Color>(
                    Color(0xFF10B981),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildMiniStatCard(String title, String value, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 6),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 4,
            offset: const Offset(0, 1),
          ),
        ],
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            value,
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            title,
            style: const TextStyle(
              fontSize: 10,
              color: Colors.grey,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCategorySection(String category, List<Map<String, dynamic>> achievements) {
    final categoryIcon = _getCategoryIcon(category);
    final categoryColor = _getCategoryColor(category);
    
    return Container(
      margin: const EdgeInsets.only(bottom: 20),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: categoryColor.withValues(alpha: 0.3),
          width: 2,
        ),
        boxShadow: [
          BoxShadow(
            color: categoryColor.withValues(alpha: 0.1),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
            decoration: BoxDecoration(
              color: categoryColor.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(15),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: categoryColor.withValues(alpha: 0.2),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(categoryIcon, color: categoryColor, size: 24),
                ),
                const SizedBox(width: 12),
                Text(
                  category.toUpperCase(),
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: categoryColor,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 10),
          SizedBox(
            height: 130,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              itemCount: achievements.length,
              itemBuilder: (context, index) {
                final achievement = achievements[index];
                final isUnlocked = _isAchievementUnlocked(achievement['id']);
                
                return _buildBadgeCard(achievement, isUnlocked);
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBadgeCard(Map<String, dynamic> achievement, bool isUnlocked) {
    final color = _getCategoryColor(achievement['category']);
    final icon = _getIconFromString(achievement['icon']);
    
    return GestureDetector(
      onTap: () => _showAchievementDetail(achievement, isUnlocked),
      child: Container(
        width: 80,
        margin: const EdgeInsets.only(right: 10),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Badge with enhanced visual hints for Grade 1-2 users
            Container(
              width: 78,
              height: 78,
              decoration: BoxDecoration(
                color: isUnlocked ? color : Colors.grey[300],
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: isUnlocked ? color.withValues(alpha: 0.7) : const Color(0xFF6366F1).withValues(alpha: 0.5),
                  width: isUnlocked ? 3 : 4,
                ),
                boxShadow: [
                  BoxShadow(
                    color: isUnlocked 
                        ? color.withValues(alpha: 0.4) 
                        : const Color(0xFF6366F1).withValues(alpha: 0.2),
                    blurRadius: isUnlocked ? 15 : 12,
                    offset: const Offset(0, 4),
                  ),
                  // Pulsing effect hint for locked badges
                  if (!isUnlocked)
                    BoxShadow(
                      color: const Color(0xFF6366F1).withValues(alpha: 0.3),
                      blurRadius: 20,
                      offset: const Offset(0, 0),
                      spreadRadius: 2,
                    ),
                ],
              ),
              child: Stack(
                children: [
                  // Main badge content
                  Center(
                    child: isUnlocked
                        ? Icon(
                            icon,
                            color: Colors.white,
                            size: 36,
                          )
                        : Icon(
                            Icons.lock_outline,
                            color: Colors.grey[600],
                            size: 32,
                          ),
                  ),
                  // Tap hint for ALL badges (both locked and unlocked)
                  Positioned(
                    top: 2,
                    right: 2,
                    child: Container(
                      width: 18,
                      height: 18,
                      decoration: BoxDecoration(
                        color: isUnlocked ? const Color(0xFFFFD700) : const Color(0xFF6366F1),
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: (isUnlocked ? const Color(0xFFFFD700) : const Color(0xFF6366F1)).withValues(alpha: 0.4),
                            blurRadius: 6,
                            offset: const Offset(0, 1),
                          ),
                        ],
                      ),
                      child: Icon(
                        isUnlocked ? Icons.info : Icons.touch_app,
                        color: Colors.white,
                        size: 12,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 8),
            Flexible(
              child: Text(
                achievement['title'],
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w600,
                  color: isUnlocked ? const Color(0xFF2C3E50) : Colors.grey[600],
                ),
                textAlign: TextAlign.center,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            const SizedBox(height: 4),
            if (isUnlocked)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: const Color(0xFFFFD700),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  '+${achievement['points']}',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 8,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              )
            else
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                decoration: BoxDecoration(
                  color: Colors.grey[200],
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  'Tap!',
                  style: TextStyle(
                    fontSize: 8,
                    color: Colors.grey[600],
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  void _showAchievementDetail(Map<String, dynamic> achievement, bool isUnlocked) {
    final color = _getCategoryColor(achievement['category']);
    final icon = _getIconFromString(achievement['icon']);
    
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return Dialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          child: Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(20),
              gradient: LinearGradient(
                colors: [
                  Colors.white,
                  color.withValues(alpha: 0.05),
                ],
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
              ),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Badge Icon
                Container(
                  width: 100,
                  height: 100,
                  decoration: BoxDecoration(
                    color: isUnlocked ? color : Colors.grey[300],
                    borderRadius: BorderRadius.circular(25),
                    border: Border.all(
                      color: isUnlocked ? color.withValues(alpha: 0.5) : Colors.grey[400]!,
                      width: 3,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: (isUnlocked ? color : Colors.grey).withValues(alpha: 0.3),
                        blurRadius: 15,
                        offset: const Offset(0, 5),
                      ),
                    ],
                  ),
                  child: Center(
                    child: isUnlocked
                        ? Icon(
                            icon,
                            color: Colors.white,
                            size: 48,
                          )
                        : Icon(
                            Icons.lock_outline,
                            color: Colors.grey[600],
                            size: 44,
                          ),
                  ),
                ),
                const SizedBox(height: 20),
                // Title and Status
                Text(
                  achievement['title'],
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF2C3E50),
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: isUnlocked ? Colors.green.withValues(alpha: 0.1) : Colors.orange.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: isUnlocked ? Colors.green.withValues(alpha: 0.3) : Colors.orange.withValues(alpha: 0.3),
                    ),
                  ),
                  child: Text(
                    isUnlocked ? 'UNLOCKED!' : 'LOCKED',
                    style: TextStyle(
                      color: isUnlocked ? Colors.green : Colors.orange,
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                // Description
                Text(
                  achievement['description'],
                  style: const TextStyle(
                    fontSize: 14,
                    color: Colors.grey,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 20),
                // Requirements
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.grey[50],
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.grey[200]!),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(
                            Icons.assignment,
                            size: 16,
                            color: color,
                          ),
                          const SizedBox(width: 8),
                          const Text(
                            'How to unlock:',
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                              color: Color(0xFF2C3E50),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Text(
                        _getRequirementDescription(achievement),
                        style: const TextStyle(
                          fontSize: 13,
                          color: Colors.grey,
                        ),
                      ),
                      if (!isUnlocked) ...
                      [
                        const SizedBox(height: 12),
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: Colors.blue.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'Your Progress:',
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                  color: Color(0xFF2C3E50),
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                _getProgressText(achievement),
                                style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.blue[700],
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                if (isUnlocked) ...
                [
                  const SizedBox(height: 16),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    decoration: BoxDecoration(
                      color: Colors.amber,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(
                          Icons.star,
                          color: Colors.white,
                          size: 16,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          '+${achievement['points']} XP Earned',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
                const SizedBox(height: 20),
                // Close Button
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: () => Navigator.pop(context),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: color,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: const Text(
                      'Got it!',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  String _getRequirementDescription(Map<String, dynamic> achievement) {
    final requirements = achievement['requirements'] as Map<String, dynamic>;
    
    if (requirements.isEmpty) {
      return 'Complete specific tasks to unlock this achievement.';
    }
    
    List<String> descriptions = [];
    
    requirements.forEach((key, value) {
      switch (key) {
        case 'totalSessions':
          descriptions.add('Complete $value practice sessions');
          break;
        case 'totalQuestions':
          descriptions.add('Answer $value questions correctly');
          break;
        case 'currentStreak':
          descriptions.add('Maintain a $value-day learning streak');
          break;
        case 'lessonsCompleted':
          descriptions.add('Complete $value lessons');
          break;
        case 'totalScore':
          descriptions.add('Earn a total score of $value points');
          break;
        case 'accuracyRate':
          descriptions.add('Achieve ${(value * 100).toInt()}% accuracy rate');
          break;
        default:
          descriptions.add('Meet the requirement: $key = $value');
      }
    });
    
    if (descriptions.length == 1) {
      return descriptions.first;
    } else {
      return descriptions.join(' and ');
    }
  }
}