class MathTopic {
  final String id;
  final String name;
  final String operator;
  final int totalLessons;
  final int completedLessons;
  final int stars;
  final bool isUnlocked;
  final String description;

  MathTopic({
    required this.id,
    required this.name,
    required this.operator,
    required this.totalLessons,
    required this.completedLessons,
    required this.stars,
    required this.isUnlocked,
    required this.description,
  });

  double get progress => completedLessons / totalLessons;
  bool get isCompleted => completedLessons >= totalLessons;
  String get progressText => '$completedLessons/$totalLessons';

  MathTopic copyWith({
    String? id,
    String? name,
    String? operator,
    int? totalLessons,
    int? completedLessons,
    int? stars,
    bool? isUnlocked,
    String? description,
  }) {
    return MathTopic(
      id: id ?? this.id,
      name: name ?? this.name,
      operator: operator ?? this.operator,
      totalLessons: totalLessons ?? this.totalLessons,
      completedLessons: completedLessons ?? this.completedLessons,
      stars: stars ?? this.stars,
      isUnlocked: isUnlocked ?? this.isUnlocked,
      description: description ?? this.description,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'operator': operator,
      'totalLessons': totalLessons,
      'completedLessons': completedLessons,
      'stars': stars,
      'isUnlocked': isUnlocked,
      'description': description,
    };
  }

  factory MathTopic.fromMap(Map<String, dynamic> map) {
    return MathTopic(
      id: map['id'] ?? '',
      name: map['name'] ?? '',
      operator: map['operator'] ?? '+',
      totalLessons: map['totalLessons'] ?? 10,
      completedLessons: map['completedLessons'] ?? 0,
      stars: map['stars'] ?? 0,
      isUnlocked: map['isUnlocked'] ?? false,
      description: map['description'] ?? '',
    );
  }
}