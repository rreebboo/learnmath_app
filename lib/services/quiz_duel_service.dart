import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'dart:async';
import 'duel_engine.dart';

class QuizDuelService {
  // Lazy initialization to avoid Firebase access before initialization
  DuelEngine? _duelEngineInstance;
  FirebaseFirestore? _firestoreInstance;
  FirebaseDatabase? _realtimeDBInstance;
  FirebaseAuth? _authInstance;

  DuelEngine get duelEngine => _duelEngineInstance ??= DuelEngine();
  FirebaseFirestore get firestore => _firestoreInstance ??= FirebaseFirestore.instance;
  FirebaseDatabase get realtimeDB => _realtimeDBInstance ??= FirebaseDatabase.instance;
  FirebaseAuth get auth => _authInstance ??= FirebaseAuth.instance;

  String? get currentUserId => auth.currentUser?.uid;
  StreamSubscription<DatabaseEvent>? _presenceSubscription;
  StreamSubscription<DatabaseEvent>? _matchmakingSubscription;

  // Simple Quick Match - create game immediately
  Future<String?> quickMatch({
    required String difficulty,
    required String operator,
    required String topicName,
  }) async {
    try {
      if (currentUserId == null) return null;

      print('QuizDuelService: Starting quick match...');

      // First try to find an existing match quickly
      final existingGameId = await duelEngine.findQuickMatch(difficulty, operator, topicName);

      if (existingGameId != null) {
        print('QuizDuelService: Found existing game: $existingGameId');
        // Join the existing game
        final success = await duelEngine.joinDuel(existingGameId);
        if (success) {
          // Don't start automatically - let players go through ready phase
          print('QuizDuelService: Joined game, now in ready phase');
          return existingGameId;
        }
      }

      // No existing game found, create a new waiting game immediately
      print('QuizDuelService: Creating new waiting game...');
      final gameId = await duelEngine.createDuel(
        difficulty: difficulty,
        operator: operator,
        topicName: topicName,
        friendId: null, // null for quick match
      );

      // Set up user presence for better matchmaking
      if (gameId != null) {
        _setupUserPresence();
      }

      return gameId;
    } catch (e) {
      print('QuizDuelService: Error in quick match: $e');
      return null;
    }
  }


  // Challenge a friend
  Future<String?> challengeFriend({
    required String friendId,
    required String difficulty,
    required String operator,
    required String topicName,
  }) async {
    try {
      print('QuizDuelService: Creating friend challenge...');

      final gameId = await duelEngine.createDuel(
        difficulty: difficulty,
        operator: operator,
        topicName: topicName,
        friendId: friendId,
      );

      // Note: Friend needs to accept the challenge before the game starts
      return gameId;
    } catch (e) {
      print('QuizDuelService: Error challenging friend: $e');
      return null;
    }
  }

  // Accept a friend challenge
  Future<bool> acceptChallenge(String gameId) async {
    try {
      print('QuizDuelService: Accepting challenge: $gameId');

      // Join the game and go to ready phase - don't auto-start
      final success = await duelEngine.joinDuel(gameId);
      if (success) {
        print('QuizDuelService: Challenge accepted, now in ready phase');
      }
      return success;
    } catch (e) {
      print('QuizDuelService: Error accepting challenge: $e');
      return false;
    }
  }

  // Mark player as ready
  Future<bool> setPlayerReady(String gameId) async {
    try {
      print('QuizDuelService: Setting player ready for game: $gameId');
      return await duelEngine.setPlayerReady(gameId);
    } catch (e) {
      print('QuizDuelService: Error setting player ready: $e');
      return false;
    }
  }

  // Submit an answer
  Future<bool> submitAnswer({
    required String gameId,
    required int questionIndex,
    required int selectedAnswer,
    required int correctAnswer,
    required double timeSpent,
  }) async {
    return await duelEngine.submitAnswer(
      gameId: gameId,
      questionIndex: questionIndex,
      selectedAnswer: selectedAnswer,
      correctAnswer: correctAnswer,
      timeSpent: timeSpent,
    );
  }

  // Handle question timeout
  Future<void> handleTimeout(String gameId, int questionIndex) async {
    await duelEngine.handleQuestionTimeout(gameId, questionIndex);
  }

  // Get real-time duel updates
  Stream<DocumentSnapshot> getDuelStream(String gameId) {
    return duelEngine.getDuelStream(gameId);
  }

  // Leave a duel with proper cleanup
  Future<void> leaveDuel(String gameId) async {
    await duelEngine.leaveDuel(gameId);
    await _cleanupMatchmaking();
  }

  // Get user's duel statistics
  Future<Map<String, dynamic>?> getDuelStats(String userId) async {
    try {
      final userDoc = await firestore.collection('users').doc(userId).get();
      if (!userDoc.exists) return null;

      final userData = userDoc.data()!;
      return userData['duelStats'] as Map<String, dynamic>? ?? {
        'totalDuels': 0,
        'wins': 0,
        'losses': 0,
        'draws': 0,
        'totalScore': 0,
        'currentWinStreak': 0,
        'bestWinStreak': 0,
      };
    } catch (e) {
      print('QuizDuelService: Error getting duel stats: $e');
      return null;
    }
  }

  // Get duel history for a user
  Future<List<Map<String, dynamic>>> getDuelHistory(String userId, {int limit = 10}) async {
    try {
      final query = await firestore
          .collection('duels')
          .where('state', isEqualTo: 'finished')
          .where('players.player1.userId', isEqualTo: userId)
          .orderBy('finishedAt', descending: true)
          .limit(limit)
          .get();

      final query2 = await firestore
          .collection('duels')
          .where('state', isEqualTo: 'finished')
          .where('players.player2.userId', isEqualTo: userId)
          .orderBy('finishedAt', descending: true)
          .limit(limit)
          .get();

      final allDuels = [...query.docs, ...query2.docs];
      allDuels.sort((a, b) {
        final aTime = a.data()['finishedAt'] as Timestamp?;
        final bTime = b.data()['finishedAt'] as Timestamp?;
        if (aTime == null || bTime == null) return 0;
        return bTime.compareTo(aTime);
      });

      return allDuels.take(limit).map((doc) {
        final data = doc.data();
        return {
          'gameId': doc.id,
          ...data,
        };
      }).toList();
    } catch (e) {
      print('QuizDuelService: Error getting duel history: $e');
      return [];
    }
  }

  // Set up user presence system
  Future<void> _setupUserPresence() async {
    if (currentUserId == null) return;

    try {
      final presenceRef = realtimeDB.ref('presence/$currentUserId');
      final connectedRef = realtimeDB.ref('.info/connected');

      // Set up presence
      _presenceSubscription?.cancel();
      _presenceSubscription = connectedRef.onValue.listen((event) async {
        final isConnected = event.snapshot.value as bool? ?? false;
        if (isConnected) {
          // Set online status
          await presenceRef.set({
            'online': true,
            'lastSeen': ServerValue.timestamp,
          });

          // Set up disconnect handler
          await presenceRef.onDisconnect().set({
            'online': false,
            'lastSeen': ServerValue.timestamp,
          });
        }
      });
    } catch (e) {
      print('QuizDuelService: Error setting up presence: $e');
    }
  }

  // Clean up user from matchmaking when leaving
  Future<void> _cleanupMatchmaking() async {
    if (currentUserId == null) return;

    try {
      // Remove from all matchmaking queues
      final matchmakingRef = realtimeDB.ref('matchmaking');
      final snapshot = await matchmakingRef.get();

      if (snapshot.exists && snapshot.value != null) {
        final matchData = Map<String, dynamic>.from(snapshot.value as Map);

        for (final matchKey in matchData.keys) {
          await matchmakingRef.child('$matchKey/$currentUserId').remove();
        }
      }
    } catch (e) {
      print('QuizDuelService: Error cleaning up matchmaking: $e');
    }
  }

  // Clean up old waiting games
  Future<void> cleanupOldGames() async {
    try {
      final oneHourAgo = DateTime.now().subtract(Duration(hours: 1));

      final oldGames = await firestore
          .collection('duels')
          .where('createdAt', isLessThan: Timestamp.fromDate(oneHourAgo))
          .where('state', isEqualTo: 'waiting')
          .get();

      for (final doc in oldGames.docs) {
        await doc.reference.delete();
      }

      // Also cleanup old matchmaking entries
      await _cleanupOldMatchmakingEntries();
    } catch (e) {
      print('QuizDuelService: Error cleaning up old games: $e');
    }
  }

  // Clean up old matchmaking entries
  Future<void> _cleanupOldMatchmakingEntries() async {
    try {
      final matchmakingRef = realtimeDB.ref('matchmaking');
      final snapshot = await matchmakingRef.get();

      if (snapshot.exists && snapshot.value != null) {
        final matchData = Map<String, dynamic>.from(snapshot.value as Map);
        final now = DateTime.now();

        for (final matchKey in matchData.keys) {
          final matchPlayers = Map<String, dynamic>.from(matchData[matchKey] as Map);

          for (final playerId in matchPlayers.keys) {
            final playerData = Map<String, dynamic>.from(matchPlayers[playerId] as Map);
            final lastActive = DateTime.fromMillisecondsSinceEpoch(playerData['lastActive'] ?? 0);

            // Remove entries older than 2 minutes
            if (now.difference(lastActive).inMinutes > 2) {
              await matchmakingRef.child('$matchKey/$playerId').remove();
            }
          }
        }
      }
    } catch (e) {
      print('QuizDuelService: Error cleaning up matchmaking entries: $e');
    }
  }

  // Dispose resources
  void dispose() {
    _presenceSubscription?.cancel();
    _matchmakingSubscription?.cancel();
    _cleanupMatchmaking();
  }
}