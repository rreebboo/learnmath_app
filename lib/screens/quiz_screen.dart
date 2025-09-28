import 'package:flutter/material.dart';
import '../services/firestore_service.dart';
import '../services/friends_service.dart';
import '../services/quiz_duel_service.dart';
import '../services/floating_challenge_service.dart';
import '../widgets/user_avatar.dart';
import 'friends_screen.dart';
import 'quiz_duel_screen.dart';

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
            UserAvatar(
              avatar: _userData?['avatar'] ?? '🦊',
              size: 40,
              gradientColors: const [Color(0xFF7ED321), Color(0xFF9ACD32)],
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
                      Icons.leaderboard,
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
          onTap: () => _showQuickMatchDialog(),
        ),
        const SizedBox(height: 12),

        // Friend Challenge
        _buildGameModeCard(
          icon: Icons.group,
          title: 'Challenge Friend',
          subtitle: 'Invite a friend to battle',
          color: const Color(0xFF5B9EF3),
          onTap: () => _showChallengeFriendsDialog(),
        ),
        const SizedBox(height: 12),

        // Tournament
        _buildGameModeCard(
          icon: Icons.leaderboard,
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
                icon: Icons.leaderboard,
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
        UserAvatar(
          avatar: avatar,
          size: 60,
          backgroundColor: Colors.white.withValues(alpha: 0.2),
          showBorder: true,
          borderColor: Colors.white,
          borderWidth: 2,
          gradientColors: const [Color(0xFF7ED321), Color(0xFF9ACD32)],
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
                  UserAvatar(
                    avatar: _userData?['avatar'] ?? '🦊',
                    size: 80,
                    backgroundColor: Colors.white,
                    gradientColors: const [Color(0xFF7ED321), Color(0xFF9ACD32)],
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
                      _showQuickMatchDialog();
                    },
                  ),
                  _buildDrawerItem(
                    icon: Icons.leaderboard,
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

  void _showQuickMatchDialog() {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        String selectedDifficulty = 'easy';
        String selectedOperator = '+';

        return StatefulBuilder(
          builder: (context, setState) {
            return AlertDialog(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
              ),
              title: Row(
                children: [
                  Icon(Icons.flash_on, color: Color(0xFF7ED321)),
                  SizedBox(width: 8),
                  Text(
                    'Quick Match',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF2C3E50),
                    ),
                  ),
                ],
              ),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Choose your challenge level:',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF2C3E50),
                    ),
                  ),
                  SizedBox(height: 15),

                  // Difficulty Selection
                  Container(
                    decoration: BoxDecoration(
                      border: Border.all(color: Colors.grey[300]!),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Column(
                      children: [
                        _buildDifficultyOption(
                          'easy', 'Easy', '1-10 numbers', Color(0xFF7ED321),
                          selectedDifficulty, (value) => setState(() => selectedDifficulty = value)
                        ),
                        Divider(height: 1),
                        _buildDifficultyOption(
                          'medium', 'Medium', '10-100 numbers', Color(0xFFFFA500),
                          selectedDifficulty, (value) => setState(() => selectedDifficulty = value)
                        ),
                        Divider(height: 1),
                        _buildDifficultyOption(
                          'hard', 'Hard', '100+ numbers', Color(0xFFFF6B6B),
                          selectedDifficulty, (value) => setState(() => selectedDifficulty = value)
                        ),
                      ],
                    ),
                  ),

                  SizedBox(height: 20),

                  Text(
                    'Choose operation:',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF2C3E50),
                    ),
                  ),
                  SizedBox(height: 15),

                  // Operation Selection
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      _buildOperatorButton('+', selectedOperator, (op) => setState(() => selectedOperator = op)),
                      _buildOperatorButton('-', selectedOperator, (op) => setState(() => selectedOperator = op)),
                      _buildOperatorButton('×', selectedOperator, (op) => setState(() => selectedOperator = op)),
                      _buildOperatorButton('÷', selectedOperator, (op) => setState(() => selectedOperator = op)),
                    ],
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: Text(
                    'Cancel',
                    style: TextStyle(color: Colors.grey[600]),
                  ),
                ),
                ElevatedButton(
                  onPressed: () {
                    Navigator.pop(context);
                    _startQuizDuel(selectedDifficulty, selectedOperator);
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Color(0xFF7ED321),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    padding: EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.flash_on, color: Colors.white, size: 18),
                      SizedBox(width: 8),
                      Text(
                        'Start Duel',
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Widget _buildDifficultyOption(
    String value,
    String title,
    String description,
    Color color,
    String selectedValue,
    Function(String) onChanged,
  ) {
    final isSelected = selectedValue == value;
    return InkWell(
      onTap: () => onChanged(value),
      child: Container(
        padding: EdgeInsets.all(12),
        child: Row(
          children: [
            Container(
              width: 20,
              height: 20,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(
                  color: isSelected ? color : Colors.grey[400]!,
                  width: 2,
                ),
                color: isSelected ? color : Colors.transparent,
              ),
              child: isSelected
                  ? Icon(Icons.check, color: Colors.white, size: 14)
                  : null,
            ),
            SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: isSelected ? color : Color(0xFF2C3E50),
                    ),
                  ),
                  Text(
                    description,
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey[600],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildOperatorButton(String operator, String selectedOperator, Function(String) onChanged) {
    final isSelected = selectedOperator == operator;
    Color operatorColor;
    switch (operator) {
      case '+': operatorColor = Color(0xFF6C5CE7); break;
      case '-': operatorColor = Color(0xFFE84393); break;
      case '×': operatorColor = Color(0xFF00B894); break;
      case '÷': operatorColor = Color(0xFFE17055); break;
      default: operatorColor = Color(0xFF5B9EF3);
    }

    return GestureDetector(
      onTap: () => onChanged(operator),
      child: Container(
        width: 50,
        height: 50,
        decoration: BoxDecoration(
          color: isSelected ? operatorColor : Colors.grey[100],
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected ? operatorColor : Colors.grey[300]!,
            width: 2,
          ),
        ),
        child: Center(
          child: Text(
            operator,
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: isSelected ? Colors.white : operatorColor,
            ),
          ),
        ),
      ),
    );
  }

  void _startQuizDuel(String difficulty, String operator) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => QuizDuelScreen(
          topicName: 'Arithmetic',
          operator: operator,
          difficulty: difficulty,
        ),
      ),
    );
  }

  void _showChallengeFriendsDialog() {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return Dialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
          child: LayoutBuilder(
            builder: (context, constraints) {
              final screenHeight = MediaQuery.of(context).size.height;
              final screenWidth = MediaQuery.of(context).size.width;
              final isSmallScreen = screenWidth < 360;
              final isMediumScreen = screenWidth < 400;

              return Container(
                constraints: BoxConstraints(
                  maxWidth: screenWidth - 32,
                  maxHeight: screenHeight * 0.8,
                  minHeight: 400,
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Header with responsive padding
                    Container(
                      padding: EdgeInsets.all(isSmallScreen ? 16 : 20),
                      decoration: const BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.only(
                          topLeft: Radius.circular(20),
                          topRight: Radius.circular(20),
                        ),
                      ),
                      child: Column(
                        children: [
                          Row(
                            children: [
                              Container(
                                padding: EdgeInsets.all(isSmallScreen ? 6 : 8),
                                decoration: BoxDecoration(
                                  color: const Color(0xFF5B9EF3).withValues(alpha: 0.1),
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: Icon(
                                  Icons.group,
                                  color: const Color(0xFF5B9EF3),
                                  size: isSmallScreen ? 20 : 24,
                                ),
                              ),
                              SizedBox(width: isSmallScreen ? 8 : 12),
                              Expanded(
                                child: Text(
                                  'Challenge Friends',
                                  style: TextStyle(
                                    fontSize: isSmallScreen ? 16 : isMediumScreen ? 18 : 20,
                                    fontWeight: FontWeight.bold,
                                    color: const Color(0xFF2C3E50),
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              IconButton(
                                onPressed: () => Navigator.pop(context),
                                icon: Icon(
                                  Icons.close,
                                  color: Colors.grey,
                                  size: isSmallScreen ? 20 : 24,
                                ),
                                padding: EdgeInsets.all(isSmallScreen ? 4 : 8),
                                constraints: BoxConstraints(
                                  minWidth: isSmallScreen ? 32 : 40,
                                  minHeight: isSmallScreen ? 32 : 40,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),

                    // Friends List with responsive container
                    Expanded(
                      child: Container(
                        decoration: const BoxDecoration(
                          color: Color(0xFFF8F9FA),
                          borderRadius: BorderRadius.only(
                            bottomLeft: Radius.circular(20),
                            bottomRight: Radius.circular(20),
                          ),
                        ),
                        child: StreamBuilder<List<Map<String, dynamic>>>(
                          stream: _friendsService.getFriends(),
                          builder: (context, snapshot) {
                            if (snapshot.connectionState == ConnectionState.waiting) {
                              return const Center(
                                child: CircularProgressIndicator(
                                  valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF5B9EF3)),
                                ),
                              );
                            }

                            if (snapshot.hasError) {
                              return Center(
                                child: Padding(
                                  padding: EdgeInsets.all(isSmallScreen ? 16 : 20),
                                  child: Column(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(
                                        Icons.error_outline,
                                        size: isSmallScreen ? 40 : 48,
                                        color: Colors.grey,
                                      ),
                                      SizedBox(height: isSmallScreen ? 12 : 16),
                                      Text(
                                        'Error loading friends',
                                        style: TextStyle(
                                          fontSize: isSmallScreen ? 14 : 16,
                                          color: Colors.grey[600],
                                        ),
                                        textAlign: TextAlign.center,
                                      ),
                                    ],
                                  ),
                                ),
                              );
                            }

                            final friends = snapshot.data ?? [];

                            if (friends.isEmpty) {
                              return Center(
                                child: Padding(
                                  padding: EdgeInsets.all(isSmallScreen ? 16 : 20),
                                  child: Column(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Container(
                                        padding: EdgeInsets.all(isSmallScreen ? 16 : 20),
                                        decoration: BoxDecoration(
                                          color: Colors.grey[100],
                                          shape: BoxShape.circle,
                                        ),
                                        child: Icon(
                                          Icons.group_off,
                                          size: isSmallScreen ? 40 : 48,
                                          color: Colors.grey[400],
                                        ),
                                      ),
                                      SizedBox(height: isSmallScreen ? 16 : 20),
                                      Text(
                                        'No Friends Yet',
                                        style: TextStyle(
                                          fontSize: isSmallScreen ? 16 : 18,
                                          fontWeight: FontWeight.bold,
                                          color: Colors.grey[600],
                                        ),
                                        textAlign: TextAlign.center,
                                      ),
                                      SizedBox(height: isSmallScreen ? 6 : 8),
                                      Text(
                                        'Add some friends to start challenging them!',
                                        textAlign: TextAlign.center,
                                        style: TextStyle(
                                          fontSize: isSmallScreen ? 12 : 14,
                                          color: Colors.grey[500],
                                        ),
                                      ),
                                      SizedBox(height: isSmallScreen ? 16 : 20),
                                      ElevatedButton(
                                        onPressed: () {
                                          Navigator.pop(context);
                                          Navigator.push(
                                            context,
                                            MaterialPageRoute(
                                              builder: (context) => const FriendsScreen(),
                                            ),
                                          );
                                        },
                                        style: ElevatedButton.styleFrom(
                                          backgroundColor: const Color(0xFF5B9EF3),
                                          shape: RoundedRectangleBorder(
                                            borderRadius: BorderRadius.circular(12),
                                          ),
                                          padding: EdgeInsets.symmetric(
                                            horizontal: isSmallScreen ? 20 : 24,
                                            vertical: isSmallScreen ? 10 : 12,
                                          ),
                                        ),
                                        child: Text(
                                          'Add Friends',
                                          style: TextStyle(
                                            color: Colors.white,
                                            fontWeight: FontWeight.bold,
                                            fontSize: isSmallScreen ? 12 : 14,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              );
                            }

                            return ListView.separated(
                              padding: EdgeInsets.all(isSmallScreen ? 12 : 16),
                              itemCount: friends.length,
                              separatorBuilder: (context, index) => SizedBox(height: isSmallScreen ? 6 : 8),
                              itemBuilder: (context, index) {
                                final friend = friends[index];
                                return _buildFriendChallengeCard(friend, isSmallScreen, isMediumScreen);
                              },
                            );
                          },
                        ),
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
        );
      },
    );
  }

  Widget _buildFriendChallengeCard(Map<String, dynamic> friend, bool isSmallScreen, bool isMediumScreen) {
    final isOnline = friend['isOnline'] ?? false;
    final level = friend['level'] ?? 1;
    final wins = friend['wins'] ?? 0;

    return Container(
      padding: EdgeInsets.all(isSmallScreen ? 12 : 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(isSmallScreen ? 12 : 15),
        border: Border.all(
          color: isOnline ? const Color(0xFF7ED321).withValues(alpha: 0.3) : Colors.grey[200]!,
          width: 1.5,
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
          // Friend Avatar with Online Status
          Stack(
            children: [
              UserAvatar(
                avatar: friend['avatar'] ?? '🦊',
                size: isSmallScreen ? 40 : isMediumScreen ? 45 : 50,
                showBorder: true,
                borderColor: isOnline ? const Color(0xFF7ED321) : Colors.grey[300]!,
                borderWidth: 2,
                gradientColors: isOnline
                    ? [const Color(0xFF7ED321), const Color(0xFF9ACD32)]
                    : [Colors.grey[400]!, Colors.grey[500]!],
              ),
              // Online status indicator
              if (isOnline)
                Positioned(
                  bottom: 0,
                  right: 0,
                  child: Container(
                    width: isSmallScreen ? 12 : 16,
                    height: isSmallScreen ? 12 : 16,
                    decoration: BoxDecoration(
                      color: const Color(0xFF7ED321),
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.white, width: 2),
                    ),
                  ),
                ),
            ],
          ),
          SizedBox(width: isSmallScreen ? 12 : 16),

          // Friend Info
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Name and Level
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        friend['name'] ?? 'Unknown',
                        style: TextStyle(
                          fontSize: isSmallScreen ? 14 : 16,
                          fontWeight: FontWeight.bold,
                          color: const Color(0xFF2C3E50),
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    Container(
                      padding: EdgeInsets.symmetric(
                        horizontal: isSmallScreen ? 6 : 8,
                        vertical: isSmallScreen ? 1 : 2,
                      ),
                      decoration: BoxDecoration(
                        color: const Color(0xFFFFB74D).withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(isSmallScreen ? 10 : 12),
                      ),
                      child: Text(
                        'LV $level',
                        style: TextStyle(
                          fontSize: isSmallScreen ? 9 : 11,
                          fontWeight: FontWeight.bold,
                          color: const Color(0xFFFF8F00),
                        ),
                      ),
                    ),
                  ],
                ),
                SizedBox(height: isSmallScreen ? 2 : 4),

                // Status and Stats
                Row(
                  children: [
                    Icon(
                      isOnline ? Icons.circle : Icons.access_time,
                      size: isSmallScreen ? 10 : 12,
                      color: isOnline ? const Color(0xFF7ED321) : Colors.grey[400],
                    ),
                    SizedBox(width: isSmallScreen ? 3 : 4),
                    Text(
                      isOnline ? 'Online' : 'Offline',
                      style: TextStyle(
                        fontSize: isSmallScreen ? 10 : 12,
                        color: isOnline ? const Color(0xFF7ED321) : Colors.grey[500],
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    SizedBox(width: isSmallScreen ? 8 : 12),
                    Icon(
                      Icons.emoji_events,
                      size: isSmallScreen ? 10 : 12,
                      color: Colors.amber[700],
                    ),
                    SizedBox(width: isSmallScreen ? 3 : 4),
                    Expanded(
                      child: Text(
                        '$wins wins',
                        style: TextStyle(
                          fontSize: isSmallScreen ? 10 : 12,
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

          // Challenge Button
          GestureDetector(
            onTap: () => _challengeFriend(friend),
            child: Container(
              padding: EdgeInsets.symmetric(
                horizontal: isSmallScreen ? 12 : 16,
                vertical: isSmallScreen ? 6 : 8,
              ),
              decoration: BoxDecoration(
                gradient: isOnline
                    ? const LinearGradient(
                        colors: [Color(0xFF5B9EF3), Color(0xFF42A5F5)],
                      )
                    : null,
                color: isOnline ? null : Colors.grey[300],
                borderRadius: BorderRadius.circular(isSmallScreen ? 16 : 20),
                boxShadow: isOnline ? [
                  BoxShadow(
                    color: const Color(0xFF5B9EF3).withValues(alpha: 0.3),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ] : null,
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.sports_martial_arts,
                    size: isSmallScreen ? 14 : 16,
                    color: isOnline ? Colors.white : Colors.grey[500],
                  ),
                  SizedBox(width: isSmallScreen ? 4 : 6),
                  Text(
                    isSmallScreen ? 'Fight' : 'Challenge',
                    style: TextStyle(
                      fontSize: isSmallScreen ? 10 : 12,
                      fontWeight: FontWeight.bold,
                      color: isOnline ? Colors.white : Colors.grey[500],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _challengeFriend(Map<String, dynamic> friend) {
    final isOnline = friend['isOnline'] ?? false;

    if (!isOnline) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('${friend['name']} is currently offline'),
          backgroundColor: Colors.grey[600],
          duration: const Duration(seconds: 2),
        ),
      );
      return;
    }

    // Close the friends dialog first
    Navigator.pop(context);

    // Show the challenge setup dialog
    _showChallengeSetupDialog(friend);
  }

  void _showChallengeSetupDialog(Map<String, dynamic> friend) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        String selectedDifficulty = 'easy';
        String selectedOperator = '+';

        return StatefulBuilder(
          builder: (context, setState) {
            return LayoutBuilder(
              builder: (context, constraints) {
                final screenWidth = MediaQuery.of(context).size.width;
                final screenHeight = MediaQuery.of(context).size.height;
                final isSmallScreen = screenWidth < 360;

                return AlertDialog(
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(20),
                  ),
                  insetPadding: EdgeInsets.symmetric(
                    horizontal: isSmallScreen ? 16 : 24,
                    vertical: isSmallScreen ? 24 : 40,
                  ),
                  contentPadding: EdgeInsets.zero,
                  titlePadding: EdgeInsets.zero,
                  title: Container(
                    padding: EdgeInsets.all(isSmallScreen ? 16 : 20),
                    decoration: const BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.only(
                        topLeft: Radius.circular(20),
                        topRight: Radius.circular(20),
                      ),
                    ),
                    child: Row(
                      children: [
                        UserAvatar(
                          avatar: friend['avatar'] ?? '🦊',
                          size: isSmallScreen ? 28 : 32,
                          gradientColors: const [Color(0xFF7ED321), Color(0xFF9ACD32)],
                        ),
                        SizedBox(width: isSmallScreen ? 8 : 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                'Challenge ${friend['name']}',
                                style: TextStyle(
                                  fontSize: isSmallScreen ? 16 : 18,
                                  fontWeight: FontWeight.bold,
                                  color: const Color(0xFF2C3E50),
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                              Text(
                                'Setup your duel',
                                style: TextStyle(
                                  fontSize: isSmallScreen ? 12 : 14,
                                  color: Colors.grey[600],
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  content: Container(
                    constraints: BoxConstraints(
                      maxHeight: screenHeight * 0.6,
                      maxWidth: screenWidth - (isSmallScreen ? 32 : 48),
                    ),
                    padding: EdgeInsets.all(isSmallScreen ? 16 : 20),
                    child: SingleChildScrollView(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Choose your challenge level:',
                            style: TextStyle(
                              fontSize: isSmallScreen ? 14 : 16,
                              fontWeight: FontWeight.w600,
                              color: const Color(0xFF2C3E50),
                            ),
                          ),
                          SizedBox(height: isSmallScreen ? 12 : 15),

                          // Difficulty Selection
                          Container(
                            decoration: BoxDecoration(
                              border: Border.all(color: Colors.grey[300]!),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Column(
                              children: [
                                _buildDifficultyOption(
                                  'easy', 'Easy', '1-10 numbers', const Color(0xFF7ED321),
                                  selectedDifficulty, (value) => setState(() => selectedDifficulty = value)
                                ),
                                const Divider(height: 1),
                                _buildDifficultyOption(
                                  'medium', 'Medium', '10-100 numbers', const Color(0xFFFFA500),
                                  selectedDifficulty, (value) => setState(() => selectedDifficulty = value)
                                ),
                                const Divider(height: 1),
                                _buildDifficultyOption(
                                  'hard', 'Hard', '100+ numbers', const Color(0xFFFF6B6B),
                                  selectedDifficulty, (value) => setState(() => selectedDifficulty = value)
                                ),
                              ],
                            ),
                          ),

                          SizedBox(height: isSmallScreen ? 16 : 20),

                          Text(
                            'Choose operation:',
                            style: TextStyle(
                              fontSize: isSmallScreen ? 14 : 16,
                              fontWeight: FontWeight.w600,
                              color: const Color(0xFF2C3E50),
                            ),
                          ),
                          SizedBox(height: isSmallScreen ? 12 : 15),

                          // Operation Selection
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                            children: [
                              _buildOperatorButton('+', selectedOperator, (op) => setState(() => selectedOperator = op)),
                              _buildOperatorButton('-', selectedOperator, (op) => setState(() => selectedOperator = op)),
                              _buildOperatorButton('×', selectedOperator, (op) => setState(() => selectedOperator = op)),
                              _buildOperatorButton('÷', selectedOperator, (op) => setState(() => selectedOperator = op)),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.pop(context),
                      child: Text(
                        'Cancel',
                        style: TextStyle(
                          color: Colors.grey[600],
                          fontSize: isSmallScreen ? 12 : 14,
                        ),
                      ),
                    ),
                    ElevatedButton(
                      onPressed: () {
                        Navigator.pop(context);
                        _sendFriendChallenge(friend, selectedDifficulty, selectedOperator);
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF5B9EF3),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        padding: EdgeInsets.symmetric(
                          horizontal: isSmallScreen ? 16 : 24,
                          vertical: isSmallScreen ? 8 : 12,
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.sports_martial_arts,
                            color: Colors.white,
                            size: isSmallScreen ? 16 : 18,
                          ),
                          SizedBox(width: isSmallScreen ? 6 : 8),
                          Text(
                            isSmallScreen ? 'Challenge' : 'Send Challenge',
                            style: TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                              fontSize: isSmallScreen ? 12 : 14,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                );
              },
            );
          },
        );
      },
    );
  }

  void _sendFriendChallenge(Map<String, dynamic> friend, String difficulty, String operator) async {
    try {
      // Use the quiz duel service to create a friend challenge
      final QuizDuelService duelService = QuizDuelService();
      final gameId = await duelService.challengeFriend(
        friendId: friend['id'],
        difficulty: difficulty,
        operator: operator,
        topicName: 'Mixed Operations', // You can make this configurable
      );

      if (gameId != null) {
        // Show success message
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                Icon(Icons.check_circle, color: Colors.white),
                SizedBox(width: 8),
                Text('Challenge sent to ${friend['name']}!'),
              ],
            ),
            backgroundColor: Color(0xFF7ED321),
            duration: const Duration(seconds: 2),
          ),
        );

        // Show floating challenge widget
        FloatingChallengeService().showFloatingChallenge(
          context,
          FloatingChallengeData(
            friendId: friend['id'],
            friendName: friend['name'],
            friendAvatar: friend['avatar'] ?? '🦊',
            topicName: 'Mixed Operations',
            operator: operator,
            difficulty: difficulty,
            gameId: gameId,
          ),
        );
      } else {
        // Show error message
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                Icon(Icons.error, color: Colors.white),
                SizedBox(width: 8),
                Text('Failed to send challenge. Please try again.'),
              ],
            ),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 3),
          ),
        );
      }
    } catch (e) {
      // Handle error
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              Icon(Icons.error, color: Colors.white),
              SizedBox(width: 8),
              Text('Error sending challenge: $e'),
            ],
          ),
          backgroundColor: Colors.red,
          duration: const Duration(seconds: 3),
        ),
      );
    }
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