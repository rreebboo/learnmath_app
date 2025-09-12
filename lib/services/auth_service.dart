import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'user_statistics_service.dart';
import 'user_preferences_service.dart';

class AuthService {
  // Use lazy initialization to avoid accessing Firebase before it's initialized
  FirebaseAuth get _auth => FirebaseAuth.instance;
  FirebaseFirestore get _firestore => FirebaseFirestore.instance;

  // Get current user
  User? get currentUser => _auth.currentUser;

  // Auth state changes stream
  Stream<User?> get authStateChanges => _auth.authStateChanges();

  // Sign up with email and password
  Future<UserCredential?> signUpWithEmailAndPassword({
    required String email,
    required String password,
    required String name,
    required String avatar,
  }) async {
    try {
      // Create user with email and password
      UserCredential result = await _auth.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );

      // Update display name
      await result.user?.updateDisplayName(name);

      // Create user document in Firestore
      await _firestore.collection('users').doc(result.user?.uid).set({
        'uid': result.user?.uid,
        'name': name,
        'email': email,
        'avatar': avatar,
        'createdAt': FieldValue.serverTimestamp(),
        'totalScore': 0,
        'lessonsCompleted': 0,
        'currentStreak': 0,
        'lastLoginDate': FieldValue.serverTimestamp(),
        'achievements': [],
        'preferences': {
          'soundEnabled': true,
          'difficulty': 'beginner',
        },
      });

      // Load user-specific data after successful signup
      await _loadUserData();

      return result;
    } on FirebaseAuthException catch (e) {
      throw _handleAuthException(e);
    } catch (e) {
      throw 'An unexpected error occurred: $e';
    }
  }

  // Sign in with email and password
  Future<UserCredential?> signInWithEmailAndPassword({
    required String email,
    required String password,
  }) async {
    try {
      UserCredential result = await _auth.signInWithEmailAndPassword(
        email: email,
        password: password,
      );

      // Update last login date
      await _firestore.collection('users').doc(result.user?.uid).update({
        'lastLoginDate': FieldValue.serverTimestamp(),
      });

      // Load user-specific data after successful login
      await _loadUserData();

      return result;
    } on FirebaseAuthException catch (e) {
      throw _handleAuthException(e);
    } catch (e) {
      throw 'An unexpected error occurred: $e';
    }
  }

  // Sign in with username only (kid-friendly approach)
  Future<UserCredential?> signInWithUsername({
    required String username,
    required String avatar,
  }) async {
    try {
      // print('AuthService: Attempting username login for: $username');
      
      // Generate a consistent email and password for this username
      final email = '${username.toLowerCase().replaceAll(' ', '')}@learnmath.local';
      final password = 'LearnMath_${username}_2024'; // Consistent password for each username
      
      // print('AuthService: Generated email: $email');

      try {
        // First try to sign in with existing account
        // print('AuthService: Trying to sign in with existing account');
        UserCredential result = await _auth.signInWithEmailAndPassword(
          email: email,
          password: password,
        );
        // print('AuthService: Successfully signed in existing user');
        
        // Update avatar and last login
        await _firestore.collection('users').doc(result.user?.uid).update({
          'avatar': avatar,
          'lastLoginDate': FieldValue.serverTimestamp(),
        });

        await _loadUserData();
        return result;
        
      } on FirebaseAuthException catch (e) {
        if (e.code == 'user-not-found' || e.code == 'wrong-password') {
          // print('AuthService: User not found, creating new account');
          
          // Create new account
          UserCredential result = await _auth.createUserWithEmailAndPassword(
            email: email,
            password: password,
          );
          
          // Update display name
          await result.user?.updateDisplayName(username);
          
          // Create user document
          await _firestore.collection('users').doc(result.user?.uid).set({
            'uid': result.user?.uid,
            'name': username.trim(),
            'email': email,
            'avatar': avatar,
            'isQuickStart': true,
            'createdAt': FieldValue.serverTimestamp(),
            'totalScore': 0,
            'lessonsCompleted': 0,
            'currentStreak': 0,
            'lastLoginDate': FieldValue.serverTimestamp(),
            'achievements': [],
            'preferences': {
              'soundEnabled': true,
              'difficulty': 'beginner',
            },
          });
          
          // print('AuthService: New user created successfully');
          await _loadUserData();
          return result;
        } else {
          // print('AuthService: Authentication error: ${e.message}');
          throw _handleAuthException(e);
        }
      }
    } catch (e) {
      // print('AuthService: Error during username login: $e');
      throw 'Error signing in: $e';
    }
  }

  // Sign in anonymously (for guest users)
  Future<UserCredential?> signInAnonymously({
    required String name,
    required String avatar,
  }) async {
    try {
      UserCredential result = await _auth.signInAnonymously();

      // Create anonymous user document
      await _firestore.collection('users').doc(result.user?.uid).set({
        'uid': result.user?.uid,
        'name': name,
        'email': null,
        'avatar': avatar,
        'isAnonymous': true,
        'createdAt': FieldValue.serverTimestamp(),
        'totalScore': 0,
        'lessonsCompleted': 0,
        'currentStreak': 0,
        'lastLoginDate': FieldValue.serverTimestamp(),
        'achievements': [],
        'preferences': {
          'soundEnabled': true,
          'difficulty': 'beginner',
        },
      });

      // Load user-specific data after successful anonymous login
      await _loadUserData();

      return result;
    } on FirebaseAuthException catch (e) {
      throw _handleAuthException(e);
    } catch (e) {
      throw 'An unexpected error occurred: $e';
    }
  }

  // Sign out
  Future<void> signOut() async {
    try {
      // Clear user-specific data before signing out
      await _clearUserData();
      await _auth.signOut();
    } catch (e) {
      throw 'Error signing out: $e';
    }
  }

  // Delete account
  Future<void> deleteAccount() async {
    try {
      final user = currentUser;
      if (user != null) {
        // Delete user document from Firestore
        await _firestore.collection('users').doc(user.uid).delete();
        
        // Delete the user account
        await user.delete();
      }
    } catch (e) {
      throw 'Error deleting account: $e';
    }
  }

  // Handle Firebase Auth exceptions
  String _handleAuthException(FirebaseAuthException e) {
    switch (e.code) {
      case 'weak-password':
        return 'The password provided is too weak.';
      case 'email-already-in-use':
        return 'An account already exists for that email.';
      case 'user-not-found':
        return 'No user found for that email.';
      case 'wrong-password':
        return 'Wrong password provided.';
      case 'invalid-email':
        return 'The email address is not valid.';
      case 'user-disabled':
        return 'This user account has been disabled.';
      case 'too-many-requests':
        return 'Too many attempts. Please try again later.';
      case 'operation-not-allowed':
        return 'This sign-in method is not allowed.';
      default:
        return 'Authentication error: ${e.message}';
    }
  }

  // Reset password
  Future<void> resetPassword(String email) async {
    try {
      await _auth.sendPasswordResetEmail(email: email);
    } on FirebaseAuthException catch (e) {
      throw _handleAuthException(e);
    } catch (e) {
      throw 'Error sending password reset email: $e';
    }
  }

  // Check if user is signed in
  bool isSignedIn() {
    return currentUser != null;
  }

  // Get suggested usernames for kids (fun and kid-friendly)
  List<String> getSuggestedUsernames() {
    final List<String> adjectives = [
      'Happy', 'Smart', 'Brave', 'Kind', 'Funny', 'Cool', 'Super', 'Star', 
      'Bright', 'Swift', 'Magic', 'Lucky', 'Sunny', 'Joy', 'Wonder'
    ];
    
    final List<String> animals = [
      'Fox', 'Tiger', 'Bear', 'Lion', 'Eagle', 'Dolphin', 'Panda', 'Wolf',
      'Owl', 'Rabbit', 'Cat', 'Dog', 'Penguin', 'Unicorn', 'Dragon'
    ];
    
    final List<String> colors = [
      'Blue', 'Green', 'Red', 'Purple', 'Orange', 'Yellow', 'Pink', 'Gold',
      'Silver', 'Rainbow'
    ];
    
    List<String> suggestions = [];
    
    // Generate combinations
    for (int i = 0; i < 5; i++) {
      adjectives.shuffle();
      animals.shuffle();
      colors.shuffle();
      
      suggestions.add('${adjectives.first}${animals.first}');
      suggestions.add('${colors.first}${animals.first}');
    }
    
    return suggestions.take(6).toList();
  }

  // Get user ID
  String? getUserId() {
    return currentUser?.uid;
  }

  // Get user email
  String? getUserEmail() {
    return currentUser?.email;
  }

  // Get user display name
  String? getUserDisplayName() {
    return currentUser?.displayName;
  }

  // Load user-specific data when user logs in
  Future<void> _loadUserData() async {
    try {
      // print('AuthService: Loading user data for ${currentUser?.uid}');
      final userStatsService = UserStatisticsService();
      await userStatsService.loadStatistics();
      // print('AuthService: User data loaded successfully');
    } catch (e) {
      // print('AuthService: Error loading user data: $e');
    }
  }

  // Clear user-specific data when user logs out
  Future<void> _clearUserData() async {
    try {
      final userStatsService = UserStatisticsService();
      final userPrefsService = UserPreferencesService.instance;
      
      // Reset in-memory data
      await userStatsService.resetCurrentUserData();
      await userPrefsService.resetCurrentUserPreferences();
    } catch (e) {
      // Error clearing user data: $e
    }
  }
}