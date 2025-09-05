import 'package:flutter/material.dart';
import 'dart:async';
import '../models/math_question.dart';
import '../services/quiz_engine.dart';
import '../services/quiz_progress_service.dart';

class AdaptiveQuizScreen extends StatefulWidget {
  const AdaptiveQuizScreen({super.key});

  @override
  State<AdaptiveQuizScreen> createState() => _AdaptiveQuizScreenState();
}

class _AdaptiveQuizScreenState extends State<AdaptiveQuizScreen>
    with TickerProviderStateMixin {
  final QuizEngine _quizEngine = QuizEngine();
  final QuizProgressService _progressService = QuizProgressService();
  late AnimationController _feedbackController;
  late AnimationController _difficultyController;
  late Animation<double> _feedbackAnimation;
  late Animation<Color?> _backgroundAnimation;
  
  MathQuestion? _currentQuestion;
  int? _selectedAnswer;
  bool _showFeedback = false;
  bool _isCorrect = false;
  String _feedbackText = '';
  Timer? _feedbackTimer;
  
  @override
  void initState() {
    super.initState();
    _setupAnimations();
    _generateNewQuestion();
  }
  
  void _setupAnimations() {
    _feedbackController = AnimationController(
      duration: const Duration(milliseconds: 600),
      vsync: this,
    );
    
    _difficultyController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );
    
    _feedbackAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _feedbackController,
      curve: Curves.elasticOut,
    ));
    
    _backgroundAnimation = ColorTween(
      begin: const Color(0xFFF5F7FA),
      end: const Color(0xFFF5F7FA),
    ).animate(_feedbackController);
  }
  
  @override
  void dispose() {
    _feedbackController.dispose();
    _difficultyController.dispose();
    _feedbackTimer?.cancel();
    super.dispose();
  }
  
  void _generateNewQuestion() {
    setState(() {
      _currentQuestion = _quizEngine.generateQuestion();
      _selectedAnswer = null;
      _showFeedback = false;
    });
  }
  
  void _selectAnswer(int answer) {
    if (_selectedAnswer != null || _showFeedback) return;
    
    setState(() {
      _selectedAnswer = answer;
      _isCorrect = answer == _currentQuestion!.correctAnswer;
      _feedbackText = _isCorrect ? 'Correct! ✓' : 'Try Again ✗';
      _showFeedback = true;
    });
    
    _quizEngine.submitAnswer(_currentQuestion!, answer);
    
    // Save attempt to Firebase
    _progressService.saveQuizAttempt(_quizEngine.attempts.last);
    
    _backgroundAnimation = ColorTween(
      begin: const Color(0xFFF5F7FA),
      end: _isCorrect 
          ? const Color(0xFFE8F5E8) 
          : const Color(0xFFFFE8E8),
    ).animate(_feedbackController);
    
    _feedbackController.forward().then((_) {
      _feedbackTimer = Timer(const Duration(seconds: 2), () {
        _feedbackController.reverse().then((_) {
          if (mounted) {
            final stats = _quizEngine.getStats();
            if (stats['isQuizComplete'] == true) {
              _showQuizCompletionDialog();
            } else if (stats['requiresLevelReset'] == true) {
              _showLevelResetDialog();
            } else {
              _generateNewQuestion();
            }
          }
        });
      });
    });
  }
  
  Color _getAnswerButtonColor(int option) {
    if (!_showFeedback) {
      return _selectedAnswer == option 
          ? const Color(0xFF5B9EF3)
          : Colors.white;
    }
    
    if (option == _currentQuestion!.correctAnswer) {
      return const Color(0xFF7ED321);
    } else if (option == _selectedAnswer && !_isCorrect) {
      return const Color(0xFFFF6B6B);
    } else {
      return Colors.grey[200]!;
    }
  }
  
  Color _getAnswerTextColor(int option) {
    if (!_showFeedback) {
      return _selectedAnswer == option ? Colors.white : const Color(0xFF2C3E50);
    }
    
    if (option == _currentQuestion!.correctAnswer) {
      return Colors.white;
    } else if (option == _selectedAnswer && !_isCorrect) {
      return Colors.white;
    } else {
      return Colors.grey[600]!;
    }
  }
  
  String _getDifficultyDisplayName() {
    switch (_quizEngine.currentDifficulty) {
      case DifficultyLevel.easy:
        return 'Easy';
      case DifficultyLevel.medium:
        return 'Medium';
      case DifficultyLevel.hard:
        return 'Hard';
    }
  }

  String _getOperationDisplayName() {
    switch (_quizEngine.currentOperation) {
      case MathOperation.addition:
        return 'Addition';
      case MathOperation.subtraction:
        return 'Subtraction';
      case MathOperation.multiplication:
        return 'Multiplication';
      case MathOperation.division:
        return 'Division';
    }
  }
  
  Color _getDifficultyColor() {
    switch (_quizEngine.currentDifficulty) {
      case DifficultyLevel.easy:
        return const Color(0xFF7ED321);
      case DifficultyLevel.medium:
        return const Color(0xFFFFA500);
      case DifficultyLevel.hard:
        return const Color(0xFFFF6B6B);
    }
  }
  
  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _backgroundAnimation,
      builder: (context, child) {
        return Scaffold(
          backgroundColor: _backgroundAnimation.value,
          appBar: _buildAppBar(),
          body: _currentQuestion == null 
              ? const Center(child: CircularProgressIndicator())
              : _buildBody(),
        );
      },
    );
  }
  
  PreferredSizeWidget _buildAppBar() {
    return PreferredSize(
      preferredSize: const Size.fromHeight(56),
      child: LayoutBuilder(
      builder: (context, constraints) {
        final screenWidth = MediaQuery.of(context).size.width;
        final isSmallScreen = screenWidth < 360;
        final isMediumScreen = screenWidth < 500;
        
        return AppBar(
          backgroundColor: Colors.transparent,
          elevation: 0,
          leading: IconButton(
            icon: const Icon(Icons.arrow_back, color: Color(0xFF2C3E50)),
            onPressed: () => _showQuitDialog(),
          ),
          title: Text(
            'Adaptive Quiz',
            style: TextStyle(
              color: const Color(0xFF2C3E50),
              fontSize: isSmallScreen ? 16 : 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          actions: [
            if (!isSmallScreen) ...[
              Container(
                margin: EdgeInsets.only(right: isMediumScreen ? 4 : 8),
                padding: EdgeInsets.symmetric(
                  horizontal: isMediumScreen ? 8 : 10, 
                  vertical: 4
                ),
                decoration: BoxDecoration(
                  color: const Color(0xFF5B9EF3).withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: const Color(0xFF5B9EF3), width: 1),
                ),
                child: Text(
                  _getOperationDisplayName(),
                  style: TextStyle(
                    fontSize: isMediumScreen ? 10 : 11,
                    fontWeight: FontWeight.bold,
                    color: const Color(0xFF5B9EF3),
                  ),
                ),
              ),
            ],
            Container(
              margin: EdgeInsets.only(right: isMediumScreen ? 8 : 16),
              padding: EdgeInsets.symmetric(
                horizontal: isMediumScreen ? 8 : 10, 
                vertical: 4
              ),
              decoration: BoxDecoration(
                color: _getDifficultyColor().withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: _getDifficultyColor(), width: 1),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.speed,
                    size: isMediumScreen ? 12 : 14,
                    color: _getDifficultyColor(),
                  ),
                  SizedBox(width: isMediumScreen ? 2 : 4),
                  Text(
                    isSmallScreen ? _getDifficultyDisplayName().substring(0, 1) : _getDifficultyDisplayName(),
                    style: TextStyle(
                      fontSize: isMediumScreen ? 10 : 11,
                      fontWeight: FontWeight.bold,
                      color: _getDifficultyColor(),
                    ),
                  ),
                ],
              ),
            ),
            if (isSmallScreen)
              PopupMenuButton<String>(
                icon: const Icon(Icons.more_vert, color: Color(0xFF2C3E50)),
                onSelected: (value) {},
                itemBuilder: (context) => [
                  PopupMenuItem(
                    value: 'operation',
                    child: Text(_getOperationDisplayName()),
                  ),
                ],
              ),
          ],
        );
      },
      ),
    );
  }
  
  Widget _buildBody() {
    final stats = _quizEngine.getStats();
    
    return SafeArea(
      child: LayoutBuilder(
        builder: (context, constraints) {
          final screenHeight = constraints.maxHeight;
          final isShortScreen = screenHeight < 600;
          
          return SingleChildScrollView(
            physics: const BouncingScrollPhysics(),
            child: ConstrainedBox(
              constraints: BoxConstraints(minHeight: screenHeight),
              child: Padding(
                padding: EdgeInsets.symmetric(
                  horizontal: MediaQuery.of(context).size.width * 0.05,
                  vertical: isShortScreen ? 10 : 20,
                ),
                child: Column(
                  children: [
                    _buildStatsBar(stats),
                    SizedBox(height: isShortScreen ? 15 : 30),
                    _buildQuestionCard(),
                    SizedBox(height: isShortScreen ? 15 : 30),
                    _buildAnswerOptions(),
                    SizedBox(height: isShortScreen ? 10 : 20),
                    if (_showFeedback) _buildFeedback(),
                    SizedBox(height: isShortScreen ? 20 : 40),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }
  
  Widget _buildStatsBar(Map<String, dynamic> stats) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final screenWidth = MediaQuery.of(context).size.width;
        final isSmallScreen = screenWidth < 360;
        final isMediumScreen = screenWidth < 500;
        
        if (isSmallScreen) {
          return Column(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
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
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: [
                    _buildStatItem(
                      icon: Icons.quiz,
                      label: 'Total',
                      value: '${stats['totalQuestions']}',
                      color: const Color(0xFF5B9EF3),
                      isCompact: true,
                    ),
                    Container(width: 1, height: 25, color: Colors.grey[300]),
                    _buildStatItem(
                      icon: Icons.check_circle,
                      label: 'Correct',
                      value: '${stats['correctAnswers']}',
                      color: const Color(0xFF7ED321),
                      isCompact: true,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 10),
              Container(
                padding: const EdgeInsets.all(12),
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
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: [
                    _buildStatItem(
                      icon: Icons.trending_up,
                      label: 'Progress',
                      value: '${stats['correctAnswersInCurrentLevel']}/10',
                      color: const Color(0xFF9B59B6),
                      isCompact: true,
                    ),
                    Container(width: 1, height: 25, color: Colors.grey[300]),
                    _buildStatItem(
                      icon: Icons.local_fire_department,
                      label: 'Streak',
                      value: '${stats['currentStreak']}',
                      color: const Color(0xFFFFA500),
                      isCompact: true,
                    ),
                  ],
                ),
              ),
            ],
          );
        } else {
          return Container(
            padding: EdgeInsets.all(isMediumScreen ? 12 : 16),
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
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                Flexible(
                  child: _buildStatItem(
                    icon: Icons.quiz,
                    label: isMediumScreen ? 'Total' : 'Questions',
                    value: '${stats['totalQuestions']}',
                    color: const Color(0xFF5B9EF3),
                    isCompact: isMediumScreen,
                  ),
                ),
                Container(width: 1, height: isMediumScreen ? 25 : 30, color: Colors.grey[300]),
                Flexible(
                  child: _buildStatItem(
                    icon: Icons.check_circle,
                    label: 'Correct',
                    value: '${stats['correctAnswers']}',
                    color: const Color(0xFF7ED321),
                    isCompact: isMediumScreen,
                  ),
                ),
                Container(width: 1, height: isMediumScreen ? 25 : 30, color: Colors.grey[300]),
                Flexible(
                  child: _buildStatItem(
                    icon: Icons.trending_up,
                    label: isMediumScreen ? 'Progress' : 'Level Progress',
                    value: '${stats['correctAnswersInCurrentLevel']}/10',
                    color: const Color(0xFF9B59B6),
                    isCompact: isMediumScreen,
                  ),
                ),
                Container(width: 1, height: isMediumScreen ? 25 : 30, color: Colors.grey[300]),
                Flexible(
                  child: _buildStatItem(
                    icon: Icons.local_fire_department,
                    label: 'Streak',
                    value: '${stats['currentStreak']}',
                    color: const Color(0xFFFFA500),
                    isCompact: isMediumScreen,
                  ),
                ),
              ],
            ),
          );
        }
      },
    );
  }
  
  Widget _buildStatItem({
    required IconData icon,
    required String label,
    required String value,
    required Color color,
    bool isCompact = false,
  }) {
    return Column(
      children: [
        Icon(
          icon, 
          color: color, 
          size: isCompact ? 16 : 20,
        ),
        SizedBox(height: isCompact ? 2 : 4),
        Text(
          value,
          style: TextStyle(
            fontSize: isCompact ? 14 : 16,
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
        Text(
          label,
          style: TextStyle(
            fontSize: isCompact ? 8 : 10,
            color: Colors.grey[600],
          ),
          textAlign: TextAlign.center,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
      ],
    );
  }
  
  Widget _buildQuestionCard() {
    return LayoutBuilder(
      builder: (context, constraints) {
        final screenWidth = MediaQuery.of(context).size.width;
        final screenHeight = MediaQuery.of(context).size.height;
        final isSmallScreen = screenWidth < 360;
        final isMediumScreen = screenWidth < 500;
        final isShortScreen = screenHeight < 600;
        
        return Container(
          width: double.infinity,
          padding: EdgeInsets.all(
            isSmallScreen ? 16 : isMediumScreen ? 20 : 24
          ),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(isSmallScreen ? 15 : 20),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.1),
                blurRadius: isSmallScreen ? 15 : 20,
                offset: const Offset(0, 5),
              ),
            ],
          ),
          child: Column(
            children: [
              if (!isSmallScreen)
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Flexible(
                      child: Text(
                        'Solve this problem:',
                        style: TextStyle(
                          fontSize: isMediumScreen ? 12 : 14,
                          color: Colors.grey[600],
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                    Container(
                      padding: EdgeInsets.symmetric(
                        horizontal: isMediumScreen ? 6 : 8, 
                        vertical: 4
                      ),
                      decoration: BoxDecoration(
                        color: const Color(0xFF9B59B6).withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: const Color(0xFF9B59B6), width: 1),
                      ),
                      child: Text(
                        isMediumScreen ? 'Perfect Score' : 'Perfect Score Required',
                        style: TextStyle(
                          fontSize: isMediumScreen ? 8 : 10,
                          fontWeight: FontWeight.bold,
                          color: const Color(0xFF9B59B6),
                        ),
                      ),
                    ),
                  ],
                ),
              if (isSmallScreen) ...[
                Text(
                  'Solve this problem:',
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey[600],
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: const Color(0xFF9B59B6).withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: const Color(0xFF9B59B6), width: 1),
                  ),
                  child: const Text(
                    'Perfect Score Required',
                    style: TextStyle(
                      fontSize: 9,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF9B59B6),
                    ),
                  ),
                ),
              ],
              SizedBox(height: isSmallScreen ? 12 : isShortScreen ? 15 : 20),
              FittedBox(
                fit: BoxFit.scaleDown,
                child: Text(
                  _currentQuestion!.questionText,
                  style: TextStyle(
                    fontSize: _getQuestionFontSize(screenWidth, screenHeight),
                    fontWeight: FontWeight.bold,
                    color: const Color(0xFF2C3E50),
                  ),
                  textAlign: TextAlign.center,
                ),
              ),
            ],
          ),
        );
      },
    );
  }
  
  double _getQuestionFontSize(double screenWidth, double screenHeight) {
    if (screenWidth < 360 || screenHeight < 600) {
      return 24; // Small screens
    } else if (screenWidth < 500 || screenHeight < 700) {
      return 28; // Medium screens
    } else {
      return 32; // Large screens
    }
  }
  
  Widget _buildAnswerOptions() {
    return LayoutBuilder(
      builder: (context, constraints) {
        final screenWidth = MediaQuery.of(context).size.width;
        final screenHeight = MediaQuery.of(context).size.height;
        final isSmallScreen = screenWidth < 360;
        final isMediumScreen = screenWidth < 500;
        final isShortScreen = screenHeight < 600;
        
        // For very small screens, use grid layout
        if (isSmallScreen && screenHeight < 650) {
          return GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              childAspectRatio: 2.5,
              crossAxisSpacing: 8,
              mainAxisSpacing: 8,
            ),
            itemCount: _currentQuestion!.options.length,
            itemBuilder: (context, index) {
              final option = _currentQuestion!.options[index];
              return ElevatedButton(
                onPressed: () => _selectAnswer(option),
                style: ElevatedButton.styleFrom(
                  backgroundColor: _getAnswerButtonColor(option),
                  foregroundColor: _getAnswerTextColor(option),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  elevation: _showFeedback ? 0 : 2,
                ),
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Text(
                    '$option',
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              );
            },
          );
        }
        
        // For regular screens, use column layout
        return Column(
          children: _currentQuestion!.options.map((option) {
            return Padding(
              padding: EdgeInsets.only(
                bottom: isSmallScreen ? 8 : isShortScreen ? 10 : 12
              ),
              child: SizedBox(
                width: double.infinity,
                height: _getButtonHeight(screenWidth, screenHeight),
                child: ElevatedButton(
                  onPressed: () => _selectAnswer(option),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _getAnswerButtonColor(option),
                    foregroundColor: _getAnswerTextColor(option),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(
                        isSmallScreen ? 12 : 15
                      ),
                    ),
                    elevation: _showFeedback ? 0 : 2,
                  ),
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Text(
                      '$option',
                      style: TextStyle(
                        fontSize: _getAnswerFontSize(screenWidth, screenHeight),
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
              ),
            );
          }).toList(),
        );
      },
    );
  }
  
  double _getButtonHeight(double screenWidth, double screenHeight) {
    if (screenWidth < 360 || screenHeight < 600) {
      return 45; // Small screens
    } else if (screenWidth < 500 || screenHeight < 700) {
      return 52; // Medium screens
    } else {
      return 60; // Large screens
    }
  }
  
  double _getAnswerFontSize(double screenWidth, double screenHeight) {
    if (screenWidth < 360 || screenHeight < 600) {
      return 16; // Small screens
    } else if (screenWidth < 500 || screenHeight < 700) {
      return 18; // Medium screens
    } else {
      return 20; // Large screens
    }
  }
  
  Widget _buildFeedback() {
    return AnimatedBuilder(
      animation: _feedbackAnimation,
      builder: (context, child) {
        return Transform.scale(
          scale: _feedbackAnimation.value,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
            decoration: BoxDecoration(
              color: _isCorrect 
                  ? const Color(0xFF7ED321) 
                  : const Color(0xFFFF6B6B),
              borderRadius: BorderRadius.circular(25),
              boxShadow: [
                BoxShadow(
                  color: (_isCorrect 
                      ? const Color(0xFF7ED321) 
                      : const Color(0xFFFF6B6B)
                  ).withValues(alpha: 0.3),
                  blurRadius: 15,
                  offset: const Offset(0, 5),
                ),
              ],
            ),
            child: Text(
              _feedbackText,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        );
      },
    );
  }
  
  void _showQuitDialog() {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(15),
          ),
          title: const Text(
            'Quit Quiz?',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Color(0xFF2C3E50),
            ),
          ),
          content: const Text(
            'Your progress will be saved. Are you sure you want to quit?',
            style: TextStyle(
              fontSize: 14,
              color: Color(0xFF2C3E50),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text(
                'Continue',
                style: TextStyle(color: Color(0xFF5B9EF3)),
              ),
            ),
            ElevatedButton(
              onPressed: () async {
                Navigator.pop(context);
                await _endQuizSession();
                if (mounted) {
                  Navigator.pop(context);
                }
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFFF6B6B),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
              child: const Text(
                'Quit',
                style: TextStyle(color: Colors.white),
              ),
            ),
          ],
        );
      },
    );
  }
  
  Future<void> _endQuizSession() async {
    final stats = _quizEngine.getStats();
    
    if (_quizEngine.attempts.isNotEmpty) {
      await _progressService.saveQuizSession(_quizEngine.attempts, stats);
    }
    
    if (mounted) {
      _showSessionSummary(stats);
    }
  }
  
  void _showLevelResetDialog() {
    final stats = _quizEngine.getStats();
    final correctAnswers = stats['correctAnswersInCurrentLevel'] as int;
    final operation = _getOperationDisplayName();
    final difficulty = _getDifficultyDisplayName();
    
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return LayoutBuilder(
          builder: (context, constraints) {
            final screenWidth = MediaQuery.of(context).size.width;
            final screenHeight = MediaQuery.of(context).size.height;
            final isSmallScreen = screenWidth < 360;
            final isShortScreen = screenHeight < 600;
            
            return AlertDialog(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(isSmallScreen ? 15 : 20),
              ),
              contentPadding: EdgeInsets.all(isSmallScreen ? 16 : 20),
              content: ConstrainedBox(
                constraints: BoxConstraints(
                  maxWidth: screenWidth * 0.9,
                  maxHeight: screenHeight * 0.8,
                ),
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        '😔',
                        style: TextStyle(fontSize: isSmallScreen ? 40 : 50),
                      ),
                      SizedBox(height: isSmallScreen ? 12 : 16),
                      Text(
                        'Level Not Passed',
                        style: TextStyle(
                          fontSize: isSmallScreen ? 20 : 24,
                          fontWeight: FontWeight.bold,
                          color: const Color(0xFF2C3E50),
                        ),
                        textAlign: TextAlign.center,
                      ),
                      SizedBox(height: isSmallScreen ? 8 : 12),
                      Text(
                        'You need a perfect score (10/10) to advance to the next level.',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: isSmallScreen ? 14 : 16,
                          color: Colors.grey[600],
                        ),
                      ),
                      SizedBox(height: isSmallScreen ? 16 : 20),
                      Container(
                        padding: EdgeInsets.all(isSmallScreen ? 12 : 16),
                        decoration: BoxDecoration(
                          color: const Color(0xFFFF6B6B).withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(15),
                        ),
                        child: Column(
                          children: [
                            FittedBox(
                              fit: BoxFit.scaleDown,
                              child: Text(
                                '$operation - $difficulty',
                                style: TextStyle(
                                  fontSize: isSmallScreen ? 16 : 18,
                                  fontWeight: FontWeight.bold,
                                  color: const Color(0xFF2C3E50),
                                ),
                              ),
                            ),
                            SizedBox(height: isSmallScreen ? 6 : 8),
                            Text(
                              'Score: $correctAnswers/10',
                              style: TextStyle(
                                fontSize: isSmallScreen ? 14 : 16,
                                color: const Color(0xFFFF6B6B),
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                      ),
                      SizedBox(height: isSmallScreen ? 16 : 20),
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton(
                          onPressed: () {
                            Navigator.pop(context);
                            _generateNewQuestion();
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF5B9EF3),
                            padding: EdgeInsets.symmetric(
                              vertical: isSmallScreen ? 12 : 16
                            ),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(15),
                            ),
                          ),
                          child: Text(
                            'Try Again',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: isSmallScreen ? 14 : 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }

  void _showQuizCompletionDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return LayoutBuilder(
          builder: (context, constraints) {
            final screenWidth = MediaQuery.of(context).size.width;
            final screenHeight = MediaQuery.of(context).size.height;
            final isSmallScreen = screenWidth < 360;
            final isShortScreen = screenHeight < 600;
            
            return AlertDialog(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(isSmallScreen ? 15 : 20),
              ),
              contentPadding: EdgeInsets.all(isSmallScreen ? 16 : 20),
              content: ConstrainedBox(
                constraints: BoxConstraints(
                  maxWidth: screenWidth * 0.95,
                  maxHeight: screenHeight * 0.85,
                ),
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        '🎉',
                        style: TextStyle(fontSize: isSmallScreen ? 45 : 60),
                      ),
                      SizedBox(height: isSmallScreen ? 12 : 16),
                      FittedBox(
                        fit: BoxFit.scaleDown,
                        child: Text(
                          'Quiz Complete!',
                          style: TextStyle(
                            fontSize: isSmallScreen ? 24 : 28,
                            fontWeight: FontWeight.bold,
                            color: const Color(0xFF2C3E50),
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ),
                      SizedBox(height: isSmallScreen ? 8 : 12),
                      Text(
                        'Congratulations! You have completed all math operations across all difficulty levels.',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: isSmallScreen ? 14 : 16,
                          color: const Color(0xFF7F8C8D),
                        ),
                      ),
                      SizedBox(height: isSmallScreen ? 16 : 24),
                      Container(
                        padding: EdgeInsets.all(isSmallScreen ? 12 : 20),
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [
                              const Color(0xFF5B9EF3).withValues(alpha: 0.1),
                              const Color(0xFF7ED321).withValues(alpha: 0.1),
                            ],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                          borderRadius: BorderRadius.circular(15),
                        ),
                        child: Column(
                          children: [
                            _buildCompletionChecklistItem('Addition - All Levels Complete', isSmallScreen),
                            SizedBox(height: isSmallScreen ? 6 : 8),
                            _buildCompletionChecklistItem('Subtraction - All Levels Complete', isSmallScreen),
                            SizedBox(height: isSmallScreen ? 6 : 8),
                            _buildCompletionChecklistItem('Multiplication - All Levels Complete', isSmallScreen),
                            SizedBox(height: isSmallScreen ? 6 : 8),
                            _buildCompletionChecklistItem('Division - All Levels Complete', isSmallScreen),
                          ],
                        ),
                      ),
                      SizedBox(height: isSmallScreen ? 16 : 24),
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton(
                          onPressed: () async {
                            Navigator.pop(context);
                            await _endQuizSession();
                            if (mounted) {
                              Navigator.pop(context);
                            }
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF5B9EF3),
                            padding: EdgeInsets.symmetric(
                              vertical: isSmallScreen ? 12 : 16
                            ),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(15),
                            ),
                          ),
                          child: Text(
                            'Finish Quiz',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: isSmallScreen ? 16 : 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }
  
  Widget _buildCompletionChecklistItem(String text, bool isSmallScreen) {
    return FittedBox(
      fit: BoxFit.scaleDown,
      child: Text(
        '✓ $text',
        style: TextStyle(
          fontSize: isSmallScreen ? 12 : 14,
          color: const Color(0xFF27AE60),
        ),
      ),
    );
  }

  void _showSessionSummary(Map<String, dynamic> stats) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        final accuracy = stats['accuracy'] as double;
        final correctAnswers = stats['correctAnswers'] as int;
        final totalQuestions = stats['totalQuestions'] as int;
        
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                '🎉',
                style: TextStyle(fontSize: 50),
              ),
              const SizedBox(height: 16),
              const Text(
                'Great Job!',
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF2C3E50),
                ),
              ),
              const SizedBox(height: 20),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: const Color(0xFF5B9EF3).withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(15),
                ),
                child: Column(
                  children: [
                    _buildSummaryRow('Questions:', '$totalQuestions'),
                    _buildSummaryRow('Correct:', '$correctAnswers'),
                    _buildSummaryRow('Accuracy:', '${(accuracy * 100).round()}%'),
                    _buildSummaryRow('Best Streak:', '${stats['currentStreak']}'),
                  ],
                ),
              ),
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () {
                    Navigator.pop(context); // Close dialog
                    Navigator.pop(context); // Return to previous screen
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF5B9EF3),
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(15),
                    ),
                  ),
                  child: const Text(
                    'Continue',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
  
  Widget _buildSummaryRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: const TextStyle(
              fontSize: 14,
              color: Color(0xFF2C3E50),
            ),
          ),
          Text(
            value,
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.bold,
              color: Color(0xFF5B9EF3),
            ),
          ),
        ],
      ),
    );
  }
}