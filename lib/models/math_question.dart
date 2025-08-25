class MathQuestion {
  final int operand1;
  final int operand2;
  final String operator;
  final int correctAnswer;
  final List<int> options;
  final String difficulty;

  MathQuestion({
    required this.operand1,
    required this.operand2,
    required this.operator,
    required this.correctAnswer,
    required this.options,
    required this.difficulty,
  });

  String get questionText => '$operand1 $operator $operand2 = ?';

  Map<String, dynamic> toMap() {
    return {
      'operand1': operand1,
      'operand2': operand2,
      'operator': operator,
      'correctAnswer': correctAnswer,
      'options': options,
      'difficulty': difficulty,
    };
  }

  factory MathQuestion.fromMap(Map<String, dynamic> map) {
    return MathQuestion(
      operand1: map['operand1'] ?? 0,
      operand2: map['operand2'] ?? 0,
      operator: map['operator'] ?? '+',
      correctAnswer: map['correctAnswer'] ?? 0,
      options: List<int>.from(map['options'] ?? []),
      difficulty: map['difficulty'] ?? 'easy',
    );
  }
}