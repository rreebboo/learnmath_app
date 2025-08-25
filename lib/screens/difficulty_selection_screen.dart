import 'package:flutter/material.dart';
import 'simple_math_practice_screen.dart';

class DifficultySelectionScreen extends StatelessWidget {
  final String topicName;
  final String operator;
  final Function(double accuracy)? onSessionComplete;

  const DifficultySelectionScreen({
    super.key,
    required this.topicName,
    required this.operator,
    this.onSessionComplete,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FA),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios, color: Color(0xFF2C3E50)),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          'Choose Difficulty - $topicName',
          style: const TextStyle(
            color: Color(0xFF2C3E50),
            fontSize: 18,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Select Your Challenge Level',
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF2C3E50),
                ),
              ),
              const SizedBox(height: 30),
              
              // Easy Level
              _buildDifficultyCard(
                context,
                'Easy',
                _getEasyDescription(operator),
                const Color(0xFF7ED321),
                Icons.sentiment_satisfied,
                'easy',
              ),
              
              const SizedBox(height: 20),
              
              // Medium Level
              _buildDifficultyCard(
                context,
                'Medium',
                _getMediumDescription(operator),
                const Color(0xFFFFA500),
                Icons.sentiment_neutral,
                'medium',
              ),
              
              const SizedBox(height: 20),
              
              // Hard Level
              _buildDifficultyCard(
                context,
                'Hard',
                _getHardDescription(operator),
                const Color(0xFFFF6B6B),
                Icons.sentiment_very_dissatisfied,
                'hard',
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDifficultyCard(
    BuildContext context,
    String title,
    String description,
    Color color,
    IconData icon,
    String difficulty,
  ) {
    return GestureDetector(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => SimpleMathPracticeScreen(
              topicName: topicName,
              operator: operator,
              difficulty: difficulty,
              onSessionComplete: onSessionComplete,
            ),
          ),
        );
      },
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: color.withValues(alpha: 0.3),
            width: 2,
          ),
          boxShadow: [
            BoxShadow(
              color: color.withValues(alpha: 0.1),
              blurRadius: 15,
              offset: const Offset(0, 5),
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              width: 60,
              height: 60,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    color,
                    color.withValues(alpha: 0.8),
                  ],
                ),
                borderRadius: BorderRadius.circular(15),
              ),
              child: Icon(
                icon,
                color: Colors.white,
                size: 30,
              ),
            ),
            const SizedBox(width: 20),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: color,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    description,
                    style: const TextStyle(
                      fontSize: 14,
                      color: Color(0xFF6B7280),
                      height: 1.4,
                    ),
                  ),
                ],
              ),
            ),
            Icon(
              Icons.arrow_forward_ios,
              color: color,
              size: 20,
            ),
          ],
        ),
      ),
    );
  }

  String _getEasyDescription(String operator) {
    switch (operator) {
      case '+':
        return 'Numbers 1-20\nSingle digit additions\nPerfect for beginners';
      case '-':
        return 'Numbers 1-20\nSimple subtractions\nNo negative results';
      case '×':
        return 'Numbers 1-5\nBasic multiplication tables\nEasy to memorize';
      case '÷':
        return 'Numbers 1-25\nSimple divisions\nWhole number results';
      default:
        return 'Basic level problems';
    }
  }

  String _getMediumDescription(String operator) {
    switch (operator) {
      case '+':
        return 'Numbers 1-100\nTwo digit additions\nSome carrying required';
      case '-':
        return 'Numbers 1-100\nTwo digit subtractions\nSome borrowing needed';
      case '×':
        return 'Numbers 1-12\nFull multiplication tables\nMore challenging';
      case '÷':
        return 'Numbers 1-144\nMedium divisions\nStill whole numbers';
      default:
        return 'Intermediate level problems';
    }
  }

  String _getHardDescription(String operator) {
    switch (operator) {
      case '+':
        return 'Numbers 1-999\nThree digit additions\nMultiple carrying steps';
      case '-':
        return 'Numbers 1-999\nThree digit subtractions\nComplex borrowing';
      case '×':
        return 'Numbers 1-25\nLarge multiplications\nChallenge your skills';
      case '÷':
        return 'Numbers 1-625\nComplex divisions\nTest your limits';
      default:
        return 'Advanced level problems';
    }
  }
}