import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:learnmath_app/main.dart' as app;

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  group('Username Login Integration Tests', () {
    testWidgets('Should be able to login with username and navigate to home', (WidgetTester tester) async {
      // Start the app
      app.main();
      await tester.pumpAndSettle();

      // Wait for splash screen to load
      await tester.pumpAndSettle(Duration(seconds: 2));

      // Look for "Let's Start Learning!" button on splash screen
      final startButton = find.text("Let's Start\nLearning!");
      expect(startButton, findsOneWidget);
      
      // Tap the start button
      await tester.tap(startButton);
      await tester.pumpAndSettle();

      // Should now be on login screen
      expect(find.text('Welcome Back!'), findsOneWidget);

      // Look for username field
      final usernameField = find.byType(TextFormField);
      expect(usernameField, findsOneWidget);

      // Enter a test username
      await tester.enterText(usernameField, 'TestKid123');
      await tester.pumpAndSettle();

      // Look for avatar selection (should have fox selected by default)
      expect(find.text('🦊'), findsWidgets);

      // Look for the "Let's Start Learning!" button
      final loginButton = find.text("Let's Start Learning!");
      expect(loginButton, findsOneWidget);

      // Tap login button
      await tester.tap(loginButton);
      await tester.pumpAndSettle(Duration(seconds: 3));

      // Should navigate to home screen
      // Look for elements that indicate we're on the home screen
      expect(find.text('TestKid123'), findsAny); // Username should appear somewhere
    });

    testWidgets('Should show username suggestions when tapped', (WidgetTester tester) async {
      // Start the app
      app.main();
      await tester.pumpAndSettle();

      // Navigate to login screen
      await tester.pumpAndSettle(Duration(seconds: 2));
      final startButton = find.text("Let's Start\nLearning!");
      await tester.tap(startButton);
      await tester.pumpAndSettle();

      // Should see username suggestions
      expect(find.text('Need ideas? Try these:'), findsOneWidget);
      
      // Should see suggested username buttons
      final suggestionButtons = find.byType(GestureDetector);
      expect(suggestionButtons, findsWidgets);

      // Tap on a suggestion to test if it fills the username field
      final firstSuggestion = suggestionButtons.first;
      await tester.tap(firstSuggestion);
      await tester.pumpAndSettle();

      // Username field should now have text
      final usernameField = find.byType(TextFormField);
      final textField = tester.widget<TextFormField>(usernameField);
      expect(textField.controller?.text.isNotEmpty, true);
    });
  });
}