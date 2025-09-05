import 'dart:math';
import '../models/math_question.dart';

enum DifficultyLevel {
  easy,
  medium,
  hard,
}

enum MathOperation {
  addition,
  subtraction,
  multiplication,
  division,
}

class QuizAttempt {
  final MathQuestion question;
  final int userAnswer;
  final bool isCorrect;
  final DifficultyLevel difficultyLevel;
  final DateTime timestamp;

  QuizAttempt({
    required this.question,
    required this.userAnswer,
    required this.isCorrect,
    required this.difficultyLevel,
    required this.timestamp,
  });

  Map<String, dynamic> toMap() {
    return {
      'question': question.toMap(),
      'userAnswer': userAnswer,
      'isCorrect': isCorrect,
      'difficultyLevel': difficultyLevel.toString(),
      'timestamp': timestamp.millisecondsSinceEpoch,
    };
  }

  factory QuizAttempt.fromMap(Map<String, dynamic> map) {
    return QuizAttempt(
      question: MathQuestion.fromMap(map['question']),
      userAnswer: map['userAnswer'] ?? 0,
      isCorrect: map['isCorrect'] ?? false,
      difficultyLevel: DifficultyLevel.values.firstWhere(
        (e) => e.toString() == map['difficultyLevel'],
        orElse: () => DifficultyLevel.easy,
      ),
      timestamp: DateTime.fromMillisecondsSinceEpoch(map['timestamp'] ?? 0),
    );
  }
}

class QuizEngine {
  static final Random _random = Random();
  
  DifficultyLevel _currentDifficulty = DifficultyLevel.easy;
  MathOperation _currentOperation = MathOperation.addition;
  int _consecutiveCorrect = 0;
  int _questionsInCurrentDifficultyAndOperation = 0;
  int _correctAnswersInCurrentLevel = 0;
  final List<QuizAttempt> _attempts = [];
  final Set<String> _usedQuestions = {};
  
  static const int questionsPerDifficultyLevel = 10;
  
  DifficultyLevel get currentDifficulty => _currentDifficulty;
  MathOperation get currentOperation => _currentOperation;
  List<QuizAttempt> get attempts => List.unmodifiable(_attempts);
  int get questionsInCurrentDifficultyAndOperation => _questionsInCurrentDifficultyAndOperation;
  int get correctAnswersInCurrentLevel => _correctAnswersInCurrentLevel;
  
  void reset() {
    _currentDifficulty = DifficultyLevel.easy;
    _currentOperation = MathOperation.addition;
    _consecutiveCorrect = 0;
    _questionsInCurrentDifficultyAndOperation = 0;
    _correctAnswersInCurrentLevel = 0;
    _attempts.clear();
    _usedQuestions.clear();
  }
  
  MathQuestion generateQuestion() {
    MathQuestion question;
    String questionKey;
    int attempts = 0;
    const maxAttempts = 50;
    
    do {
      switch (_currentOperation) {
        case MathOperation.addition:
          question = _generateAdditionQuestion();
          break;
        case MathOperation.subtraction:
          question = _generateSubtractionQuestion();
          break;
        case MathOperation.multiplication:
          question = _generateMultiplicationQuestion();
          break;
        case MathOperation.division:
          question = _generateDivisionQuestion();
          break;
      }
      
      questionKey = '${question.operand1}${question.operator}${question.operand2}$_currentDifficulty$_currentOperation';
      attempts++;
      
      if (attempts >= maxAttempts) {
        _usedQuestions.clear();
        break;
      }
    } while (_usedQuestions.contains(questionKey));
    
    _usedQuestions.add(questionKey);
    return question;
  }
  
  void submitAnswer(MathQuestion question, int userAnswer) {
    final isCorrect = userAnswer == question.correctAnswer;
    final attempt = QuizAttempt(
      question: question,
      userAnswer: userAnswer,
      isCorrect: isCorrect,
      difficultyLevel: _currentDifficulty,
      timestamp: DateTime.now(),
    );
    
    _attempts.add(attempt);
    _questionsInCurrentDifficultyAndOperation++;
    
    if (isCorrect) {
      _consecutiveCorrect++;
      _correctAnswersInCurrentLevel++;
    } else {
      _consecutiveCorrect = 0;
    }
    
    if (_questionsInCurrentDifficultyAndOperation >= questionsPerDifficultyLevel) {
      _handleLevelCompletion();
    }
  }
  
  void _handleLevelCompletion() {
    bool hasPerfectScore = _correctAnswersInCurrentLevel == questionsPerDifficultyLevel;
    
    if (hasPerfectScore) {
      _progressToNextLevel();
    } else {
      _resetCurrentLevel();
    }
  }
  
  void _progressToNextLevel() {
    _questionsInCurrentDifficultyAndOperation = 0;
    _correctAnswersInCurrentLevel = 0;
    _consecutiveCorrect = 0;
    
    if (_currentDifficulty == DifficultyLevel.easy) {
      _currentDifficulty = DifficultyLevel.medium;
    } else if (_currentDifficulty == DifficultyLevel.medium) {
      _currentDifficulty = DifficultyLevel.hard;
    } else if (_currentDifficulty == DifficultyLevel.hard) {
      _currentDifficulty = DifficultyLevel.easy;
      _progressToNextOperation();
    }
  }
  
  void _resetCurrentLevel() {
    _questionsInCurrentDifficultyAndOperation = 0;
    _correctAnswersInCurrentLevel = 0;
    _consecutiveCorrect = 0;
  }
  
  void _progressToNextOperation() {
    switch (_currentOperation) {
      case MathOperation.addition:
        _currentOperation = MathOperation.subtraction;
        break;
      case MathOperation.subtraction:
        _currentOperation = MathOperation.multiplication;
        break;
      case MathOperation.multiplication:
        _currentOperation = MathOperation.division;
        break;
      case MathOperation.division:
        break;
    }
  }
  
  bool isQuizComplete() {
    return _currentOperation == MathOperation.division && 
           _currentDifficulty == DifficultyLevel.hard && 
           _questionsInCurrentDifficultyAndOperation >= questionsPerDifficultyLevel &&
           _correctAnswersInCurrentLevel == questionsPerDifficultyLevel;
  }
  
  bool requiresLevelReset() {
    return _questionsInCurrentDifficultyAndOperation >= questionsPerDifficultyLevel &&
           _correctAnswersInCurrentLevel < questionsPerDifficultyLevel;
  }
  
  MathQuestion _generateAdditionQuestion() {
    int operand1, operand2;
    
    switch (_currentDifficulty) {
      case DifficultyLevel.easy:
        operand1 = _random.nextInt(9) + 1; // 1-9 (1-digit)
        operand2 = _random.nextInt(9) + 1; // 1-9 (1-digit)
        break;
      case DifficultyLevel.medium:
        operand1 = _random.nextInt(90) + 10; // 10-99 (2-digit)
        operand2 = _random.nextInt(90) + 10; // 10-99 (2-digit)
        break;
      case DifficultyLevel.hard:
        operand1 = _random.nextInt(900) + 100; // 100-999 (3-digit)
        operand2 = _random.nextInt(900) + 100; // 100-999 (3-digit)
        break;
    }
    
    final correctAnswer = operand1 + operand2;
    final options = _generateOptions(correctAnswer);
    
    return MathQuestion(
      operand1: operand1,
      operand2: operand2,
      operator: '+',
      correctAnswer: correctAnswer,
      options: options,
      difficulty: _currentDifficulty.toString().split('.').last,
    );
  }
  
  MathQuestion _generateSubtractionQuestion() {
    int operand1, operand2;
    
    switch (_currentDifficulty) {
      case DifficultyLevel.easy:
        operand1 = _random.nextInt(8) + 2; // 2-9 (1-digit)
        operand2 = _random.nextInt(operand1 - 1) + 1; // 1 to operand1-1 (1-digit)
        break;
      case DifficultyLevel.medium:
        operand1 = _random.nextInt(90) + 10; // 10-99 (2-digit)
        operand2 = _random.nextInt(90) + 10; // 10-99 (2-digit)
        if (operand2 > operand1) {
          final temp = operand1;
          operand1 = operand2;
          operand2 = temp;
        }
        break;
      case DifficultyLevel.hard:
        operand1 = _random.nextInt(900) + 100; // 100-999 (3-digit)
        operand2 = _random.nextInt(900) + 100; // 100-999 (3-digit)
        if (operand2 > operand1) {
          final temp = operand1;
          operand1 = operand2;
          operand2 = temp;
        }
        break;
    }
    
    final correctAnswer = operand1 - operand2;
    final options = _generateOptions(correctAnswer);
    
    return MathQuestion(
      operand1: operand1,
      operand2: operand2,
      operator: '-',
      correctAnswer: correctAnswer,
      options: options,
      difficulty: _currentDifficulty.toString().split('.').last,
    );
  }
  
  MathQuestion _generateMultiplicationQuestion() {
    int operand1, operand2;
    
    switch (_currentDifficulty) {
      case DifficultyLevel.easy:
        operand1 = _random.nextInt(9) + 1; // 1-9 (1-digit)
        operand2 = _random.nextInt(9) + 1; // 1-9 (1-digit)
        break;
      case DifficultyLevel.medium:
        operand1 = _random.nextInt(90) + 10; // 10-99 (2-digit)
        operand2 = _random.nextInt(90) + 10; // 10-99 (2-digit)
        break;
      case DifficultyLevel.hard:
        operand1 = _random.nextInt(900) + 100; // 100-999 (3-digit)
        operand2 = _random.nextInt(900) + 100; // 100-999 (3-digit)
        break;
    }
    
    final correctAnswer = operand1 * operand2;
    final options = _generateOptions(correctAnswer);
    
    return MathQuestion(
      operand1: operand1,
      operand2: operand2,
      operator: '×',
      correctAnswer: correctAnswer,
      options: options,
      difficulty: _currentDifficulty.toString().split('.').last,
    );
  }
  
  MathQuestion _generateDivisionQuestion() {
    int divisor, quotient;
    
    switch (_currentDifficulty) {
      case DifficultyLevel.easy:
        divisor = _random.nextInt(8) + 2; // 2-9 (1-digit)
        quotient = _random.nextInt(9) + 1; // 1-9 (1-digit)
        break;
      case DifficultyLevel.medium:
        divisor = _random.nextInt(90) + 10; // 10-99 (2-digit)
        quotient = _random.nextInt(90) + 10; // 10-99 (2-digit)
        break;
      case DifficultyLevel.hard:
        divisor = _random.nextInt(900) + 100; // 100-999 (3-digit)
        quotient = _random.nextInt(900) + 100; // 100-999 (3-digit)
        break;
    }
    
    final operand1 = divisor * quotient;
    final correctAnswer = quotient;
    final options = _generateOptions(correctAnswer);
    
    return MathQuestion(
      operand1: operand1,
      operand2: divisor,
      operator: '÷',
      correctAnswer: correctAnswer,
      options: options,
      difficulty: _currentDifficulty.toString().split('.').last,
    );
  }
  
  List<int> _generateOptions(int correctAnswer) {
    final Set<int> options = {correctAnswer};
    
    while (options.length < 4) {
      int wrongAnswer;
      
      if (correctAnswer <= 20) {
        wrongAnswer = correctAnswer + (_random.nextInt(21) - 10);
      } else if (correctAnswer <= 100) {
        wrongAnswer = correctAnswer + (_random.nextInt(41) - 20);
      } else if (correctAnswer <= 1000) {
        wrongAnswer = correctAnswer + (_random.nextInt(201) - 100);
      } else {
        wrongAnswer = correctAnswer + (_random.nextInt(2001) - 1000);
      }
      
      if (wrongAnswer > 0 && wrongAnswer != correctAnswer) {
        options.add(wrongAnswer);
      }
    }
    
    final List<int> optionsList = options.toList();
    optionsList.shuffle();
    return optionsList;
  }
  
  Map<String, dynamic> getStats() {
    if (_attempts.isEmpty) {
      return {
        'totalQuestions': 0,
        'correctAnswers': 0,
        'accuracy': 0.0,
        'currentStreak': _consecutiveCorrect,
        'currentOperation': _currentOperation.toString().split('.').last,
        'currentDifficulty': _currentDifficulty.toString().split('.').last,
        'questionsInCurrentLevel': _questionsInCurrentDifficultyAndOperation,
        'correctAnswersInCurrentLevel': _correctAnswersInCurrentLevel,
        'questionsNeededForNextLevel': questionsPerDifficultyLevel - _questionsInCurrentDifficultyAndOperation,
        'requiresPerfectScore': true,
        'requiresLevelReset': requiresLevelReset(),
        'isQuizComplete': isQuizComplete(),
        'difficultyDistribution': {
          'easy': 0,
          'medium': 0,
          'hard': 0,
        },
      };
    }
    
    final correctAnswers = _attempts.where((a) => a.isCorrect).length;
    final accuracy = correctAnswers / _attempts.length;
    
    final difficultyDistribution = <String, int>{
      'easy': 0,
      'medium': 0,
      'hard': 0,
    };
    
    for (final attempt in _attempts) {
      final diff = attempt.difficultyLevel.toString().split('.').last;
      difficultyDistribution[diff] = (difficultyDistribution[diff] ?? 0) + 1;
    }
    
    return {
      'totalQuestions': _attempts.length,
      'correctAnswers': correctAnswers,
      'accuracy': accuracy,
      'currentStreak': _consecutiveCorrect,
      'currentOperation': _currentOperation.toString().split('.').last,
      'currentDifficulty': _currentDifficulty.toString().split('.').last,
      'questionsInCurrentLevel': _questionsInCurrentDifficultyAndOperation,
      'correctAnswersInCurrentLevel': _correctAnswersInCurrentLevel,
      'questionsNeededForNextLevel': questionsPerDifficultyLevel - _questionsInCurrentDifficultyAndOperation,
      'requiresPerfectScore': true,
      'requiresLevelReset': requiresLevelReset(),
      'isQuizComplete': isQuizComplete(),
      'difficultyDistribution': difficultyDistribution,
    };
  }
}