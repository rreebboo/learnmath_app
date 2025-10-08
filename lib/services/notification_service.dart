import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import '../models/notification.dart';

class NotificationService {
  static final NotificationService _instance = NotificationService._internal();
  factory NotificationService() => _instance;
  NotificationService._internal();

  // Use lazy initialization to avoid accessing Firebase before it's initialized
  FirebaseFirestore? _firestoreInstance;
  FirebaseAuth? _authInstance;
  FirebaseFirestore get _firestore => _firestoreInstance ??= FirebaseFirestore.instance;
  FirebaseAuth get _auth => _authInstance ??= FirebaseAuth.instance;

  // Check if Firebase is initialized
  bool get _isFirebaseInitialized => Firebase.apps.isNotEmpty;

  String? get currentUserId => _auth.currentUser?.uid;

  // Stream to listen to notifications for the current user
  Stream<List<AppNotification>>? streamUserNotifications() {
    print('NotificationService: streamUserNotifications called');
    print('NotificationService: Firebase initialized: $_isFirebaseInitialized, currentUserId: $currentUserId');

    if (!_isFirebaseInitialized || currentUserId == null) {
      print('NotificationService: Cannot create stream - Firebase not initialized or user not authenticated');
      return null;
    }

    print('NotificationService: Creating notification stream for user: $currentUserId');

    return _firestore
        .collection('users')
        .doc(currentUserId!)
        .collection('notifications')
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snapshot) {
          print('NotificationService: Stream received ${snapshot.docs.length} documents');
          return snapshot.docs
              .map((doc) {
                print('NotificationService: Processing notification doc: ${doc.id}');
                return AppNotification.fromFirestore(doc);
              })
              .toList();
        });
  }

  // Get unread notifications count
  Future<int> getUnreadNotificationsCount() async {
    if (!_isFirebaseInitialized || currentUserId == null) return 0;

    try {
      final snapshot = await _firestore
          .collection('users')
          .doc(currentUserId!)
          .collection('notifications')
          .where('isRead', isEqualTo: false)
          .get();

      return snapshot.docs.length;
    } catch (e) {
      print('Error getting unread notifications count: $e');
      return 0;
    }
  }

  // Stream for unread notifications count
  Stream<int> streamUnreadNotificationsCount() {
    if (!_isFirebaseInitialized || currentUserId == null) {
      return Stream.value(0);
    }

    return _firestore
        .collection('users')
        .doc(currentUserId!)
        .collection('notifications')
        .where('isRead', isEqualTo: false)
        .snapshots()
        .map((snapshot) => snapshot.docs.length);
  }

  // Send a duel challenge notification
  Future<void> sendDuelChallengeNotification({
    required String toUserId,
    required String fromUserName,
    required String fromUserAvatar,
    String? duelId,
    String? difficulty,
    String? topicName,
  }) async {
    print('NotificationService: Attempting to send duel challenge notification');
    print('NotificationService: toUserId: $toUserId, fromUserName: $fromUserName, duelId: $duelId');
    print('NotificationService: Firebase initialized: $_isFirebaseInitialized, currentUserId: $currentUserId');

    if (!_isFirebaseInitialized || currentUserId == null) {
      print('NotificationService: Cannot send notification - Firebase not initialized or user not authenticated');
      return;
    }

    try {
      final notification = AppNotification(
        id: '',
        title: 'Math Duel Challenge! 🔢',
        message: '$fromUserName wants to challenge you to a math duel!',
        type: NotificationType.duelChallenge,
        fromUserId: currentUserId!,
        toUserId: toUserId,
        fromUserName: fromUserName,
        fromUserAvatar: fromUserAvatar,
        data: {
          'duelId': duelId,
          'challengerName': fromUserName,
          'difficulty': difficulty,
          'topicName': topicName,
        },
        createdAt: DateTime.now(),
      );

      print('NotificationService: About to write notification to Firestore');
      print('NotificationService: Target path: users/$toUserId/notifications');

      final docRef = await _firestore
          .collection('users')
          .doc(toUserId)
          .collection('notifications')
          .add(notification.toFirestore());

      print('NotificationService: Notification written successfully with ID: ${docRef.id}');

      // Notification saved - popup handled by global listener

      print('Duel challenge notification sent to $toUserId');
    } catch (e) {
      print('Error sending duel challenge notification: $e');
    }
  }

  // Send a friend request notification
  Future<void> sendFriendRequestNotification({
    required String toUserId,
    required String fromUserName,
    required String fromUserAvatar,
  }) async {
    if (!_isFirebaseInitialized || currentUserId == null) return;

    try {
      final notification = AppNotification(
        id: '',
        title: 'Friend Request 🤝',
        message: '$fromUserName sent you a friend request!',
        type: NotificationType.friendRequest,
        fromUserId: currentUserId!,
        toUserId: toUserId,
        fromUserName: fromUserName,
        fromUserAvatar: fromUserAvatar,
        data: {
          'requesterId': currentUserId,
          'requesterName': fromUserName,
        },
        createdAt: DateTime.now(),
      );

      await _firestore
          .collection('users')
          .doc(toUserId)
          .collection('notifications')
          .add(notification.toFirestore());

      // Notification saved - popup handled by global listener

      print('Friend request notification sent to $toUserId');
    } catch (e) {
      print('Error sending friend request notification: $e');
    }
  }

  // Send a general notification
  Future<void> sendGeneralNotification({
    required String toUserId,
    required String title,
    required String message,
    Map<String, dynamic>? data,
  }) async {
    if (!_isFirebaseInitialized || currentUserId == null) return;

    try {
      // Get current user data
      final userDoc = await _firestore
          .collection('users')
          .doc(currentUserId!)
          .get();

      String fromUserName = 'System';
      String? fromUserAvatar;

      if (userDoc.exists) {
        final userData = userDoc.data() as Map<String, dynamic>;
        fromUserName = userData['name'] ?? 'System';
        fromUserAvatar = userData['avatar'];
      }

      // Determine notification type based on data
      NotificationType notificationType = NotificationType.general;
      if (data != null && data['type'] == 'achievement') {
        notificationType = NotificationType.achievement;
      }

      final notification = AppNotification(
        id: '',
        title: title,
        message: message,
        type: notificationType,
        fromUserId: currentUserId!,
        toUserId: toUserId,
        fromUserName: fromUserName,
        fromUserAvatar: fromUserAvatar,
        data: data,
        createdAt: DateTime.now(),
      );

      await _firestore
          .collection('users')
          .doc(toUserId)
          .collection('notifications')
          .add(notification.toFirestore());

      // Notification saved - popup handled by global listener

      print('General notification sent to $toUserId');
    } catch (e) {
      print('Error sending general notification: $e');
    }
  }

  // Send friend request response notification (accepted or declined)
  Future<void> sendFriendRequestResponseNotification({
    required String toUserId,
    required String fromUserId,
    required String fromUserName,
    required String fromUserAvatar,
    required bool accepted,
  }) async {
    print('NotificationService: sendFriendRequestResponseNotification called');
    print('NotificationService: toUserId=$toUserId, fromUserId=$fromUserId, fromUserName=$fromUserName, accepted=$accepted');

    if (!_isFirebaseInitialized) {
      print('NotificationService: ERROR - Firebase not initialized!');
      return;
    }

    try {
      final title = accepted
          ? 'Friend Request Accepted! 🎉'
          : 'Friend Request Declined!';

      final message = accepted
          ? '$fromUserName accepted your friend request. You can now challenge each other!'
          : '$fromUserName declined your friend request.';

      print('NotificationService: Creating notification - title: "$title"');
      print('NotificationService: Message: "$message"');

      final notification = AppNotification(
        id: '',
        title: title,
        message: message,
        type: NotificationType.friendRequestResponse,
        fromUserId: fromUserId,
        toUserId: toUserId,
        fromUserName: fromUserName,
        fromUserAvatar: fromUserAvatar,
        data: {
          'type': 'friend_request_response',
          'accepted': accepted,
          'responderId': fromUserId,
        },
        createdAt: DateTime.now(),
      );

      print('NotificationService: Writing to Firestore path: users/$toUserId/notifications');

      final docRef = await _firestore
          .collection('users')
          .doc(toUserId)
          .collection('notifications')
          .add(notification.toFirestore());

      print('NotificationService: ✅ Notification written successfully with ID: ${docRef.id}');
      print('NotificationService: Friend request response notification sent to $toUserId (accepted: $accepted)');
    } catch (e, stackTrace) {
      print('NotificationService: ❌ ERROR sending friend request response notification: $e');
      print('NotificationService: Stack trace: $stackTrace');
    }
  }

  // Mark notification as read
  Future<void> markAsRead(String notificationId) async {
    if (!_isFirebaseInitialized || currentUserId == null) return;

    try {
      await _firestore
          .collection('users')
          .doc(currentUserId!)
          .collection('notifications')
          .doc(notificationId)
          .update({'isRead': true});

      print('Notification $notificationId marked as read');
    } catch (e) {
      print('Error marking notification as read: $e');
    }
  }

  // Mark all notifications as read
  Future<void> markAllAsRead() async {
    if (!_isFirebaseInitialized || currentUserId == null) return;

    try {
      final batch = _firestore.batch();
      final notifications = await _firestore
          .collection('users')
          .doc(currentUserId!)
          .collection('notifications')
          .where('isRead', isEqualTo: false)
          .get();

      for (final doc in notifications.docs) {
        batch.update(doc.reference, {'isRead': true});
      }

      await batch.commit();
      print('All notifications marked as read');
    } catch (e) {
      print('Error marking all notifications as read: $e');
    }
  }

  // Delete notification
  Future<void> deleteNotification(String notificationId) async {
    if (!_isFirebaseInitialized || currentUserId == null) return;

    try {
      await _firestore
          .collection('users')
          .doc(currentUserId!)
          .collection('notifications')
          .doc(notificationId)
          .delete();

      print('Notification $notificationId deleted');
    } catch (e) {
      print('Error deleting notification: $e');
    }
  }

  // Clear all notifications
  Future<void> clearAllNotifications() async {
    if (!_isFirebaseInitialized || currentUserId == null) return;

    try {
      final batch = _firestore.batch();
      final notifications = await _firestore
          .collection('users')
          .doc(currentUserId!)
          .collection('notifications')
          .get();

      for (final doc in notifications.docs) {
        batch.delete(doc.reference);
      }

      await batch.commit();
      print('All notifications cleared');
    } catch (e) {
      print('Error clearing all notifications: $e');
    }
  }

  // Test notification function - for debugging
  Future<void> sendTestNotification(String toUserId) async {
    if (!_isFirebaseInitialized || currentUserId == null) return;

    try {
      print('NotificationService: Sending test notification to $toUserId');

      final notification = AppNotification(
        id: '',
        title: 'Test Notification 🧪',
        message: 'This is a test notification to verify the system is working!',
        type: NotificationType.general,
        fromUserId: currentUserId!,
        toUserId: toUserId,
        fromUserName: 'Test System',
        fromUserAvatar: '🤖',
        data: {
          'testType': 'system_test',
        },
        createdAt: DateTime.now(),
      );

      final docRef = await _firestore
          .collection('users')
          .doc(toUserId)
          .collection('notifications')
          .add(notification.toFirestore());

      print('NotificationService: Test notification sent successfully with ID: ${docRef.id}');
    } catch (e) {
      print('NotificationService: Error sending test notification: $e');
    }
  }
}