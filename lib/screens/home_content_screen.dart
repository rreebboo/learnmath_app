import 'package:flutter/material.dart';
import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:firebase_auth/firebase_auth.dart';
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
  
  // Simple hover/tap animation controller
  late AnimationController _hoverController;

  @override
  void initState() {
    super.initState();
    _initializeAnimations();
    _setupRealtimeUserData();
    _loadSelectedDifficulty();
    _cleanupDebugDataIfNeeded();
  }

  void _initializeAnimations() {
    // Simple, lightweight animation for touch feedback only
    _hoverController = AnimationController(
      duration: const Duration(milliseconds: 150),
      vsync: this,
    );
  }

  @override
  void dispose() {
    _userDataSubscription?.cancel();
    _hoverController.dispose();
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
                  children: [
                    // Left side - User info (flexible)
                    Expanded(
                      flex: 3,
                      child: Row(
                        children: [
                          UserAvatar(
                            avatar: _userData?['avatar'] ?? '🦊',
                            size: 40,
                            gradientColors: const [Color(0xFF7ED321), Color(0xFF9ACD32)],
                          ),
                          const SizedBox(width: 8),
                          Flexible(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Flexible(
                                      child: Text(
                                        'Hi ${_userData?['name'] ?? 'Emma'}! ',
                                        style: const TextStyle(
                                          fontSize: 16,
                                          fontWeight: FontWeight.w600,
                                          color: Color(0xFF2C3E50),
                                        ),
                                        overflow: TextOverflow.ellipsis,
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
                                    Flexible(
                                      child: Text(
                                        '${_userData?['totalScore'] ?? _userData?['stars'] ?? 248} XP',
                                        style: TextStyle(
                                          fontSize: 12,
                                          color: Colors.grey[600],
                                        ),
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    // Right side - Actions (fixed width)
                    Row(
                      mainAxisSize: MainAxisSize.min,
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
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                          decoration: BoxDecoration(
                            color: const Color(0xFFFFE4B5),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(
                                Icons.local_fire_department,
                                size: 16,
                                color: Colors.orange,
                              ),
                              const SizedBox(width: 4),
                              Text(
                                '${_userData?['currentStreak'] ?? _userData?['streak'] ?? 7} Day${(_userData?['currentStreak'] ?? _userData?['streak'] ?? 7) == 1 ? '' : 's'}!',
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                  color: Colors.orange[700],
                                ),
                                overflow: TextOverflow.ellipsis,
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
                                    offset: Offset(1, 1),
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

                // Responsive 2x2 Grid for action cards
                _buildActionGrid(),
                
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

    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      curve: Curves.easeOut,
      transform: isSelected ? Matrix4.diagonal3Values(1.02, 1.02, 1.0) : Matrix4.identity(),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(16),
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          splashColor: color.withValues(alpha: 0.3),
          highlightColor: color.withValues(alpha: 0.1),
          onTap: () async {
            // Haptic feedback for better UX
            _hoverController.forward().then((_) => _hoverController.reverse());

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
          child: Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: isSelected ? Colors.white.withValues(alpha: 0.8) : Colors.white.withValues(alpha: 0.3),
                width: isSelected ? 3 : 2,
              ),
              boxShadow: [
                BoxShadow(
                  color: color.withValues(alpha: isSelected ? 0.4 : 0.25),
                  blurRadius: isSelected ? 12 : 6,
                  offset: Offset(0, isSelected ? 6 : 3),
                ),
              ],
              // Simple, static gradient - no animations
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  color,
                  color.withValues(alpha: 0.8),
                ],
              ),
            ),
            child: Row(
              children: [
                Container(
                  width: 45,
                  height: 45,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.1),
                        blurRadius: 4,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Center(
                    child: Text(
                      index == 0 ? '1' : index == 1 ? '2' : '3',
                      style: TextStyle(
                        color: color,
                        fontWeight: FontWeight.bold,
                        fontSize: 20,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        level,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                          shadows: [
                            Shadow(
                              color: Colors.black54,
                              offset: Offset(1, 1),
                              blurRadius: 2,
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        description,
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.9),
                          fontSize: 12,
                          shadows: [
                            Shadow(
                              color: Colors.black54,
                              offset: Offset(1, 1),
                              blurRadius: 2,
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: List.generate(
                          3,
                          (i) => Icon(
                            Icons.star,
                            size: 14,
                            color: i < stars
                                ? Colors.yellow
                                : Colors.white.withValues(alpha: 0.4),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const Icon(
                    Icons.play_circle_fill,
                    color: Colors.white,
                    size: 28,
                  ),
                ],
              ),
            ),
          ),
        ),
      );
  }

  Widget _buildActionGrid() {
    final screenWidth = MediaQuery.of(context).size.width;
    final screenHeight = MediaQuery.of(context).size.height;

    // Android 8+ adaptive sizing based on actual device characteristics
    final isSmallScreen = screenWidth < 360;
    final isCompactHeight = screenHeight < 640; // Common for older Android devices

    // Adaptive spacing for different Android device types
    final spacing = isSmallScreen ? 6.0 : isCompactHeight ? 7.0 : 8.0;

    return Column(
      children: [
        Row(
          children: [
            Expanded(
              child: _buildCompactActionCard(
                Icons.person,
                'Solo Practice',
                'Practice at your own pace',
                const Color(0xFF2196F3),
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
            SizedBox(width: spacing),
            Expanded(
              child: _buildCompactActionCard(
                Icons.psychology,
                'Adaptive Quiz 🧠',
                'AI-powered questions',
                const Color(0xFF9C27B0),
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
        SizedBox(height: spacing),
        Row(
          children: [
            Expanded(
              child: _buildCompactActionCard(
                Icons.sports_martial_arts,
                'Math Battle Arena 🔢',
                'Duel with friends!',
                const Color(0xFFFF9800),
                () {
                  widget.onTabChange(2);
                },
              ),
            ),
            SizedBox(width: spacing),
            Expanded(
              child: _buildCompactActionCard(
                Icons.trending_up,
                'My Progress',
                'See how you\'re doing',
                const Color(0xFF00ACC1),
                () {
                  widget.onTabChange(3);
                },
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildCompactActionCard(IconData icon, String title, String subtitle, Color color, VoidCallback onTap) {
    return Expanded(
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 4),
        child: Material(
          borderRadius: BorderRadius.circular(16),
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: onTap,
            borderRadius: BorderRadius.circular(16),
            child: Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: color.withValues(alpha: 0.2),
                  width: 1,
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.05),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: color,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(
                      icon,
                      color: Colors.white,
                      size: 20,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    title,
                    textAlign: TextAlign.center,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF2C3E50),
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    textAlign: TextAlign.center,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 10,
                      color: Colors.grey[600],
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

  Widget _buildQuickActionCard(IconData icon, String title, String subtitle, Color color, VoidCallback onTap) {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 6),
      child: Material(
        borderRadius: BorderRadius.circular(16),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(16),
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: color.withValues(alpha: 0.2),
                width: 1,
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.05),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Row(
              children: [
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: color,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(
                    icon,
                    color: Colors.white,
                    size: 24,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFF2C3E50),
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        subtitle,
                        style: TextStyle(
                          fontSize: 13,
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

  // Clean up debug data automatically
  Future<void> _cleanupDebugDataIfNeeded() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    try {
      // Check if user has debug test data
      final userDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .get();

      if (userDoc.exists) {
        final userData = userDoc.data() as Map<String, dynamic>;
        final currentName = userData['name'] as String?;
        bool needsCleanup = false;

        // Check for debug test data
        if (currentName != null && currentName.contains('Debug Test User')) {
          needsCleanup = true;
        }

        if (userData.containsKey('testField')) {
          needsCleanup = true;
        }

        if (needsCleanup) {
          print('🧹 Auto-cleaning debug data...');

          // Reset user name to proper value
          if (currentName != null && currentName.contains('Debug Test User')) {
            await FirebaseFirestore.instance
                .collection('users')
                .doc(user.uid)
                .update({
              'name': user.displayName ?? user.email?.split('@')[0] ?? 'User',
            });
          }

          // Remove debug test field
          if (userData.containsKey('testField')) {
            await FirebaseFirestore.instance
                .collection('users')
                .doc(user.uid)
                .update({
              'testField': FieldValue.delete(),
            });
          }

          // Remove debug test from lesson_progress
          await FirebaseFirestore.instance
              .collection('users')
              .doc(user.uid)
              .collection('lesson_progress')
              .doc('debug_test')
              .delete()
              .catchError((e) => null); // Ignore if doesn't exist

          // Remove debug test file from Storage
          await FirebaseStorage.instance
              .ref()
              .child('users')
              .child(user.uid)
              .child('debug')
              .child('test.txt')
              .delete()
              .catchError((e) => null); // Ignore if doesn't exist

          print('✅ Debug data cleaned automatically');
        }
      }
    } catch (e) {
      // Ignore cleanup errors - don't affect user experience
      print('ℹ️ Debug cleanup completed');
    }
  }

}