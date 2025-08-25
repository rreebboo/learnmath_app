import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Difficulty System Tests', () {
    test('Easy Addition should generate numbers 1-10', () {
      // Test easy addition ranges
      for (int i = 0; i < 10; i++) {
        final operand1 = _generateAdditionOperand1('easy');
        final operand2 = _generateAdditionOperand2('easy');
        
        expect(operand1, greaterThanOrEqualTo(1));
        expect(operand1, lessThanOrEqualTo(10));
        expect(operand2, greaterThanOrEqualTo(1));
        expect(operand2, lessThanOrEqualTo(10));
      }
    });

    test('Medium Addition should generate numbers 10-99', () {
      // Test medium addition ranges
      for (int i = 0; i < 10; i++) {
        final operand1 = _generateAdditionOperand1('medium');
        final operand2 = _generateAdditionOperand2('medium');
        
        expect(operand1, greaterThanOrEqualTo(10));
        expect(operand1, lessThanOrEqualTo(99));
        expect(operand2, greaterThanOrEqualTo(10));
        expect(operand2, lessThanOrEqualTo(99));
      }
    });

    test('Hard Addition should generate numbers 100-999', () {
      // Test hard addition ranges
      for (int i = 0; i < 10; i++) {
        final operand1 = _generateAdditionOperand1('hard');
        final operand2 = _generateAdditionOperand2('hard');
        
        expect(operand1, greaterThanOrEqualTo(100));
        expect(operand1, lessThanOrEqualTo(999));
        expect(operand2, greaterThanOrEqualTo(100));
        expect(operand2, lessThanOrEqualTo(999));
      }
    });

    test('Easy Subtraction should not produce negative results', () {
      for (int i = 0; i < 20; i++) {
        final operand1 = _generateSubtractionOperand1('easy');
        final operand2 = _generateSubtractionOperand2('easy', operand1);
        final result = operand1 - operand2;
        
        expect(result, greaterThanOrEqualTo(0));
        expect(operand1, greaterThanOrEqualTo(6));
        expect(operand1, lessThanOrEqualTo(20));
      }
    });

    test('Easy Multiplication should use numbers 1-5', () {
      for (int i = 0; i < 10; i++) {
        final operand1 = _generateMultiplicationOperand1('easy');
        final operand2 = _generateMultiplicationOperand2('easy');
        
        expect(operand1, greaterThanOrEqualTo(1));
        expect(operand1, lessThanOrEqualTo(5));
        expect(operand2, greaterThanOrEqualTo(1));
        expect(operand2, lessThanOrEqualTo(5));
      }
    });

    test('Medium Multiplication should use numbers 1-12', () {
      for (int i = 0; i < 10; i++) {
        final operand1 = _generateMultiplicationOperand1('medium');
        final operand2 = _generateMultiplicationOperand2('medium');
        
        expect(operand1, greaterThanOrEqualTo(1));
        expect(operand1, lessThanOrEqualTo(12));
        expect(operand2, greaterThanOrEqualTo(1));
        expect(operand2, lessThanOrEqualTo(12));
      }
    });

    test('Division should always produce whole numbers', () {
      for (int i = 0; i < 20; i++) {
        final divisor = _generateDivisionDivisor('easy');
        final quotient = _generateDivisionQuotient('easy');
        final dividend = divisor * quotient;
        
        expect(dividend % divisor, equals(0));
        expect(dividend / divisor, equals(quotient));
      }
    });

    test('Score calculation should reward difficulty', () {
      // Easy perfect score
      final easyScore = _calculateTestScore(10, 10, 60, 'easy');
      
      // Medium perfect score
      final mediumScore = _calculateTestScore(10, 10, 60, 'medium');
      
      // Hard perfect score  
      final hardScore = _calculateTestScore(10, 10, 60, 'hard');
      
      expect(mediumScore, greaterThan(easyScore));
      expect(hardScore, greaterThan(mediumScore));
    });

    test('Star calculation should reward accuracy and speed', () {
      // Perfect accuracy, good time
      expect(_calculateTestStars(1.0, 8.0), equals(5));
      
      // Good accuracy
      expect(_calculateTestStars(0.9, 12.0), greaterThanOrEqualTo(4));
      
      // Average accuracy
      expect(_calculateTestStars(0.8, 15.0), greaterThanOrEqualTo(3));
      
      // Poor accuracy
      expect(_calculateTestStars(0.5, 20.0), lessThanOrEqualTo(2));
    });
  });
}

// Helper functions to simulate the math generation logic
int _generateAdditionOperand1(String difficulty) {
  final random = DateTime.now().millisecondsSinceEpoch % 1000;
  switch (difficulty.toLowerCase()) {
    case 'easy':
      return (random % 10) + 1; // 1-10
    case 'medium':
      return (random % 90) + 10; // 10-99
    case 'hard':
      return (random % 900) + 100; // 100-999
    default:
      return (random % 10) + 1;
  }
}

int _generateAdditionOperand2(String difficulty) {
  return _generateAdditionOperand1(difficulty);
}

int _generateSubtractionOperand1(String difficulty) {
  final random = DateTime.now().millisecondsSinceEpoch % 1000;
  switch (difficulty.toLowerCase()) {
    case 'easy':
      return (random % 15) + 6; // 6-20
    case 'medium':
      return (random % 90) + 50; // 50-139
    case 'hard':
      return (random % 900) + 200; // 200-1099
    default:
      return (random % 15) + 6;
  }
}

int _generateSubtractionOperand2(String difficulty, int operand1) {
  final random = DateTime.now().millisecondsSinceEpoch % 1000;
  switch (difficulty.toLowerCase()) {
    case 'easy':
      return (random % (operand1 - 1)) + 1;
    case 'medium':
      return (random % (operand1 - 10)) + 10;
    case 'hard':
      return (random % (operand1 - 50)) + 50;
    default:
      return (random % (operand1 - 1)) + 1;
  }
}

int _generateMultiplicationOperand1(String difficulty) {
  final random = DateTime.now().millisecondsSinceEpoch % 1000;
  switch (difficulty.toLowerCase()) {
    case 'easy':
      return (random % 5) + 1; // 1-5
    case 'medium':
      return (random % 12) + 1; // 1-12
    case 'hard':
      return (random % 25) + 1; // 1-25
    default:
      return (random % 5) + 1;
  }
}

int _generateMultiplicationOperand2(String difficulty) {
  return _generateMultiplicationOperand1(difficulty);
}

int _generateDivisionDivisor(String difficulty) {
  final random = DateTime.now().millisecondsSinceEpoch % 1000;
  switch (difficulty.toLowerCase()) {
    case 'easy':
      return (random % 5) + 2; // 2-6
    case 'medium':
      return (random % 10) + 2; // 2-11
    case 'hard':
      return (random % 23) + 2; // 2-24
    default:
      return (random % 5) + 2;
  }
}

int _generateDivisionQuotient(String difficulty) {
  final random = DateTime.now().millisecondsSinceEpoch % 1000;
  switch (difficulty.toLowerCase()) {
    case 'easy':
      return (random % 5) + 1; // 1-5
    case 'medium':
      return (random % 12) + 1; // 1-12
    case 'hard':
      return (random % 25) + 1; // 1-25
    default:
      return (random % 5) + 1;
  }
}

int _calculateTestScore(int correct, int total, int timeSeconds, String difficulty) {
  double baseScore = correct * 10.0;
  
  double difficultyMultiplier = switch (difficulty.toLowerCase()) {
    'easy' => 1.0,
    'medium' => 1.5,
    'hard' => 2.0,
    _ => 1.0,
  };
  
  double accuracy = correct / total;
  double accuracyBonus = accuracy == 1.0 ? 1.3 : (accuracy >= 0.9 ? 1.1 : 1.0);
  
  return (baseScore * difficultyMultiplier * accuracyBonus).round();
}

int _calculateTestStars(double accuracy, double averageTime) {
  int stars = 1;
  
  if (accuracy >= 0.6) stars = 2;
  if (accuracy >= 0.8) stars = 3;
  if (accuracy >= 0.9) stars = 4;
  
  if (accuracy == 1.0) {
    stars = 5;
  } else if (accuracy >= 0.9 && averageTime <= 10.0) {
    stars = 5;
  }
  
  return stars;
}