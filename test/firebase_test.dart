import 'package:flutter_test/flutter_test.dart';
import 'package:learnmath_app/services/auth_service.dart';
import 'package:learnmath_app/services/firestore_service.dart';

void main() {
  group('Firebase Integration Tests', () {
    setUpAll(() async {
      // Mock Firebase for testing
      TestWidgetsFlutterBinding.ensureInitialized();
    });

    test('AuthService should initialize without errors', () {
      final authService = AuthService();
      expect(authService, isNotNull);
    });

    test('FirestoreService should initialize without errors', () {
      final firestoreService = FirestoreService();
      expect(firestoreService, isNotNull);
    });

    test('Current user ID should be accessible', () {
      final firestoreService = FirestoreService();
      // Should not throw an error even if null
      expect(() => firestoreService.currentUserId, returnsNormally);
    });
  });
}