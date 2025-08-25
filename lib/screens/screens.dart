// screens.dart - Central export file for all screen widgets
// This file makes it easier to import multiple screens and provides
// a single location to see all available screens in the app

// Auth Screens
export 'splash_screen.dart';
export 'login_screen.dart';
export 'signup_screen.dart';

// Main App Screens
export 'home_screen.dart';
export 'home_content_screen.dart';
export 'practice_screen.dart';
export 'practice_selection_screen.dart';
export 'math_practice_session_screen.dart';
export 'simple_math_practice_screen.dart';
export 'difficulty_selection_screen.dart';
export 'quiz_screen.dart';
export 'friends_screen.dart';
export 'progress_screen.dart';
export 'profile_screen.dart';

/* 
SCREEN ORGANIZATION:

📱 AUTH FLOW:
├── SplashScreen - App entry point with branding
├── LoginScreen - User authentication 
└── SignUpScreen - New user registration

🏠 MAIN APP (5-tab navigation):
├── HomeScreen - Main container with bottom navigation
├── HomeContent - Home tab content with dashboard
├── PracticeScreen (SoloPracticeScreen) - Lessons tab content
├── QuizScreen - Quiz tab content  
├── ProgressScreen - Progress tab content
└── ProfileScreen - Profile tab content

🎯 ADDITIONAL SCREENS:
└── PracticeSelectionScreen - Different practice modes

NAVIGATION FLOW:
SplashScreen → LoginScreen → HomeScreen → [5 tabs + additional screens]

IMPORTS USAGE:
Instead of:
  import 'splash_screen.dart';
  import 'login_screen.dart';
  import 'home_screen.dart';

Use:
  import 'screens/screens.dart';
*/