import 'package:flutter_test/flutter_test.dart';
import 'package:learnmath_app/services/math_service.dart';

void main() {
  group('MathService', () {
    test('should generate addition question correctly', () {
      final question = MathService.generateQuestion(
        topic: 'addition',
        difficulty: 'easy',
      );

      expect(question.operator, '+');
      expect(question.correctAnswer, question.operand1 + question.operand2);
      expect(question.options.length, 4);
      expect(question.options.contains(question.correctAnswer), true);
    });

    test('should generate subtraction question correctly', () {
      final question = MathService.generateQuestion(
        topic: 'subtraction',
        difficulty: 'easy',
      );

      expect(question.operator, '-');
      expect(question.correctAnswer, question.operand1 - question.operand2);
      expect(question.options.length, 4);
      expect(question.options.contains(question.correctAnswer), true);
    });

    test('should generate multiplication question correctly', () {
      final question = MathService.generateQuestion(
        topic: 'multiplication',
        difficulty: 'easy',
      );

      expect(question.operator, '×');
      expect(question.correctAnswer, question.operand1 * question.operand2);
      expect(question.options.length, 4);
      expect(question.options.contains(question.correctAnswer), true);
    });

    test('should generate division question correctly', () {
      final question = MathService.generateQuestion(
        topic: 'division',
        difficulty: 'easy',
      );

      expect(question.operator, '÷');
      expect(question.correctAnswer, question.operand1 ~/ question.operand2);
      expect(question.options.length, 4);
      expect(question.options.contains(question.correctAnswer), true);
      // Verify it's evenly divisible
      expect(question.operand1 % question.operand2, 0);
    });

    test('should generate multiple questions', () {
      final questions = MathService.generateQuestions(
        topic: 'addition',
        difficulty: 'easy',
        count: 5,
      );

      expect(questions.length, 5);
      for (final question in questions) {
        expect(question.operator, '+');
        expect(question.correctAnswer, question.operand1 + question.operand2);
      }
    });

    test('should calculate score correctly', () {
      final score = MathService.calculateScore(
        correctAnswers: 8,
        totalQuestions: 10,
        timeSpent: const Duration(minutes: 2),
        difficulty: 'easy',
      );

      expect(score, greaterThan(0));
      expect(score, isA<int>());
    });

    test('should calculate stars correctly', () {
      // Perfect performance
      int stars = MathService.calculateStars(
        accuracy: 1.0,
        averageTime: const Duration(seconds: 5),
      );
      expect(stars, 5);

      // Good performance
      stars = MathService.calculateStars(
        accuracy: 0.8,
        averageTime: const Duration(seconds: 20),
      );
      expect(stars, greaterThanOrEqualTo(2));

      // Poor performance
      stars = MathService.calculateStars(
        accuracy: 0.5,
        averageTime: const Duration(seconds: 30),
      );
      expect(stars, lessThan(3));
    });

    test('should have correct default topics', () {
      final topics = MathService.getDefaultTopics();

      expect(topics.length, 4);
      expect(topics[0].name, 'Addition');
      expect(topics[0].isUnlocked, true); // First topic should be unlocked
      expect(topics[1].name, 'Subtraction');
      expect(topics[1].isUnlocked, false); // Others should be locked initially
      expect(topics[2].name, 'Multiplication');
      expect(topics[3].name, 'Division');
    });
  });
}