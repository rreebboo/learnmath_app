import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'dart:async';
import 'dart:math';

enum DuelGameState { waiting, ready, active, finished }
enum QuestionState { waiting, active, answered, timeUp }

class DuelEngine {
  // Lazy initialization to avoid Firebase access before initialization
  FirebaseFirestore? _firestoreInstance;
  FirebaseDatabase? _realtimeDBInstance;
  FirebaseAuth? _authInstance;

  FirebaseFirestore get firestore => _firestoreInstance ??= FirebaseFirestore.instance;
  FirebaseDatabase get realtimeDB => _realtimeDBInstance ??= FirebaseDatabase.instance;
  FirebaseAuth get auth => _authInstance ??= FirebaseAuth.instance;

  // Store active game sessions for cleanup
  final Map<String, StreamSubscription> _gameSubscriptions = {};

  String? get currentUserId => auth.currentUser?.uid;

  // Game Configuration
  static const int questionsPerDuel = 10;
  static const int timePerQuestion = 15; // seconds
  static const int pointsPerCorrectAnswer = 10;

  // Create a new duel session with real-time tracking
  Future<String?> createDuel({
    required String difficulty,
    required String operator,
    required String topicName,
    String? friendId, // null for quick match, userId for friend challenge
  }) async {
    try {
      if (currentUserId == null) return null;

      final gameRef = firestore.collection('duels').doc();
      final gameId = gameRef.id;
      final questions = _generateQuestions(difficulty, operator);

      final duelData = {
        'gameId': gameId,
        'state': DuelGameState.waiting.name,
        'difficulty': difficulty,
        'operator': operator,
        'topicName': topicName,
        'isQuickMatch': friendId == null,
        'createdAt': FieldValue.serverTimestamp(),
        'startedAt': null,
        'finishedAt': null,
        'lastActivity': FieldValue.serverTimestamp(),

        // Players - for friend challenges, don't auto-add player2
        'players': {
          'player1': {
            'userId': currentUserId,
            'score': 0,
            'hearts': 5,
            'ready': false,
            'answers': [],
            'currentQuestion': 0,
          },
          'player2': null, // Always start as null - friend must accept first
        },

        // Challenge data (for friend challenges)
        'challengeData': friendId != null ? {
          'challengerId': currentUserId,
          'challengedId': friendId,
          'status': 'pending', // pending, accepted, declined
          'sentAt': FieldValue.serverTimestamp(),
        } : null,

        // Game Data
        'currentQuestionIndex': 0,
        'questions': questions,
        'totalQuestions': questionsPerDuel,
        'questionState': QuestionState.waiting.name,
        'questionStartTime': null,
        'winner': null,
        'isDraw': false,

        // Stats tracking
        'duelHistory': {
          'questionHistory': [],
          'timePerQuestion': [],
          'pointsPerQuestion': [],
        }
      };

      await gameRef.set(duelData);

      // Track active session in Realtime DB
      await _trackActiveSession(gameId);

      return gameId;
    } catch (e) {
      print('DuelEngine: Error creating duel: $e');
      return null;
    }
  }

  // Track active session for real-time cleanup
  Future<void> _trackActiveSession(String gameId) async {
    if (currentUserId == null) return;

    try {
      final sessionRef = realtimeDB.ref('activeSessions/$gameId');
      await sessionRef.set({
        'gameId': gameId,
        'creator': currentUserId,
        'createdAt': ServerValue.timestamp,
        'lastActivity': ServerValue.timestamp,
        'active': true,
      });

      // Set up disconnect cleanup
      await sessionRef.onDisconnect().remove();
    } catch (e) {
      print('DuelEngine: Error tracking session: $e');
    }
  }

  // Join an existing duel (for quick match)
  Future<bool> joinDuel(String gameId) async {
    try {
      if (currentUserId == null) return false;

      // First check if game still exists and is valid
      final gameDoc = await firestore.collection('duels').doc(gameId).get();
      if (!gameDoc.exists) {
        print('DuelEngine: Game $gameId no longer exists');
        return false;
      }

      final gameData = gameDoc.data()!;
      final state = gameData['state'] as String;

      if (state != DuelGameState.waiting.name && state != DuelGameState.ready.name) {
        print('DuelEngine: Game $gameId is not in a joinable state: $state');
        return false;
      }

      await firestore.collection('duels').doc(gameId).update({
        'players.player2': {
          'userId': currentUserId,
          'score': 0,
          'hearts': 5,
          'ready': false,
          'answers': [],
          'currentQuestion': 0,
        },
        'state': DuelGameState.ready.name,
        'lastActivity': FieldValue.serverTimestamp(),
      });

      // Update session tracking
      await _updateSessionActivity(gameId);

      return true;
    } catch (e) {
      print('DuelEngine: Error joining duel: $e');
      return false;
    }
  }

  // Accept a friend challenge
  Future<bool> acceptFriendChallenge(String gameId) async {
    try {
      if (currentUserId == null) return false;

      print('DuelEngine: Accepting friend challenge $gameId');

      // First check if game still exists and is valid
      final gameDoc = await firestore.collection('duels').doc(gameId).get();
      if (!gameDoc.exists) {
        print('DuelEngine: Challenge $gameId no longer exists');
        return false;
      }

      final gameData = gameDoc.data()!;
      final challengeData = gameData['challengeData'] as Map<String, dynamic>?;

      if (challengeData == null) {
        print('DuelEngine: Not a friend challenge');
        return false;
      }

      if (challengeData['challengedId'] != currentUserId) {
        print('DuelEngine: Challenge not for current user');
        return false;
      }

      if (challengeData['status'] != 'pending') {
        print('DuelEngine: Challenge is not pending: ${challengeData['status']}');
        return false;
      }

      // Accept the challenge by adding player2 and updating status
      await firestore.collection('duels').doc(gameId).update({
        'players.player2': {
          'userId': currentUserId,
          'score': 0,
          'hearts': 5,
          'ready': false,
          'answers': [],
          'currentQuestion': 0,
        },
        'challengeData.status': 'accepted',
        'challengeData.acceptedAt': FieldValue.serverTimestamp(),
        'state': DuelGameState.ready.name,
        'lastActivity': FieldValue.serverTimestamp(),
      });

      // Update session tracking
      await _updateSessionActivity(gameId);

      print('DuelEngine: Challenge accepted successfully');
      return true;
    } catch (e) {
      print('DuelEngine: Error accepting challenge: $e');
      return false;
    }
  }

  // Decline a friend challenge
  Future<bool> declineFriendChallenge(String gameId) async {
    try {
      if (currentUserId == null) return false;

      print('DuelEngine: Declining friend challenge $gameId');

      // First check if game still exists and is valid
      final gameDoc = await firestore.collection('duels').doc(gameId).get();
      if (!gameDoc.exists) {
        print('DuelEngine: Challenge $gameId no longer exists');
        return false;
      }

      final gameData = gameDoc.data()!;
      final challengeData = gameData['challengeData'] as Map<String, dynamic>?;

      if (challengeData == null || challengeData['challengedId'] != currentUserId) {
        print('DuelEngine: Invalid challenge or not for current user');
        return false;
      }

      // Mark challenge as declined and delete the game
      await firestore.collection('duels').doc(gameId).update({
        'challengeData.status': 'declined',
        'challengeData.declinedAt': FieldValue.serverTimestamp(),
        'state': 'declined',
      });

      print('DuelEngine: Challenge declined successfully');
      return true;
    } catch (e) {
      print('DuelEngine: Error declining challenge: $e');
      return false;
    }
  }

  // Update session activity
  Future<void> _updateSessionActivity(String gameId) async {
    try {
      final sessionRef = realtimeDB.ref('activeSessions/$gameId');
      await sessionRef.update({
        'lastActivity': ServerValue.timestamp,
      });
    } catch (e) {
      print('DuelEngine: Error updating session activity: $e');
    }
  }

  // Mark player as ready
  Future<bool> setPlayerReady(String gameId) async {
    try {
      if (currentUserId == null) return false;

      // Get current game data
      final gameDoc = await firestore.collection('duels').doc(gameId).get();
      if (!gameDoc.exists) {
        print('DuelEngine: Game $gameId does not exist');
        return false;
      }

      final gameData = gameDoc.data()!;
      final players = gameData['players'] as Map<String, dynamic>;

      // Determine which player we are
      final isPlayer1 = players['player1']['userId'] == currentUserId;
      final playerKey = isPlayer1 ? 'player1' : 'player2';

      print('DuelEngine: Marking $playerKey as ready in game $gameId');

      // Update player ready status
      await firestore.collection('duels').doc(gameId).update({
        'players.$playerKey.ready': true,
        'lastActivity': FieldValue.serverTimestamp(),
      });

      // Check if both players are now ready
      final player1Ready = isPlayer1 ? true : (players['player1']['ready'] ?? false);
      final player2Ready = isPlayer1 ? (players['player2']['ready'] ?? false) : true;

      if (player1Ready && player2Ready) {
        print('DuelEngine: Both players ready, starting duel automatically');
        await _startDuelInternal(gameId);
      }

      return true;
    } catch (e) {
      print('DuelEngine: Error setting player ready: $e');
      return false;
    }
  }

  // Start the duel when both players are ready
  Future<bool> startDuel(String gameId) async {
    return await _startDuelInternal(gameId);
  }

  // Internal start duel method
  Future<bool> _startDuelInternal(String gameId) async {
    try {
      // Verify game still exists and is in correct state
      final gameDoc = await firestore.collection('duels').doc(gameId).get();
      if (!gameDoc.exists) {
        print('DuelEngine: Cannot start - game $gameId no longer exists');
        return false;
      }

      final gameData = gameDoc.data()!;
      final state = gameData['state'] as String;

      if (state != DuelGameState.ready.name) {
        print('DuelEngine: Cannot start - game $gameId is not ready: $state');
        return false;
      }

      await firestore.collection('duels').doc(gameId).update({
        'state': DuelGameState.active.name,
        'startedAt': FieldValue.serverTimestamp(),
        'currentQuestionIndex': 0,
        'questionState': QuestionState.active.name,
        'questionStartTime': FieldValue.serverTimestamp(),
        'lastActivity': FieldValue.serverTimestamp(),
      });

      // Update session tracking
      await _updateSessionActivity(gameId);

      return true;
    } catch (e) {
      print('DuelEngine: Error starting duel: $e');
      return false;
    }
  }


  // Submit an answer for the current question
  Future<bool> submitAnswer({
    required String gameId,
    required int questionIndex,
    required int selectedAnswer,
    required int correctAnswer,
    required double timeSpent,
  }) async {
    try {
      if (currentUserId == null) return false;

      final isCorrect = selectedAnswer == correctAnswer;
      final points = isCorrect ? pointsPerCorrectAnswer : 0;

      final answerData = {
        'questionIndex': questionIndex,
        'selectedAnswer': selectedAnswer,
        'correctAnswer': correctAnswer,
        'isCorrect': isCorrect,
        'points': points,
        'timeSpent': timeSpent,
      };

      // Determine which player we are
      final duelDoc = await firestore.collection('duels').doc(gameId).get();
      if (!duelDoc.exists) return false;

      final duelData = duelDoc.data()!;
      final players = duelData['players'] as Map<String, dynamic>;
      final isPlayer1 = players['player1']['userId'] == currentUserId;
      final playerKey = isPlayer1 ? 'player1' : 'player2';

      // Update player's answer, score, and hearts (if wrong answer)
      Map<String, dynamic> updateData = {
        'players.$playerKey.answers': FieldValue.arrayUnion([answerData]),
        'players.$playerKey.score': FieldValue.increment(points),
      };

      // Deduct a heart if answer is wrong
      if (!isCorrect) {
        final currentPlayer = players[playerKey] as Map<String, dynamic>;
        final currentHearts = currentPlayer['hearts'] ?? 5;
        if (currentHearts > 0) {
          updateData['players.$playerKey.hearts'] = currentHearts - 1;
        }
      }

      await firestore.collection('duels').doc(gameId).update(updateData);

      // Check if both players have answered
      await _checkQuestionCompletion(gameId, questionIndex);

      return true;
    } catch (e) {
      print('DuelEngine: Error submitting answer: $e');
      return false;
    }
  }

  // Check if both players have answered the current question
  Future<void> _checkQuestionCompletion(String gameId, int questionIndex) async {
    try {
      final duelDoc = await firestore.collection('duels').doc(gameId).get();
      if (!duelDoc.exists) return;

      final duelData = duelDoc.data()!;
      final players = duelData['players'] as Map<String, dynamic>;

      // Check for game over conditions (hearts reached 0)
      final player1Hearts = players['player1']['hearts'] ?? 5;
      final player2Hearts = players['player2']['hearts'] ?? 5;

      if (player1Hearts <= 0 || player2Hearts <= 0) {
        // Game over due to hearts
        await _finishDuel(gameId);
        return;
      }

      final player1Answers = List.from(players['player1']['answers'] ?? []);
      final player2Answers = List.from(players['player2']['answers'] ?? []);

      // Check if both players have answered this question
      final player1HasAnswered = player1Answers.any((answer) => answer['questionIndex'] == questionIndex);
      final player2HasAnswered = player2Answers.any((answer) => answer['questionIndex'] == questionIndex);

      if (player1HasAnswered && player2HasAnswered) {
        await _moveToNextQuestion(gameId, questionIndex);
      }
    } catch (e) {
      print('DuelEngine: Error checking question completion: $e');
    }
  }

  // Move to the next question or end the duel
  Future<void> _moveToNextQuestion(String gameId, int currentQuestionIndex) async {
    try {
      final nextQuestionIndex = currentQuestionIndex + 1;

      if (nextQuestionIndex >= questionsPerDuel) {
        // Duel is finished
        await _finishDuel(gameId);
      } else {
        // Move to next question
        await firestore.collection('duels').doc(gameId).update({
          'currentQuestionIndex': nextQuestionIndex,
          'questionState': QuestionState.active.name,
          'questionStartTime': FieldValue.serverTimestamp(),
        });
      }
    } catch (e) {
      print('DuelEngine: Error moving to next question: $e');
    }
  }

  // Finish the duel and determine winner with cleanup
  Future<void> _finishDuel(String gameId) async {
    try {
      final duelDoc = await firestore.collection('duels').doc(gameId).get();
      if (!duelDoc.exists) return;

      final duelData = duelDoc.data()!;
      final players = duelData['players'] as Map<String, dynamic>;

      final player1Score = players['player1']['score'] as int;
      final player2Score = players['player2']['score'] as int;
      final player1Hearts = players['player1']['hearts'] ?? 5;
      final player2Hearts = players['player2']['hearts'] ?? 5;

      String? winner;
      bool isDraw = false;

      // Check if game ended due to hearts reaching 0
      if (player1Hearts <= 0 && player2Hearts <= 0) {
        isDraw = true;
      } else if (player1Hearts <= 0) {
        winner = players['player2']['userId'];
      } else if (player2Hearts <= 0) {
        winner = players['player1']['userId'];
      } else {
        // Game ended normally, determine winner by score
        if (player1Score > player2Score) {
          winner = players['player1']['userId'];
        } else if (player2Score > player1Score) {
          winner = players['player2']['userId'];
        } else {
          isDraw = true;
        }
      }

      await firestore.collection('duels').doc(gameId).update({
        'state': DuelGameState.finished.name,
        'finishedAt': FieldValue.serverTimestamp(),
        'lastActivity': FieldValue.serverTimestamp(),
        'winner': winner,
        'isDraw': isDraw,
        'questionState': QuestionState.answered.name,
      });

      // Update player statistics
      await _updatePlayerStats(
        players['player1']['userId'],
        players['player2']['userId'],
        player1Score,
        player2Score,
        winner,
        isDraw,
      );

      // Clean up all resources for this game
      await _cleanupSession(gameId);
    } catch (e) {
      print('DuelEngine: Error finishing duel: $e');
      // Always cleanup even on error
      await _cleanupSession(gameId);
    }
  }

  // Update player statistics after duel completion
  Future<void> _updatePlayerStats(
    String player1Id,
    String player2Id,
    int player1Score,
    int player2Score,
    String? winner,
    bool isDraw,
  ) async {
    try {
      // Update Player 1 stats
      final player1Updates = {
        'duelStats.totalDuels': FieldValue.increment(1),
        'duelStats.totalScore': FieldValue.increment(player1Score),
      };

      if (winner == player1Id) {
        player1Updates['duelStats.wins'] = FieldValue.increment(1);
        player1Updates['duelStats.currentWinStreak'] = FieldValue.increment(1);
      } else if (isDraw) {
        player1Updates['duelStats.draws'] = FieldValue.increment(1);
      } else {
        player1Updates['duelStats.losses'] = FieldValue.increment(1);
      }

      // Reset win streak if not winning
      if (winner != player1Id) {
        await firestore.collection('users').doc(player1Id).update({'duelStats.currentWinStreak': 0});
      }

      await firestore.collection('users').doc(player1Id).update(player1Updates);

      // Update Player 2 stats
      final player2Updates = {
        'duelStats.totalDuels': FieldValue.increment(1),
        'duelStats.totalScore': FieldValue.increment(player2Score),
      };

      if (winner == player2Id) {
        player2Updates['duelStats.wins'] = FieldValue.increment(1);
        player2Updates['duelStats.currentWinStreak'] = FieldValue.increment(1);
      } else if (isDraw) {
        player2Updates['duelStats.draws'] = FieldValue.increment(1);
      } else {
        player2Updates['duelStats.losses'] = FieldValue.increment(1);
      }

      // Reset win streak if not winning
      if (winner != player2Id) {
        await firestore.collection('users').doc(player2Id).update({'duelStats.currentWinStreak': 0});
      }

      await firestore.collection('users').doc(player2Id).update(player2Updates);
    } catch (e) {
      print('DuelEngine: Error updating player stats: $e');
    }
  }

  // Handle question timeout
  Future<void> handleQuestionTimeout(String gameId, int questionIndex) async {
    try {
      if (currentUserId == null) return;

      // Submit a timeout answer (wrong answer with max time)
      await submitAnswer(
        gameId: gameId,
        questionIndex: questionIndex,
        selectedAnswer: -1, // Special value for timeout
        correctAnswer: 0, // Will result in 0 points
        timeSpent: timePerQuestion.toDouble(),
      );
    } catch (e) {
      print('DuelEngine: Error handling timeout: $e');
    }
  }

  // Get duel stream for real-time updates
  Stream<DocumentSnapshot> getDuelStream(String gameId) {
    return firestore.collection('duels').doc(gameId).snapshots();
  }

  // Find available quick match
  Future<String?> findQuickMatch(String difficulty, String operator, String topicName) async {
    try {
      print('DuelEngine: Looking for quick match - $difficulty, $operator, $topicName');

      final query = await firestore
          .collection('duels')
          .where('state', isEqualTo: DuelGameState.waiting.name)
          .where('isQuickMatch', isEqualTo: true)
          .where('difficulty', isEqualTo: difficulty)
          .where('operator', isEqualTo: operator)
          .where('topicName', isEqualTo: topicName)
          .limit(10) // Get more results to check
          .get();

      print('DuelEngine: Found ${query.docs.length} waiting games');

      for (final gameDoc in query.docs) {
        final gameData = gameDoc.data();
        final players = gameData['players'] as Map<String, dynamic>;

        print('DuelEngine: Checking game ${gameDoc.id}');
        print('DuelEngine: Player1: ${players['player1']['userId']}, Player2: ${players['player2']}');
        print('DuelEngine: Current user: $currentUserId');

        // Make sure it's not our own game and player2 slot is empty
        // Also check that the game isn't too old (avoid stale games)
        if (players['player1']['userId'] != currentUserId &&
            players['player2'] == null) {

          // Check game age - only join games less than 2 minutes old
          final createdAt = gameData['createdAt'] as Timestamp?;
          if (createdAt != null) {
            final gameAge = DateTime.now().difference(createdAt.toDate());
            if (gameAge.inMinutes > 2) {
              print('DuelEngine: Game ${gameDoc.id} is too old (${gameAge.inMinutes} minutes), skipping');
              continue;
            }
          }

          print('DuelEngine: Found suitable game: ${gameDoc.id}');
          return gameDoc.id;
        }
      }

      print('DuelEngine: No suitable games found');
      return null;
    } catch (e) {
      print('DuelEngine: Error finding quick match: $e');
      return null;
    }
  }

  // Generate questions for the duel
  List<Map<String, dynamic>> _generateQuestions(String difficulty, String operator) {
    final Random random = Random();
    final List<Map<String, dynamic>> questions = [];

    for (int i = 0; i < questionsPerDuel; i++) {
      final question = _generateSingleQuestion(difficulty, operator, random);
      questions.add(question);
    }

    return questions;
  }

  Map<String, dynamic> _generateSingleQuestion(String difficulty, String operator, Random random) {
    int operand1, operand2, correctAnswer;

    switch (operator) {
      case '+':
        switch (difficulty.toLowerCase()) {
          case 'easy':
            operand1 = random.nextInt(10) + 1;
            operand2 = random.nextInt(10) + 1;
            break;
          case 'medium':
            operand1 = random.nextInt(90) + 10;
            operand2 = random.nextInt(90) + 10;
            break;
          case 'hard':
            operand1 = random.nextInt(900) + 100;
            operand2 = random.nextInt(900) + 100;
            break;
          default:
            operand1 = random.nextInt(10) + 1;
            operand2 = random.nextInt(10) + 1;
        }
        correctAnswer = operand1 + operand2;
        break;

      case '-':
        switch (difficulty.toLowerCase()) {
          case 'easy':
            operand1 = random.nextInt(15) + 6;
            operand2 = random.nextInt(operand1 - 1) + 1;
            break;
          case 'medium':
            operand1 = random.nextInt(90) + 50;
            operand2 = random.nextInt(operand1 - 10) + 10;
            break;
          case 'hard':
            operand1 = random.nextInt(900) + 200;
            operand2 = random.nextInt(operand1 - 50) + 50;
            break;
          default:
            operand1 = random.nextInt(15) + 6;
            operand2 = random.nextInt(operand1 - 1) + 1;
        }
        correctAnswer = operand1 - operand2;
        break;

      case '×':
        switch (difficulty.toLowerCase()) {
          case 'easy':
            operand1 = random.nextInt(5) + 1;
            operand2 = random.nextInt(5) + 1;
            break;
          case 'medium':
            operand1 = random.nextInt(12) + 1;
            operand2 = random.nextInt(12) + 1;
            break;
          case 'hard':
            operand1 = random.nextInt(25) + 1;
            operand2 = random.nextInt(25) + 1;
            break;
          default:
            operand1 = random.nextInt(5) + 1;
            operand2 = random.nextInt(5) + 1;
        }
        correctAnswer = operand1 * operand2;
        break;

      case '÷':
        switch (difficulty.toLowerCase()) {
          case 'easy':
            operand2 = random.nextInt(5) + 2;
            correctAnswer = random.nextInt(5) + 1;
            break;
          case 'medium':
            operand2 = random.nextInt(10) + 2;
            correctAnswer = random.nextInt(12) + 1;
            break;
          case 'hard':
            operand2 = random.nextInt(23) + 2;
            correctAnswer = random.nextInt(25) + 1;
            break;
          default:
            operand2 = random.nextInt(5) + 2;
            correctAnswer = random.nextInt(5) + 1;
        }
        operand1 = operand2 * correctAnswer;
        break;

      default:
        operand1 = random.nextInt(10) + 1;
        operand2 = random.nextInt(10) + 1;
        correctAnswer = operand1 + operand2;
    }

    // Generate wrong answer options
    Set<int> options = {correctAnswer};
    while (options.length < 4) {
      int wrongAnswer;
      if (correctAnswer <= 10) {
        wrongAnswer = random.nextInt(20) + 1;
      } else {
        wrongAnswer = correctAnswer + (random.nextInt(21) - 10);
      }
      if (wrongAnswer > 0) {
        options.add(wrongAnswer);
      }
    }

    final shuffledOptions = options.toList()..shuffle();

    return {
      'operand1': operand1,
      'operand2': operand2,
      'operator': operator,
      'correctAnswer': correctAnswer,
      'options': shuffledOptions,
    };
  }

  // Leave/cancel a duel with proper cleanup
  Future<void> leaveDuel(String gameId) async {
    try {
      if (currentUserId == null) return;

      final duelDoc = await firestore.collection('duels').doc(gameId).get();
      if (!duelDoc.exists) {
        // Clean up session tracking even if game doesn't exist
        await _cleanupSession(gameId);
        return;
      }

      final duelData = duelDoc.data()!;
      final state = duelData['state'] as String;
      final players = duelData['players'] as Map<String, dynamic>;

      if (state == DuelGameState.waiting.name || state == DuelGameState.ready.name) {
        // Handle leaving before game starts
        if (players['player1']['userId'] == currentUserId && players['player2'] == null) {
          // Delete the game entirely
          await firestore.collection('duels').doc(gameId).delete();
        } else if (players['player2']?['userId'] == currentUserId) {
          // Remove player2
          await firestore.collection('duels').doc(gameId).update({
            'players.player2': null,
            'state': DuelGameState.waiting.name,
            'lastActivity': FieldValue.serverTimestamp(),
          });
        } else if (players['player1']['userId'] == currentUserId && players['player2'] != null) {
          // Player1 leaving, transfer to player2 or delete
          await firestore.collection('duels').doc(gameId).delete();
        }
      } else if (state == DuelGameState.active.name) {
        // Handle leaving during active game - forfeit
        final winnerId = players['player1']['userId'] == currentUserId
            ? players['player2']['userId']
            : players['player1']['userId'];

        print('DuelEngine: Player $currentUserId forfeiting active game. Winner: $winnerId');

        await firestore.collection('duels').doc(gameId).update({
          'state': DuelGameState.finished.name,
          'finishedAt': FieldValue.serverTimestamp(),
          'winner': winnerId,
          'isDraw': false,
          'forfeit': true,
          'forfeitBy': currentUserId,
          'lastActivity': FieldValue.serverTimestamp(),
        });

        print('DuelEngine: Forfeit successfully recorded in Firestore');
      }

      // Clean up all resources
      await _cleanupSession(gameId);

    } catch (e) {
      print('DuelEngine: Error leaving duel: $e');
      // Always try to cleanup even if there's an error
      await _cleanupSession(gameId);
    }
  }

  // Clean up session tracking
  Future<void> _cleanupSession(String gameId) async {
    try {
      // Remove from active sessions
      final sessionRef = realtimeDB.ref('activeSessions/$gameId');
      await sessionRef.remove();

      // Cancel any subscriptions
      _gameSubscriptions[gameId]?.cancel();
      _gameSubscriptions.remove(gameId);
    } catch (e) {
      print('DuelEngine: Error cleaning up session: $e');
    }
  }

  // Enhanced cleanup method
  void dispose() {
    // Cancel all game subscriptions
    for (final subscription in _gameSubscriptions.values) {
      subscription.cancel();
    }
    _gameSubscriptions.clear();

    print('DuelEngine: All subscriptions cleaned up');
  }
}