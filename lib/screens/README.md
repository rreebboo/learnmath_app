# Screens Directory

This directory contains all the screen widgets for the LearnMath app, organized for easy navigation and maintenance.

## 📁 File Organization

### 🔐 Authentication Screens
- `splash_screen.dart` - App entry point with branding and loading
- `login_screen.dart` - User authentication form
- `signup_screen.dart` - New user registration form

### 🏠 Main Application Screens
- `home_screen.dart` - Main container with 5-tab bottom navigation
- `home_content_screen.dart` - Home tab dashboard with user info and quick actions
- `practice_screen.dart` - Solo practice lessons (renamed from PracticeScreen to SoloPracticeScreen)
- `quiz_screen.dart` - Quiz challenges and competitions
- `progress_screen.dart` - User progress tracking and statistics
- `profile_screen.dart` - User profile management and settings

### 🎯 Additional Screens
- `practice_selection_screen.dart` - Different practice mode options
- `screens.dart` - Central export file for easy imports

## 🚀 Navigation Flow

```
SplashScreen 
    ↓
LoginScreen/SignUpScreen
    ↓
HomeScreen (5-tab navigation)
    ├── Tab 0: HomeContent
    ├── Tab 1: SoloPracticeScreen
    ├── Tab 2: QuizScreen
    ├── Tab 3: ProgressScreen
    └── Tab 4: ProfileScreen
```

## 📦 Import Usage

### Before (multiple imports):
```dart
import 'screens/splash_screen.dart';
import 'screens/login_screen.dart';
import 'screens/home_screen.dart';
import 'screens/practice_screen.dart';
```

### After (single import):
```dart
import 'screens/screens.dart';
```

## 🎨 Screen Features

### HomeContent
- User dashboard with greeting
- XP and streak tracking
- Difficulty level selection
- Quick action cards
- Recent badges display

### SoloPracticeScreen
- Math topic cards (Addition, Subtraction, Multiplication, Division)
- Progress tracking
- Locked/unlocked lessons
- Continue learning feature

### QuizScreen
- Quiz challenges placeholder
- Coming soon functionality

### ProgressScreen
- Statistics cards (Lessons, Quiz Score, Streak, XP)
- Progress chart placeholder

### ProfileScreen
- User profile management
- Settings (Sound, Difficulty, Notifications)
- About and support options
- Logout functionality

## 🔧 Technical Notes

- All screens follow Flutter best practices
- Proper state management with StatefulWidget/StatelessWidget
- Consistent styling with app theme colors
- Responsive design for different screen sizes
- Error handling and loading states