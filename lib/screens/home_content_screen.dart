import 'package:flutter/material.dart';
import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'practice_screen.dart';
import 'adaptive_quiz_screen.dart';
import 'leaderboard_screen.dart';
import '../services/firestore_service.dart';
import '../services/user_preferences_service.dart';
import '../widgets/user_avatar.dart';

class HomeContent extends StatefulWidget {
  final Function(int) onTabChange;
  
  const HomeContent({super.key, required this.onTabChange});

  @override
  State<HomeContent> createState() => _HomeContentState();
}

class _HomeContentState extends State<HomeContent> with TickerProviderStateMixin {
  final FirestoreService _firestoreService = FirestoreService();
  final UserPreferencesService _prefsService = UserPreferencesService.instance;
  Map<String, dynamic>? _userData;
  bool _isLoading = true;
  int _selectedLevel = 0; // 0: Easy, 1: Moderate, 2: Advanced
  StreamSubscription<DocumentSnapshot>? _userDataSubscription;
  
  // Optimized animation controllers for level buttons
  late AnimationController _animationController1;
  late AnimationController _animationController2;
  late AnimationController _animationController3;
  late Animation<double> _animation1;
  late Animation<double> _animation2;
  late Animation<double> _animation3;

  @override
  void initState() {
    super.initState();
    _initializeAnimations();
    _setupRealtimeUserData();
    _loadSelectedDifficulty();
  }

  void _initializeAnimations() {
    // Balanced animation controllers - visible but smooth
    _animationController1 = AnimationController(
      duration: const Duration(milliseconds: 3500), // Balanced speed for visibility
      vsync: this,
    );
    _animationController2 = AnimationController(
      duration: const Duration(milliseconds: 4000), // Different timing for variety
      vsync: this,
    );
    _animationController3 = AnimationController(
      duration: const Duration(milliseconds: 3000), // Faster for more dynamic feel
      vsync: this,
    );

    // Create animations with varied curves for different effects
    _animation1 = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _animationController1, curve: Curves.easeInOutSine)
    );
    _animation2 = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _animationController2, curve: Curves.easeInOutQuart)
    );
    _animation3 = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _animationController3, curve: Curves.easeInOutCubic)
    );

    // Start animations with staggered timing for natural flow
    _animationController1.repeat(reverse: true);
    Future.delayed(const Duration(milliseconds: 300), () {
      _animationController2.repeat(reverse: true);
    });
    Future.delayed(const Duration(milliseconds: 600), () {
      _animationController3.repeat(reverse: true);
    });
  }

  @override
  void dispose() {
    _userDataSubscription?.cancel();
    _animationController1.dispose();
    _animationController2.dispose();
    _animationController3.dispose();
    super.dispose();
  }

  void _setupRealtimeUserData() {
    final userStream = _firestoreService.streamCurrentUserData();
    if (userStream != null) {
      _userDataSubscription = userStream.listen(
        (DocumentSnapshot snapshot) {
          if (mounted) {
            setState(() {
              if (snapshot.exists) {
                _userData = snapshot.data() as Map<String, dynamic>?;
              } else {
                _userData = null;
              }
              _isLoading = false;
            });
          }
        },
        onError: (error) {
          if (mounted) {
            setState(() {
              _isLoading = false;
            });
          }
        },
      );
    } else {
      // Fallback to one-time load if no user is logged in
      _loadUserDataOnce();
    }
  }

  Future<void> _loadUserDataOnce() async {
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
                        UserAvatar(
                          avatar: _userData?['avatar'] ?? '🦊',
                          size: 40,
                          gradientColors: const [Color(0xFF7ED321), Color(0xFF9ACD32)],
                        ),
                        const SizedBox(width: 8),
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
                                  '${_userData?['totalScore'] ?? _userData?['stars'] ?? 248} XP',
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
                              Icons.leaderboard,
                              color: Colors.amber.shade600,
                              size: 20,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
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
                                '${_userData?['currentStreak'] ?? _userData?['streak'] ?? 7} Day Streak!',
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
                  padding: EdgeInsets.all(MediaQuery.of(context).size.width < 360 ? 14 : 18),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Color(0xFFE8B4FF), Color(0xFFC490FF)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFFE8B4FF).withValues(alpha: 0.3),
                        blurRadius: 12,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.2),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Icon(
                          Icons.lightbulb_outline,
                          color: Colors.white,
                          size: MediaQuery.of(context).size.width < 360 ? 22 : 24,
                        ),
                      ),
                      SizedBox(width: MediaQuery.of(context).size.width < 360 ? 10 : 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              "You're doing amazing!",
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: MediaQuery.of(context).size.width < 360 ? 15 : 17,
                                fontWeight: FontWeight.w800,
                                letterSpacing: 0.3,
                                shadows: [
                                  Shadow(
                                    color: Colors.black.withValues(alpha: 0.2),
                                    offset: const Offset(1, 1),
                                    blurRadius: 2,
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              "Ready for today's math adventure?",
                              style: TextStyle(
                                color: Colors.white.withValues(alpha: 0.95),
                                fontSize: MediaQuery.of(context).size.width < 360 ? 12 : 14,
                                fontWeight: FontWeight.w500,
                                height: 1.2,
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
                
                // Level Cards with Animated Gradients
                _buildLevelCard(
                  0,
                  'EASY',
                  '1-digit + 1-digit numbers',
                  const Color(0xFF9CCC65), // Easy level - base green
                  Icons.star,
                  1,
                ),
                const SizedBox(height: 8),
                _buildLevelCard(
                  1,
                  'MODERATE',
                  '2-digit + 1-digit numbers',
                  const Color(0xFFFFB74D), // Moderate level - base orange
                  Icons.star,
                  2,
                ),
                const SizedBox(height: 8),
                _buildLevelCard(
                  2,
                  'ADVANCED',
                  '3-digit + 2-digit numbers',
                  const Color(0xFFEF5350), // Advanced level - base red
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

                // Leaderboards - Featured at the top
                _buildQuickActionCard(
                  Icons.leaderboard,
                  'Leaderboards',
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
                const SizedBox(height: 16),

                // 2x2 Grid for remaining actions
                Row(
                  children: [
                    Expanded(
                      child: _buildCompactActionCard(
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
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: _buildCompactActionCard(
                        Icons.psychology,
                        'Adaptive Quiz 🧠',
                        'AI-powered questions',
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
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: _buildCompactActionCard(
                        Icons.sports_martial_arts,
                        'Math Battle Arena 🔢',
                        'Duel with friends!',
                        const Color(0xFFFF9800), // Consistent orange
                        () {
                          // Set bottom nav to Quiz tab
                          widget.onTabChange(2);
                        },
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: _buildCompactActionCard(
                        Icons.trending_up,
                        'My Progress',
                        'See how you\'re doing',
                        const Color(0xFF00ACC1), // Consistent cyan
                        () {
                          // Set bottom nav to Progress tab
                          widget.onTabChange(3);
                        },
                      ),
                    ),
                  ],
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
            setState(() {
              _selectedLevel = index;
            });

            await _prefsService.setSelectedDifficulty(index);

            if (mounted) {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => SoloPracticeScreen(difficulty: index),
                ),
              );
            }
          },
          child: AnimatedBuilder(
            animation: _getAnimationForIndex(index),
            builder: (context, child) => AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                color: isSelected ? brighterColor : color,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: _getAnimatedBorderColor(index, isSelected, color, brighterColor),
                  width: isSelected ? 3 : 2,
                ),
                boxShadow: [
                  BoxShadow(
                    color: color.withValues(alpha: isSelected ? 0.35 : 0.25),
                    blurRadius: isSelected ? 15 : 8,
                    offset: Offset(0, isSelected ? 8 : 4),
                    spreadRadius: isSelected ? 1 : 0,
                  ),
                  if (isSelected)
                    BoxShadow(
                      color: Colors.white.withValues(alpha: 0.2),
                      blurRadius: 6,
                      offset: const Offset(0, -2),
                      spreadRadius: -2,
                    ),
                ],
                // Optimized gradient with reduced complexity
                gradient: LinearGradient(
                  begin: _getAnimatedBeginAlignment(index),
                  end: _getAnimatedEndAlignment(index),
                  colors: _getGradientColors(index, isSelected, color, brighterColor),
                  stops: _getAnimatedStops(index),
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
                          fontSize: 20,
                        ),
                        child: Text(index == 0 ? '1' : index == 1 ? '2' : '3'),
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
                                color: Colors.black.withValues(alpha: 0.6),
                                offset: const Offset(2, 2),
                                blurRadius: 4,
                              ),
                              Shadow(
                                color: Colors.black.withValues(alpha: 0.3),
                                offset: const Offset(1, 1),
                                blurRadius: 2,
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
                                color: Colors.black.withValues(alpha: 0.5),
                                offset: const Offset(1.5, 1.5),
                                blurRadius: 3,
                              ),
                              Shadow(
                                color: Colors.black.withValues(alpha: 0.2),
                                offset: const Offset(0.5, 0.5),
                                blurRadius: 1,
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
      ),
    );
  }

  Widget _buildCompactActionCard(IconData icon, String title, String subtitle, Color color, VoidCallback onTap) {
    return Container(
      margin: const EdgeInsets.all(4),
      child: ElevatedButton(
        onPressed: onTap,
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.white,
          foregroundColor: color,
          elevation: 3,
          shadowColor: Colors.black26,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
            side: BorderSide(color: color.withValues(alpha: 0.3), width: 1),
          ),
          padding: const EdgeInsets.all(16),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: color,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(
                icon,
                color: Colors.white,
                size: 22,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              title,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.bold,
                color: Color(0xFF2C3E50),
              ),
            ),
            const SizedBox(height: 4),
            Text(
              subtitle,
              textAlign: TextAlign.center,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.normal,
                color: Color(0xFF666666),
                height: 1.3,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildQuickActionCard(IconData icon, String title, String subtitle, Color color, VoidCallback onTap) {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 6),
      child: ElevatedButton(
        onPressed: onTap,
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.white,
          foregroundColor: color,
          elevation: 4,
          shadowColor: Colors.black26,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
            side: BorderSide(color: color.withValues(alpha: 0.3), width: 1.5),
          ),
          padding: const EdgeInsets.all(20),
        ),
        child: Row(
          children: [
            Container(
              width: 50,
              height: 50,
              decoration: BoxDecoration(
                color: color,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(
                icon,
                color: Colors.white,
                size: 26,
              ),
            ),
            const SizedBox(width: 20),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF2C3E50),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    subtitle,
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.normal,
                      color: Color(0xFF666666),
                    ),
                  ),
                ],
              ),
            ),
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: color,
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(
                Icons.arrow_forward_rounded,
                color: Colors.white,
                size: 18,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBadge(String emoji, String label) {
    final screenWidth = MediaQuery.of(context).size.width;

    return Column(
      children: [
        Container(
          width: screenWidth < 360 ? 56 : 64,
          height: screenWidth < 360 ? 56 : 64,
          decoration: BoxDecoration(
            color: Colors.white,
            shape: BoxShape.circle,
            border: Border.all(
              color: const Color(0xFFE0E0E0),
              width: 1,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.08),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Center(
            child: Text(
              emoji,
              style: TextStyle(fontSize: screenWidth < 360 ? 24 : 28),
            ),
          ),
        ),
        SizedBox(height: screenWidth < 360 ? 6 : 8),
        Text(
          label,
          style: TextStyle(
            fontSize: screenWidth < 360 ? 11 : 12,
            fontWeight: FontWeight.w600,
            color: const Color(0xFF4A4A4A),
          ),
          textAlign: TextAlign.center,
        ),
      ],
    );
  }

  // Optimized animation helper methods with reduced complexity
  Animation<double> _getAnimationForIndex(int index) {
    switch (index) {
      case 0: return _animation1;
      case 1: return _animation2;
      case 2: return _animation3;
      default: return _animation1;
    }
  }

  // Enhanced gradient colors with visible animations
  List<Color> _getGradientColors(int index, bool isSelected, Color baseColor, Color brighterColor) {
    double animValue = _getAnimationForIndex(index).value;
    Color primary = isSelected ? brighterColor : baseColor;

    // Enhanced color variations for visible effects
    double intensity = 0.3 + (animValue * 0.4); // Much more variation
    double reverseIntensity = 0.7 - (animValue * 0.4); // Counter animation

    switch (index) {
      case 0: // Easy - Green with flowing effect
        return [
          Color.lerp(primary, const Color(0xFF4CAF50), intensity) ?? primary,
          Color.lerp(primary, const Color(0xFF81C784), reverseIntensity) ?? primary,
          Color.lerp(primary, const Color(0xFF66BB6A), intensity) ?? primary,
          Color.lerp(primary, const Color(0xFFA5D6A7), reverseIntensity) ?? primary,
        ];
      case 1: // Moderate - Orange with vibrant flow
        return [
          Color.lerp(primary, const Color(0xFFFF9800), intensity) ?? primary,
          Color.lerp(primary, const Color(0xFFFFAB40), reverseIntensity) ?? primary,
          Color.lerp(primary, const Color(0xFFFFB74D), intensity) ?? primary,
          Color.lerp(primary, const Color(0xFFFFCC02), reverseIntensity) ?? primary,
        ];
      case 2: // Advanced - Red with dynamic pulses
        return [
          Color.lerp(primary, const Color(0xFFF44336), intensity) ?? primary,
          Color.lerp(primary, const Color(0xFFE57373), reverseIntensity) ?? primary,
          Color.lerp(primary, const Color(0xFFEF5350), intensity) ?? primary,
          Color.lerp(primary, const Color(0xFFEF9A9A), reverseIntensity) ?? primary,
        ];
      default:
        return [primary, brighterColor, primary, brighterColor];
    }
  }

  // Enhanced alignment animations with visible movement
  Alignment _getAnimatedBeginAlignment(int index) {
    double value = _getAnimationForIndex(index).value;

    switch (index) {
      case 0: // Easy - Dramatic diagonal sweep
        return Alignment.lerp(
          Alignment.topLeft,
          Alignment.bottomCenter,
          value
        ) ?? Alignment.topLeft;
      case 1: // Moderate - Full horizontal sweep
        return Alignment.lerp(
          Alignment.centerLeft,
          Alignment.centerRight,
          value
        ) ?? Alignment.centerLeft;
      case 2: // Advanced - Circular motion
        return Alignment.lerp(
          Alignment.topCenter,
          Alignment.bottomLeft,
          value
        ) ?? Alignment.topCenter;
      default:
        return Alignment.topLeft;
    }
  }

  Alignment _getAnimatedEndAlignment(int index) {
    double value = _getAnimationForIndex(index).value;

    switch (index) {
      case 0: // Easy - Dramatic diagonal sweep
        return Alignment.lerp(
          Alignment.bottomRight,
          Alignment.topCenter,
          value
        ) ?? Alignment.bottomRight;
      case 1: // Moderate - Full horizontal sweep
        return Alignment.lerp(
          Alignment.centerRight,
          Alignment.centerLeft,
          value
        ) ?? Alignment.centerRight;
      case 2: // Advanced - Circular motion
        return Alignment.lerp(
          Alignment.bottomCenter,
          Alignment.topRight,
          value
        ) ?? Alignment.bottomCenter;
      default:
        return Alignment.bottomRight;
    }
  }

  // Enhanced gradient stops with visible flow
  List<double> _getAnimatedStops(int index) {
    double value = _getAnimationForIndex(index).value;
    double subtleOffset = value * 0.3; // More noticeable movement

    switch (index) {
      case 0: // Easy - Gentle wave
        return [
          0.0,
          0.25 + (subtleOffset * 0.5),
          0.6 + (subtleOffset * 0.3),
          1.0
        ];
      case 1: // Moderate - Pulsing effect
        return [
          0.0,
          0.2 + (subtleOffset * 0.6),
          0.7 + (subtleOffset * 0.4),
          1.0
        ];
      case 2: // Advanced - Dynamic transitions
        return [
          0.0,
          0.15 + (subtleOffset * 0.7),
          0.65 + (subtleOffset * 0.5),
          1.0
        ];
      default:
        return [0.0, 0.3, 0.7, 1.0];
    }
  }

  // Enhanced border color animation with visible effects
  Color _getAnimatedBorderColor(int index, bool isSelected, Color baseColor, Color brighterColor) {
    double animValue = _getAnimationForIndex(index).value;
    Color primaryBorder = isSelected ? brighterColor : baseColor;
    double intensity = 0.3 + (animValue * 0.5); // Much more visible intensity

    switch (index) {
      case 0: // Easy - Pulsing green border
        return Color.lerp(
          primaryBorder,
          const Color(0xFF4CAF50),
          intensity
        ) ?? primaryBorder;
      case 1: // Moderate - Vibrant orange border
        return Color.lerp(
          primaryBorder,
          const Color(0xFFFF9800),
          intensity
        ) ?? primaryBorder;
      case 2: // Advanced - Dynamic red border
        return Color.lerp(
          primaryBorder,
          const Color(0xFFE53935),
          intensity
        ) ?? primaryBorder;
      default:
        return primaryBorder;
    }
  }
}