import 'package:flutter/material.dart';
import 'dart:async';
import 'dart:math' as math;

class ModernQuizScreen extends StatefulWidget {
  final String topicName;
  final String operator;
  final String difficulty;

  const ModernQuizScreen({
    super.key,
    required this.topicName,
    required this.operator,
    this.difficulty = 'easy',
  });

  @override
  State<ModernQuizScreen> createState() => _ModernQuizScreenState();
}

class _ModernQuizScreenState extends State<ModernQuizScreen> with TickerProviderStateMixin {
  final math.Random _random = math.Random();
  late AnimationController _backgroundController;
  late AnimationController _questionController;
  late AnimationController _answerController;
  late AnimationController _progressController;
  late Animation<double> _backgroundAnimation;
  late Animation<double> _questionPulse;
  late Animation<double> _answerScale;
  late Animation<double> _progressGlow;
  
  int currentQuestionIndex = 0;
  int correctAnswers = 0;
  int? selectedAnswer;
  bool hasAnswered = false;
  
  int operand1 = 0;
  int operand2 = 0;
  int correctAnswerValue = 0;
  List<int> options = [];
  
  final int totalQuestions = 10;
  late Stopwatch stopwatch;
  Timer? timer;

  @override
  void initState() {
    super.initState();
    _initializeAnimations();
    _generateQuestion();
    stopwatch = Stopwatch()..start();
    _startTimer();
  }

  void _initializeAnimations() {
    _backgroundController = AnimationController(
      duration: const Duration(seconds: 20),
      vsync: this,
    )..repeat();
    
    _questionController = AnimationController(
      duration: const Duration(milliseconds: 1500),
      vsync: this,
    );
    
    _answerController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );
    
    _progressController = AnimationController(
      duration: const Duration(milliseconds: 600),
      vsync: this,
    );

    _backgroundAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(_backgroundController);

    _questionPulse = Tween<double>(
      begin: 0.95,
      end: 1.05,
    ).animate(CurvedAnimation(
      parent: _questionController,
      curve: Curves.easeInOut,
    ));

    _answerScale = Tween<double>(
      begin: 0.8,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _answerController,
      curve: Curves.elasticOut,
    ));

    _progressGlow = Tween<double>(
      begin: 1.0,
      end: 1.2,
    ).animate(CurvedAnimation(
      parent: _progressController,
      curve: Curves.easeInOut,
    ));

    _questionController.repeat(reverse: true);
    _answerController.forward();
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
    _answerController.reset();
    _answerController.forward();
  }

  void _generateAdditionQuestion() {
    switch (widget.difficulty.toLowerCase()) {
      case 'easy':
        operand1 = _random.nextInt(10) + 1;
        operand2 = _random.nextInt(10) + 1;
        break;
      case 'medium':
        operand1 = _random.nextInt(90) + 10;
        operand2 = _random.nextInt(90) + 10;
        break;
      case 'hard':
        operand1 = _random.nextInt(900) + 100;
        operand2 = _random.nextInt(900) + 100;
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
        operand1 = _random.nextInt(15) + 6;
        operand2 = _random.nextInt(operand1 - 1) + 1;
        break;
      case 'medium':
        operand1 = _random.nextInt(90) + 50;
        operand2 = _random.nextInt(operand1 - 10) + 10;
        break;
      case 'hard':
        operand1 = _random.nextInt(900) + 200;
        operand2 = _random.nextInt(operand1 - 50) + 50;
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
        operand1 = _random.nextInt(5) + 1;
        operand2 = _random.nextInt(5) + 1;
        break;
      case 'medium':
        operand1 = _random.nextInt(12) + 1;
        operand2 = _random.nextInt(12) + 1;
        break;
      case 'hard':
        operand1 = _random.nextInt(25) + 1;
        operand2 = _random.nextInt(25) + 1;
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
        operand2 = _random.nextInt(5) + 2;
        correctAnswerValue = _random.nextInt(5) + 1;
        break;
      case 'medium':
        operand2 = _random.nextInt(10) + 2;
        correctAnswerValue = _random.nextInt(12) + 1;
        break;
      case 'hard':
        operand2 = _random.nextInt(23) + 2;
        correctAnswerValue = _random.nextInt(25) + 1;
        break;
      default:
        operand2 = _random.nextInt(5) + 2;
        correctAnswerValue = _random.nextInt(5) + 1;
    }
    operand1 = operand2 * correctAnswerValue;
  }

  void _selectAnswer(int answer) {
    if (hasAnswered) return;
    
    setState(() {
      selectedAnswer = answer;
      hasAnswered = true;
    });

    if (answer == correctAnswerValue) {
      correctAnswers++;
      _progressController.forward().then((_) => _progressController.reverse());
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

  void _completeSession() {
    stopwatch.stop();
    timer?.cancel();
    
    // Show completion dialog
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => _buildCompletionDialog(),
    );
  }

  Color _getDifficultyColor() {
    switch (widget.difficulty.toLowerCase()) {
      case 'easy':
        return const Color(0xFF00D4AA);
      case 'medium':
        return const Color(0xFFFF6B6B);
      case 'hard':
        return const Color(0xFF4ECDC4);
      default:
        return const Color(0xFF5B9EF3);
    }
  }

  Color _getOperatorColor() {
    switch (widget.operator) {
      case '+':
        return const Color(0xFF6C5CE7);
      case '-':
        return const Color(0xFFE84393);
      case '×':
        return const Color(0xFF00B894);
      case '÷':
        return const Color(0xFFE17055);
      default:
        return const Color(0xFF74B9FF);
    }
  }

  @override
  void dispose() {
    _backgroundController.dispose();
    _questionController.dispose();
    _answerController.dispose();
    _progressController.dispose();
    timer?.cancel();
    stopwatch.stop();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: AnimatedBuilder(
        animation: _backgroundAnimation,
        builder: (context, child) {
          return Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  const Color(0xFF0F0F23),
                  const Color(0xFF1A1A3E),
                  _getDifficultyColor().withValues(alpha: 0.3),
                  _getOperatorColor().withValues(alpha: 0.2),
                ],
                transform: GradientRotation(_backgroundAnimation.value * 2 * math.pi),
              ),
            ),
            child: SafeArea(
              child: Column(
                children: [
                  _buildModernAppBar(),
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.all(20),
                      child: Column(
                        children: [
                          _buildProgressSection(),
                          const SizedBox(height: 30),
                          _buildQuestionSection(),
                          const SizedBox(height: 40),
                          _buildAnswerSection(),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildModernAppBar() {
    return Container(
      padding: const EdgeInsets.all(20),
      child: Row(
        children: [
          Container(
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(15),
              border: Border.all(
                color: Colors.white.withValues(alpha: 0.2),
                width: 1,
              ),
            ),
            child: IconButton(
              icon: const Icon(Icons.arrow_back, color: Colors.white),
              onPressed: () => Navigator.pop(context),
            ),
          ),
          const SizedBox(width: 20),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${widget.topicName} Quiz',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        _getDifficultyColor(),
                        _getDifficultyColor().withValues(alpha: 0.7),
                      ],
                    ),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    '${widget.difficulty.toUpperCase()} LEVEL',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 1.0,
                    ),
                  ),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            decoration: BoxDecoration(
              color: _getOperatorColor().withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: _getOperatorColor(),
                width: 2,
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.timer,
                  color: _getOperatorColor(),
                  size: 18,
                ),
                const SizedBox(width: 8),
                Text(
                  '${stopwatch.elapsed.inMinutes}:${(stopwatch.elapsed.inSeconds % 60).toString().padLeft(2, '0')}',
                  style: TextStyle(
                    color: _getOperatorColor(),
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildProgressSection() {
    return AnimatedBuilder(
      animation: _progressGlow,
      builder: (context, child) {
        return Transform.scale(
          scale: _progressGlow.value,
          child: Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  Colors.white.withValues(alpha: 0.1),
                  Colors.white.withValues(alpha: 0.05),
                ],
              ),
              borderRadius: BorderRadius.circular(25),
              border: Border.all(
                color: _getDifficultyColor().withValues(alpha: 0.3),
                width: 2,
              ),
              boxShadow: [
                BoxShadow(
                  color: _getDifficultyColor().withValues(alpha: 0.3),
                  blurRadius: 20,
                  offset: const Offset(0, 10),
                ),
              ],
            ),
            child: Column(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Question ${currentQuestionIndex + 1} of $totalQuestions',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: _getDifficultyColor().withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(15),
                      ),
                      child: Text(
                        '$correctAnswers Correct',
                        style: TextStyle(
                          color: _getDifficultyColor(),
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Container(
                  height: 8,
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Stack(
                    children: [
                      FractionallySizedBox(
                        widthFactor: (currentQuestionIndex + 1) / totalQuestions,
                        child: Container(
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              colors: [
                                _getDifficultyColor(),
                                _getOperatorColor(),
                              ],
                            ),
                            borderRadius: BorderRadius.circular(4),
                            boxShadow: [
                              BoxShadow(
                                color: _getDifficultyColor().withValues(alpha: 0.5),
                                blurRadius: 8,
                                offset: const Offset(0, 2),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildQuestionSection() {
    return AnimatedBuilder(
      animation: _questionPulse,
      builder: (context, child) {
        return Transform.scale(
          scale: _questionPulse.value,
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.all(30),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  Colors.white,
                  Colors.white.withValues(alpha: 0.95),
                  _getOperatorColor().withValues(alpha: 0.1),
                ],
              ),
              borderRadius: BorderRadius.circular(30),
              border: Border.all(
                color: _getOperatorColor().withValues(alpha: 0.3),
                width: 3,
              ),
              boxShadow: [
                BoxShadow(
                  color: _getOperatorColor().withValues(alpha: 0.3),
                  blurRadius: 25,
                  offset: const Offset(0, 15),
                  spreadRadius: 5,
                ),
                BoxShadow(
                  color: Colors.white.withValues(alpha: 0.8),
                  blurRadius: 15,
                  offset: const Offset(-5, -5),
                ),
              ],
            ),
            child: Column(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        _getOperatorColor(),
                        _getOperatorColor().withValues(alpha: 0.8),
                      ],
                    ),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    'Solve the Problem',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                const SizedBox(height: 20),
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: const Color(0xFF1A1A3E),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: _getDifficultyColor(),
                      width: 2,
                    ),
                  ),
                  child: Text(
                    '$operand1 ${widget.operator} $operand2 = ?',
                    style: TextStyle(
                      fontSize: 42,
                      fontWeight: FontWeight.w900,
                      color: _getDifficultyColor(),
                      letterSpacing: 2.0,
                      shadows: [
                        Shadow(
                          color: _getDifficultyColor().withValues(alpha: 0.5),
                          blurRadius: 10,
                          offset: const Offset(0, 3),
                        ),
                      ],
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),
                if (hasAnswered) ...[
                  const SizedBox(height: 20),
                  TweenAnimationBuilder<double>(
                    duration: const Duration(milliseconds: 600),
                    tween: Tween(begin: 0.0, end: 1.0),
                    curve: Curves.elasticOut,
                    builder: (context, value, child) {
                      return Transform.scale(
                        scale: value,
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              colors: selectedAnswer == correctAnswerValue
                                  ? [const Color(0xFF00D4AA), const Color(0xFF00B894)]
                                  : [const Color(0xFFFF6B6B), const Color(0xFFE84393)],
                            ),
                            borderRadius: BorderRadius.circular(25),
                            boxShadow: [
                              BoxShadow(
                                color: (selectedAnswer == correctAnswerValue
                                    ? const Color(0xFF00D4AA)
                                    : const Color(0xFFFF6B6B)).withValues(alpha: 0.4),
                                blurRadius: 15,
                                offset: const Offset(0, 8),
                              ),
                            ],
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                selectedAnswer == correctAnswerValue
                                    ? Icons.check_circle
                                    : Icons.cancel,
                                color: Colors.white,
                                size: 24,
                              ),
                              const SizedBox(width: 10),
                              Text(
                                selectedAnswer == correctAnswerValue
                                    ? 'Excellent!'
                                    : 'Try Again!',
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                ],
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildAnswerSection() {
    return AnimatedBuilder(
      animation: _answerScale,
      builder: (context, child) {
        return Transform.scale(
          scale: _answerScale.value,
          child: GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              crossAxisSpacing: 20,
              mainAxisSpacing: 20,
              childAspectRatio: 2.0,
            ),
            itemCount: options.length,
            itemBuilder: (context, index) {
              final option = options[index];
              final isCorrect = option == correctAnswerValue;
              final isSelected = selectedAnswer == option;
              
              return TweenAnimationBuilder<double>(
                duration: Duration(milliseconds: 400 + (index * 150)),
                tween: Tween(begin: 0.0, end: 1.0),
                curve: Curves.easeOutBack,
                builder: (context, value, child) {
                  return Transform.scale(
                    scale: value,
                    child: Transform.translate(
                      offset: Offset((1 - value) * 100, 0),
                      child: _buildAnswerButton(option, isCorrect, isSelected, index),
                    ),
                  );
                },
              );
            },
          ),
        );
      },
    );
  }

  Widget _buildAnswerButton(int option, bool isCorrect, bool isSelected, int index) {
    Color primaryColor;
    Color secondaryColor;
    
    if (hasAnswered) {
      if (isCorrect) {
        primaryColor = const Color(0xFF00D4AA);
        secondaryColor = const Color(0xFF00B894);
      } else if (isSelected && !isCorrect) {
        primaryColor = const Color(0xFFFF6B6B);
        secondaryColor = const Color(0xFFE84393);
      } else {
        primaryColor = Colors.grey[400]!;
        secondaryColor = Colors.grey[500]!;
      }
    } else {
      primaryColor = Colors.white;
      secondaryColor = _getOperatorColor().withValues(alpha: 0.1);
    }

    return GestureDetector(
      onTap: hasAnswered ? null : () => _selectAnswer(option),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [primaryColor, secondaryColor],
          ),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: hasAnswered && isCorrect
                ? const Color(0xFF00D4AA)
                : hasAnswered && isSelected
                    ? const Color(0xFFFF6B6B)
                    : _getOperatorColor().withValues(alpha: 0.4),
            width: hasAnswered ? 3 : 2,
          ),
          boxShadow: [
            BoxShadow(
              color: hasAnswered && isCorrect
                  ? const Color(0xFF00D4AA).withValues(alpha: 0.4)
                  : hasAnswered && isSelected
                      ? const Color(0xFFFF6B6B).withValues(alpha: 0.4)
                      : _getOperatorColor().withValues(alpha: 0.2),
              blurRadius: hasAnswered ? 15 : 10,
              offset: const Offset(0, 5),
            ),
          ],
        ),
        child: Center(
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (hasAnswered && isCorrect)
                const Icon(
                  Icons.check_circle,
                  color: Colors.white,
                  size: 24,
                ),
              if (hasAnswered && isSelected && !isCorrect)
                const Icon(
                  Icons.cancel,
                  color: Colors.white,
                  size: 24,
                ),
              if (hasAnswered && (isCorrect || isSelected))
                const SizedBox(width: 8),
              Text(
                '$option',
                style: TextStyle(
                  fontSize: 32,
                  fontWeight: FontWeight.w900,
                  color: hasAnswered 
                      ? Colors.white 
                      : _getOperatorColor(),
                  letterSpacing: 1.0,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCompletionDialog() {
    final accuracy = correctAnswers / totalQuestions;
    
    return Dialog(
      backgroundColor: Colors.transparent,
      child: Container(
        padding: const EdgeInsets.all(30),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              const Color(0xFF1A1A3E),
              const Color(0xFF2D2D5F),
              _getDifficultyColor().withValues(alpha: 0.3),
            ],
          ),
          borderRadius: BorderRadius.circular(25),
          border: Border.all(
            color: _getDifficultyColor(),
            width: 2,
          ),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TweenAnimationBuilder<double>(
              duration: const Duration(seconds: 1),
              tween: Tween(begin: 0.0, end: 1.0),
              curve: Curves.elasticOut,
              builder: (context, value, child) {
                return Transform.scale(
                  scale: value,
                  child: Text(
                    '🎉',
                    style: TextStyle(fontSize: 60),
                  ),
                );
              },
            ),
            const SizedBox(height: 20),
            Text(
              'Quiz Complete!',
              style: TextStyle(
                color: _getDifficultyColor(),
                fontSize: 28,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 20),
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(15),
              ),
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Score:',
                        style: const TextStyle(color: Colors.white, fontSize: 16),
                      ),
                      Text(
                        '$correctAnswers/$totalQuestions',
                        style: TextStyle(
                          color: _getDifficultyColor(),
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Accuracy:',
                        style: const TextStyle(color: Colors.white, fontSize: 16),
                      ),
                      Text(
                        '${(accuracy * 100).round()}%',
                        style: TextStyle(
                          color: _getDifficultyColor(),
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Time:',
                        style: const TextStyle(color: Colors.white, fontSize: 16),
                      ),
                      Text(
                        '${stopwatch.elapsed.inMinutes}:${(stopwatch.elapsed.inSeconds % 60).toString().padLeft(2, '0')}',
                        style: TextStyle(
                          color: _getDifficultyColor(),
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 30),
            Row(
              children: [
                Expanded(
                  child: ElevatedButton(
                    onPressed: () {
                      Navigator.pop(context);
                      Navigator.pop(context);
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.white.withValues(alpha: 0.2),
                      padding: const EdgeInsets.symmetric(vertical: 15),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(15),
                      ),
                    ),
                    child: const Text(
                      'Back',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 15),
                Expanded(
                  child: ElevatedButton(
                    onPressed: () {
                      Navigator.pop(context);
                      Navigator.pushReplacement(
                        context,
                        MaterialPageRoute(
                          builder: (context) => ModernQuizScreen(
                            topicName: widget.topicName,
                            operator: widget.operator,
                            difficulty: widget.difficulty,
                          ),
                        ),
                      );
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _getDifficultyColor(),
                      padding: const EdgeInsets.symmetric(vertical: 15),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(15),
                      ),
                    ),
                    child: const Text(
                      'Play Again',
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
          ],
        ),
      ),
    );
  }
}