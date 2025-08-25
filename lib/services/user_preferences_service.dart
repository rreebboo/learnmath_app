import 'package:shared_preferences/shared_preferences.dart';
import 'auth_service.dart';

class UserPreferencesService {
  static const String _difficultyKeyPrefix = 'selected_difficulty_';
  
  static UserPreferencesService? _instance;
  static UserPreferencesService get instance {
    return _instance ??= UserPreferencesService._();
  }
  
  UserPreferencesService._();

  final AuthService _authService = AuthService();

  String get _currentUserDifficultyKey {
    final userId = _authService.getUserId();
    return userId != null ? '$_difficultyKeyPrefix$userId' : '${_difficultyKeyPrefix}anonymous';
  }
  
  // Store the selected difficulty (0: Easy, 1: Medium, 2: Advanced)
  Future<void> setSelectedDifficulty(int difficulty) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_currentUserDifficultyKey, difficulty);
  }
  
  // Get the selected difficulty, defaults to 0 (Easy)
  Future<int> getSelectedDifficulty() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getInt(_currentUserDifficultyKey) ?? 0;
  }
  
  // Convert difficulty index to string
  String getDifficultyString(int difficulty) {
    switch (difficulty) {
      case 0:
        return 'easy';
      case 1:
        return 'medium';
      case 2:
        return 'hard';
      default:
        return 'easy';
    }
  }
  
  // Convert difficulty string to index
  int getDifficultyIndex(String difficulty) {
    switch (difficulty.toLowerCase()) {
      case 'easy':
        return 0;
      case 'medium':
        return 1;
      case 'hard':
        return 2;
      default:
        return 0;
    }
  }

  // Reset user preferences to defaults
  Future<void> resetCurrentUserPreferences() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_currentUserDifficultyKey);
    } catch (e) {
      // Error clearing preferences
    }
  }

  // Clear all user preferences from device
  Future<void> clearAllUserPreferences() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final keys = prefs.getKeys().where((key) => key.startsWith(_difficultyKeyPrefix));
      for (final key in keys) {
        await prefs.remove(key);
      }
    } catch (e) {
      // Error clearing all preferences
    }
  }
}