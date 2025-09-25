import 'package:flutter/material.dart';
import 'dart:async';
import '../models/math_question.dart';
import '../models/math_topic.dart';
import '../services/math_service.dart';
import '../services/firestore_service.dart';
import '../services/auth_service.dart';

class MathPracticeSessionScreen extends StatefulWidget {
  final MathTopic topic;
  final String difficulty;

  const MathPracticeSessionScreen({
    super.key,
    required this.topic,
    this.difficulty = 'easy',
  });

  @override
  State<MathPracticeSessionScreen> createState() => _MathPracticeSessionScreenState();
}

class _MathPracticeSessionScreenState extends State<MathPracticeSessionScreen> {
  final FirestoreService _firestoreService = FirestoreService();
  final AuthService _authService = AuthService();
  
  late List<MathQuestion> questions;
  Stopwatch? stopwatch;
  Timer? timer;
  
  int currentQuestionIndex = 0;
  int correctAnswers = 0;
  int? selectedAnswer;
  bool hasAnswered = false;
  bool isSessionComplete = false;
  
  @override
  void initState() {
    super.initState();
    _initializeSession();
  }

  void _initializeSession() {
    questions = MathService.generateQuestions(
      topic: widget.topic.id,
      difficulty: widget.difficulty,
      count: 10,
    );
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

  void _selectAnswer(int answer) {
    if (hasAnswered) return;
    
    setState(() {
      selectedAnswer = answer;
      hasAnswered = true;
    });

    if (answer == questions[currentQuestionIndex].correctAnswer) {
      correctAnswers++;
    }

    // Show result for 2 seconds then move to next question
    Future.delayed(const Duration(seconds: 2), () {
      if (mounted) {
        _nextQuestion();
      }
    });
  }

  void _nextQuestion() {
    if (currentQuestionIndex < questions.length - 1) {
      setState(() {
        currentQuestionIndex++;
        selectedAnswer = null;
        hasAnswered = false;
      });
    } else {
      _completeSession();
    }
  }

  void _completeSession() {
    stopwatch?.stop();
    timer?.cancel();
    
    setState(() {
      isSessionComplete = true;
    });
    
    _saveSession();
  }

  Future<void> _saveSession() async {
    final user = _authService.currentUser;
    if (user == null) {
      // If no user, just show the completion screen without saving
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Session completed (offline mode)')),
        );
      }
      return;
    }

    final timeSpent = Duration(seconds: stopwatch?.elapsed.inSeconds ?? 0);
    final accuracy = correctAnswers / questions.length;
    
    final stars = MathService.calculateStars(
      accuracy: accuracy,
      averageTime: Duration(seconds: timeSpent.inSeconds ~/ questions.length),
    );
    
    final score = MathService.calculateScore(
      correctAnswers: correctAnswers,
      totalQuestions: questions.length,
      timeSpent: timeSpent,
      difficulty: widget.difficulty,
    );

    try {
      await _firestoreService.completeLessonAndUpdateProgress(
        userId: user.uid,
        topicId: widget.topic.id,
        newStars: stars,
        score: score,
        totalQuestions: questions.length,
        correctAnswers: correctAnswers,
        timeSpent: timeSpent,
      );
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Session saved successfully!')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Session completed (offline): $e')),
        );
      }
    }
  }

  @override
  void dispose() {
    timer?.cancel();
    stopwatch?.stop();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (isSessionComplete) {
      return _buildCompletionScreen();
    }

    final currentQuestion = questions[currentQuestionIndex];
    
    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FA),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.close, color: Color(0xFF2C3E50)),
          onPressed: () => _showExitDialog(),
        ),
        title: Text(
          '${widget.topic.name} Practice',
          style: const TextStyle(
            color: Color(0xFF2C3E50),
            fontSize: 18,
            fontWeight: FontWeight.w600,
          ),
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
                  _formatTime(stopwatch?.elapsed ?? Duration.zero),
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
                      value: (currentQuestionIndex + 1) / questions.length,
                      backgroundColor: Colors.grey[300],
                      valueColor: AlwaysStoppedAnimation<Color>(
                        _getTopicColor(widget.topic.id),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Text(
                    '${currentQuestionIndex + 1}/${questions.length}',
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
                        currentQuestion.questionText,
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
                          selectedAnswer == currentQuestion.correctAnswer
                              ? Icons.check_circle
                              : Icons.cancel,
                          color: selectedAnswer == currentQuestion.correctAnswer
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
                  itemCount: currentQuestion.options.length,
                  itemBuilder: (context, index) {
                    final option = currentQuestion.options[index];
                    final isCorrect = option == currentQuestion.correctAnswer;
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
              
              // Score display
              Container(
                padding: const EdgeInsets.all(15),
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
                    Column(
                      children: [
                        Text(
                          correctAnswers.toString(),
                          style: const TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                            color: Colors.green,
                          ),
                        ),
                        const Text(
                          'Correct',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey,
                          ),
                        ),
                      ],
                    ),
                    Column(
                      children: [
                        Text(
                          '${((correctAnswers / (currentQuestionIndex + (hasAnswered ? 1 : 0))) * 100).round()}%',
                          style: const TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF5B9EF3),
                          ),
                        ),
                        const Text(
                          'Accuracy',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey,
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

  Widget _buildCompletionScreen() {
    final accuracy = correctAnswers / questions.length;
    final timeSpent = Duration(seconds: stopwatch?.elapsed.inSeconds ?? 0);
    final stars = MathService.calculateStars(
      accuracy: accuracy,
      averageTime: Duration(seconds: timeSpent.inSeconds ~/ questions.length),
    );
    
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
                    const Text(
                      'Lesson Complete!',
                      style: TextStyle(
                        fontSize: 28,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF2C3E50),
                      ),
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
                    
                    // Stats
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceAround,
                      children: [
                        _buildStat('Correct', '$correctAnswers/${questions.length}', Colors.green),
                        _buildStat('Accuracy', '${(accuracy * 100).round()}%', const Color(0xFF5B9EF3)),
                        _buildStat('Time', _formatTime(timeSpent), const Color(0xFF7ED321)),
                      ],
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
                              Navigator.pop(context);
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (context) => MathPracticeSessionScreen(
                                    topic: widget.topic,
                                    difficulty: widget.difficulty,
                                  ),
                                ),
                              );
                            },
                            style: ElevatedButton.styleFrom(
                              backgroundColor: _getTopicColor(widget.topic.id),
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

  void _showExitDialog() {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Exit Practice?'),
          content: const Text('Your progress will be lost if you exit now.'),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
                Navigator.of(context).pop();
              },
              child: const Text('Exit'),
            ),
          ],
        );
      },
    );
  }

  String _formatTime(Duration duration) {
    String twoDigits(int n) => n.toString().padLeft(2, '0');
    final minutes = twoDigits(duration.inMinutes);
    final seconds = twoDigits(duration.inSeconds.remainder(60));
    return '$minutes:$seconds';
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
}