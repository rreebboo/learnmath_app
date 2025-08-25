import 'package:flutter/material.dart';
import 'home_content_screen.dart';
import 'practice_screen.dart';
import 'quiz_screen.dart';
import 'progress_screen.dart';
import 'profile_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _selectedIndex = 0;

  late List<Widget> _screens;

  @override
  void initState() {
    super.initState();
    _screens = [
      HomeContent(onTabChange: (index) {
        setState(() {
          _selectedIndex = index;
        });
      }),
      const SoloPracticeScreen(), // Changed to SoloPracticeScreen
      const QuizScreen(),
      const ProgressScreen(),
      ProfileScreen(onBackPressed: () {
        setState(() {
          _selectedIndex = 0; // Navigate to home tab
        });
      }),
    ];
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Color(0xFFF5F7FA),
      body: _screens[_selectedIndex],
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.05),
              blurRadius: 10,
              offset: Offset(0, -5),
            ),
          ],
        ),
        child: BottomNavigationBar(
          currentIndex: _selectedIndex,
          onTap: (index) {
            setState(() {
              _selectedIndex = index;
            });
          },
          type: BottomNavigationBarType.fixed,
          backgroundColor: Colors.white,
          elevation: 0,
          selectedItemColor: Color(0xFF5B9EF3),
          unselectedItemColor: Colors.grey[400],
          selectedFontSize: 12,
          unselectedFontSize: 12,
          items: [
            BottomNavigationBarItem(
              icon: Icon(Icons.home_rounded, size: 24),
              label: 'Home',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.book_rounded, size: 24),
              label: 'Lessons',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.sports_martial_arts, size: 24),
              label: 'Duel',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.trending_up_rounded, size: 24),
              label: 'Progress',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.person_rounded, size: 24),
              label: 'Profile',
            ),
          ],
        ),
      ),
    );
  }
}

