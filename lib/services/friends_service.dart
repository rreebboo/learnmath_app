import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class FriendsService {
  static final FriendsService _instance = FriendsService._internal();
  factory FriendsService() => _instance;
  FriendsService._internal();

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  String? get currentUserId => _auth.currentUser?.uid;

  // Get user's friends list
  Stream<List<Map<String, dynamic>>> getFriends() {
    if (currentUserId == null) return Stream.value([]);
    
    return _firestore
        .collection('users')
        .doc(currentUserId)
        .collection('friends')
        .snapshots()
        .asyncMap((snapshot) async {
      List<Map<String, dynamic>> friends = [];
      
      for (var doc in snapshot.docs) {
        try {
          final friendId = doc.id;
          final friendData = await _firestore
              .collection('users')
              .doc(friendId)
              .get();
          
          if (friendData.exists) {
            final data = friendData.data() as Map<String, dynamic>;
            friends.add({
              'id': friendId,
              'name': data['name'] ?? 'Unknown',
              'avatar': data['avatar'] ?? '🦊',
              'isOnline': data['isOnline'] ?? false,
              'lastSeen': data['lastSeen'],
              'totalScore': data['totalScore'] ?? 0,
              'wins': data['wins'] ?? 0,
              'level': _getUserLevel(data['totalScore'] ?? 0),
              'status': doc.data()['status'] ?? 'accepted',
              'addedAt': doc.data()['addedAt'],
            });
          }
        } catch (e) {
          // print('Error fetching friend data: $e');
        }
      }
      
      // Sort by online status, then by name
      friends.sort((a, b) {
        if (a['isOnline'] != b['isOnline']) {
          return a['isOnline'] ? -1 : 1;
        }
        return a['name'].toString().compareTo(b['name'].toString());
      });
      
      return friends;
    });
  }

  // Get friend requests (incoming)
  Stream<List<Map<String, dynamic>>> getFriendRequests() {
    if (currentUserId == null) return Stream.value([]);
    
    return _firestore
        .collection('users')
        .doc(currentUserId)
        .collection('friendRequests')
        .where('type', isEqualTo: 'incoming')
        .snapshots()
        .asyncMap((snapshot) async {
      List<Map<String, dynamic>> requests = [];
      
      for (var doc in snapshot.docs) {
        try {
          final fromUserId = doc.data()['fromUserId'];
          final userData = await _firestore
              .collection('users')
              .doc(fromUserId)
              .get();
          
          if (userData.exists) {
            final data = userData.data() as Map<String, dynamic>;
            requests.add({
              'id': doc.id,
              'fromUserId': fromUserId,
              'name': data['name'] ?? 'Unknown',
              'avatar': data['avatar'] ?? '🦊',
              'totalScore': data['totalScore'] ?? 0,
              'sentAt': doc.data()['sentAt'],
              'message': doc.data()['message'] ?? '',
            });
          }
        } catch (e) {
          // print('Error fetching friend request: $e');
        }
      }
      
      return requests;
    });
  }

  // Search for users by name or username
  Future<List<Map<String, dynamic>>> searchUsers(String query) async {
    if (query.trim().isEmpty || currentUserId == null) return [];
    
    try {
      final normalizedQuery = query.toLowerCase().trim();
      
      // Search by name
      final nameQuery = await _firestore
          .collection('users')
          .where('name', isGreaterThanOrEqualTo: normalizedQuery)
          .where('name', isLessThanOrEqualTo: '$normalizedQuery\uf8ff')
          .limit(10)
          .get();
      
      // Search by username if it exists
      final usernameQuery = await _firestore
          .collection('users')
          .where('username', isGreaterThanOrEqualTo: normalizedQuery)
          .where('username', isLessThanOrEqualTo: '$normalizedQuery\uf8ff')
          .limit(10)
          .get();
      
      Set<String> userIds = {};
      List<Map<String, dynamic>> results = [];
      
      // Process name search results
      for (var doc in nameQuery.docs) {
        if (doc.id != currentUserId && !userIds.contains(doc.id)) {
          userIds.add(doc.id);
          final data = doc.data();
          results.add({
            'id': doc.id,
            'name': data['name'] ?? 'Unknown',
            'username': data['username'] ?? '',
            'avatar': data['avatar'] ?? '🦊',
            'totalScore': data['totalScore'] ?? 0,
            'level': _getUserLevel(data['totalScore'] ?? 0),
          });
        }
      }
      
      // Process username search results
      for (var doc in usernameQuery.docs) {
        if (doc.id != currentUserId && !userIds.contains(doc.id)) {
          userIds.add(doc.id);
          final data = doc.data();
          results.add({
            'id': doc.id,
            'name': data['name'] ?? 'Unknown',
            'username': data['username'] ?? '',
            'avatar': data['avatar'] ?? '🦊',
            'totalScore': data['totalScore'] ?? 0,
            'level': _getUserLevel(data['totalScore'] ?? 0),
          });
        }
      }
      
      return results;
    } catch (e) {
      // print('Error searching users: $e');
      return [];
    }
  }

  // Send friend request
  Future<bool> sendFriendRequest(String toUserId, {String message = ''}) async {
    if (currentUserId == null) return false;
    
    try {
      final batch = _firestore.batch();
      
      // Add to recipient's friend requests
      final requestRef = _firestore
          .collection('users')
          .doc(toUserId)
          .collection('friendRequests')
          .doc();
      
      batch.set(requestRef, {
        'fromUserId': currentUserId,
        'type': 'incoming',
        'message': message,
        'sentAt': FieldValue.serverTimestamp(),
      });
      
      // Add to sender's sent requests
      final sentRef = _firestore
          .collection('users')
          .doc(currentUserId)
          .collection('friendRequests')
          .doc();
      
      batch.set(sentRef, {
        'toUserId': toUserId,
        'type': 'outgoing',
        'message': message,
        'sentAt': FieldValue.serverTimestamp(),
      });
      
      await batch.commit();
      return true;
    } catch (e) {
      // print('Error sending friend request: $e');
      return false;
    }
  }

  // Accept friend request
  Future<bool> acceptFriendRequest(String requestId, String fromUserId) async {
    if (currentUserId == null) return false;
    
    try {
      final batch = _firestore.batch();
      
      // Add to both users' friends lists
      final myFriendRef = _firestore
          .collection('users')
          .doc(currentUserId)
          .collection('friends')
          .doc(fromUserId);
      
      final theirFriendRef = _firestore
          .collection('users')
          .doc(fromUserId)
          .collection('friends')
          .doc(currentUserId);
      
      batch.set(myFriendRef, {
        'status': 'accepted',
        'addedAt': FieldValue.serverTimestamp(),
      });
      
      batch.set(theirFriendRef, {
        'status': 'accepted',
        'addedAt': FieldValue.serverTimestamp(),
      });
      
      // Remove friend request
      final requestRef = _firestore
          .collection('users')
          .doc(currentUserId)
          .collection('friendRequests')
          .doc(requestId);
      
      batch.delete(requestRef);
      
      await batch.commit();
      return true;
    } catch (e) {
      // print('Error accepting friend request: $e');
      return false;
    }
  }

  // Decline friend request
  Future<bool> declineFriendRequest(String requestId) async {
    if (currentUserId == null) return false;
    
    try {
      await _firestore
          .collection('users')
          .doc(currentUserId)
          .collection('friendRequests')
          .doc(requestId)
          .delete();
      return true;
    } catch (e) {
      // print('Error declining friend request: $e');
      return false;
    }
  }

  // Remove friend
  Future<bool> removeFriend(String friendId) async {
    if (currentUserId == null) return false;
    
    try {
      final batch = _firestore.batch();
      
      // Remove from both users' friends lists
      final myFriendRef = _firestore
          .collection('users')
          .doc(currentUserId)
          .collection('friends')
          .doc(friendId);
      
      final theirFriendRef = _firestore
          .collection('users')
          .doc(friendId)
          .collection('friends')
          .doc(currentUserId);
      
      batch.delete(myFriendRef);
      batch.delete(theirFriendRef);
      
      await batch.commit();
      return true;
    } catch (e) {
      // print('Error removing friend: $e');
      return false;
    }
  }

  // Check if users are friends
  Future<bool> areFriends(String userId) async {
    if (currentUserId == null) return false;
    
    try {
      final doc = await _firestore
          .collection('users')
          .doc(currentUserId)
          .collection('friends')
          .doc(userId)
          .get();
      
      return doc.exists;
    } catch (e) {
      // print('Error checking friendship: $e');
      return false;
    }
  }

  // Challenge friend to duel
  Future<bool> challengeFriend(String friendId, {String gameMode = 'quick'}) async {
    if (currentUserId == null) return false;
    
    try {
      // Create a duel challenge
      await _firestore
          .collection('challenges')
          .add({
        'fromUserId': currentUserId,
        'toUserId': friendId,
        'gameMode': gameMode,
        'status': 'pending',
        'createdAt': FieldValue.serverTimestamp(),
        'expiresAt': Timestamp.fromDate(
          DateTime.now().add(const Duration(minutes: 10)),
        ),
      });
      
      return true;
    } catch (e) {
      // print('Error sending challenge: $e');
      return false;
    }
  }

  // Helper method to determine user level based on score
  String _getUserLevel(int score) {
    if (score < 100) return 'Beginner';
    if (score < 500) return 'Student';
    if (score < 1000) return 'Scholar';
    if (score < 2000) return 'Expert';
    return 'Master';
  }

  // Update user online status
  Future<void> updateOnlineStatus(bool isOnline) async {
    if (currentUserId == null) return;
    
    try {
      await _firestore
          .collection('users')
          .doc(currentUserId)
          .update({
        'isOnline': isOnline,
        'lastSeen': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      // print('Error updating online status: $e');
    }
  }
}