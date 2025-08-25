import 'package:flutter/material.dart';
import 'dart:async';
import 'dart:math' as math;
import '../services/user_statistics_service.dart';

class SimpleMathPracticeScreen extends StatefulWidget {
  final String topicName;
  final String operator;
  final String difficulty;
  final Function(double accuracy)? onSessionComplete;

  const SimpleMathPracticeScreen({
    super.key,
    required this.topicName,
    required this.operator,
    this.difficulty = 'easy',
    this.onSessionComplete,
  });

  @override
  State<SimpleMathPracticeScreen> createState() => _SimpleMathPracticeScreenState();
}

class _SimpleMathPracticeScreenState extends State<SimpleMathPracticeScreen> {
  final math.Random _random = math.Random();
  final UserStatisticsService _statsService = UserStatisticsService();
  late Stopwatch stopwatch;
  Timer? timer;
  
  int currentQuestionIndex = 0;
  int correctAnswers = 0;
  int? selectedAnswer;
  bool hasAnswered = false;
  bool isSessionComplete = false;
  
  // Current question data
  int operand1 = 0;
  int operand2 = 0;
  int correctAnswerValue = 0;
  List<int> options = [];
  
  final int totalQuestions = 10;
  
  @override
  void initState() {
    super.initState();
    _initializeSession();
  }

  void _initializeSession() async {
    await _statsService.loadStatistics();
    _generateQuestion();
    stopwatch = Stopwatch()..start();
    _startTimer();
  }

  void _startTimer() {
    timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (mounted) {
        setState(() {});
      }
    });
  }

  void _generateQuestion() {
    switch (widget.operator) {
      case '+':
        _generateAdditionQuestion();
        break;
      case '-':
        _generateSubtractionQuestion();
        break;
      case '×':
        _generateMultiplicationQuestion();
        break;
      case '÷':
        _generateDivisionQuestion();
        break;
    }
    
    // Generate options
    Set<int> optionSet = {correctAnswerValue};
    while (optionSet.length < 4) {
      int wrongAnswer;
      if (correctAnswerValue <= 10) {
        wrongAnswer = _random.nextInt(20) + 1;
      } else {
        wrongAnswer = correctAnswerValue + (_random.nextInt(21) - 10);
      }
      if (wrongAnswer > 0) {
        optionSet.add(wrongAnswer);
      }
    }
    
    options = optionSet.toList()..shuffle();
  }

  void _generateAdditionQuestion() {
    switch (widget.difficulty.toLowerCase()) {
      case 'easy':
        operand1 = _random.nextInt(10) + 1; // 1-10
        operand2 = _random.nextInt(10) + 1; // 1-10
        break;
      case 'medium':
        operand1 = _random.nextInt(90) + 10; // 10-99
        operand2 = _random.nextInt(90) + 10; // 10-99
        break;
      case 'hard':
        operand1 = _random.nextInt(900) + 100; // 100-999
        operand2 = _random.nextInt(900) + 100; // 100-999
        break;
      default:
        operand1 = _random.nextInt(10) + 1;
        operand2 = _random.nextInt(10) + 1;
    }
    correctAnswerValue = operand1 + operand2;
  }

  void _generateSubtractionQuestion() {
    switch (widget.difficulty.toLowerCase()) {
      case 'easy':
        operand1 = _random.nextInt(15) + 6; // 6-20
        operand2 = _random.nextInt(operand1 - 1) + 1; // 1 to operand1-1
        break;
      case 'medium':
        operand1 = _random.nextInt(90) + 50; // 50-139
        operand2 = _random.nextInt(operand1 - 10) + 10; // 10 to operand1-10
        break;
      case 'hard':
        operand1 = _random.nextInt(900) + 200; // 200-1099
        operand2 = _random.nextInt(operand1 - 50) + 50; // 50 to operand1-50
        break;
      default:
        operand1 = _random.nextInt(15) + 6;
        operand2 = _random.nextInt(operand1 - 1) + 1;
    }
    correctAnswerValue = operand1 - operand2;
  }

  void _generateMultiplicationQuestion() {
    switch (widget.difficulty.toLowerCase()) {
      case 'easy':
        operand1 = _random.nextInt(5) + 1; // 1-5
        operand2 = _random.nextInt(5) + 1; // 1-5
        break;
      case 'medium':
        operand1 = _random.nextInt(12) + 1; // 1-12
        operand2 = _random.nextInt(12) + 1; // 1-12
        break;
      case 'hard':
        operand1 = _random.nextInt(25) + 1; // 1-25
        operand2 = _random.nextInt(25) + 1; // 1-25
        break;
      default:
        operand1 = _random.nextInt(5) + 1;
        operand2 = _random.nextInt(5) + 1;
    }
    correctAnswerValue = operand1 * operand2;
  }

  void _generateDivisionQuestion() {
    switch (widget.difficulty.toLowerCase()) {
      case 'easy':
        operand2 = _random.nextInt(5) + 2; // 2-6
        correctAnswerValue = _random.nextInt(5) + 1; // 1-5
        break;
      case 'medium':
        operand2 = _random.nextInt(10) + 2; // 2-11
        correctAnswerValue = _random.nextInt(12) + 1; // 1-12
        break;
      case 'hard':
        operand2 = _random.nextInt(23) + 2; // 2-24
        correctAnswerValue = _random.nextInt(25) + 1; // 1-25
        break;
      default:
        operand2 = _random.nextInt(5) + 2;
        correctAnswerValue = _random.nextInt(5) + 1;
    }
    operand1 = operand2 * correctAnswerValue; // Ensure whole number result
  }

  void _selectAnswer(int answer) {
    if (hasAnswered) return;
    
    setState(() {
      selectedAnswer = answer;
      hasAnswered = true;
    });

    if (answer == correctAnswerValue) {
      correctAnswers++;
    }

    Future.delayed(const Duration(seconds: 2), () {
      if (mounted) {
        _nextQuestion();
      }
    });
  }

  void _nextQuestion() {
    if (currentQuestionIndex < totalQuestions - 1) {
      setState(() {
        currentQuestionIndex++;
        selectedAnswer = null;
        hasAnswered = false;
        _generateQuestion();
      });
    } else {
      _completeSession();
    }
  }

  void _completeSession() async {
    stopwatch.stop();
    timer?.cancel();
    
    setState(() {
      isSessionComplete = true;
    });
    
    // Record session statistics
    final accuracy = correctAnswers / totalQuestions;
    final averageTime = stopwatch.elapsed.inSeconds / totalQuestions;
    final stars = _calculateStars(accuracy, averageTime);
    final score = _calculateScore(accuracy, stopwatch.elapsed);
    
    await _statsService.recordSession(
      topic: widget.topicName,
      difficulty: widget.difficulty,
      questions: totalQuestions,
      correctAnswers: correctAnswers,
      timeSpent: stopwatch.elapsed.inSeconds,
      stars: stars,
      score: score,
    );
    
    // Call the completion callback if provided
    if (widget.onSessionComplete != null) {
      widget.onSessionComplete!(accuracy);
    }
  }

  @override
  void dispose() {
    timer?.cancel();
    stopwatch.stop();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (isSessionComplete) {
      return _buildCompletionScreen();
    }

    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FA),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.close, color: Color(0xFF2C3E50)),
          onPressed: () => Navigator.pop(context),
        ),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '${widget.topicName} Practice',
              style: const TextStyle(
                color: Color(0xFF2C3E50),
                fontSize: 16,
                fontWeight: FontWeight.w600,
              ),
            ),
            Text(
              '${widget.difficulty.toUpperCase()} Level',
              style: TextStyle(
                color: _getDifficultyColor(widget.difficulty),
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
              color: const Color(0xFF7ED321).withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Row(
              children: [
                const Icon(
                  Icons.timer,
                  color: Color(0xFF7ED321),
                  size: 16,
                ),
                const SizedBox(width: 4),
                Text(
                  _formatTime(stopwatch.elapsed),
                  style: const TextStyle(
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
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Progress indicator
              Row(
                children: [
                  Expanded(
                    child: LinearProgressIndicator(
                      value: (currentQuestionIndex + 1) / totalQuestions,
                      backgroundColor: Colors.grey[300],
                      valueColor: const AlwaysStoppedAnimation<Color>(
                        Color(0xFF5B9EF3),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Text(
                    '${currentQuestionIndex + 1}/$totalQuestions',
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF2C3E50),
                    ),
                  ),
                ],
              ),
              
              const SizedBox(height: 40),
              
              // Question
              Center(
                child: Container(
                  padding: const EdgeInsets.all(30),
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
                    children: [
                      Text(
                        '$operand1 ${widget.operator} $operand2 = ?',
                        style: const TextStyle(
                          fontSize: 36,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF2C3E50),
                        ),
                        textAlign: TextAlign.center,
                      ),
                      if (hasAnswered) ...[
                        const SizedBox(height: 20),
                        Icon(
                          selectedAnswer == correctAnswerValue
                              ? Icons.check_circle
                              : Icons.cancel,
                          color: selectedAnswer == correctAnswerValue
                              ? Colors.green
                              : Colors.red,
                          size: 48,
                        ),
                      ],
                    ],
                  ),
                ),
              ),
              
              const SizedBox(height: 40),
              
              // Answer options
              Expanded(
                child: GridView.builder(
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 2,
                    crossAxisSpacing: 15,
                    mainAxisSpacing: 15,
                    childAspectRatio: 2.0,
                  ),
                  itemCount: options.length,
                  itemBuilder: (context, index) {
                    final option = options[index];
                    final isCorrect = option == correctAnswerValue;
                    final isSelected = selectedAnswer == option;
                    
                    Color backgroundColor = Colors.white;
                    Color textColor = const Color(0xFF2C3E50);
                    
                    if (hasAnswered) {
                      if (isCorrect) {
                        backgroundColor = Colors.green;
                        textColor = Colors.white;
                      } else if (isSelected && !isCorrect) {
                        backgroundColor = Colors.red;
                        textColor = Colors.white;
                      }
                    }
                    
                    return GestureDetector(
                      onTap: () => _selectAnswer(option),
                      child: Container(
                        decoration: BoxDecoration(
                          color: backgroundColor,
                          borderRadius: BorderRadius.circular(15),
                          border: Border.all(
                            color: hasAnswered && isCorrect
                                ? Colors.green
                                : hasAnswered && isSelected
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
                          child: Text(
                            option.toString(),
                            style: TextStyle(
                              fontSize: 28,
                              fontWeight: FontWeight.bold,
                              color: textColor,
                            ),
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),
              
              const SizedBox(height: 20),
              
              // Enhanced Statistics Display
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      _getDifficultyColor(widget.difficulty).withValues(alpha: 0.1),
                      _getDifficultyColor(widget.difficulty).withValues(alpha: 0.05),
                    ],
                  ),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: _getDifficultyColor(widget.difficulty).withValues(alpha: 0.3),
                    width: 1,
                  ),
                ),
                child: Column(
                  children: [
                    Row(
                      children: [
                        Icon(
                          Icons.analytics,
                          color: _getDifficultyColor(widget.difficulty),
                          size: 20,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          'Live Statistics',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: _getDifficultyColor(widget.difficulty),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 15),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceAround,
                      children: [
                        _buildStatCard(
                          'Correct',
                          correctAnswers.toString(),
                          '/ $totalQuestions',
                          Colors.green,
                          Icons.check_circle,
                        ),
                        _buildStatCard(
                          'Accuracy',
                          '${((correctAnswers / math.max(currentQuestionIndex + (hasAnswered ? 1 : 0), 1)) * 100).round()}%',
                          '',
                          const Color(0xFF5B9EF3),
                          Icons.track_changes,
                        ),
                        _buildStatCard(
                          'Speed',
                          '${_getAverageTime()}s',
                          'avg',
                          const Color(0xFFFFA500),
                          Icons.speed,
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCompletionScreen() {
    final accuracy = correctAnswers / totalQuestions;
    final timeSpent = Duration(seconds: stopwatch.elapsed.inSeconds);
    final averageTime = timeSpent.inSeconds / totalQuestions;
    
    // Difficulty-based scoring
    int stars = _calculateStars(accuracy, averageTime);
    int score = _calculateScore(accuracy, timeSpent);
    String performance = _getPerformanceMessage(accuracy, averageTime);
    
    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FA),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.all(30),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.1),
                      blurRadius: 20,
                      offset: const Offset(0, 10),
                    ),
                  ],
                ),
                child: Column(
                  children: [
                    const Icon(
                      Icons.celebration,
                      size: 80,
                      color: Color(0xFF7ED321),
                    ),
                    const SizedBox(height: 20),
                    Text(
                      'Level Complete!',
                      style: TextStyle(
                        fontSize: 28,
                        fontWeight: FontWeight.bold,
                        color: _getDifficultyColor(widget.difficulty),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      decoration: BoxDecoration(
                        color: _getDifficultyColor(widget.difficulty).withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        '${widget.difficulty.toUpperCase()} ${widget.topicName}',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: _getDifficultyColor(widget.difficulty),
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      performance,
                      style: const TextStyle(
                        fontSize: 16,
                        color: Color(0xFF6B7280),
                        fontStyle: FontStyle.italic,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 20),
                    
                    // Stars
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: List.generate(5, (index) => Icon(
                        Icons.star,
                        size: 30,
                        color: index < stars ? Colors.amber : Colors.grey[300],
                      )),
                    ),
                    
                    const SizedBox(height: 20),
                    
                    // Enhanced Stats with Score
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF8F9FA),
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Column(
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                Icons.emoji_events,
                                color: _getDifficultyColor(widget.difficulty),
                                size: 24,
                              ),
                              const SizedBox(width: 8),
                              Text(
                                'Score: $score points',
                                style: TextStyle(
                                  fontSize: 20,
                                  fontWeight: FontWeight.bold,
                                  color: _getDifficultyColor(widget.difficulty),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 16),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceAround,
                            children: [
                              _buildStat('Correct', '$correctAnswers/$totalQuestions', Colors.green),
                              _buildStat('Accuracy', '${(accuracy * 100).round()}%', const Color(0xFF5B9EF3)),
                              _buildStat('Avg Time', '${averageTime.round()}s', const Color(0xFF7ED321)),
                            ],
                          ),
                        ],
                      ),
                    ),
                    
                    const SizedBox(height: 30),
                    
                    // Buttons
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton(
                            onPressed: () => Navigator.pop(context),
                            style: OutlinedButton.styleFrom(
                              padding: const EdgeInsets.symmetric(vertical: 15),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                            child: const Text('Back to Topics'),
                          ),
                        ),
                        const SizedBox(width: 15),
                        Expanded(
                          child: ElevatedButton(
                            onPressed: () {
                              Navigator.pushReplacement(
                                context,
                                MaterialPageRoute(
                                  builder: (context) => SimpleMathPracticeScreen(
                                    topicName: widget.topicName,
                                    operator: widget.operator,
                                  ),
                                ),
                              );
                            },
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF5B9EF3),
                              padding: const EdgeInsets.symmetric(vertical: 15),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                            child: const Text(
                              'Practice Again',
                              style: TextStyle(color: Colors.white),
                            ),
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
      ),
    );
  }

  Widget _buildStat(String label, String value, Color color) {
    return Column(
      children: [
        Text(
          value,
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
        Text(
          label,
          style: const TextStyle(
            fontSize: 12,
            color: Colors.grey,
          ),
        ),
      ],
    );
  }

  String _formatTime(Duration duration) {
    String twoDigits(int n) => n.toString().padLeft(2, '0');
    final minutes = twoDigits(duration.inMinutes);
    final seconds = twoDigits(duration.inSeconds.remainder(60));
    return '$minutes:$seconds';
  }

  Color _getDifficultyColor(String difficulty) {
    switch (difficulty.toLowerCase()) {
      case 'easy':
        return const Color(0xFF7ED321);
      case 'medium':
        return const Color(0xFFFFA500);
      case 'hard':
        return const Color(0xFFFF6B6B);
      default:
        return const Color(0xFF5B9EF3);
    }
  }

  int _getAverageTime() {
    if (currentQuestionIndex == 0 && !hasAnswered) return 0;
    final questionsSoFar = currentQuestionIndex + (hasAnswered ? 1 : 0);
    return questionsSoFar > 0 ? (stopwatch.elapsed.inSeconds / questionsSoFar).round() : 0;
  }

  Widget _buildStatCard(String label, String value, String suffix, Color color, IconData icon) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(
              color: color.withValues(alpha: 0.1),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          children: [
            Icon(icon, color: color, size: 20),
            const SizedBox(height: 6),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.baseline,
              textBaseline: TextBaseline.alphabetic,
              children: [
                Text(
                  value,
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: color,
                  ),
                ),
                if (suffix.isNotEmpty)
                  Text(
                    suffix,
                    style: TextStyle(
                      fontSize: 12,
                      color: color.withValues(alpha: 0.7),
                      fontWeight: FontWeight.w500,
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 2),
            Text(
              label,
              style: TextStyle(
                fontSize: 10,
                color: Colors.grey[600],
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }

  int _calculateStars(double accuracy, double averageTime) {
    int stars = 1; // Base star for completion
    
    // Accuracy-based stars
    if (accuracy >= 0.6) stars = 2;
    if (accuracy >= 0.8) stars = 3;
    if (accuracy >= 0.9) stars = 4;
    
    // Perfect accuracy with good time = 5 stars
    if (accuracy == 1.0) {
      stars = 5;
    } else if (accuracy >= 0.9 && averageTime <= _getTargetTime()) {
      stars = 5;
    }
    
    return stars;
  }

  int _calculateScore(double accuracy, Duration totalTime) {
    double baseScore = correctAnswers * 10.0;
    
    // Difficulty multiplier
    double difficultyMultiplier = switch (widget.difficulty.toLowerCase()) {
      'easy' => 1.0,
      'medium' => 1.5,
      'hard' => 2.0,
      _ => 1.0,
    };
    
    // Time bonus (faster = more points)
    double averageTime = totalTime.inSeconds / totalQuestions;
    double timeMultiplier = 1.0;
    double targetTime = _getTargetTime();
    
    if (averageTime <= targetTime * 0.5) {
      timeMultiplier = 1.5; // Very fast
    } else if (averageTime <= targetTime) {
      timeMultiplier = 1.2; // Good speed
    }
    
    // Accuracy bonus
    double accuracyBonus = accuracy == 1.0 ? 1.3 : (accuracy >= 0.9 ? 1.1 : 1.0);
    
    return (baseScore * difficultyMultiplier * timeMultiplier * accuracyBonus).round();
  }

  double _getTargetTime() {
    return switch (widget.difficulty.toLowerCase()) {
      'easy' => 10.0,
      'medium' => 15.0,
      'hard' => 20.0,
      _ => 10.0,
    };
  }

  String _getPerformanceMessage(double accuracy, double averageTime) {
    if (accuracy == 1.0 && averageTime <= _getTargetTime()) {
      return "Perfect! You're a math champion! 🏆";
    } else if (accuracy >= 0.9) {
      return "Excellent work! Keep it up! ⭐";
    } else if (accuracy >= 0.8) {
      return "Great job! You're improving! 👍";
    } else if (accuracy >= 0.7) {
      return "Good effort! Practice makes perfect! 💪";
    } else if (accuracy >= 0.5) {
      return "Nice try! Keep practicing! 📚";
    } else {
      return "Don't give up! Every expert was once a beginner! 🌟";
    }
  }
}