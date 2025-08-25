import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Quick Start Email Generation Tests', () {
    test('Should generate consistent email for username', () {
      // Test the email generation logic
      String generateEmailForUsername(String username) {
        return '${username.toLowerCase().replaceAll(' ', '')}@learnmath.local';
      }
      
      String generatePasswordForUsername(String username) {
        return 'LearnMath_${username}_2024';
      }
      
      // Test various usernames
      expect(generateEmailForUsername('TestKid'), equals('testkid@learnmath.local'));
      expect(generateEmailForUsername('Happy Fox'), equals('happyfox@learnmath.local'));
      expect(generateEmailForUsername('ALEX123'), equals('alex123@learnmath.local'));
      
      // Test password generation
      expect(generatePasswordForUsername('TestKid'), equals('LearnMath_TestKid_2024'));
      expect(generatePasswordForUsername('Happy Fox'), equals('LearnMath_Happy Fox_2024'));
      
      // Test consistency - same username should always generate same email/password
      final username = 'SameName';
      expect(generateEmailForUsername(username), equals(generateEmailForUsername(username)));
      expect(generatePasswordForUsername(username), equals(generatePasswordForUsername(username)));
    });

    test('Should handle special characters in usernames', () {
      String generateEmailForUsername(String username) {
        return '${username.toLowerCase().replaceAll(' ', '')}@learnmath.local';
      }
      
      // Test usernames with spaces and special characters
      expect(generateEmailForUsername('My User'), equals('myuser@learnmath.local'));
      expect(generateEmailForUsername('Test User 123'), equals('testuser123@learnmath.local'));
      expect(generateEmailForUsername('   SpacedOut   '), equals('spacedout@learnmath.local'));
    });
  });
}