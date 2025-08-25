import 'package:flutter_test/flutter_test.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:learnmath_app/services/auth_service.dart';
import 'package:learnmath_app/firebase_options.dart';

void main() {
  group('Username Login Tests', () {
    late AuthService authService;

    setUpAll(() async {
      TestWidgetsFlutterBinding.ensureInitialized();
      await Firebase.initializeApp(
        options: DefaultFirebaseOptions.currentPlatform,
      );
    });

    setUp(() {
      authService = AuthService();
    });

    test('AuthService should provide username suggestions', () {
      final suggestions = authService.getSuggestedUsernames();
      
      expect(suggestions, isNotEmpty);
      expect(suggestions.length, equals(6));
      
      // Check that suggestions are strings and not empty
      for (String suggestion in suggestions) {
        expect(suggestion, isA<String>());
        expect(suggestion.isNotEmpty, isTrue);
        expect(suggestion.length, greaterThan(3)); // Should be meaningful names
      }
    });

    test('Username suggestions should be unique', () {
      final suggestions = authService.getSuggestedUsernames();
      final uniqueSuggestions = suggestions.toSet();
      
      // All suggestions should be unique
      expect(uniqueSuggestions.length, equals(suggestions.length));
    });

    test('Username suggestions should be kid-friendly', () {
      final suggestions = authService.getSuggestedUsernames();
      
      for (String suggestion in suggestions) {
        // Should not contain inappropriate words or numbers
        expect(suggestion.contains(RegExp(r'[0-9]')), isFalse);
        expect(suggestion.contains(' '), isFalse);
        expect(suggestion.length, lessThan(20)); // Reasonable length
      }
    });
  });
}