import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class FriendsService {
  static final FriendsService _instance = FriendsService._internal();
  factory FriendsService() => _instance;
  FriendsService._internal();

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  String? get currentUserId {
    final user = _auth.currentUser;
    print('FriendsService: Current user UID: ${user?.uid}');
    print('FriendsService: Current user email: ${user?.email}');
    print('FriendsService: Current user display name: ${user?.displayName}');
    print('FriendsService: Current user isAnonymous: ${user?.isAnonymous}');
    print('FriendsService: Current user emailVerified: ${user?.emailVerified}');
    
    if (user == null) {
      print('FriendsService: ⚠️ WARNING - No authenticated user found!');
    }
    
    return user?.uid;
  }

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
        .where('status', isEqualTo: 'pending')
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
    print('FriendsService: Searching for users with query: "$query"');
    
    if (query.trim().isEmpty || currentUserId == null) {
      print('FriendsService: Empty query or null currentUserId');
      return [];
    }
    
    try {
      final normalizedQuery = query.toLowerCase().trim();
      print('FriendsService: Normalized query: "$normalizedQuery"');
      
      // Search by name (case-insensitive)
      final nameQuery = await _firestore
          .collection('users')
          .orderBy('name')
          .startAt([normalizedQuery])
          .endAt([normalizedQuery + '\uf8ff'])
          .limit(10)
          .get();
      
      print('FriendsService: Found ${nameQuery.docs.length} users by name');
      
      Set<String> userIds = {};
      List<Map<String, dynamic>> results = [];
      
      // Process name search results
      for (var doc in nameQuery.docs) {
        if (doc.id != currentUserId && !userIds.contains(doc.id)) {
          userIds.add(doc.id);
          final data = doc.data();
          
          // Check if the name contains the search query (case-insensitive)
          final userName = (data['name'] ?? '').toString().toLowerCase();
          if (userName.contains(normalizedQuery)) {
            results.add({
              'id': doc.id,
              'name': data['name'] ?? 'Unknown',
              'username': data['username'] ?? '',
              'avatar': data['avatar'] ?? '🦊',
              'totalScore': data['totalScore'] ?? 0,
              'level': _getUserLevel(data['totalScore'] ?? 0),
            });
            print('FriendsService: Added user: ${data['name']} (${doc.id})');
          }
        }
      }
      
      // Also search for exact matches by doing a simple query
      if (results.isEmpty) {
        print('FriendsService: No results from ordered query, trying simple search');
        final simpleQuery = await _firestore
            .collection('users')
            .limit(50)
            .get();
        
        for (var doc in simpleQuery.docs) {
          if (doc.id != currentUserId && !userIds.contains(doc.id)) {
            final data = doc.data();
            final userName = (data['name'] ?? '').toString().toLowerCase();
            
            if (userName.contains(normalizedQuery)) {
              userIds.add(doc.id);
              results.add({
                'id': doc.id,
                'name': data['name'] ?? 'Unknown',
                'username': data['username'] ?? '',
                'avatar': data['avatar'] ?? '🦊',
                'totalScore': data['totalScore'] ?? 0,
                'level': _getUserLevel(data['totalScore'] ?? 0),
              });
              print('FriendsService: Found match: ${data['name']} (${doc.id})');
            }
          }
        }
      }
      
      print('FriendsService: Returning ${results.length} search results');
      return results;
    } catch (e) {
      print('FriendsService: Error searching users: $e');
      print('FriendsService: Error type: ${e.runtimeType}');
      return [];
    }
  }

  // Send friend request
  Future<bool> sendFriendRequest(String toUserId, {String message = ''}) async {
    print('FriendsService: Attempting to send friend request from $currentUserId to $toUserId');
    
    if (currentUserId == null) {
      print('FriendsService: ERROR - currentUserId is null, user not authenticated');
      return false;
    }
    
    if (toUserId == currentUserId) {
      print('FriendsService: ERROR - Cannot send friend request to self');
      return false;
    }
    
    try {
      // Test basic Firestore connectivity first
      print('FriendsService: Testing Firestore connectivity...');
      await _firestore.collection('users').limit(1).get();
      print('FriendsService: Firestore connectivity confirmed');
      
      // Verify current user exists in Firestore
      print('FriendsService: Verifying current user exists in Firestore...');
      final currentUserDoc = await _firestore.collection('users').doc(currentUserId).get();
      if (!currentUserDoc.exists) {
        print('FriendsService: ERROR - Current user document does not exist in Firestore');
        print('FriendsService: Current user ID: $currentUserId');
        return false;
      }
      print('FriendsService: Current user verified: ${currentUserDoc.data()?['name']}');
      
      print('FriendsService: Checking if users are already friends');
      // Check if already friends
      final alreadyFriends = await areFriends(toUserId);
      if (alreadyFriends) {
        print('FriendsService: Users are already friends');
        return false;
      }
      
      print('FriendsService: Checking for existing outgoing request');
      // Check if request already sent by looking in current user's outgoing requests
      final existingOutgoingRequest = await _firestore
          .collection('users')
          .doc(currentUserId)
          .collection('friendRequests')
          .where('toUserId', isEqualTo: toUserId)
          .where('type', isEqualTo: 'outgoing')
          .where('status', isEqualTo: 'pending')
          .get();
      
      if (existingOutgoingRequest.docs.isNotEmpty) {
        print('FriendsService: Request already sent');
        return false;
      }
      
      print('FriendsService: Verifying target user exists');
      // Verify target user exists
      final targetUserDoc = await _firestore.collection('users').doc(toUserId).get();
      if (!targetUserDoc.exists) {
        print('FriendsService: ERROR - Target user does not exist');
        print('FriendsService: Target user ID: $toUserId');
        return false;
      }
      print('FriendsService: Target user verified: ${targetUserDoc.data()?['name']}');
      
      print('FriendsService: Creating friend request documents');
      final batch = _firestore.batch();
      
      // Add to recipient's friend requests
      final requestRef = _firestore
          .collection('users')
          .doc(toUserId)
          .collection('friendRequests')
          .doc();
      
      final incomingRequestData = {
        'fromUserId': currentUserId,
        'type': 'incoming',
        'message': message,
        'sentAt': FieldValue.serverTimestamp(),
        'status': 'pending',
      };
      
      print('FriendsService: Adding incoming request: $incomingRequestData');
      batch.set(requestRef, incomingRequestData);
      
      // Add to sender's sent requests
      final sentRef = _firestore
          .collection('users')
          .doc(currentUserId)
          .collection('friendRequests')
          .doc();
      
      final outgoingRequestData = {
        'toUserId': toUserId,
        'type': 'outgoing',
        'message': message,
        'sentAt': FieldValue.serverTimestamp(),
        'status': 'pending',
      };
      
      print('FriendsService: Adding outgoing request: $outgoingRequestData');
      batch.set(sentRef, outgoingRequestData);
      
      print('FriendsService: Committing batch write to Firestore...');
      await batch.commit();
      print('FriendsService: ✅ Friend request sent successfully!');
      return true;
    } catch (e, stackTrace) {
      print('FriendsService: ❌ ERROR sending friend request: $e');
      print('FriendsService: Error type: ${e.runtimeType}');
      print('FriendsService: Stack trace: $stackTrace');
      
      // Try to provide more specific error information
      if (e.toString().contains('permission')) {
        print('FriendsService: This appears to be a permissions error - check Firestore rules');
      } else if (e.toString().contains('network')) {
        print('FriendsService: This appears to be a network connectivity error');
      } else if (e.toString().contains('auth')) {
        print('FriendsService: This appears to be an authentication error');
      }
      
      return false;
    }
  }

  // Accept friend request
  Future<bool> acceptFriendRequest(String requestId, String fromUserId) async {
    print('FriendsService: Accepting friend request - requestId: $requestId, fromUserId: $fromUserId');
    
    if (currentUserId == null) {
      print('FriendsService: ERROR - currentUserId is null');
      return false;
    }
    
    try {
      print('FriendsService: Starting batch transaction for accepting friend request');
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
      
      final friendData = {
        'status': 'accepted',
        'addedAt': FieldValue.serverTimestamp(),
      };
      
      print('FriendsService: Adding $currentUserId to $fromUserId\'s friends');
      batch.set(myFriendRef, friendData);
      
      print('FriendsService: Adding $fromUserId to $currentUserId\'s friends');
      batch.set(theirFriendRef, friendData);
      
      // Remove friend request from recipient (current user)
      final requestRef = _firestore
          .collection('users')
          .doc(currentUserId)
          .collection('friendRequests')
          .doc(requestId);
      
      print('FriendsService: Removing incoming request: $requestId');
      batch.delete(requestRef);
      
      // Note: We only remove the incoming request from current user's collection
      // The sender's outgoing request will remain but can be filtered out in queries
      print('FriendsService: Not modifying sender\'s collection due to security rules');
      
      print('FriendsService: Committing batch transaction...');
      await batch.commit();
      print('FriendsService: ✅ Friend request accepted successfully!');
      
      // Clean up any remaining friend requests between these users
      await cleanupFriendRequests(currentUserId!, fromUserId);
      
      return true;
    } catch (e, stackTrace) {
      print('FriendsService: ❌ ERROR accepting friend request: $e');
      print('FriendsService: Error type: ${e.runtimeType}');
      print('FriendsService: Stack trace: $stackTrace');
      
      // Provide more specific error information
      if (e.toString().contains('permission')) {
        print('FriendsService: This appears to be a permissions error - check Firestore rules');
      } else if (e.toString().contains('not-found')) {
        print('FriendsService: Request document not found - may have been already processed');
      }
      
      return false;
    }
  }

  // Decline friend request
  Future<bool> declineFriendRequest(String requestId) async {
    print('FriendsService: Declining friend request - requestId: $requestId');
    
    if (currentUserId == null) {
      print('FriendsService: ERROR - currentUserId is null');
      return false;
    }
    
    try {
      // First, get the request to find the sender
      print('FriendsService: Getting friend request document...');
      final requestDoc = await _firestore
          .collection('users')
          .doc(currentUserId)
          .collection('friendRequests')
          .doc(requestId)
          .get();
      
      if (!requestDoc.exists) {
        print('FriendsService: ERROR - Friend request document not found');
        return false;
      }
      
      final fromUserId = requestDoc.data()?['fromUserId'];
      if (fromUserId == null) {
        print('FriendsService: ERROR - fromUserId not found in request document');
        return false;
      }
      
      print('FriendsService: Found request from user: $fromUserId');
      final batch = _firestore.batch();
      
      // Delete the incoming request
      print('FriendsService: Deleting incoming request: $requestId');
      batch.delete(requestDoc.reference);
      
      // Note: We only remove the incoming request from current user's collection
      // The sender's outgoing request will remain but can be filtered out in queries
      print('FriendsService: Not modifying sender\'s collection due to security rules');
      
      print('FriendsService: Committing batch transaction...');
      await batch.commit();
      print('FriendsService: ✅ Friend request declined successfully!');
      
      // Clean up any remaining friend requests between these users
      await cleanupFriendRequests(currentUserId!, fromUserId);
      
      return true;
    } catch (e, stackTrace) {
      print('FriendsService: ❌ ERROR declining friend request: $e');
      print('FriendsService: Error type: ${e.runtimeType}');
      print('FriendsService: Stack trace: $stackTrace');
      
      return false;
    }
  }

  // Remove friend
  Future<bool> removeFriend(String friendId) async {
    print('FriendsService: Attempting to remove friend - friendId: $friendId');
    
    if (currentUserId == null) {
      print('FriendsService: ERROR - currentUserId is null');
      return false;
    }
    
    try {
      print('FriendsService: Starting batch transaction to remove friendship');
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
      
      print('FriendsService: Removing $friendId from $currentUserId\'s friends list');
      batch.delete(myFriendRef);
      
      print('FriendsService: Removing $currentUserId from $friendId\'s friends list');
      batch.delete(theirFriendRef);
      
      print('FriendsService: Committing batch transaction...');
      await batch.commit();
      print('FriendsService: ✅ Friend removed successfully!');
      
      // Clean up any existing friend requests between these users
      print('FriendsService: Cleaning up friend requests after removal...');
      await cleanupFriendRequests(currentUserId!, friendId);
      
      return true;
    } catch (e, stackTrace) {
      print('FriendsService: ❌ ERROR removing friend: $e');
      print('FriendsService: Error type: ${e.runtimeType}');
      print('FriendsService: Stack trace: $stackTrace');
      
      if (e.toString().contains('permission')) {
        print('FriendsService: This appears to be a permissions error - check Firestore rules');
      }
      
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

  // Smart status check that cleans up stale requests automatically
  Future<String> getCleanRelationshipStatus(String userId) async {
    if (currentUserId == null) return 'none';
    
    try {
      print('FriendsService: Smart status check for $userId');
      
      // First check if they're already friends
      final areAlreadyFriends = await areFriends(userId);
      if (areAlreadyFriends) {
        // Clean up any stale friend requests if they're already friends
        await cleanupFriendRequests(currentUserId!, userId);
        print('FriendsService: Status = friends (cleaned up any stale requests)');
        return 'friends';
      }
      
      // Check for pending requests
      final hasPending = await hasPendingRequest(userId);
      if (hasPending) {
        print('FriendsService: Status = pending');
        return 'pending';
      }
      
      print('FriendsService: Status = none (can add friend)');
      return 'none';
    } catch (e) {
      print('FriendsService: Error in smart status check: $e');
      return 'none';
    }
  }

  // Check if friend request is pending
  Future<bool> hasPendingRequest(String userId) async {
    if (currentUserId == null) return false;
    
    try {
      print('FriendsService: Checking pending requests between $currentUserId and $userId');
      
      // Check for outgoing request from current user
      final outgoingRequest = await _firestore
          .collection('users')
          .doc(currentUserId)
          .collection('friendRequests')
          .where('toUserId', isEqualTo: userId)
          .where('type', isEqualTo: 'outgoing')
          .where('status', isEqualTo: 'pending')
          .get();
      
      print('FriendsService: Found ${outgoingRequest.docs.length} outgoing requests');
      if (outgoingRequest.docs.isNotEmpty) return true;
      
      // Check for incoming request from the other user
      final incomingRequest = await _firestore
          .collection('users')
          .doc(currentUserId)
          .collection('friendRequests')
          .where('fromUserId', isEqualTo: userId)
          .where('type', isEqualTo: 'incoming')
          .where('status', isEqualTo: 'pending')
          .get();
      
      print('FriendsService: Found ${incomingRequest.docs.length} incoming requests');
      final hasPending = incomingRequest.docs.isNotEmpty;
      
      print('FriendsService: Has pending request: $hasPending');
      return hasPending;
    } catch (e) {
      print('FriendsService: Error checking pending request: $e');
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

  // Test Firestore connection
  Future<bool> testFirestoreConnection() async {
    try {
      print('FriendsService: Testing Firestore connection...');
      final testDoc = await _firestore
          .collection('users')
          .limit(1)
          .get();
      print('FriendsService: Firestore connection test - found ${testDoc.docs.length} users');
      return true;
    } catch (e) {
      print('FriendsService: Firestore connection test failed: $e');
      return false;
    }
  }

  // Test Firestore write permissions by trying to write to own user doc
  Future<bool> testFirestoreWritePermissions() async {
    if (currentUserId == null) {
      print('FriendsService: Cannot test write permissions - no authenticated user');
      return false;
    }

    try {
      print('FriendsService: Testing Firestore write permissions...');
      
      // Try to update the user's own document with a test field
      await _firestore
          .collection('users')
          .doc(currentUserId)
          .update({
        'lastConnectionTest': FieldValue.serverTimestamp(),
      });
      
      print('FriendsService: ✅ Write permissions test successful');
      return true;
    } catch (e) {
      print('FriendsService: ❌ Write permissions test failed: $e');
      print('FriendsService: Error type: ${e.runtimeType}');
      
      if (e.toString().contains('permission')) {
        print('FriendsService: This is a permissions error - check Firestore rules');
      } else if (e.toString().contains('not-found')) {
        print('FriendsService: User document not found - user may need to be recreated');
      }
      
      return false;
    }
  }

  // Clean up stale friend requests (both directions when friendship is formed)
  Future<void> cleanupFriendRequests(String userId1, String userId2) async {
    try {
      print('FriendsService: Cleaning up friend requests between $userId1 and $userId2');
      
      final batch = _firestore.batch();
      
      // Clean up requests from userId1 (outgoing from userId1 to userId2)
      final user1OutgoingQuery = await _firestore
          .collection('users')
          .doc(userId1)
          .collection('friendRequests')
          .where('toUserId', isEqualTo: userId2)
          .get();
      
      for (var doc in user1OutgoingQuery.docs) {
        print('FriendsService: Cleaning up $userId1 outgoing request: ${doc.id}');
        batch.delete(doc.reference);
      }
      
      // Clean up requests to userId1 (incoming to userId1 from userId2)
      final user1IncomingQuery = await _firestore
          .collection('users')
          .doc(userId1)
          .collection('friendRequests')
          .where('fromUserId', isEqualTo: userId2)
          .get();
      
      for (var doc in user1IncomingQuery.docs) {
        print('FriendsService: Cleaning up $userId1 incoming request: ${doc.id}');
        batch.delete(doc.reference);
      }
      
      // Clean up requests from userId2 (outgoing from userId2 to userId1)
      final user2OutgoingQuery = await _firestore
          .collection('users')
          .doc(userId2)
          .collection('friendRequests')
          .where('toUserId', isEqualTo: userId1)
          .get();
      
      for (var doc in user2OutgoingQuery.docs) {
        print('FriendsService: Cleaning up $userId2 outgoing request: ${doc.id}');
        batch.delete(doc.reference);
      }
      
      // Clean up requests to userId2 (incoming to userId2 from userId1)
      final user2IncomingQuery = await _firestore
          .collection('users')
          .doc(userId2)
          .collection('friendRequests')
          .where('fromUserId', isEqualTo: userId1)
          .get();
      
      for (var doc in user2IncomingQuery.docs) {
        print('FriendsService: Cleaning up $userId2 incoming request: ${doc.id}');
        batch.delete(doc.reference);
      }
      
      if (user1OutgoingQuery.docs.isNotEmpty || user1IncomingQuery.docs.isNotEmpty || 
          user2OutgoingQuery.docs.isNotEmpty || user2IncomingQuery.docs.isNotEmpty) {
        await batch.commit();
        print('FriendsService: ✅ Friend requests cleaned up successfully');
      } else {
        print('FriendsService: No friend requests to clean up');
      }
    } catch (e) {
      print('FriendsService: ⚠️ Error cleaning up friend requests: $e');
    }
  }

  // Test creating a subcollection document (for friend requests)
  Future<bool> testSubcollectionWrite() async {
    if (currentUserId == null) {
      print('FriendsService: Cannot test subcollection write - no authenticated user');
      return false;
    }

    try {
      print('FriendsService: Testing subcollection write permissions...');
      
      // Try to create a test document in friendRequests subcollection
      final testRef = _firestore
          .collection('users')
          .doc(currentUserId)
          .collection('friendRequests')
          .doc('test_write_permissions');
      
      await testRef.set({
        'test': true,
        'createdAt': FieldValue.serverTimestamp(),
      });
      
      print('FriendsService: ✅ Test document created successfully');
      
      // Clean up the test document
      await testRef.delete();
      print('FriendsService: ✅ Test document cleaned up');
      
      return true;
    } catch (e) {
      print('FriendsService: ❌ Subcollection write test failed: $e');
      print('FriendsService: Error type: ${e.runtimeType}');
      
      return false;
    }
  }

  // Comprehensive test of all friends functionality
  Future<bool> testFriendsFunctionality() async {
    print('FriendsService: 🧪 Starting comprehensive friends functionality test...');
    
    try {
      // Test 1: Basic connectivity
      print('FriendsService: Test 1 - Basic connectivity');
      final connectionTest = await testFirestoreConnection();
      if (!connectionTest) {
        print('FriendsService: ❌ Basic connectivity failed');
        return false;
      }
      print('FriendsService: ✅ Basic connectivity passed');
      
      // Test 2: Authentication
      print('FriendsService: Test 2 - Authentication');
      if (currentUserId == null) {
        print('FriendsService: ❌ User not authenticated');
        return false;
      }
      print('FriendsService: ✅ User authenticated: $currentUserId');
      
      // Test 3: Write permissions
      print('FriendsService: Test 3 - Write permissions');
      final writeTest = await testFirestoreWritePermissions();
      if (!writeTest) {
        print('FriendsService: ❌ Write permissions failed');
        return false;
      }
      print('FriendsService: ✅ Write permissions passed');
      
      // Test 4: Subcollection permissions
      print('FriendsService: Test 4 - Subcollection permissions');
      final subcollectionTest = await testSubcollectionWrite();
      if (!subcollectionTest) {
        print('FriendsService: ❌ Subcollection permissions failed');
        return false;
      }
      print('FriendsService: ✅ Subcollection permissions passed');
      
      // Test 5: Friends list retrieval
      print('FriendsService: Test 5 - Friends list retrieval');
      final friendsStream = getFriends();
      await for (final friends in friendsStream.take(1)) {
        print('FriendsService: ✅ Friends list retrieved: ${friends.length} friends');
        break;
      }
      
      // Test 6: Friend requests retrieval
      print('FriendsService: Test 6 - Friend requests retrieval');
      final requestsStream = getFriendRequests();
      await for (final requests in requestsStream.take(1)) {
        print('FriendsService: ✅ Friend requests retrieved: ${requests.length} requests');
        break;
      }
      
      print('FriendsService: 🎉 All friends functionality tests passed!');
      return true;
      
    } catch (e, stackTrace) {
      print('FriendsService: ❌ Friends functionality test failed: $e');
      print('FriendsService: Stack trace: $stackTrace');
      return false;
    }
  }

  // Force refresh and check all friendship and request states  
  Future<Map<String, dynamic>> getRelationshipStatus(String userId) async {
    if (currentUserId == null) return {'status': 'error', 'message': 'Not authenticated'};
    
    try {
      print('FriendsService: Getting complete relationship status with $userId');
      
      final result = <String, dynamic>{};
      
      // Check if already friends
      final areFriendsResult = await areFriends(userId);
      result['areFriends'] = areFriendsResult;
      
      if (areFriendsResult) {
        result['status'] = 'friends';
        return result;
      }
      
      // Check for any pending requests
      final hasPendingResult = await hasPendingRequest(userId);
      result['hasPendingRequest'] = hasPendingResult;
      
      if (hasPendingResult) {
        result['status'] = 'pending';
      } else {
        result['status'] = 'none';
      }
      
      print('FriendsService: Relationship status with $userId: ${result['status']}');
      return result;
      
    } catch (e) {
      print('FriendsService: Error getting relationship status: $e');
      return {'status': 'error', 'message': e.toString()};
    }
  }

  // Force refresh relationship status after operations
  Future<void> forceRefreshRelationship(String userId) async {
    if (currentUserId == null) return;
    
    try {
      print('FriendsService: Force refreshing relationship with $userId');
      
      // Wait a moment for Firestore to propagate changes
      await Future.delayed(const Duration(milliseconds: 500));
      
      // Clean up any remaining stale requests
      await cleanupFriendRequests(currentUserId!, userId);
      
      // Add another small delay
      await Future.delayed(const Duration(milliseconds: 300));
      
      print('FriendsService: ✅ Force refresh completed for $userId');
    } catch (e) {
      print('FriendsService: Error during force refresh: $e');
    }
  }

  // Aggressive cleanup that removes ALL pending requests (use with caution)
  Future<bool> aggressiveCleanupAllRequests() async {
    if (currentUserId == null) return false;
    
    try {
      print('FriendsService: 🔥 AGGRESSIVE cleanup - removing ALL friend requests for $currentUserId');
      
      final batch = _firestore.batch();
      int deletedCount = 0;
      
      // Get ALL friend requests for current user (including pending ones)
      final allRequests = await _firestore
          .collection('users')
          .doc(currentUserId)
          .collection('friendRequests')
          .get();
      
      print('FriendsService: Found ${allRequests.docs.length} requests to remove');
      
      for (var doc in allRequests.docs) {
        print('FriendsService: Removing request ${doc.id}');
        batch.delete(doc.reference);
        deletedCount++;
      }
      
      if (deletedCount > 0) {
        await batch.commit();
        print('FriendsService: ✅ Aggressively deleted $deletedCount friend requests');
      } else {
        print('FriendsService: No requests to delete');
      }
      
      return true;
    } catch (e) {
      print('FriendsService: ❌ Error during aggressive cleanup: $e');
      return false;
    }
  }

  // Debug function to manually clean up all stale requests for current user
  Future<bool> debugCleanupAllRequests() async {
    if (currentUserId == null) return false;
    
    try {
      print('FriendsService: 🧹 Starting debug cleanup of ALL friend requests for $currentUserId');
      
      final batch = _firestore.batch();
      int deletedCount = 0;
      
      // Get ALL friend requests for current user
      final allRequests = await _firestore
          .collection('users')
          .doc(currentUserId)
          .collection('friendRequests')
          .get();
      
      print('FriendsService: Found ${allRequests.docs.length} total requests to analyze');
      
      for (var doc in allRequests.docs) {
        final data = doc.data();
        final status = data['status'] ?? 'unknown';
        final type = data['type'] ?? 'unknown';
        
        print('FriendsService: Request ${doc.id}: type=$type, status=$status');
        
        // Remove any non-pending requests (these are stale)
        if (status != 'pending') {
          print('FriendsService: Marking stale request for deletion: ${doc.id} (status: $status)');
          batch.delete(doc.reference);
          deletedCount++;
        }
        
        // For pending requests, verify the other user still exists and relationship
        else if (status == 'pending') {
          final otherUserId = type == 'outgoing' ? data['toUserId'] : data['fromUserId'];
          if (otherUserId != null) {
            // Check if they're already friends (shouldn't have pending requests)
            final alreadyFriends = await areFriends(otherUserId);
            if (alreadyFriends) {
              print('FriendsService: Removing stale request - already friends with $otherUserId');
              batch.delete(doc.reference);
              deletedCount++;
            }
          }
        }
      }
      
      if (deletedCount > 0) {
        await batch.commit();
        print('FriendsService: 🧹 Cleanup complete - removed $deletedCount stale requests');
      } else {
        print('FriendsService: 🧹 No cleanup needed - all requests are valid');
      }
      
      return true;
    } catch (e) {
      print('FriendsService: ❌ Debug cleanup failed: $e');
      return false;
    }
  }

  // Get statistics about friends system
  Future<Map<String, dynamic>> getFriendsStats() async {
    if (currentUserId == null) return {};
    
    try {
      final stats = <String, dynamic>{};
      
      // Count friends
      final friendsSnapshot = await _firestore
          .collection('users')
          .doc(currentUserId)
          .collection('friends')
          .get();
      stats['friendsCount'] = friendsSnapshot.docs.length;
      
      // Count incoming requests
      final incomingSnapshot = await _firestore
          .collection('users')
          .doc(currentUserId)
          .collection('friendRequests')
          .where('type', isEqualTo: 'incoming')
          .where('status', isEqualTo: 'pending')
          .get();
      stats['incomingRequestsCount'] = incomingSnapshot.docs.length;
      
      // Count outgoing requests
      final outgoingSnapshot = await _firestore
          .collection('users')
          .doc(currentUserId)
          .collection('friendRequests')
          .where('type', isEqualTo: 'outgoing')
          .where('status', isEqualTo: 'pending')
          .get();
      stats['outgoingRequestsCount'] = outgoingSnapshot.docs.length;
      
      print('FriendsService: Stats - Friends: ${stats['friendsCount']}, '
            'Incoming: ${stats['incomingRequestsCount']}, '
            'Outgoing: ${stats['outgoingRequestsCount']}');
      
      return stats;
    } catch (e) {
      print('FriendsService: Error getting friends stats: $e');
      return {};
    }
  }
}