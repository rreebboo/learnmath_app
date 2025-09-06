import 'package:flutter/material.dart';
import 'practice_screen.dart';
import 'adaptive_quiz_screen.dart';
import 'leaderboard_screen.dart';
import '../services/firestore_service.dart';
import '../services/user_preferences_service.dart';

class HomeContent extends StatefulWidget {
  final Function(int) onTabChange;
  
  const HomeContent({super.key, required this.onTabChange});

  @override
  State<HomeContent> createState() => _HomeContentState();
}

class _HomeContentState extends State<HomeContent> {
  final FirestoreService _firestoreService = FirestoreService();
  final UserPreferencesService _prefsService = UserPreferencesService.instance;
  Map<String, dynamic>? _userData;
  bool _isLoading = true;
  int _selectedLevel = 0; // 0: Easy, 1: Moderate, 2: Advanced

  @override
  void initState() {
    super.initState();
    _loadUserData();
    _loadSelectedDifficulty();
  }

  Future<void> _loadUserData() async {
    try {
      final userData = await _firestoreService.getCurrentUserData();
      if (mounted) {
        setState(() {
          _userData = userData;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _loadSelectedDifficulty() async {
    final difficulty = await _prefsService.getSelectedDifficulty();
    if (mounted) {
      setState(() {
        _selectedLevel = difficulty;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Center(
        child: CircularProgressIndicator(
          valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF5B9EF3)),
        ),
      );
    }

    return Container(
      color: const Color(0xFFF5F7FA),
      child: SafeArea(
        child: SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        Container(
                          width: 40,
                          height: 40,
                          decoration: const BoxDecoration(
                            shape: BoxShape.circle,
                            gradient: LinearGradient(
                              colors: [Color(0xFF7ED321), Color(0xFF9ACD32)],
                            ),
                          ),
                          child: Center(
                            child: Text(
                              _userData?['avatar'] ?? '🦊',
                              style: const TextStyle(fontSize: 20),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Text(
                                  'Hi ${_userData?['name'] ?? 'Emma'}! ',
                                  style: const TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w600,
                                    color: Color(0xFF2C3E50),
                                  ),
                                ),
                                const Text(
                                  '👋',
                                  style: TextStyle(fontSize: 16),
                                ),
                              ],
                            ),
                            Row(
                              children: [
                                const Icon(
                                  Icons.star,
                                  size: 14,
                                  color: Colors.amber,
                                ),
                                const SizedBox(width: 4),
                                Text(
                                  '${_userData?['stars'] ?? 248} XP',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: Colors.grey[600],
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ],
                    ),
                    Row(
                      children: [
                        GestureDetector(
                          onTap: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) => const LeaderboardScreen(),
                              ),
                            );
                          },
                          child: Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: Colors.amber.shade100,
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Icon(
                              Icons.emoji_events,
                              color: Colors.amber.shade600,
                              size: 20,
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                          decoration: BoxDecoration(
                            color: const Color(0xFFFFE4B5),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Row(
                            children: [
                              const Icon(
                                Icons.local_fire_department,
                                size: 16,
                                color: Colors.orange,
                              ),
                              const SizedBox(width: 4),
                              Text(
                                '${_userData?['streak'] ?? 7} Day Streak!',
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                  color: Colors.orange[700],
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: 25),
                
                // Motivational Card
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Color(0xFFE8B4FF), Color(0xFFC490FF)],
                    ),
                    borderRadius: BorderRadius.circular(15),
                  ),
                  child: const Row(
                    children: [
                      Icon(
                        Icons.lightbulb_outline,
                        color: Colors.white,
                        size: 24,
                      ),
                      SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              "You're doing amazing!",
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            Text(
                              "Ready for today's math adventure?",
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 13,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 25),
                
                // Choose Your Level
                const Text(
                  'Choose Your Level',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF2C3E50),
                  ),
                ),
                const SizedBox(height: 15),
                
                // Level Cards
                _buildLevelCard(
                  0,
                  'EASY',
                  '1-digit numbers',
                  const Color(0xFF4CAF50), // Easy level - consistent green
                  Icons.star,
                  1,
                ),
                const SizedBox(height: 12),
                _buildLevelCard(
                  1,
                  'MODERATE',
                  '2-3 digit numbers',
                  const Color(0xFFFF9800), // Moderate level - consistent orange
                  Icons.star,
                  2,
                ),
                const SizedBox(height: 12),
                _buildLevelCard(
                  2,
                  'ADVANCED',
                  '4+ digit numbers',
                  const Color(0xFFE53935), // Advanced level - consistent red
                  Icons.star,
                  3,
                ),
                
                const SizedBox(height: 25),
                
                // Quick Actions
                const Text(
                  'Quick Actions',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF2C3E50),
                  ),
                ),
                const SizedBox(height: 15),
                
                _buildQuickActionCard(
                  Icons.person,
                  'Solo Practice',
                  'Practice at your own pace',
                  const Color(0xFF2196F3), // Consistent blue
                  () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => const SoloPracticeScreen(),
                      ),
                    );
                  },
                ),
                const SizedBox(height: 12),
                _buildQuickActionCard(
                  Icons.psychology,
                  'Adaptive Quiz 🧠',
                  'AI-powered questions that adapt to your skill',
                  const Color(0xFF9C27B0), // Consistent purple
                  () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => const AdaptiveQuizScreen(),
                      ),
                    );
                  },
                ),
                const SizedBox(height: 12),
                _buildQuickActionCard(
                  Icons.sports_martial_arts,
                  'Math Battle Arena 🔢',
                  'Duel with friends in math battles!',
                  const Color(0xFFFF9800), // Consistent orange
                  () {
                    // Set bottom nav to Quiz tab
                    widget.onTabChange(2);
                  },
                ),
                const SizedBox(height: 12),
_buildQuickActionCard(
                  Icons.trending_up,
                  'My Progress',
                  'See how you\'re doing',
                  const Color(0xFF00ACC1), // Consistent cyan
                  () {
                    // Set bottom nav to Progress tab
                    widget.onTabChange(3);
                  },
                ),
                const SizedBox(height: 12),
                _buildQuickActionCard(
                  Icons.emoji_events,
                  'Leaderboards 🏆',
                  'See how you rank against others!',
                  const Color(0xFFFFB74D), // Consistent amber
                  () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => const LeaderboardScreen(),
                      ),
                    );
                  },
                ),
                
                const SizedBox(height: 25),
                
                // Recent Badges
                const Text(
                  'Recent Badges',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF2C3E50),
                  ),
                ),
                const SizedBox(height: 15),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: [
                    _buildBadge('🥇', 'First Win'),
                    _buildBadge('🎯', 'Smart Kid'),
                    _buildBadge('⚡', 'Speed Star'),
                  ],
                ),
                const SizedBox(height: 20),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildLevelCard(int index, String level, String description, Color color, IconData icon, int stars) {
    bool isSelected = _selectedLevel == index;
    
    // Create brighter color for hover/pressed states
    Color brighterColor = Color.lerp(color, Colors.white, 0.15) ?? color;
    Color darkerColor = Color.lerp(color, Colors.black, 0.1) ?? color;
    
    return AnimatedContainer(
      duration: const Duration(milliseconds: 250),
      curve: Curves.easeInOut,
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(16),
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          splashColor: brighterColor.withValues(alpha: 0.3),
          highlightColor: brighterColor.withValues(alpha: 0.1),
          onTap: () async {
            // Haptic feedback
            // HapticFeedback.lightImpact(); // Uncomment if you want haptic feedback
            
            setState(() {
              _selectedLevel = index;
            });
            
            // Save selected difficulty
            await _prefsService.setSelectedDifficulty(index);
            
            // Navigate to practice with selected level
            if (mounted) {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => SoloPracticeScreen(difficulty: index),
                ),
              );
            }
          },
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              // Use full brightness for the colors now
              color: isSelected ? brighterColor : color,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: isSelected ? brighterColor : darkerColor,
                width: isSelected ? 2.5 : 2,
              ),
              boxShadow: [
                BoxShadow(
                  color: color.withValues(alpha: isSelected ? 0.35 : 0.25),
                  blurRadius: isSelected ? 15 : 8,
                  offset: Offset(0, isSelected ? 8 : 4),
                  spreadRadius: isSelected ? 1 : 0,
                ),
                // Add a subtle inner glow effect when selected
                if (isSelected)
                  BoxShadow(
                    color: Colors.white.withValues(alpha: 0.2),
                    blurRadius: 6,
                    offset: const Offset(0, -2),
                    spreadRadius: -2,
                  ),
              ],
              // Add a subtle gradient overlay for more depth
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  (isSelected ? brighterColor : color).withValues(alpha: 1.0),
                  (isSelected ? brighterColor : color).withValues(alpha: 0.9),
                ],
              ),
            ),
            child: Row(
              children: [
                AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  width: 45,
                  height: 45,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: isSelected ? 0.15 : 0.1),
                        blurRadius: isSelected ? 6 : 4,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Center(
                    child: AnimatedDefaultTextStyle(
                      duration: const Duration(milliseconds: 200),
                      style: TextStyle(
                        color: isSelected ? brighterColor : darkerColor,
                        fontWeight: FontWeight.bold,
                        fontSize: index == 0 ? 19 : index == 1 ? 15 : 13,
                      ),
                      child: Text(index == 0 ? '1' : index == 1 ? '23' : '123+'),
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      AnimatedDefaultTextStyle(
                        duration: const Duration(milliseconds: 200),
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: isSelected ? 15 : 14,
                          fontWeight: FontWeight.bold,
                          shadows: [
                            Shadow(
                              color: Colors.black.withValues(alpha: 0.3),
                              offset: const Offset(1, 1),
                              blurRadius: 3,
                            ),
                          ],
                        ),
                        child: Text(level),
                      ),
                      const SizedBox(height: 2),
                      AnimatedDefaultTextStyle(
                        duration: const Duration(milliseconds: 200),
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.95),
                          fontSize: isSelected ? 13 : 12,
                          shadows: [
                            Shadow(
                              color: Colors.black.withValues(alpha: 0.25),
                              offset: const Offset(1, 1),
                              blurRadius: 2,
                            ),
                          ],
                        ),
                        child: Text(description),
                      ),
                      const SizedBox(height: 6),
                      Row(
                        children: List.generate(
                          3,
                          (i) => AnimatedContainer(
                            duration: Duration(milliseconds: 150 + (i * 50)),
                            child: Icon(
                              Icons.star,
                              size: isSelected ? 15 : 14,
                              color: i < stars
                                  ? (isSelected ? Colors.yellow.shade300 : Colors.yellow)
                                  : Colors.white.withValues(alpha: 0.4),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  child: Icon(
                    Icons.play_circle_fill,
                    color: Colors.white,
                    size: isSelected ? 30 : 28,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildQuickActionCard(IconData icon, String title, String subtitle, Color color, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(15),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.05),
              blurRadius: 10,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(
                icon,
                color: color,
                size: 20,
              ),
            ),
            const SizedBox(width: 15),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF2C3E50),
                    ),
                  ),
                  Text(
                    subtitle,
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey[600],
                    ),
                  ),
                ],
              ),
            ),
            Icon(
              Icons.arrow_forward_ios,
              color: Colors.grey[400],
              size: 16,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBadge(String emoji, String label) {
    return Column(
      children: [
        Container(
          width: 60,
          height: 60,
          decoration: BoxDecoration(
            color: Colors.white,
            shape: BoxShape.circle,
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.05),
                blurRadius: 10,
                offset: const Offset(0, 3),
              ),
            ],
          ),
          child: Center(
            child: Text(
              emoji,
              style: const TextStyle(fontSize: 28),
            ),
          ),
        ),
        const SizedBox(height: 8),
        Text(
          label,
          style: TextStyle(
            fontSize: 11,
            color: Colors.grey[600],
          ),
        ),
      ],
    );
  }
}