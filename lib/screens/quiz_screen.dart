import 'package:flutter/material.dart';
import '../services/firestore_service.dart';
import '../services/friends_service.dart';
import 'friends_screen.dart';

class QuizScreen extends StatefulWidget {
  const QuizScreen({super.key});

  @override
  State<QuizScreen> createState() => _QuizScreenState();
}

class _QuizScreenState extends State<QuizScreen> with TickerProviderStateMixin {
  final FirestoreService _firestoreService = FirestoreService();
  final FriendsService _friendsService = FriendsService();
  late AnimationController _animationController;
  late Animation<double> _scaleAnimation;
  Map<String, dynamic>? _userData;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );
    _scaleAnimation = Tween<double>(
      begin: 0.8,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _animationController,
      curve: Curves.bounceOut,
    ));
    _loadUserData();
    _animationController.forward();
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FA),
      appBar: AppBar(
        backgroundColor: const Color(0xFFF5F7FA),
        elevation: 0,
        leading: Builder(
          builder: (context) => IconButton(
            icon: const Icon(Icons.menu, color: Color(0xFF2C3E50)),
            onPressed: () => Scaffold.of(context).openDrawer(),
          ),
        ),
        title: const Text(
          'Math Duel Arena',
          style: TextStyle(
            color: Color(0xFF2C3E50),
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.group, color: Color(0xFF5B9EF3)),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const FriendsScreen()),
              );
            },
          ),
        ],
      ),
      drawer: _buildDrawer(),
      body: _isLoading ? _buildLoadingBody() : _buildMainBody(),
    );
  }

  Widget _buildLoadingBody() {
    return const Center(
      child: CircularProgressIndicator(
        valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF5B9EF3)),
      ),
    );
  }

  Widget _buildMainBody() {
    return SafeArea(
      child: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header matching home screen style
              _buildHeader(),
              const SizedBox(height: 25),

              // Main Duel Arena - Purple gradient like home screen
              _buildDuelArena(),
              const SizedBox(height: 25),

              // Game Modes - Matching home screen style
              _buildGameModes(),
              const SizedBox(height: 25),

              // Stats Section
              _buildStatsSection(),
              const SizedBox(height: 25),

              // Practice Mode - Matching home screen quick actions
              _buildPracticeMode(),
              const SizedBox(height: 20),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Row(
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
                      'Ready to Duel?',
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF2C3E50),
                      ),
                    ),
                    const Text(
                      ' ⚔️',
                      style: TextStyle(fontSize: 16),
                    ),
                  ],
                ),
                Row(
                  children: [
                    const Icon(
                      Icons.emoji_events,
                      size: 14,
                      color: Colors.amber,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      '${_userData?['totalScore'] ?? 0} Points',
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
                '${_userData?['winStreak'] ?? 0} Streak!',
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
    );
  }

  Widget _buildDuelArena() {
    return ScaleTransition(
      scale: _scaleAnimation,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [Color(0xFFE8B4FF), Color(0xFFC490FF)],
          ),
          borderRadius: BorderRadius.circular(15),
        ),
        child: Column(
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(
                  Icons.sports_martial_arts,
                  color: Colors.white,
                  size: 24,
                ),
                const SizedBox(width: 12),
                const Text(
                  'Math Duel Arena',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            const Text(
              'Challenge friends and prove your math skills!',
              style: TextStyle(
                color: Colors.white,
                fontSize: 13,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 20),
            
            // Duel Preview - Two players
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                _buildPlayerPreview(
                  _userData?['avatar'] ?? '🦊',
                  _userData?['name'] ?? 'You',
                  true,
                ),
                Container(
                  width: 50,
                  height: 50,
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.2),
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.white, width: 2),
                  ),
                  child: const Center(
                    child: Text(
                      'VS',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
                _buildPlayerPreview('🤖', 'Opponent', false),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildGameModes() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Choose Your Battle',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: Color(0xFF2C3E50),
          ),
        ),
        const SizedBox(height: 15),

        // Quick Match
        _buildGameModeCard(
          icon: Icons.flash_on,
          title: 'Quick Match',
          subtitle: 'Find an opponent instantly',
          color: const Color(0xFF7ED321),
          onTap: () => _showComingSoonDialog('Quick Match'),
        ),
        const SizedBox(height: 12),

        // Friend Challenge
        _buildGameModeCard(
          icon: Icons.group,
          title: 'Challenge Friend',
          subtitle: 'Invite a friend to battle',
          color: const Color(0xFF5B9EF3),
          onTap: () => _showFriendChallengeDialog(),
        ),
        const SizedBox(height: 12),

        // Tournament
        _buildGameModeCard(
          icon: Icons.emoji_events,
          title: 'Tournament',
          subtitle: 'Compete in championships',
          color: const Color(0xFFFFA500),
          onTap: () => _showComingSoonDialog('Tournament'),
        ),
      ],
    );
  }

  Widget _buildStatsSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Your Battle Stats',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: Color(0xFF2C3E50),
          ),
        ),
        const SizedBox(height: 15),
        Row(
          children: [
            Expanded(
              child: _buildStatCard(
                icon: Icons.emoji_events,
                title: 'Wins',
                value: '${_userData?['wins'] ?? 0}',
                color: const Color(0xFF7ED321),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _buildStatCard(
                icon: Icons.school,
                title: 'Battles',
                value: '${(_userData?['wins'] ?? 0) + (_userData?['losses'] ?? 0)}',
                color: const Color(0xFF5B9EF3),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _buildStatCard(
                icon: Icons.whatshot,
                title: 'Streak',
                value: '${_userData?['winStreak'] ?? 0}',
                color: const Color(0xFFFFA500),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildPracticeMode() {
    return Container(
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
              color: const Color(0xFF9C27B0).withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(
              Icons.fitness_center,
              color: Color(0xFF9C27B0),
              size: 20,
            ),
          ),
          const SizedBox(width: 15),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Practice Mode',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF2C3E50),
                  ),
                ),
                Text(
                  'Sharpen your skills before battle',
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey,
                  ),
                ),
              ],
            ),
          ),
          GestureDetector(
            onTap: () => _showComingSoonDialog('Practice Mode'),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(
                color: const Color(0xFF9C27B0),
                borderRadius: BorderRadius.circular(20),
              ),
              child: const Text(
                'Start',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPlayerPreview(String avatar, String name, bool isUser) {
    return Column(
      children: [
        Container(
          width: 60,
          height: 60,
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.2),
            borderRadius: BorderRadius.circular(15),
            border: Border.all(color: Colors.white, width: 2),
          ),
          child: Center(
            child: Text(
              avatar,
              style: const TextStyle(fontSize: 24),
            ),
          ),
        ),
        const SizedBox(height: 8),
        Text(
          name,
          style: const TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: Colors.white,
          ),
        ),
      ],
    );
  }

  Widget _buildGameModeCard({
    required IconData icon,
    required String title,
    required String subtitle,
    required Color color,
    required VoidCallback onTap,
  }) {
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

  Widget _buildStatCard({
    required IconData icon,
    required String title,
    required String value,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.all(15),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 5,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        children: [
          Icon(
            icon,
            color: color,
            size: 24,
          ),
          const SizedBox(height: 8),
          Text(
            value,
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
          Text(
            title,
            style: TextStyle(
              fontSize: 11,
              color: Colors.grey[600],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDrawer() {
    return Drawer(
      child: Container(
        color: const Color(0xFFF5F7FA),
        child: Column(
          children: [
            // Drawer Header
            Container(
              padding: const EdgeInsets.fromLTRB(20, 60, 20, 20),
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  colors: [Color(0xFFE8B4FF), Color(0xFFC490FF)],
                ),
              ),
              child: Column(
                children: [
                  Container(
                    width: 80,
                    height: 80,
                    decoration: const BoxDecoration(
                      shape: BoxShape.circle,
                      color: Colors.white,
                    ),
                    child: Center(
                      child: Text(
                        _userData?['avatar'] ?? '🦊',
                        style: const TextStyle(fontSize: 36),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    _userData?['name'] ?? 'Player',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  Text(
                    '${_userData?['totalScore'] ?? 0} points',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 14,
                    ),
                  ),
                ],
              ),
            ),

            // Menu Items
            Expanded(
              child: ListView(
                padding: const EdgeInsets.all(0),
                children: [
                  _buildDrawerItem(
                    icon: Icons.group,
                    title: 'Friends',
                    subtitle: 'Manage your friends',
                    onTap: () {
                      Navigator.pop(context);
                      Navigator.push(
                        context,
                        MaterialPageRoute(builder: (context) => const FriendsScreen()),
                      );
                    },
                  ),
                  _buildDrawerItem(
                    icon: Icons.sports_martial_arts,
                    title: 'Quick Challenge',
                    subtitle: 'Challenge a random player',
                    onTap: () {
                      Navigator.pop(context);
                      _showComingSoonDialog('Quick Challenge');
                    },
                  ),
                  _buildDrawerItem(
                    icon: Icons.emoji_events,
                    title: 'Tournaments',
                    subtitle: 'Join math competitions',
                    onTap: () {
                      Navigator.pop(context);
                      _showComingSoonDialog('Tournaments');
                    },
                  ),
                ],
              ),
            ),

            // Footer
            Container(
              padding: const EdgeInsets.all(20),
              child: StreamBuilder<List<Map<String, dynamic>>>(
                stream: _friendsService.getFriends(),
                builder: (context, snapshot) {
                  final friendCount = snapshot.data?.length ?? 0;
                  return Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              '$friendCount Friends',
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                color: Color(0xFF2C3E50),
                              ),
                            ),
                            Text(
                              'Ready to duel!',
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.grey[600],
                              ),
                            ),
                          ],
                        ),
                        const Icon(
                          Icons.group,
                          color: Color(0xFF5B9EF3),
                          size: 24,
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDrawerItem({
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    return ListTile(
      leading: Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          color: const Color(0xFF5B9EF3).withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Icon(icon, color: const Color(0xFF5B9EF3), size: 20),
      ),
      title: Text(
        title,
        style: const TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.w600,
          color: Color(0xFF2C3E50),
        ),
      ),
      subtitle: Text(
        subtitle,
        style: TextStyle(
          fontSize: 12,
          color: Colors.grey[600],
        ),
      ),
      onTap: onTap,
    );
  }

  void _showFriendChallengeDialog() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const FriendsScreen()),
    );
  }

  void _showComingSoonDialog(String feature) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(15),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                '🚧',
                style: TextStyle(fontSize: 50),
              ),
              const SizedBox(height: 15),
              Text(
                '$feature Coming Soon!',
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF2C3E50),
                ),
              ),
              const SizedBox(height: 10),
              Text(
                'We\'re working hard to bring you amazing multiplayer features!',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 14,
                  color: Colors.grey[600],
                ),
              ),
              const SizedBox(height: 20),
              ElevatedButton(
                onPressed: () => Navigator.pop(context),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF5B9EF3),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: const Text(
                  'Got it!',
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}