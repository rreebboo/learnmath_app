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

      final user = _auth.currentUser;
      if (user == null) {
        throw 'No user logged in';
      }

      // Create a unique file name
      final String fileName = 'profile_${user.uid}_${DateTime.now().millisecondsSinceEpoch}${path.extension(imageFile.path)}';

      // Create reference to Firebase Storage
      final Reference ref = _storage
          .ref()
          .child('profile_images')
          .child(fileName);

      // Upload file
      final UploadTask uploadTask = ref.putFile(File(imageFile.path));

      // Wait for upload to complete
      final TaskSnapshot snapshot = await uploadTask;

      // Get download URL
      final String downloadUrl = await snapshot.ref.getDownloadURL();

      return downloadUrl;
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
}