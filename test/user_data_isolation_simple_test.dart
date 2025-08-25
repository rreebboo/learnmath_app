import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  group('User Data Storage Key Tests', () {
    setUp(() async {
      SharedPreferences.setMockInitialValues({});
    });

    test('User-specific keys should be unique for different users', () async {
      final prefs = await SharedPreferences.getInstance();
      
      // Simulate different users with different data
      const user1StatsKey = 'user_statistics_user123';
      const user2StatsKey = 'user_statistics_user456';
      const user1DiffKey = 'selected_difficulty_user123';
      const user2DiffKey = 'selected_difficulty_user456';
      
      // Set data for user 1
      await prefs.setString(user1StatsKey, '{"totalSessions": 5, "totalScore": 500}');
      await prefs.setInt(user1DiffKey, 2);
      
      // Set data for user 2
      await prefs.setString(user2StatsKey, '{"totalSessions": 3, "totalScore": 300}');
      await prefs.setInt(user2DiffKey, 1);
      
      // Verify isolation
      final user1Stats = prefs.getString(user1StatsKey);
      final user2Stats = prefs.getString(user2StatsKey);
      final user1Diff = prefs.getInt(user1DiffKey);
      final user2Diff = prefs.getInt(user2DiffKey);
      
      expect(user1Stats, contains('"totalSessions": 5'));
      expect(user2Stats, contains('"totalSessions": 3'));
      expect(user1Diff, 2);
      expect(user2Diff, 1);
      
      // Verify they are different
      expect(user1Stats, isNot(equals(user2Stats)));
      expect(user1Diff, isNot(equals(user2Diff)));
    });

    test('Clearing specific user data should not affect other users', () async {
      final prefs = await SharedPreferences.getInstance();
      
      const user1StatsKey = 'user_statistics_user123';
      const user2StatsKey = 'user_statistics_user456';
      
      // Set data for both users
      await prefs.setString(user1StatsKey, '{"totalSessions": 5}');
      await prefs.setString(user2StatsKey, '{"totalSessions": 3}');
      
      // Clear user 1 data only
      await prefs.remove(user1StatsKey);
      
      // Verify user 1 data is gone but user 2 data remains
      expect(prefs.getString(user1StatsKey), isNull);
      expect(prefs.getString(user2StatsKey), isNotNull);
      expect(prefs.getString(user2StatsKey), contains('"totalSessions": 3'));
    });

    test('Finding and clearing all user data should work correctly', () async {
      final prefs = await SharedPreferences.getInstance();
      
      // Set up multiple users and some other data
      await prefs.setString('user_statistics_user1', '{"data": "user1"}');
      await prefs.setString('user_statistics_user2', '{"data": "user2"}');
      await prefs.setString('selected_difficulty_user1', '1');
      await prefs.setString('selected_difficulty_user2', '2');
      await prefs.setString('other_setting', 'should_remain');
      
      // Find all user-specific keys
      final allKeys = prefs.getKeys();
      final userStatsKeys = allKeys.where((key) => key.startsWith('user_statistics_'));
      final userDiffKeys = allKeys.where((key) => key.startsWith('selected_difficulty_'));
      
      // Clear all user-specific data
      for (final key in [...userStatsKeys, ...userDiffKeys]) {
        await prefs.remove(key);
      }
      
      // Verify user data is cleared but other settings remain
      expect(prefs.getString('user_statistics_user1'), isNull);
      expect(prefs.getString('user_statistics_user2'), isNull);
      expect(prefs.getString('selected_difficulty_user1'), isNull);
      expect(prefs.getString('selected_difficulty_user2'), isNull);
      expect(prefs.getString('other_setting'), 'should_remain');
    });
  });
}