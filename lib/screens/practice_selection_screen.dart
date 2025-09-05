import 'package:flutter/material.dart';
import 'practice_screen.dart';
import 'adaptive_quiz_screen.dart';

class PracticeSelectionScreen extends StatelessWidget {
  const PracticeSelectionScreen({super.key});

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
        title: const Text(
          'Practice Math',
          style: TextStyle(
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
                'Choose Your Practice Mode',
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF2C3E50),
                ),
              ),
              const SizedBox(height: 30),
              
              // Solo Practice Card
              _buildPracticeCard(
                context,
                'Solo Practice',
                'Practice at your own pace with personalized lessons',
                const Color(0xFF5B9EF3),
                Icons.person,
                () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => const SoloPracticeScreen(),
                    ),
                  );
                },
              ),
              
              const SizedBox(height: 20),
              
              // Adaptive Quiz Card
              _buildPracticeCard(
                context,
                'Adaptive Quiz',
                'AI-powered questions that adapt to your skill level',
                const Color(0xFF9C27B0),
                Icons.psychology,
                () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => const AdaptiveQuizScreen(),
                    ),
                  );
                },
              ),
              
              const SizedBox(height: 20),
              
              // Quick Math Card
              _buildPracticeCard(
                context,
                'Quick Math',
                'Fast-paced challenges to improve your speed',
                const Color(0xFF7ED321),
                Icons.flash_on,
                () {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Quick Math coming soon!'),
                      duration: Duration(seconds: 2),
                    ),
                  );
                },
              ),
              
              const SizedBox(height: 20),
              
              // Story Problems Card
              _buildPracticeCard(
                context,
                'Story Problems',
                'Real-world math problems with fun stories',
                const Color(0xFF9C27B0),
                Icons.book,
                () {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Story Problems coming soon!'),
                      duration: Duration(seconds: 2),
                    ),
                  );
                },
              ),
              
              const SizedBox(height: 20),
              
              // Challenge Mode Card
              _buildPracticeCard(
                context,
                'Challenge Mode',
                'Test your skills with advanced problems',
                const Color(0xFFFF6B6B),
                Icons.emoji_events,
                () {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Challenge Mode coming soon!'),
                      duration: Duration(seconds: 2),
                    ),
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
  
  Widget _buildPracticeCard(
    BuildContext context,
    String title,
    String description,
    Color color,
    IconData icon,
    VoidCallback onTap,
  ) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(20),
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
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF2C3E50),
                    ),
                  ),
                  const SizedBox(height: 5),
                  Text(
                    description,
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.grey[600],
                    ),
                  ),
                ],
              ),
            ),
            Icon(
              Icons.arrow_forward_ios,
              color: Colors.grey[400],
              size: 20,
            ),
          ],
        ),
      ),
    );
  }
}