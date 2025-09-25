import 'dart:io';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path/path.dart' as path;

class ImageService {
  FirebaseStorage get _storage => FirebaseStorage.instance;
  FirebaseAuth get _auth => FirebaseAuth.instance;
  final ImagePicker _picker = ImagePicker();

  // Check if Firebase is initialized
  bool get _isFirebaseInitialized => Firebase.apps.isNotEmpty;

  // Pick image from gallery
  Future<XFile?> pickImageFromGallery() async {
    try {
      final XFile? image = await _picker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 512,
        maxHeight: 512,
        imageQuality: 80,
      );
      return image;
    } catch (e) {
      throw 'Error picking image: $e';
    }
  }

  // Pick image from camera
  Future<XFile?> pickImageFromCamera() async {
    try {
      final XFile? image = await _picker.pickImage(
        source: ImageSource.camera,
        maxWidth: 512,
        maxHeight: 512,
        imageQuality: 80,
      );
      return image;
    } catch (e) {
      throw 'Error taking photo: $e';
    }
  }

  // Upload image to Firebase Storage
  Future<String> uploadProfileImage(XFile imageFile) async {
    try {
      if (!_isFirebaseInitialized) {
        throw 'Firebase is not initialized';
      }

      // Wait for authentication state to be ready
      final user = _auth.currentUser;
      if (user == null) {
        throw 'No user logged in';
      }

      // Force refresh the authentication token to ensure it's valid
      await user.reload();
      final refreshedUser = _auth.currentUser;
      if (refreshedUser == null) {
        throw 'User authentication expired, please log in again';
      }

      // Get fresh ID token to ensure authentication is valid
      final idToken = await refreshedUser.getIdToken(true);
      if (idToken == null || idToken.isEmpty) {
        throw 'Unable to get authentication token, please log in again';
      }

      // Create a unique file name
      final String fileName = 'profile_${DateTime.now().millisecondsSinceEpoch}${path.extension(imageFile.path)}';

      // Create reference to Firebase Storage with user-specific directory structure
      final Reference ref = _storage
          .ref()
          .child('users')
          .child(refreshedUser.uid)
          .child('profile_images')
          .child(fileName);

      // Set metadata to include content type
      final SettableMetadata metadata = SettableMetadata(
        contentType: 'image/${path.extension(imageFile.path).substring(1)}',
        customMetadata: {
          'uploadedBy': refreshedUser.uid,
          'uploadedAt': DateTime.now().toIso8601String(),
        },
      );

      // Upload file with metadata
      final UploadTask uploadTask = ref.putFile(File(imageFile.path), metadata);

      // Wait for upload to complete
      final TaskSnapshot snapshot = await uploadTask;

      // Get download URL
      final String downloadUrl = await snapshot.ref.getDownloadURL();

      return downloadUrl;
    } on FirebaseException catch (e) {
      if (e.code == 'unauthorized') {
        throw 'Permission denied. Please log out and log back in, then try again.';
      } else if (e.code == 'unauthenticated') {
        throw 'Authentication required. Please log in again.';
      } else {
        throw 'Firebase error: ${e.message}';
      }
    } catch (e) {
      throw 'Error uploading image: $e';
    }
  }

  // Delete old profile image from Firebase Storage
  Future<void> deleteProfileImage(String imageUrl) async {
    try {
      if (!_isFirebaseInitialized) {
        print('Warning: Firebase not initialized, skipping image deletion');
        return;
      }

      if (imageUrl.isEmpty || !imageUrl.contains('firebase')) {
        return; // Not a Firebase Storage URL
      }

      final Reference ref = _storage.refFromURL(imageUrl);
      await ref.delete();
    } catch (e) {
      // Silently fail - image might already be deleted or not exist
      print('Warning: Could not delete old profile image: $e');
    }
  }

  // Check if string is an image URL (vs emoji)
  bool isImageUrl(String avatar) {
    return avatar.startsWith('http://') || avatar.startsWith('https://');
  }

  // Get user's storage directory reference
  Reference? getUserStorageRef() {
    final user = _auth.currentUser;
    if (user == null) return null;

    return _storage
        .ref()
        .child('users')
        .child(user.uid);
  }

  // Upload lesson-related files (if needed in the future)
  Future<String> uploadLessonFile(XFile file, String lessonId) async {
    try {
      if (!_isFirebaseInitialized) {
        throw 'Firebase is not initialized';
      }

      final user = _auth.currentUser;
      if (user == null) {
        throw 'No user logged in';
      }

      // Create a unique file name
      final String fileName = 'lesson_${lessonId}_${DateTime.now().millisecondsSinceEpoch}${path.extension(file.path)}';

      // Create reference to Firebase Storage with user-specific directory structure
      final Reference ref = _storage
          .ref()
          .child('users')
          .child(user.uid)
          .child('lesson_files')
          .child(fileName);

      // Set metadata
      final SettableMetadata metadata = SettableMetadata(
        customMetadata: {
          'uploadedBy': user.uid,
          'uploadedAt': DateTime.now().toIso8601String(),
          'lessonId': lessonId,
        },
      );

      // Upload file
      final UploadTask uploadTask = ref.putFile(File(file.path), metadata);
      final TaskSnapshot snapshot = await uploadTask;
      final String downloadUrl = await snapshot.ref.getDownloadURL();

      return downloadUrl;
    } catch (e) {
      throw 'Error uploading lesson file: $e';
    }
  }

  // Clean up all user files (for account deletion)
  Future<void> deleteAllUserFiles() async {
    try {
      if (!_isFirebaseInitialized) {
        print('Warning: Firebase not initialized, skipping file cleanup');
        return;
      }

      final user = _auth.currentUser;
      if (user == null) {
        print('Warning: No user logged in, skipping file cleanup');
        return;
      }

      final Reference userRef = _storage
          .ref()
          .child('users')
          .child(user.uid);

      // List all files in user's directory
      final ListResult result = await userRef.listAll();

      // Delete all files
      for (Reference fileRef in result.items) {
        try {
          await fileRef.delete();
        } catch (e) {
          print('Warning: Could not delete file ${fileRef.name}: $e');
        }
      }

      // Delete subdirectories recursively
      for (Reference prefixRef in result.prefixes) {
        await _deleteDirectoryRecursively(prefixRef);
      }

    } catch (e) {
      print('Warning: Could not clean up user files: $e');
    }
  }

  // Helper method to delete directory recursively
  Future<void> _deleteDirectoryRecursively(Reference dirRef) async {
    try {
      final ListResult result = await dirRef.listAll();

      // Delete all files in this directory
      for (Reference fileRef in result.items) {
        try {
          await fileRef.delete();
        } catch (e) {
          print('Warning: Could not delete file ${fileRef.name}: $e');
        }
      }

      // Delete subdirectories recursively
      for (Reference prefixRef in result.prefixes) {
        await _deleteDirectoryRecursively(prefixRef);
      }
    } catch (e) {
      print('Warning: Could not delete directory ${dirRef.name}: $e');
    }
  }
}