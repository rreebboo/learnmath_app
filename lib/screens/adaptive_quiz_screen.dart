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
  late AnimationController _questionController;
  late AnimationController _progressController;
  late Animation<double> _feedbackAnimation;
  late Animation<double> _progressScaleAnimation;
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
    
    _questionController = AnimationController(
      duration: const Duration(milliseconds: 500),
      vsync: this,
    );
    
    _progressController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );
    
    _feedbackAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _feedbackController,
      curve: Curves.elasticOut,
    ));
    
    
    _progressScaleAnimation = Tween<double>(
      begin: 1.0,
      end: 1.1,
    ).animate(CurvedAnimation(
      parent: _progressController,
      curve: Curves.easeInOut,
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
    _questionController.dispose();
    _progressController.dispose();
    _feedbackTimer?.cancel();
    super.dispose();
  }
  
  void _generateNewQuestion() {
    try {
      _questionController.forward().then((_) {
        final newQuestion = _quizEngine.generateQuestion();
        setState(() {
          _currentQuestion = newQuestion;
          _selectedAnswer = null;
          _showFeedback = false;
        });
        _questionController.reverse();
      });
      
      _progressController.forward().then((_) {
        _progressController.reverse();
      });
    } catch (e) {
      print('Error generating question: $e');
      // Handle error gracefully - could show error dialog or retry
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                Icon(Icons.error_outline, color: Colors.white),
                SizedBox(width: 8),
                Text('Error generating question. Please try again.'),
              ],
            ),
            backgroundColor: Colors.red,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          ),
        );
      }
    }
  }
  
  void _selectAnswer(int answer) {
    if (_selectedAnswer != null || _showFeedback || _currentQuestion == null) return;
    
    setState(() {
      _selectedAnswer = answer;
      _isCorrect = answer == _currentQuestion!.correctAnswer;
      _feedbackText = _isCorrect ? 'Correct! ✓' : 'Try Again ✗';
      _showFeedback = true;
    });
    
    try {
      _quizEngine.submitAnswer(_currentQuestion!, answer);
      
      // Save attempt to Firebase if attempts exist
      if (_quizEngine.attempts.isNotEmpty) {
        _progressService.saveQuizAttempt(_quizEngine.attempts.last);
      }
    } catch (e) {
      // Handle quiz engine errors gracefully
      print('Error submitting answer: $e');
      // Reset feedback state if error occurs
      setState(() {
        _showFeedback = false;
        _selectedAnswer = null;
      });
      return;
    }
    
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
            try {
              final stats = _quizEngine.getStats();
              if (stats['isQuizComplete'] == true) {
                _showQuizCompletionDialog();
              } else if (stats['requiresLevelReset'] == true) {
                _showLevelResetDialog();
              } else {
                _generateNewQuestion();
              }
            } catch (e) {
              print('Error getting quiz stats: $e');
              // Fallback to generating new question
              _generateNewQuestion();
            }
          }
        });
      });
    });
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
          backgroundColor: _backgroundAnimation.value ?? const Color(0xFFF5F7FA),
          appBar: _buildAppBar(),
          body: Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  const Color(0xFFF5F7FA),
                  const Color(0xFFEBF0F5),
                  _getDifficultyColor().withValues(alpha: 0.05),
                ],
              ),
            ),
            child: _currentQuestion == null 
                ? Center(
                    child: Container(
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                          color: _getDifficultyColor().withValues(alpha: 0.3),
                          width: 2,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.05),
                            blurRadius: 15,
                            offset: const Offset(0, 5),
                          ),
                        ],
                      ),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          CircularProgressIndicator(
                            valueColor: AlwaysStoppedAnimation<Color>(_getDifficultyColor()),
                            strokeWidth: 3,
                          ),
                          const SizedBox(height: 16),
                          Text(
                            'Preparing Quiz...',
                            style: TextStyle(
                              color: _getDifficultyColor(),
                              fontSize: 16,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    ),
                  )
                : _buildBody(),
          ),
        );
      },
    );
  }
  
  PreferredSizeWidget _buildAppBar() {
    return AppBar(
      backgroundColor: Colors.white,
      elevation: 0,
      leading: IconButton(
        icon: const Icon(Icons.close, color: Color(0xFF2C3E50)),
        onPressed: () => _showQuitDialog(),
      ),
      title: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Adaptive Quiz',
            style: TextStyle(
              color: Color(0xFF2C3E50),
              fontSize: 18,
              fontWeight: FontWeight.w600,
            ),
          ),
          Text(
            _getOperationDisplayName(),
            style: TextStyle(
              color: _getDifficultyColor(),
              fontSize: 12,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
      actions: [
        Container(
          margin: const EdgeInsets.only(right: 16),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color: _getDifficultyColor().withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(20),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.speed,
                color: _getDifficultyColor(),
                size: 16,
              ),
              const SizedBox(width: 4),
              Text(
                _getDifficultyDisplayName(),
                style: TextStyle(
                  color: _getDifficultyColor(),
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                ),
              ),
            ],
          ),
        ),
      ],
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
    return AnimatedBuilder(
      animation: _progressScaleAnimation,
      builder: (context, child) {
        return Transform.scale(
          scale: _progressScaleAnimation.value,
          child: LayoutBuilder(
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
                        gradient: LinearGradient(
                          colors: [
                            Colors.white,
                            const Color(0xFFFAFBFC),
                          ],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        borderRadius: BorderRadius.circular(15),
                        border: Border.all(
                          color: const Color(0xFF5B9EF3).withValues(alpha: 0.2),
                          width: 1,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: const Color(0xFF5B9EF3).withValues(alpha: 0.1),
                            blurRadius: 12,
                            offset: const Offset(0, 4),
                            spreadRadius: 1,
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
                          Container(
                            width: 2,
                            height: 25,
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                colors: [
                                  Colors.grey[300]!,
                                  Colors.grey[200]!,
                                ],
                                begin: Alignment.topCenter,
                                end: Alignment.bottomCenter,
                              ),
                              borderRadius: BorderRadius.circular(1),
                            ),
                          ),
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
                        gradient: LinearGradient(
                          colors: [
                            Colors.white,
                            const Color(0xFFFAFBFC),
                          ],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        borderRadius: BorderRadius.circular(15),
                        border: Border.all(
                          color: const Color(0xFF9B59B6).withValues(alpha: 0.2),
                          width: 1,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: const Color(0xFF9B59B6).withValues(alpha: 0.1),
                            blurRadius: 12,
                            offset: const Offset(0, 4),
                            spreadRadius: 1,
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
                          Container(
                            width: 2,
                            height: 25,
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                colors: [
                                  Colors.grey[300]!,
                                  Colors.grey[200]!,
                                ],
                                begin: Alignment.topCenter,
                                end: Alignment.bottomCenter,
                              ),
                              borderRadius: BorderRadius.circular(1),
                            ),
                          ),
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
                    gradient: LinearGradient(
                      colors: [
                        Colors.white,
                        const Color(0xFFFAFBFC),
                      ],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(15),
                    border: Border.all(
                      color: _getDifficultyColor().withValues(alpha: 0.3),
                      width: 1.5,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: _getDifficultyColor().withValues(alpha: 0.15),
                        blurRadius: 15,
                        offset: const Offset(0, 5),
                        spreadRadius: 2,
                      ),
                      BoxShadow(
                        color: Colors.white,
                        blurRadius: 8,
                        offset: const Offset(-2, -2),
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
                      Container(
                        width: 2,
                        height: isMediumScreen ? 25 : 30,
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [
                              Colors.grey[300]!,
                              Colors.grey[200]!,
                            ],
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                          ),
                          borderRadius: BorderRadius.circular(1),
                        ),
                      ),
                      Flexible(
                        child: _buildStatItem(
                          icon: Icons.check_circle,
                          label: 'Correct',
                          value: '${stats['correctAnswers']}',
                          color: const Color(0xFF7ED321),
                          isCompact: isMediumScreen,
                        ),
                      ),
                      Container(
                        width: 2,
                        height: isMediumScreen ? 25 : 30,
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [
                              Colors.grey[300]!,
                              Colors.grey[200]!,
                            ],
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                          ),
                          borderRadius: BorderRadius.circular(1),
                        ),
                      ),
                      Flexible(
                        child: _buildStatItem(
                          icon: Icons.trending_up,
                          label: isMediumScreen ? 'Progress' : 'Level Progress',
                          value: '${stats['correctAnswersInCurrentLevel']}/10',
                          color: const Color(0xFF9B59B6),
                          isCompact: isMediumScreen,
                        ),
                      ),
                      Container(
                        width: 2,
                        height: isMediumScreen ? 25 : 30,
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [
                              Colors.grey[300]!,
                              Colors.grey[200]!,
                            ],
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                          ),
                          borderRadius: BorderRadius.circular(1),
                        ),
                      ),
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
          ),
        );
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
    return TweenAnimationBuilder<double>(
      duration: const Duration(milliseconds: 600),
      tween: Tween(begin: 0.0, end: 1.0),
      curve: Curves.elasticOut,
      builder: (context, animValue, child) {
        return Transform.scale(
          scale: animValue,
          child: Container(
            padding: EdgeInsets.symmetric(
              horizontal: isCompact ? 8 : 12,
              vertical: isCompact ? 6 : 8,
            ),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: color.withValues(alpha: 0.2),
                width: 1,
              ),
            ),
            child: Column(
              children: [
                Container(
                  padding: EdgeInsets.all(isCompact ? 4 : 6),
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Icon(
                    icon, 
                    color: color, 
                    size: isCompact ? 16 : 20,
                  ),
                ),
                SizedBox(height: isCompact ? 4 : 6),
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
                    color: color.withValues(alpha: 0.7),
                    fontWeight: FontWeight.w500,
                  ),
                  textAlign: TextAlign.center,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        );
      },
    );
  }
  
  Widget _buildQuestionCard() {
    return LayoutBuilder(
      builder: (context, constraints) {
        final screenWidth = MediaQuery.of(context).size.width;
        final screenHeight = MediaQuery.of(context).size.height;
        final isSmallScreen = screenWidth < 360;
        
        return Container(
          width: double.infinity,
          margin: const EdgeInsets.symmetric(horizontal: 8),
          padding: EdgeInsets.all(isSmallScreen ? 20 : 24),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(20),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.05),
                blurRadius: 15,
                offset: const Offset(0, 5),
              ),
            ],
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              // Header
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.psychology,
                    color: _getDifficultyColor(),
                    size: 20,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    'Solve this problem:',
                    style: TextStyle(
                      fontSize: 16,
                      color: _getDifficultyColor(),
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
              
              const SizedBox(height: 30),
              
              // Question Text - Completely Centered
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: const Color(0xFFF5F7FA),
                  borderRadius: BorderRadius.circular(15),
                  border: Border.all(
                    color: _getDifficultyColor().withValues(alpha: 0.2),
                    width: 2,
                  ),
                ),
                child: Center(
                  child: Text(
                    _currentQuestion!.questionText,
                    style: TextStyle(
                      fontSize: _getQuestionFontSize(screenWidth, screenHeight),
                      fontWeight: FontWeight.bold,
                      color: _getDifficultyColor(),
                      letterSpacing: 1.5,
                      height: 1.3,
                    ),
                    textAlign: TextAlign.center,
                  ),
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
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        crossAxisSpacing: 15,
        mainAxisSpacing: 15,
        childAspectRatio: 2.0,
      ),
      itemCount: _currentQuestion!.options.length,
      itemBuilder: (context, index) {
        final option = _currentQuestion!.options[index];
        final isCorrect = option == _currentQuestion!.correctAnswer;
        final isSelected = _selectedAnswer == option;
        
        Color backgroundColor = Colors.white;
        Color textColor = const Color(0xFF2C3E50);
        
        if (_showFeedback) {
          if (isCorrect) {
            backgroundColor = Colors.green;
            textColor = Colors.white;
          } else if (isSelected && !isCorrect) {
            backgroundColor = Colors.red;
            textColor = Colors.white;
          }
        }
        
        return GestureDetector(
          onTap: _showFeedback ? null : () => _selectAnswer(option),
          child: Container(
            decoration: BoxDecoration(
              color: backgroundColor,
              borderRadius: BorderRadius.circular(15),
              border: Border.all(
                color: _showFeedback && isCorrect
                    ? Colors.green
                    : _showFeedback && isSelected
                        ? Colors.red
                        : Colors.grey[300]!,
                width: 2,
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.05),
                  blurRadius: 10,
                  offset: const Offset(0, 3),
                ),
              ],
            ),
            child: Center(
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  if (_showFeedback && isCorrect)
                    const Icon(
                      Icons.check_circle,
                      color: Colors.white,
                      size: 20,
                    ),
                  if (_showFeedback && isSelected && !isCorrect)
                    const Icon(
                      Icons.cancel,
                      color: Colors.white,
                      size: 20,
                    ),
                  if (_showFeedback && (isCorrect || isSelected))
                    const SizedBox(width: 8),
                  Text(
                    option.toString(),
                    style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      color: textColor,
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
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
                final navigator = Navigator.of(context);
                navigator.pop(); // Close the quit dialog
                await _saveQuizSessionOnly();
                if (mounted) {
                  navigator.pop(); // Return to previous screen
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

  Future<void> _saveQuizSessionOnly() async {
    try {
      final stats = _quizEngine.getStats();
      
      if (_quizEngine.attempts.isNotEmpty) {
        await _progressService.saveQuizSession(_quizEngine.attempts, stats);
        print('Quiz session saved successfully');
      }
    } catch (e) {
      print('Error saving quiz session: $e');
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
                            final navigator = Navigator.of(context);
                            navigator.pop();
                            await _endQuizSession();
                            if (mounted) {
                              navigator.pop();
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