import 'package:flutter/material.dart';
import '../models/math_topic.dart';
import '../services/math_service.dart';
import '../services/firestore_service.dart';
import '../services/auth_service.dart';
import '../services/user_preferences_service.dart';
import '../services/progression_service.dart';
import 'simple_math_practice_screen.dart';

class SoloPracticeScreen extends StatefulWidget {
  final int? difficulty;
  
  const SoloPracticeScreen({super.key, this.difficulty});

  @override
  State<SoloPracticeScreen> createState() => _SoloPracticeScreenState();
}

class _SoloPracticeScreenState extends State<SoloPracticeScreen> {
  final FirestoreService _firestoreService = FirestoreService();
  final AuthService _authService = AuthService();
  final UserPreferencesService _prefsService = UserPreferencesService.instance;
  final ProgressionService _progressionService = ProgressionService.instance;
  List<MathTopic> topics = [];
  bool isLoading = true;
  
  // Simple offline progress tracking
  Set<String> completedSessions = {};

  @override
  void initState() {
    super.initState();
    _loadTopics();
  }

  Future<void> _loadTopics() async {
    try {
      final user = _authService.currentUser;
      if (user == null) {
        // If no user, just load default topics with simple progression
        final defaultTopics = MathService.getDefaultTopics();
        // Apply progression rules
        final updatedTopics = await _progressionService.applyProgressionRules(defaultTopics);
        setState(() {
          topics = updatedTopics;
          isLoading = false;
        });
        return;
      }

      final defaultTopics = MathService.getDefaultTopics();
      final cloudTopics = await _firestoreService.getUpdatedTopicsWithProgress(
        user.uid,
        defaultTopics,
      );
      
      // Apply progression rules
      final updatedTopics = await _progressionService.applyProgressionRules(cloudTopics);

      setState(() {
        topics = updatedTopics;
        isLoading = false;
      });
    } catch (e) {
      // Fallback to default topics if there's an error
      final defaultTopics = MathService.getDefaultTopics();
      final updatedTopics = await _progressionService.applyProgressionRules(defaultTopics);
      setState(() {
        topics = updatedTopics;
        isLoading = false;
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Using offline mode')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (isLoading) {
      return Scaffold(
        backgroundColor: const Color(0xFFF5F7FA),
        body: const Center(
          child: CircularProgressIndicator(),
        ),
      );
    }
    return Scaffold(
      backgroundColor: Color(0xFFF5F7FA),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back_ios, color: Color(0xFF2C3E50)),
          onPressed: () => Navigator.pop(context),
        ),
        title: Row(
          children: [
            Container(
              padding: EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Color(0xFF5B9EF3).withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(
                Icons.school,
                color: Color(0xFF5B9EF3),
                size: 20,
              ),
            ),
            SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'LearnMath',
                    style: TextStyle(
                      color: Color(0xFF2C3E50),
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  Text(
                    'Choose Your Lesson',
                    style: TextStyle(
                      color: Colors.grey[600],
                      fontSize: 12,
                      fontWeight: FontWeight.normal,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          Container(
            margin: EdgeInsets.only(right: 16),
            padding: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: Color(0xFF7ED321).withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Row(
              children: [
                Icon(
                  Icons.star,
                  color: Color(0xFF7ED321),
                  size: 16,
                ),
                SizedBox(width: 4),
                Text(
                  '47',
                  style: TextStyle(
                    color: Color(0xFF7ED321),
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
      body: SingleChildScrollView(
        child: Padding(
          padding: EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Continue Learning Card
              Container(
                padding: EdgeInsets.all(20),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [Color(0xFF5B9EF3), Color(0xFF3F7FDB)],
                  ),
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: [
                    BoxShadow(
                      color: Color(0xFF5B9EF3).withValues(alpha: 0.3),
                      blurRadius: 15,
                      offset: Offset(0, 8),
                    ),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Continue Learning',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    SizedBox(height: 10),
                    Text(
                      'Addition - Lesson 3',
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.9),
                        fontSize: 14,
                      ),
                    ),
                    SizedBox(height: 15),
                    Row(
                      children: [
                        Expanded(
                          child: Container(
                            height: 8,
                            decoration: BoxDecoration(
                              color: Colors.white.withValues(alpha: 0.3),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: FractionallySizedBox(
                              alignment: Alignment.centerLeft,
                              widthFactor: 0.65,
                              child: Container(
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  borderRadius: BorderRadius.circular(4),
                                ),
                              ),
                            ),
                          ),
                        ),
                        SizedBox(width: 10),
                        Text(
                          '65%',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                    SizedBox(height: 15),
                    ElevatedButton(
                      onPressed: () {
                        // Continue lesson
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.white,
                        foregroundColor: Color(0xFF5B9EF3),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        padding: EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                      ),
                      child: Text(
                        'Continue',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              
              SizedBox(height: 25),
              
              // Math Topics
              Text(
                'Math Topics',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF2C3E50),
                ),
              ),
              SizedBox(height: 15),
              
              // Dynamic topic cards from loaded data
              ...topics.map((topic) => Column(
                children: [
                  _buildTopicCard(topic),
                  const SizedBox(height: 15),
                ],
              )),
            ],
          ),
        ),
      ),
    );
  }
  
  Widget _buildTopicCard(MathTopic topic) {
    Color color = _getTopicColor(topic.id);
    IconData icon = _getTopicIcon(topic.id);
    bool isInProgress = topic.completedLessons > 0 && !topic.isCompleted;

    return GestureDetector(
      onTap: topic.isUnlocked ? () async {
        // Get saved difficulty preference
        final difficultyIndex = await _prefsService.getSelectedDifficulty();
        final difficultyString = _prefsService.getDifficultyString(difficultyIndex);
        
        if (mounted) {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => SimpleMathPracticeScreen(
                topicName: topic.name,
                operator: topic.operator,
                difficulty: difficultyString,
                onSessionComplete: (double accuracy) => _onSessionComplete(topic.id, difficultyString, accuracy),
              ),
            ),
          ).then((_) => _loadTopics());
        }
      } : () {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Complete previous topics to unlock ${topic.name}'),
            duration: const Duration(seconds: 2),
          ),
        );
      },
      child: Container(
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
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              // Icon Container
              Container(
                width: 50,
                height: 50,
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(15),
                ),
                child: Icon(
                  topic.isUnlocked ? icon : Icons.lock,
                  color: topic.isUnlocked ? color : Colors.grey,
                  size: 24,
                ),
              ),
              const SizedBox(width: 15),
              
              // Content
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          topic.name,
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                            color: topic.isUnlocked ? const Color(0xFF2C3E50) : Colors.grey,
                          ),
                        ),
                        if (topic.isUnlocked)
                          Row(
                            children: List.generate(
                              5,
                              (index) => Icon(
                                Icons.star,
                                size: 14,
                                color: index < topic.stars ? Colors.amber : Colors.grey[300],
                              ),
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${topic.totalLessons} Lessons',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey[600],
                      ),
                    ),
                    if (topic.isUnlocked) ...[
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          if (isInProgress)
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                              decoration: BoxDecoration(
                                color: Colors.orange.withValues(alpha: 0.1),
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: const Text(
                                'In Progress',
                                style: TextStyle(
                                  fontSize: 10,
                                  color: Colors.orange,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Row(
                              children: [
                                const Text(
                                  'Progress',
                                  style: TextStyle(
                                    fontSize: 11,
                                    color: Colors.grey,
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  topic.progressText,
                                  style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w600,
                                    color: color,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ] else ...[
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          const Icon(
                            Icons.lock,
                            size: 12,
                            color: Colors.grey,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            'Complete previous topics to unlock',
                            style: TextStyle(
                              fontSize: 11,
                              color: Colors.grey[600],
                            ),
                          ),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Color _getTopicColor(String topicId) {
    switch (topicId) {
      case 'addition':
        return const Color(0xFF7ED321);
      case 'subtraction':
        return const Color(0xFFFFA500);
      case 'multiplication':
        return const Color(0xFFE91E63);
      case 'division':
        return const Color(0xFFFF6B6B);
      default:
        return const Color(0xFF5B9EF3);
    }
  }

  IconData _getTopicIcon(String topicId) {
    switch (topicId) {
      case 'addition':
        return Icons.add;
      case 'subtraction':
        return Icons.remove;
      case 'multiplication':
        return Icons.close;
      case 'division':
        return Icons.more_horiz;
      default:
        return Icons.calculate;
    }
  }


  void _onSessionComplete(String topicId, String difficulty, double accuracy) async {
    completedSessions.add(topicId);
    
    // Update progression and check for unlocks
    Map<String, dynamic> progressionResult = await _progressionService.updateProgression(
      topicId, 
      difficulty, 
      accuracy, 
      topics
    );
    
    // Show congratulations if new topic unlocked
    if (progressionResult['newTopicUnlocked'] == true) {
      if (mounted) {
        String unlockedTopicId = progressionResult['unlockedTopicId'];
        String topicName = topics.firstWhere((t) => t.id == unlockedTopicId).name;
        
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('🎉 Perfect score! $topicName unlocked!'),
            backgroundColor: Colors.green,
            duration: const Duration(seconds: 4),
          ),
        );
      }
    } else if (progressionResult['perfectScore'] == true) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('🌟 Perfect score achieved!'),
            backgroundColor: Colors.amber,
            duration: const Duration(seconds: 3),
          ),
        );
      }
    }
  }
}