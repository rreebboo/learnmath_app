import 'package:flutter/material.dart';
import '../services/database_service.dart';
import '../services/firestore_service.dart';
import '../widgets/achievement_card.dart';
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

  @override
  void initState() {
    super.initState();
    _loadAchievements();
  }

  Future<void> _loadAchievements() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      // Load all available achievements
      final achievements = await _databaseService.getAchievements();
      
      // Load user's unlocked achievements and stats
      final currentUserId = _firestoreService.currentUserId;
      if (currentUserId != null) {
        final userData = await _firestoreService.getUserData(currentUserId);
        final userAchievements = List<String>.from(userData?['achievements'] ?? []);
        
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
      default:
        return Colors.grey;
    }
  }

  bool _isAchievementUnlocked(String achievementId) {
    return _userAchievements.contains(achievementId);
  }

  String _getProgressText(Map<String, dynamic> achievement) {
    if (_isAchievementUnlocked(achievement['id'])) {
      return 'Unlocked!';
    }

    if (_userStats == null) return 'Progress: 0%';

    final requirements = achievement['requirements'] as Map<String, dynamic>;
    
    // Calculate progress based on requirements
    for (final requirement in requirements.entries) {
      final requiredValue = requirement.value as num;
      final currentValue = (_userStats![requirement.key] as num?) ?? 0;
      final progress = (currentValue / requiredValue * 100).clamp(0, 100);
      
      return 'Progress: ${progress.toInt()}%';
    }
    
    return 'Progress: 0%';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Achievements',
          style: TextStyle(
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
        backgroundColor: const Color(0xFF6366F1),
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh, color: Colors.white),
            onPressed: _loadAchievements,
          ),
        ],
      ),
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Color(0xFF6366F1),
              Color(0xFF8B5CF6),
              Color(0xFFF3F4F6),
            ],
            stops: [0.0, 0.3, 1.0],
          ),
        ),
        child: Column(
          children: [
            // Stats Header
            Container(
              padding: const EdgeInsets.all(20),
              child: Column(
                children: [
                  Text(
                    'Your Progress',
                    style: const TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      _buildStatCard(
                        'Unlocked',
                        '${_userAchievements.length}',
                        Icons.emoji_events,
                        Colors.amber,
                      ),
                      _buildStatCard(
                        'Total',
                        '${_allAchievements.length}',
                        Icons.flag,
                        Colors.white,
                      ),
                      _buildStatCard(
                        'Points',
                        '${_userStats?['achievementPoints'] ?? 0}',
                        Icons.star,
                        Colors.yellow,
                      ),
                    ],
                  ),
                ],
              ),
            ),
            
            // Achievements List
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
                        : ListView.builder(
                            padding: const EdgeInsets.all(20),
                            itemCount: _allAchievements.length,
                            itemBuilder: (context, index) {
                              final achievement = _allAchievements[index];
                              final isUnlocked = _isAchievementUnlocked(achievement['id']);
                              
                              return Container(
                                margin: const EdgeInsets.only(bottom: 12),
                                child: _buildAchievementTile(achievement, isUnlocked),
                              );
                            },
                          ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatCard(String title, String value, IconData icon, Color iconColor) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.2),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white.withOpacity(0.3)),
      ),
      child: Column(
        children: [
          Icon(icon, color: iconColor, size: 24),
          const SizedBox(height: 4),
          Text(
            value,
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
          Text(
            title,
            style: const TextStyle(
              fontSize: 12,
              color: Colors.white70,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAchievementTile(Map<String, dynamic> achievement, bool isUnlocked) {
    final color = _getCategoryColor(achievement['category']);
    final icon = _getIconFromString(achievement['icon']);
    
    return Container(
      decoration: BoxDecoration(
        color: isUnlocked ? Colors.white : Colors.grey[50],
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isUnlocked ? color.withOpacity(0.3) : Colors.grey[300]!,
          width: 2,
        ),
        boxShadow: [
          BoxShadow(
            color: isUnlocked ? color.withOpacity(0.1) : Colors.grey.withOpacity(0.1),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.all(16),
        leading: Container(
          width: 56,
          height: 56,
          decoration: BoxDecoration(
            color: isUnlocked ? color : Colors.grey[400],
            shape: BoxShape.circle,
            boxShadow: [
              BoxShadow(
                color: (isUnlocked ? color : Colors.grey).withOpacity(0.3),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Icon(
            icon,
            color: Colors.white,
            size: 28,
          ),
        ),
        title: Text(
          achievement['title'],
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: isUnlocked ? const Color(0xFF2C3E50) : Colors.grey[600],
          ),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 4),
            Text(
              achievement['description'],
              style: TextStyle(
                fontSize: 14,
                color: isUnlocked ? Colors.grey[700] : Colors.grey[500],
              ),
            ),
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: isUnlocked ? color.withOpacity(0.1) : Colors.grey[200],
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                _getProgressText(achievement),
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: isUnlocked ? color : Colors.grey[600],
                ),
              ),
            ),
          ],
        ),
        trailing: isUnlocked
            ? Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: Colors.amber,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Text(
                  '+${achievement['points']}',
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 12,
                  ),
                ),
              )
            : Icon(
                Icons.lock_outline,
                color: Colors.grey[400],
              ),
      ),
    );
  }
}