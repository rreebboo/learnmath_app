import 'dart:math';
import '../models/math_question.dart';
import '../models/math_topic.dart';

class MathService {
  static final Random _random = Random();

  // Generate a math question based on topic and difficulty
  static MathQuestion generateQuestion({
    required String topic,
    required String difficulty,
  }) {
    switch (topic.toLowerCase()) {
      case 'addition':
        return _generateAdditionQuestion(difficulty);
      case 'subtraction':
        return _generateSubtractionQuestion(difficulty);
      case 'multiplication':
        return _generateMultiplicationQuestion(difficulty);
      case 'division':
        return _generateDivisionQuestion(difficulty);
      default:
        return _generateAdditionQuestion(difficulty);
    }
  }

  // Generate multiple questions for a practice session
  static List<MathQuestion> generateQuestions({
    required String topic,
    required String difficulty,
    required int count,
  }) {
    return List.generate(
      count,
      (index) => generateQuestion(topic: topic, difficulty: difficulty),
    );
  }

  // Addition questions
  static MathQuestion _generateAdditionQuestion(String difficulty) {
    int operand1, operand2;
    
    switch (difficulty.toLowerCase()) {
      case 'easy':
        // Easy: 1-digit + 1-digit (1-9 + 1-9)
        operand1 = _random.nextInt(9) + 1; // 1-9 (1-digit)
        operand2 = _random.nextInt(9) + 1; // 1-9 (1-digit)
        break;
      case 'medium':
      case 'moderate':
        // Moderate: 2-digit + 1-digit (10-99 + 1-9)
        operand1 = _random.nextInt(90) + 10; // 10-99 (2-digit)
        operand2 = _random.nextInt(9) + 1; // 1-9 (1-digit)
        break;
      case 'hard':
      case 'advanced':
        // Advanced: 3-digit + 2-digit (100-999 + 10-99)
        operand1 = _random.nextInt(900) + 100; // 100-999 (3-digit)
        operand2 = _random.nextInt(90) + 10; // 10-99 (2-digit)
        break;
      default:
        operand1 = _random.nextInt(9) + 1;
        operand2 = _random.nextInt(9) + 1;
    }

    final correctAnswer = operand1 + operand2;
    final options = _generateOptions(correctAnswer);

    return MathQuestion(
      operand1: operand1,
      operand2: operand2,
      operator: '+',
      correctAnswer: correctAnswer,
      options: options,
      difficulty: difficulty,
    );
  }

  // Subtraction questions
  static MathQuestion _generateSubtractionQuestion(String difficulty) {
    int operand1, operand2;
    
    switch (difficulty.toLowerCase()) {
      case 'easy':
        // Easy: 1-digit - 1-digit (1-9 - 1-9, result >= 0)
        operand1 = _random.nextInt(9) + 1; // 1-9 (1-digit)
        operand2 = _random.nextInt(9) + 1; // 1-9 (1-digit)
        // Ensure operand1 >= operand2 to avoid negative results
        if (operand2 > operand1) {
          final temp = operand1;
          operand1 = operand2;
          operand2 = temp;
        }
        break;
      case 'medium':
      case 'moderate':
        // Moderate: 2-digit - 1-digit (10-99 - 1-9)
        operand1 = _random.nextInt(90) + 10; // 10-99 (2-digit)
        operand2 = _random.nextInt(9) + 1; // 1-9 (1-digit)
        break;
      case 'hard':
      case 'advanced':
        // Advanced: 3-digit - 2-digit (100-999 - 10-99)
        operand1 = _random.nextInt(900) + 100; // 100-999 (3-digit)
        operand2 = _random.nextInt(90) + 10; // 10-99 (2-digit)
        break;
      default:
        operand1 = _random.nextInt(9) + 1;
        operand2 = _random.nextInt(9) + 1;
        if (operand2 > operand1) {
          final temp = operand1;
          operand1 = operand2;
          operand2 = temp;
        }
    }

    final correctAnswer = operand1 - operand2;
    final options = _generateOptions(correctAnswer);

    return MathQuestion(
      operand1: operand1,
      operand2: operand2,
      operator: '-',
      correctAnswer: correctAnswer,
      options: options,
      difficulty: difficulty,
    );
  }

  // Multiplication questions
  static MathQuestion _generateMultiplicationQuestion(String difficulty) {
    int operand1, operand2;
    
    switch (difficulty.toLowerCase()) {
      case 'easy':
        // Easy: 1-digit × 1-digit (1-9 × 1-9)
        operand1 = _random.nextInt(9) + 1; // 1-9 (1-digit)
        operand2 = _random.nextInt(9) + 1; // 1-9 (1-digit)
        break;
      case 'medium':
      case 'moderate':
        // Moderate: 2-digit × 1-digit (10-99 × 1-9)
        operand1 = _random.nextInt(90) + 10; // 10-99 (2-digit)
        operand2 = _random.nextInt(9) + 1; // 1-9 (1-digit)
        break;
      case 'hard':
      case 'advanced':
        // Advanced: 3-digit × 2-digit (100-999 × 10-99)
        operand1 = _random.nextInt(900) + 100; // 100-999 (3-digit)
        operand2 = _random.nextInt(90) + 10; // 10-99 (2-digit)
        break;
      default:
        operand1 = _random.nextInt(9) + 1;
        operand2 = _random.nextInt(9) + 1;
    }

    final correctAnswer = operand1 * operand2;
    final options = _generateOptions(correctAnswer);

    return MathQuestion(
      operand1: operand1,
      operand2: operand2,
      operator: '×',
      correctAnswer: correctAnswer,
      options: options,
      difficulty: difficulty,
    );
  }

  // Division questions
  static MathQuestion _generateDivisionQuestion(String difficulty) {
    int divisor, quotient;
    
    switch (difficulty.toLowerCase()) {
      case 'easy':
        // Easy: (1-digit × 1-digit) ÷ 1-digit = 1-digit
        divisor = _random.nextInt(9) + 1; // 1-9 (1-digit)
        quotient = _random.nextInt(9) + 1; // 1-9 (1-digit)
        break;
      case 'medium':
      case 'moderate':
        // Moderate: (2-digit × 1-digit) ÷ 1-digit = 2-digit
        divisor = _random.nextInt(9) + 1; // 1-9 (1-digit)
        quotient = _random.nextInt(90) + 10; // 10-99 (2-digit)
        break;
      case 'hard':
      case 'advanced':
        // Advanced: (3-digit × 2-digit) ÷ 2-digit = 3-digit
        divisor = _random.nextInt(90) + 10; // 10-99 (2-digit)
        quotient = _random.nextInt(900) + 100; // 100-999 (3-digit)
        break;
      default:
        divisor = _random.nextInt(9) + 1;
        quotient = _random.nextInt(9) + 1;
    }

    final operand1 = divisor * quotient; // Ensure whole number result
    final correctAnswer = quotient;
    final options = _generateOptions(correctAnswer);

    return MathQuestion(
      operand1: operand1,
      operand2: divisor,
      operator: '÷',
      correctAnswer: correctAnswer,
      options: options,
      difficulty: difficulty,
    );
  }

  // Generate multiple choice options
  static List<int> _generateOptions(int correctAnswer) {
    final Set<int> options = {correctAnswer};
    
    while (options.length < 4) {
      int wrongAnswer;
      if (correctAnswer <= 10) {
        wrongAnswer = _random.nextInt(20) + 1;
      } else if (correctAnswer <= 50) {
        wrongAnswer = correctAnswer + (_random.nextInt(21) - 10); // ±10
      } else {
        wrongAnswer = correctAnswer + (_random.nextInt(41) - 20); // ±20
      }
      
      if (wrongAnswer > 0 && wrongAnswer != correctAnswer) {
        options.add(wrongAnswer);
      }
    }
    
    final List<int> optionsList = options.toList();
    optionsList.shuffle();
    return optionsList;
  }

  // Calculate score based on accuracy and time
  static int calculateScore({
    required int correctAnswers,
    required int totalQuestions,
    required Duration timeSpent,
    required String difficulty,
  }) {
    final double accuracy = correctAnswers / totalQuestions;
    final double baseScore = correctAnswers * 10;
    
    // Difficulty multiplier
    double difficultyMultiplier = 1.0;
    switch (difficulty.toLowerCase()) {
      case 'easy':
        difficultyMultiplier = 1.0;
        break;
      case 'medium':
      case 'moderate':
        difficultyMultiplier = 1.5;
        break;
      case 'hard':
      case 'advanced':
        difficultyMultiplier = 2.0;
        break;
    }

    // Time bonus (faster = more points, max 50% bonus)
    final int averageTimePerQuestion = timeSpent.inSeconds ~/ totalQuestions;
    double timeMultiplier = 1.0;
    if (averageTimePerQuestion <= 5) {
      timeMultiplier = 1.5;
    } else if (averageTimePerQuestion <= 10) {
      timeMultiplier = 1.3;
    } else if (averageTimePerQuestion <= 15) {
      timeMultiplier = 1.1;
    }

    // Perfect accuracy bonus
    double accuracyBonus = accuracy == 1.0 ? 1.2 : 1.0;

    final int finalScore = (baseScore * difficultyMultiplier * timeMultiplier * accuracyBonus).round();
    return finalScore;
  }

  // Get default math topics with progression
  static List<MathTopic> getDefaultTopics() {
    return [
      MathTopic(
        id: 'addition',
        name: 'Addition',
        operator: '+',
        totalLessons: 10,
        completedLessons: 0,
        stars: 0,
        isUnlocked: true, // First topic is always unlocked
        description: 'Learn to add numbers together',
      ),
      MathTopic(
        id: 'subtraction',
        name: 'Subtraction',
        operator: '-',
        totalLessons: 10,
        completedLessons: 0,
        stars: 0,
        isUnlocked: false,
        description: 'Learn to subtract numbers',
      ),
      MathTopic(
        id: 'multiplication',
        name: 'Multiplication',
        operator: '×',
        totalLessons: 8,
        completedLessons: 0,
        stars: 0,
        isUnlocked: false,
        description: 'Learn to multiply numbers',
      ),
      MathTopic(
        id: 'division',
        name: 'Division',
        operator: '÷',
        totalLessons: 8,
        completedLessons: 0,
        stars: 0,
        isUnlocked: false,
        description: 'Learn to divide numbers',
      ),
    ];
  }

  // Check if next topic should be unlocked
  static bool shouldUnlockNextTopic(MathTopic currentTopic) {
    // Unlock next topic if current topic is at least 70% complete
    return currentTopic.progress >= 0.7;
  }

  // Get stars based on performance
  static int calculateStars({
    required double accuracy,
    required Duration averageTime,
  }) {
    int stars = 0;
    
    // Base star for completion
    if (accuracy > 0) stars++;
    
    // Second star for good accuracy
    if (accuracy >= 0.7) stars++;
    
    // Third star for excellent accuracy
    if (accuracy >= 0.9) stars++;
    
    // Bonus stars for speed (optional)
    if (accuracy >= 0.8 && averageTime.inSeconds <= 10) {
      stars = 5; // Perfect performance
    } else if (accuracy >= 0.8 && averageTime.inSeconds <= 15) {
      stars = 4; // Excellent performance
    }
    
    return stars.clamp(0, 5);
  }
}