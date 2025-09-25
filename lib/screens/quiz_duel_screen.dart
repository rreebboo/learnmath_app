import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter/foundation.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'dart:async';
import '../services/quiz_duel_service.dart';
import '../services/firestore_service.dart';
import '../services/game_sound_service.dart';
import '../widgets/particle_effects.dart';
import '../widgets/user_avatar.dart';

class QuizDuelScreen extends StatefulWidget {
  final String topicName;
  final String operator;
  final String difficulty;

  const QuizDuelScreen({
    super.key,
    required this.topicName,
    required this.operator,
    required this.difficulty,
  });

  @override
  State<QuizDuelScreen> createState() => _QuizDuelScreenState();
}

class _QuizDuelScreenState extends State<QuizDuelScreen> with TickerProviderStateMixin {
  final QuizDuelService _duelService = QuizDuelService();
  final FirestoreService _firestoreService = FirestoreService();
  final GameSoundService _soundService = GameSoundService();

  // Animation Controllers
  late AnimationController _pulseController;
  late AnimationController _battleController;
  late AnimationController _celebrationController;
  late AnimationController _damageController;
  late AnimationController _scoreController;
  late AnimationController _timerController;
  late AnimationController _lightningController;
  late AnimationController _powerUpController;
  late AnimationController _shakeController;

  String? _gameId;
  StreamSubscription<DocumentSnapshot>? _gameSubscription;
  Map<String, dynamic>? _duelData;
  Map<String, dynamic>? _currentUserData;
  Map<String, dynamic>? _opponentData;

  // Game State
  bool _isWaitingForOpponent = true;
  bool _gameStarted = false;
  bool _isReadyPhase = false;
  bool _currentUserReady = false;
  bool _opponentReady = false;
  bool _isSettingReady = false;
  int _currentQuestionIndex = 0;
  int? _selectedAnswer;
  bool _hasAnswered = false;
  Timer? _questionTimer;
  Timer? _matchmakingTimer;
  int _timeRemaining = 15;
  int _waitingTime = 0;

  // User info
  Map<String, dynamic>? _currentUser;
  Map<String, dynamic>? _opponent;

  // Game Effects State
  bool _showCorrectEffect = false;
  bool _isMatchmakingInProgress = false;
  bool _showFloatingScore = false;
  int _floatingScoreValue = 0;

  @override
  void initState() {
    super.initState();
    _initializeAnimations();
    _initializeGameServices();
    _loadUserData();
    _startQuickMatch();
  }

  Future<void> _initializeGameServices() async {
    await _soundService.initialize();
  }

  void _initializeAnimations() {
    _pulseController = AnimationController(
      duration: const Duration(milliseconds: 1000),
      vsync: this,
    )..repeat(reverse: true);

    _battleController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );

    _celebrationController = AnimationController(
      duration: const Duration(milliseconds: 1500),
      vsync: this,
    );

    _damageController = AnimationController(
      duration: const Duration(milliseconds: 600),
      vsync: this,
    );

    _scoreController = AnimationController(
      duration: const Duration(milliseconds: 1200),
      vsync: this,
    );

    _timerController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );

    _lightningController = AnimationController(
      duration: const Duration(milliseconds: 400),
      vsync: this,
    );

    _powerUpController = AnimationController(
      duration: const Duration(milliseconds: 1000),
      vsync: this,
    );

    _shakeController = AnimationController(
      duration: const Duration(milliseconds: 500),
      vsync: this,
    );
  }

  void _triggerEpicBattleEffects(bool isCorrect) {
    if (isCorrect) {
      _soundService.playCorrectAnswer();
      _soundService.playScoreIncrease();

      // Show floating score animation
      final scoreGained = _timeRemaining >= 10 ? 150 : _timeRemaining >= 5 ? 100 : 50;
      setState(() {
        _showCorrectEffect = true;
        _showFloatingScore = true;
        _floatingScoreValue = scoreGained;
      });

      // Trigger multiple celebration animations
      _battleController.forward().then((_) => _battleController.reset());
      _celebrationController.forward().then((_) => _celebrationController.reset());
      _powerUpController.forward().then((_) => _powerUpController.reset());
      _lightningController.forward().then((_) => _lightningController.reset());

      // Reset floating score after animation
      Future.delayed(const Duration(milliseconds: 1500), () {
        if (mounted) {
          setState(() {
            _showFloatingScore = false;
          });
        }
      });

      Future.delayed(const Duration(milliseconds: 2500), () {
        if (mounted) {
          setState(() {
            _showCorrectEffect = false;
          });
        }
      });
    } else {
      _soundService.playWrongAnswer();
      _soundService.playHeartLoss();
      _damageController.forward().then((_) => _damageController.reset());
      _shakeController.forward().then((_) => _shakeController.reset());
    }
  }

  Future<void> _startQuickMatch() async {
    if (_isMatchmakingInProgress) {
      return; // Prevent multiple simultaneous matchmaking attempts
    }

    _isMatchmakingInProgress = true;

    try {
      // Set the UI state immediately to show waiting screen
      setState(() {
        _isWaitingForOpponent = true;
        _gameStarted = false;
      });

      final gameId = await _duelService.quickMatch(
        topicName: widget.topicName,
        operator: widget.operator,
        difficulty: widget.difficulty,
      );

      if (gameId != null) {
        setState(() {
          _gameId = gameId;
        });

        _subscribeToGameUpdates(gameId);
        _startMatchmakingTimer();
      } else {
        // If no game created, show error or retry
        if (kDebugMode) {
          print('Failed to create game');
        }
      }
    } catch (e) {
      if (kDebugMode) {
        print('Error starting quick match: $e');
      }
    } finally {
      _isMatchmakingInProgress = false;
    }
  }

  void _subscribeToGameUpdates(String gameId) {
    // Cancel existing subscription first to prevent leaks
    _gameSubscription?.cancel();

    if (kDebugMode) {
      print('Subscribing to game updates for: $gameId');
    }

    _gameSubscription = _duelService.getDuelStream(gameId).listen(
      (snapshot) {
        if (kDebugMode) {
          print('Game update received - exists: ${snapshot.exists}');
        }

        if (mounted && snapshot.exists) {
          final data = snapshot.data() as Map<String, dynamic>?;
          if (kDebugMode) {
            print('Game data received: ${data != null ? data['state'] : 'NULL'}');
          }

          setState(() {
            _duelData = data;
            _updateGameState();
          });
        } else if (mounted && !snapshot.exists) {
          if (kDebugMode) {
            print('WARNING: Game document does not exist!');
          }
          // Handle case where game document was deleted - go back to main screen
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted && Navigator.canPop(context)) {
              Navigator.of(context).pop();
            }
          });
        }
      },
      onError: (error) {
        if (kDebugMode) {
          print('Stream error: $error');
        }
        // Handle error by trying to recreate the match
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) {
            _startQuickMatch();
          }
        });
      },
    );
  }

  void _updateGameState() {
    if (_duelData == null || !mounted) return;

    try {
      // Validate data structure before using
      if (!_duelData!.containsKey('state') || !_duelData!.containsKey('players')) {
        if (kDebugMode) {
          print('Invalid game data structure');
        }
        return;
      }

      final state = _duelData!['state'] as String;
      final players = _duelData!['players'] as Map<String, dynamic>;
      final currentUserId = _duelService.currentUserId;

      // Determine which player is current user
      final player1 = players['player1'] as Map<String, dynamic>?;
      final player2 = players['player2'] as Map<String, dynamic>?;

      if (player1?['userId'] == currentUserId) {
        _currentUserData = player1;
        _opponentData = player2;
      } else if (player2?['userId'] == currentUserId) {
        _currentUserData = player2;
        _opponentData = player1;
      }

      // Update UI data for opponent
      if (_opponentData != null) {
        final opponentUserId = _opponentData!['userId'] as String;
        // Load opponent user data
        _loadOpponentData(opponentUserId);
      }

      // Update ready states
      _currentUserReady = _currentUserData?['ready'] ?? false;
      _opponentReady = _opponentData?['ready'] ?? false;

      // Update current question index with sync check
      final newQuestionIndex = _duelData!['currentQuestionIndex'] ?? 0;

      // Update game state variables

      // Check if question index changed - reset local state if needed
      if (newQuestionIndex != _currentQuestionIndex) {
        _hasAnswered = false;
        _selectedAnswer = null;
        _questionTimer?.cancel();
        _currentQuestionIndex = newQuestionIndex;
      }

    switch (state) {
      case 'waiting':
        _isWaitingForOpponent = true;
        _gameStarted = false;
        _isReadyPhase = false;
        break;
      case 'ready':
        _isWaitingForOpponent = true; // Keep waiting state true for unified screen
        _gameStarted = false;
        _isReadyPhase = true;
        _matchmakingTimer?.cancel();

        if (kDebugMode) {
          print('Ready phase: Current user ready: $_currentUserReady, Opponent ready: $_opponentReady');
        }
        break;
      case 'active':
        _isWaitingForOpponent = false;
        _gameStarted = true;
        _isReadyPhase = false;
        _matchmakingTimer?.cancel();

        // Game is now active, starting question timer
        _startQuestionTimer();
        break;
      case 'finished':
        _questionTimer?.cancel();
        _showGameEndDialog();
        break;
      }

      // CRITICAL FIX: Call setState to rebuild the UI after state changes
      if (mounted) {
        setState(() {
          // State variables have been updated above
        });
      }
    } catch (e) {
      if (kDebugMode) {
        print('Error updating game state: $e');
      }
      // Handle gracefully - show error state or restart
    }
  }

  void _startQuestionTimer() {
    // Always cancel existing timer first to prevent multiple timers
    _questionTimer?.cancel();
    _questionTimer = null;

    if (_duelData == null || !mounted) return;

    final questionState = _duelData!['questionState'] as String?;
    final gameCurrentIndex = _duelData!['currentQuestionIndex'] as int;

    if (kDebugMode) {
      print('Starting question timer - State: $questionState, Game Index: $gameCurrentIndex, Local Index: $_currentQuestionIndex, HasAnswered: $_hasAnswered');
    }

    // Start timer if the question is active and we haven't answered yet
    if (questionState == 'active' && !_hasAnswered) {
      // Update our local question index if needed
      if (gameCurrentIndex != _currentQuestionIndex) {
        _currentQuestionIndex = gameCurrentIndex;
      }

      setState(() {
        _timeRemaining = 15;
        _hasAnswered = false;
        _selectedAnswer = null;
      });

      if (kDebugMode) {
        print('Question timer started for question $_currentQuestionIndex');
      }

      _questionTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
        if (!mounted) {
          timer.cancel();
          return;
        }

        setState(() {
          _timeRemaining--;
          if (_timeRemaining == 5) {
            _soundService.playTimeWarning();
            _timerController.forward().then((_) => _timerController.reset());
          }
        });

        // Timer countdown in progress

        if (_timeRemaining <= 0) {
          timer.cancel();
          _handleTimeout();
        }
      });
    }
  }

  void _startMatchmakingTimer() {
    // Cancel existing timer if any
    _matchmakingTimer?.cancel();

    // Reset waiting time
    _waitingTime = 0;

    _matchmakingTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }

      setState(() {
        _waitingTime++;
      });

      // Continue waiting - no AI fallback
      // Real players only
    });
  }

  Future<void> _loadOpponentData(String opponentUserId) async {
    try {
      final userData = await _firestoreService.getUserData(opponentUserId);
      if (mounted && userData != null) {
        setState(() {
          _opponent = {
            'userId': opponentUserId,
            'name': userData['name'] ?? 'Opponent',
            'avatar': userData['avatar'] ?? '🚀',
          };
        });
      }
    } catch (e) {
      if (kDebugMode) {
        print('Error loading opponent data: $e');
      }
      // Fallback opponent data
      setState(() {
        _opponent = {
          'userId': opponentUserId,
          'name': 'Opponent',
          'avatar': '🚀',
        };
      });
    }
  }



  Future<void> _loadUserData() async {
    try {
      final userData = await _firestoreService.getCurrentUserData();
      if (mounted && userData != null) {
        setState(() {
          _currentUser = userData;
        });
      }
    } catch (e) {
      if (kDebugMode) {
        print('Error loading user data: $e');
      }
    }
  }

  void _selectAnswer(int answer) {
    if (_hasAnswered || _duelData == null) return;

    setState(() {
      _hasAnswered = true;
      _selectedAnswer = answer;
    });

    _questionTimer?.cancel();

    final questions = _duelData!['questions'] as List<dynamic>;
    final currentQuestion = questions[_currentQuestionIndex] as Map<String, dynamic>;
    final correctAnswer = currentQuestion['correctAnswer'] as int;
    final isCorrect = answer == correctAnswer;
    final timeSpent = 15.0 - _timeRemaining;

    _triggerEpicBattleEffects(isCorrect);

    _duelService.submitAnswer(
      gameId: _gameId!,
      questionIndex: _currentQuestionIndex,
      selectedAnswer: answer,
      correctAnswer: correctAnswer,
      timeSpent: timeSpent,
    );
  }

  void _handleTimeout() {
    if (_hasAnswered || _duelData == null) return;

    setState(() {
      _hasAnswered = true;
      _selectedAnswer = -1;
    });

    _triggerEpicBattleEffects(false);
    _duelService.handleTimeout(_gameId!, _currentQuestionIndex);
  }

  void _showGameEndDialog() {
    if (_duelData == null || !mounted) return;

    // Check if we can actually show a dialog
    if (!Navigator.canPop(context)) {
      if (kDebugMode) {
        print('Cannot show game end dialog - navigation stack is empty');
      }
      return;
    }

    final winner = _duelData!['winner'];
    final isDraw = _duelData!['isDraw'] ?? false;
    final currentUserId = _duelService.currentUserId;
    final currentUserScore = _currentUserData?['score'] ?? 0;
    final opponentScore = _opponentData?['score'] ?? 0;
    final isWinner = winner == currentUserId;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => PopScope(
        canPop: false, // Prevent back button during dialog
        child: _buildGameEndDialog(isWinner, isDraw, currentUserScore, opponentScore),
      ),
    );
  }

  void _showQuitConfirmation() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Leave Battle?'),
        content: Text(_gameStarted
            ? 'Leaving now will count as a forfeit. Are you sure?'
            : 'Are you sure you want to leave this math duel?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Stay'),
          ),
          TextButton(
            onPressed: () async {
              final navigator = Navigator.of(context);
              navigator.pop(); // Close confirmation dialog
              await _leaveGame();
              if (mounted) {
                navigator.pop(); // Go back to main screen
              }
            },
            child: const Text('Leave'),
          ),
        ],
      ),
    );
  }

  // Mark current player as ready
  Future<void> _setPlayerReady() async {
    if (_gameId != null && !_isSettingReady) {
      setState(() {
        _isSettingReady = true;
      });

      try {
        final success = await _duelService.setPlayerReady(_gameId!);
        if (success) {
          if (kDebugMode) {
            print('Successfully set player as ready');
          }
        } else {
          if (kDebugMode) {
            print('Failed to set player as ready');
          }
        }
      } catch (e) {
        if (kDebugMode) {
          print('Error setting player ready: $e');
        }
      } finally {
        if (mounted) {
          setState(() {
            _isSettingReady = false;
          });
        }
      }
    }
  }

  // Clean game exit
  Future<void> _leaveGame() async {
    try {
      // Leave the game service
      if (_gameId != null) {
        await _duelService.leaveDuel(_gameId!);
      }
    } catch (e) {
      if (kDebugMode) {
        print('Error leaving game: $e');
      }
    }

    // Cleanup is handled in dispose()
  }

  @override
  void dispose() {
    // Leave the game if still active
    if (_gameId != null && mounted) {
      _leaveGame();
    }

    // Cancel all timers first
    _questionTimer?.cancel();
    _questionTimer = null;
    _matchmakingTimer?.cancel();
    _matchmakingTimer = null;

    // Cancel stream subscription
    _gameSubscription?.cancel();
    _gameSubscription = null;

    // Dispose all animation controllers
    _pulseController.dispose();
    _battleController.dispose();
    _celebrationController.dispose();
    _damageController.dispose();
    _scoreController.dispose();
    _timerController.dispose();
    _lightningController.dispose();
    _powerUpController.dispose();
    _shakeController.dispose();

    // Dispose sound service
    _soundService.dispose();

    // Dispose duel service resources
    _duelService.dispose();

    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        if (didPop) return;
        _showQuitConfirmation();
      },
      child: Scaffold(
        backgroundColor: const Color(0xFFF5F7FA),
        body: SafeArea(
          child: Stack(
            children: [
              _buildCurrentScreen(),
              _buildBackButton(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCurrentScreen() {
    if (kDebugMode) {
      print('_buildCurrentScreen: gameId=$_gameId, duelData=${_duelData?.containsKey('state')}, waiting=$_isWaitingForOpponent, ready=$_isReadyPhase, started=$_gameStarted');
    }

    // Emergency fallback for completely broken state
    if (_gameId == null) {
      if (kDebugMode) {
        print('No gameId, showing waiting screen and restarting match');
      }
      // Try to restart the match
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          _startQuickMatch();
        }
      });
      return _buildGameWaitingScreen(); // Go directly to waiting screen
    }

    // If duel data is null, show waiting screen (not loading)
    if (_duelData == null) {
      if (kDebugMode) {
        print('No duel data, showing waiting screen');
      }
      return _buildGameWaitingScreen();
    }

    // Normal state flow
    if (_isWaitingForOpponent || _isReadyPhase) {
      if (kDebugMode) {
        print('Showing waiting screen (waiting=$_isWaitingForOpponent, ready=$_isReadyPhase)');
      }
      // Use the same waiting screen for both waiting and ready phases
      return _buildGameWaitingScreen();
    } else if (_gameStarted) {
      if (kDebugMode) {
        print('Showing battle screen');
      }
      return _buildBattleScreen();
    } else {
      if (kDebugMode) {
        print('Fallback: showing loading screen');
      }
      // Should not reach here
      return _buildLoadingScreen('Preparing game...');
    }
  }

  Widget _buildLoadingScreen(String message) {
    return Center(
      child: Container(
        margin: const EdgeInsets.all(32),
        padding: const EdgeInsets.all(40),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.1),
              blurRadius: 15,
              offset: const Offset(0, 5),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(
              width: 60,
              height: 60,
              child: CircularProgressIndicator(
                valueColor: const AlwaysStoppedAnimation<Color>(Color(0xFF2196F3)),
                strokeWidth: 4,
              ),
            ).animate(onPlay: (controller) => controller.repeat())
              .rotate(duration: 2000.ms),
            const SizedBox(height: 24),
            Text(
              message,
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w600,
                color: Color(0xFF2C3E50),
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    ).animate().fadeIn(duration: 600.ms).scale(begin: const Offset(0.8, 0.8));
  }

  Widget _buildBackButton() {
    return Positioned(
      top: 16,
      left: 16,
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(15),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.1),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: IconButton(
          onPressed: () {
            _soundService.playButtonClick();
            _showQuitConfirmation();
          },
          icon: const Icon(
            Icons.arrow_back,
            color: Color(0xFF2C3E50),
            size: 24,
          ),
        ),
      ),
    );
  }

  Widget _buildGameWaitingScreen() {
    // Check if opponent is found (when both players are in the game)
    final bool opponentFound = _opponentData != null;

    if (kDebugMode) {
      print('_buildGameWaitingScreen: opponentFound=$opponentFound, opponentData=$_opponentData, isReadyPhase=$_isReadyPhase');
    }

    return Center(
      child: Container(
        margin: const EdgeInsets.all(24),
        padding: const EdgeInsets.all(32),
        decoration: BoxDecoration(
          gradient: opponentFound
              ? const LinearGradient(
                  colors: [Color(0xFF4CAF50), Color(0xFF66BB6A)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                )
              : null,
          color: opponentFound ? null : Colors.white,
          borderRadius: BorderRadius.circular(24),
          boxShadow: [
            BoxShadow(
              color: opponentFound
                  ? const Color(0xFF4CAF50).withValues(alpha: 0.3)
                  : Colors.black.withValues(alpha: 0.1),
              blurRadius: 20,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (!opponentFound) ...[
              // Finding opponent UI
              Container(
                width: 120,
                height: 120,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: RadialGradient(
                    colors: [
                      const Color(0xFF2196F3).withValues(alpha: 0.2),
                      const Color(0xFF2196F3).withValues(alpha: 0.1),
                      Colors.transparent,
                    ],
                  ),
                ),
                child: Center(
                  child: Container(
                    width: 60,
                    height: 60,
                    decoration: const BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: LinearGradient(
                        colors: [Color(0xFF2196F3), Color(0xFF64B5F6)],
                      ),
                    ),
                    child: const Icon(
                      Icons.sports_esports,
                      color: Colors.white,
                      size: 30,
                    ),
                  ),
                ),
              ).animate(onPlay: (controller) => controller.repeat())
                .scale(duration: 2000.ms, begin: const Offset(0.8, 0.8), end: const Offset(1.2, 1.2))
                .then()
                .scale(duration: 2000.ms, begin: const Offset(1.2, 1.2), end: const Offset(0.8, 0.8)),
              const SizedBox(height: 32),
              Text(
                '🎮 FINDING OPPONENT',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: const Color(0xFF2C3E50),
                  letterSpacing: 1.2,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),
              Text(
                'Searching for math warriors...',
                style: TextStyle(
                  fontSize: 16,
                  color: const Color(0xFF2C3E50).withValues(alpha: 0.7),
                  fontWeight: FontWeight.w500,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 24),
              // Game-style progress bar
              Container(
                width: double.infinity,
                height: 8,
                decoration: BoxDecoration(
                  color: const Color(0xFFE0E0E0),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: FractionallySizedBox(
                  widthFactor: (_waitingTime % 15) / 15.0,
                  alignment: Alignment.centerLeft,
                  child: Container(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [const Color(0xFF2196F3), const Color(0xFF1976D2)],
                      ),
                      borderRadius: BorderRadius.circular(4),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: const Color(0xFFF5F7FA),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  'Waiting ${_waitingTime}s',
                  style: TextStyle(
                    fontSize: 14,
                    color: const Color(0xFF2C3E50),
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ] else ...[
              // Opponent found - Ready phase UI
              // Match Found Header
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: Colors.white.withValues(alpha: 0.3)),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.sports_esports,
                          color: Colors.white,
                          size: 18,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          'OPPONENT FOUND',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                            letterSpacing: 0.8,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 32),

              // Players Display
              Row(
                children: [
                  // Current User
                  Expanded(
                    child: Column(
                      children: [
                        // Avatar with ready indicator overlay
                        Stack(
                          children: [
                            UserAvatar(
                              avatar: _currentUser?['avatar'] ?? '👤',
                              size: 70,
                              backgroundColor: Colors.white,
                              gradientColors: _currentUserReady
                                  ? [const Color(0xFF4CAF50), const Color(0xFF66BB6A)]
                                  : [const Color(0xFF9E9E9E), const Color(0xFFBDBDBD)],
                              showBorder: true,
                              borderColor: _currentUserReady ? Colors.green : Colors.white.withValues(alpha: 0.3),
                              borderWidth: 3,
                            ),
                            if (_currentUserReady)
                              Positioned(
                                bottom: 0,
                                right: 0,
                                child: Container(
                                  width: 24,
                                  height: 24,
                                  decoration: BoxDecoration(
                                    color: Colors.green,
                                    shape: BoxShape.circle,
                                    border: Border.all(color: Colors.white, width: 2),
                                  ),
                                  child: Icon(
                                    Icons.check,
                                    size: 12,
                                    color: Colors.white,
                                  ),
                                ),
                              ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        Text(
                          'You',
                          style: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                          ),
                          textAlign: TextAlign.center,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 4),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                          decoration: BoxDecoration(
                            color: _currentUserReady
                                ? Colors.green.withValues(alpha: 0.2)
                                : Colors.white.withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(
                            _currentUserReady ? '✓ Ready' : 'Not Ready',
                            style: TextStyle(
                              color: _currentUserReady ? Colors.green : Colors.white.withValues(alpha: 0.8),
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),

                  // VS section
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    child: Column(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.2),
                            shape: BoxShape.circle,
                          ),
                          child: Text(
                            'VS',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),

                  // Opponent
                  Expanded(
                    child: Column(
                      children: [
                        // Avatar with ready indicator overlay
                        Stack(
                          children: [
                            UserAvatar(
                              avatar: _opponent?['avatar'] ?? '🚀',
                              size: 70,
                              backgroundColor: Colors.white,
                              gradientColors: _opponentReady
                                  ? [const Color(0xFF4CAF50), const Color(0xFF66BB6A)]
                                  : [const Color(0xFF9E9E9E), const Color(0xFFBDBDBD)],
                              showBorder: true,
                              borderColor: _opponentReady ? Colors.green : Colors.white.withValues(alpha: 0.3),
                              borderWidth: 3,
                            ),
                            if (_opponentReady)
                              Positioned(
                                bottom: 0,
                                right: 0,
                                child: Container(
                                  width: 24,
                                  height: 24,
                                  decoration: BoxDecoration(
                                    color: Colors.green,
                                    shape: BoxShape.circle,
                                    border: Border.all(color: Colors.white, width: 2),
                                  ),
                                  child: Icon(
                                    Icons.check,
                                    size: 12,
                                    color: Colors.white,
                                  ),
                                ),
                              ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        Text(
                          _opponent?['name'] ?? 'Opponent',
                          style: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                          ),
                          textAlign: TextAlign.center,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 4),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                          decoration: BoxDecoration(
                            color: _opponentReady
                                ? Colors.green.withValues(alpha: 0.2)
                                : Colors.white.withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(
                            _opponentReady ? '✓ Ready' : 'Not Ready',
                            style: TextStyle(
                              color: _opponentReady ? Colors.green : Colors.white.withValues(alpha: 0.8),
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 32),

              // Game Info Section
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: Colors.white.withValues(alpha: 0.2)),
                ),
                child: Column(
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.quiz, color: Colors.white, size: 18),
                        const SizedBox(width: 8),
                        Text(
                          '${widget.topicName} • ${widget.difficulty.toUpperCase()}',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      '10 Questions • ${widget.operator} Operations',
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.8),
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),

              // Ready Button or Status
              if (!_currentUserReady) ...[
                // Ready Button
                GestureDetector(
                  onTap: _isSettingReady ? null : _setPlayerReady,
                  child: Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(vertical: 18),
                    decoration: BoxDecoration(
                      gradient: _isSettingReady
                          ? LinearGradient(
                              colors: [Colors.grey[500]!, Colors.grey[700]!],
                            )
                          : const LinearGradient(
                              colors: [Color(0xFF2196F3), Color(0xFF1565C0)],
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                            ),
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: [
                        BoxShadow(
                          color: (_isSettingReady ? Colors.grey : const Color(0xFF2196F3))
                              .withValues(alpha: 0.4),
                          blurRadius: 15,
                          offset: const Offset(0, 8),
                        ),
                      ],
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        if (_isSettingReady) ...[
                          SizedBox(
                            width: 22,
                            height: 22,
                            child: CircularProgressIndicator(
                              valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                              strokeWidth: 2.5,
                            ),
                          ),
                          const SizedBox(width: 16),
                        ] else ...[
                          Container(
                            padding: const EdgeInsets.all(6),
                            decoration: BoxDecoration(
                              color: Colors.white.withValues(alpha: 0.2),
                              shape: BoxShape.circle,
                            ),
                            child: Icon(
                              Icons.flash_on,
                              color: Colors.white,
                              size: 18,
                            ),
                          ),
                          const SizedBox(width: 12),
                        ],
                        Text(
                          _isSettingReady ? 'GETTING READY...' : 'I\'M READY!',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 0.8,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  'Tap when you\'re ready to battle!',
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.7),
                    fontSize: 13,
                    fontStyle: FontStyle.italic,
                  ),
                  textAlign: TextAlign.center,
                ),
              ] else ...[
                // Waiting Status
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(vertical: 20),
                  decoration: BoxDecoration(
                    color: Colors.green.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: Colors.green.withValues(alpha: 0.3)),
                  ),
                  child: Column(
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: Colors.green.withValues(alpha: 0.2),
                              shape: BoxShape.circle,
                            ),
                            child: Icon(
                              Icons.check,
                              color: Colors.green,
                              size: 20,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Text(
                            'You are ready!',
                            style: TextStyle(
                              color: Colors.green,
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      if (_opponentReady) ...[
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Text(
                              'Starting match...',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ] else ...[
                        Text(
                          'Waiting for opponent to get ready...',
                          style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.8),
                            fontSize: 14,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ],
          ],
        ),
      ),
    ).animate().fadeIn(duration: 800.ms).slideY(begin: 0.3);
  }



  Widget _buildBattleScreen() {
    if (_duelData == null) {
      return _buildLoadingScreen('Loading battle...');
    }

    final questions = _duelData!['questions'] as List<dynamic>?;
    if (questions == null || _currentQuestionIndex >= questions.length) {
      return _buildLoadingScreen('Calculating results...');
    }

    final currentQuestion = questions[_currentQuestionIndex] as Map<String, dynamic>?;
    if (currentQuestion == null) {
      return _buildLoadingScreen('Loading question...');
    }

    return SafeArea(
      child: LayoutBuilder(
        builder: (context, constraints) {
          final screenHeight = constraints.maxHeight;

          // Use flexible column with proper spacing
          return Column(
            children: [
              // Header - Fixed compact size
              _buildBattleHeader(),

              // Main content - Use Expanded with flex ratios for responsive sizing
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                  child: ConstrainedBox(
                    constraints: BoxConstraints(
                      minHeight: screenHeight - 120, // Account for header and safe area
                    ),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      children: [
                        // Battle Arena - Flexible with min/max constraints
                        Container(
                          constraints: BoxConstraints(
                            minHeight: 140,
                            maxHeight: (screenHeight * 0.3).clamp(140, 200),
                          ),
                          child: Stack(
                            children: [
                              _buildBattleArena(),
                              // Floating score animation overlay
                              if (_showFloatingScore)
                                Positioned.fill(
                                  child: Center(
                                    child: FloatingScoreAnimation(
                                      score: _floatingScoreValue,
                                      color: const Color(0xFF4CAF50),
                                      isVisible: _showFloatingScore,
                                    ),
                                  ),
                                ),
                            ],
                          ),
                        ).animate()
                          .fadeIn(duration: 600.ms)
                          .slideY(begin: -0.2, duration: 800.ms, curve: Curves.elasticOut),

                        const SizedBox(height: 16),

                        // Question Section - Flexible with min/max constraints
                        Container(
                          constraints: BoxConstraints(
                            minHeight: 100,
                            maxHeight: (screenHeight * 0.25).clamp(100, 160),
                          ),
                          child: _buildQuestionSection(currentQuestion),
                        ).animate()
                          .fadeIn(delay: 300.ms, duration: 600.ms)
                          .scale(begin: const Offset(0.8, 0.8), duration: 800.ms, curve: Curves.elasticOut),

                        const SizedBox(height: 16),

                        // Answer Section - Flexible with aspect ratio preservation
                        Container(
                          constraints: BoxConstraints(
                            minHeight: 120,
                            maxHeight: (screenHeight * 0.35).clamp(120, 250),
                          ),
                          child: _buildAnswersSection(currentQuestion),
                        ).animate()
                          .fadeIn(delay: 600.ms, duration: 600.ms)
                          .slideY(begin: 0.3, duration: 800.ms, curve: Curves.easeOutBack),

                        const SizedBox(height: 16),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildBattleHeader() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border(
          bottom: BorderSide(color: const Color(0xFFE0E0E0)),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Flexible(
            child: Text(
              'Question ${_currentQuestionIndex + 1} / 10',
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: Color(0xFF2C3E50),
              ),
            ),
          ),
          PulseAnimation(
            isActive: _timeRemaining <= 5,
            duration: const Duration(milliseconds: 500),
            minScale: 0.9,
            maxScale: 1.1,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: _timeRemaining <= 5
                    ? [const Color(0xFFF44336), const Color(0xFFE57373)]
                    : [const Color(0xFF2196F3), const Color(0xFF64B5F6)],
                ),
                borderRadius: BorderRadius.circular(16),
                boxShadow: _timeRemaining <= 5 ? [
                  BoxShadow(
                    color: const Color(0xFFF44336).withValues(alpha: 0.4),
                    blurRadius: 6,
                    offset: const Offset(0, 1),
                  ),
                ] : null,
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    _timeRemaining <= 5 ? Icons.timer_off : Icons.timer,
                    color: Colors.white,
                    size: 16,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    '${_timeRemaining}s',
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBattleArena() {
    final currentUserScore = _currentUserData?['score'] ?? 0;
    final opponentScore = _opponentData?['score'] ?? 0;
    final currentUserHearts = _currentUserData?['hearts'] ?? 5;
    final opponentHearts = _opponentData?['hearts'] ?? 5;
    final userWinning = currentUserScore > opponentScore;
    final isDraw = currentUserScore == opponentScore;

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.08),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Battle header with app's gradient style
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFF2196F3), Color(0xFF64B5F6)],
              ),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Text(
              '🎮 BATTLE ARENA',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.bold,
                color: Colors.white,
                letterSpacing: 0.8,
              ),
            ),
          ),
          const SizedBox(height: 8),

          // Players Row - Flexible layout
          LayoutBuilder(
            builder: (context, constraints) {
              final vsWidth = 70.0; // Reduced VS section width

              return Row(
                children: [
                  // Current User
                  Expanded(
                    child: _buildPlayerCard(
                      _currentUser?['avatar'] ?? '🦊',
                      'You',
                      currentUserScore,
                      currentUserHearts,
                      true,
                    ).animate()
                      .fadeIn(delay: 200.ms, duration: 600.ms)
                      .slideX(begin: -0.3, duration: 800.ms, curve: Curves.elasticOut),
                  ),

                  // VS Section - Compact
                  SizedBox(
                    width: vsWidth,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        // Animated battle icon - Smaller
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              colors: isDraw
                                  ? [const Color(0xFFFFB74D), const Color(0xFFFF9800)]
                                  : userWinning
                                      ? [const Color(0xFF4CAF50), const Color(0xFF66BB6A)]
                                      : [const Color(0xFFF44336), const Color(0xFFEF5350)],
                            ),
                            shape: BoxShape.circle,
                            boxShadow: [
                              BoxShadow(
                                color: (isDraw
                                    ? const Color(0xFFFF9800)
                                    : userWinning
                                        ? const Color(0xFF4CAF50)
                                        : const Color(0xFFF44336))
                                    .withValues(alpha: 0.3),
                                blurRadius: 6,
                                offset: const Offset(0, 2),
                              ),
                            ],
                          ),
                          child: Icon(
                            isDraw
                                ? Icons.balance
                                : userWinning
                                    ? Icons.trending_up
                                    : Icons.trending_down,
                            color: Colors.white,
                            size: 18,
                          ),
                        ).animate(onPlay: (controller) => controller.repeat())
                          .scale(duration: 1500.ms, begin: const Offset(0.9, 0.9), end: const Offset(1.1, 1.1))
                          .then()
                          .scale(duration: 1500.ms, begin: const Offset(1.1, 1.1), end: const Offset(0.9, 0.9)),

                        const SizedBox(height: 4),

                        // VS text
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(6),
                            border: Border.all(color: const Color(0xFF2196F3).withValues(alpha: 0.3)),
                          ),
                          child: const Text(
                            'VS',
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w900,
                              color: Color(0xFF2C3E50),
                              letterSpacing: 1.0,
                            ),
                          ),
                        ),

                        const SizedBox(height: 4),

                        // Score display - Compact
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                          decoration: BoxDecoration(
                            gradient: const LinearGradient(
                              colors: [Color(0xFFE8B4FF), Color(0xFFC490FF)],
                            ),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            '$currentUserScore-$opponentScore',
                            style: const TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w800,
                              color: Colors.white,
                            ),
                          ),
                        ).animate()
                          .fadeIn(delay: 400.ms, duration: 600.ms)
                          .scale(begin: const Offset(0.7, 0.7), duration: 600.ms, curve: Curves.elasticOut),
                      ],
                    ),
                  ),

                  // Opponent
                  Expanded(
                    child: _buildPlayerCard(
                      _opponent?['avatar'] ?? '🤖',
                      _opponent?['name'] ?? 'Opponent',
                      opponentScore,
                      opponentHearts,
                      false,
                    ).animate()
                      .fadeIn(delay: 200.ms, duration: 600.ms)
                      .slideX(begin: 0.3, duration: 800.ms, curve: Curves.elasticOut),
                  ),
                ],
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildPlayerCard(String avatar, String name, int score, int hearts, bool isCurrentUser) {
    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: isCurrentUser
              ? [const Color(0xFF2196F3).withValues(alpha: 0.1), const Color(0xFF64B5F6).withValues(alpha: 0.1)]
              : [const Color(0xFFFF9800).withValues(alpha: 0.1), const Color(0xFFFFB74D).withValues(alpha: 0.1)],
        ),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isCurrentUser
            ? const Color(0xFF2196F3).withValues(alpha: 0.3)
            : const Color(0xFFFF9800).withValues(alpha: 0.3),
          width: 1.5,
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Avatar with app's gradient colors - Smaller
          UserAvatar(
            avatar: avatar,
            size: 32,
            showBorder: true,
            borderColor: isCurrentUser ? const Color(0xFF2196F3) : const Color(0xFFFF9800),
            borderWidth: 2,
            gradientColors: isCurrentUser
                ? [const Color(0xFF2196F3), const Color(0xFF64B5F6)]
                : [const Color(0xFFFF9800), const Color(0xFFFFB74D)],
          ),
          const SizedBox(height: 6),

          // Name with light theme styling - Smaller
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.8),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              name.length > 7 ? '${name.substring(0, 6)}...' : name,
              style: const TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.bold,
                color: Color(0xFF2C3E50),
              ),
              textAlign: TextAlign.center,
            ),
          ),
          const SizedBox(height: 4),

          // Score with app colors - Smaller
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFF4CAF50), Color(0xFF66BB6A)],
              ),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              '$score',
              style: const TextStyle(
                fontSize: 10,
                color: Colors.white,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          const SizedBox(height: 4),

          // Hearts with proper colors - Smaller
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: List.generate(5, (index) => Padding(
              padding: const EdgeInsets.symmetric(horizontal: 0.5),
              child: Icon(
                index < hearts ? Icons.favorite : Icons.favorite_border,
                color: index < hearts ? Colors.red[400] : Colors.grey[300],
                size: 10,
              ),
            )),
          ),
        ],
      ),
    );
  }

  Widget _buildQuestionSection(Map<String, dynamic> question) {
    final operand1 = question['operand1'];
    final operand2 = question['operand2'];
    final operator = question['operator'];

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFF2196F3).withValues(alpha: 0.3)),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF2196F3).withValues(alpha: 0.15),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Header - Compact
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFF2196F3), Color(0xFF64B5F6)],
              ),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Text(
              '🧮 SOLVE THIS',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.bold,
                color: Colors.white,
                letterSpacing: 0.8,
              ),
            ),
          ),
          const SizedBox(height: 12),

          // Equation - More responsive sizing
          LayoutBuilder(
            builder: (context, constraints) {
              final availableWidth = constraints.maxWidth;
              // More conservative font scaling
              final baseFontSize = (availableWidth * 0.08).clamp(24.0, 36.0);
              final operatorSize = (baseFontSize * 0.7).clamp(16.0, 24.0);
              final questionMarkSize = (baseFontSize * 0.8).clamp(20.0, 28.0);

              return Wrap(
                alignment: WrapAlignment.center,
                crossAxisAlignment: WrapCrossAlignment.center,
                spacing: 8,
                runSpacing: 4,
                children: [
                  Text(
                    operand1.toString(),
                    style: TextStyle(
                      fontSize: baseFontSize,
                      fontWeight: FontWeight.w900,
                      color: const Color(0xFF2C3E50),
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.all(6),
                    decoration: const BoxDecoration(
                      gradient: LinearGradient(
                        colors: [Color(0xFFFF9800), Color(0xFFFF6F00)],
                      ),
                      shape: BoxShape.circle,
                    ),
                    child: Text(
                      operator,
                      style: TextStyle(
                        fontSize: operatorSize,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                  ),
                  Text(
                    operand2.toString(),
                    style: TextStyle(
                      fontSize: baseFontSize,
                      fontWeight: FontWeight.w900,
                      color: const Color(0xFF2C3E50),
                    ),
                  ),
                  Text(
                    '=',
                    style: TextStyle(
                      fontSize: baseFontSize * 0.85,
                      fontWeight: FontWeight.w600,
                      color: const Color(0xFF2C3E50),
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [Color(0xFF4CAF50), Color(0xFF66BB6A)],
                      ),
                      borderRadius: BorderRadius.circular(10),
                      boxShadow: [
                        BoxShadow(
                          color: const Color(0xFF4CAF50).withValues(alpha: 0.3),
                          blurRadius: 6,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: Text(
                      '?',
                      style: TextStyle(
                        fontSize: questionMarkSize,
                        fontWeight: FontWeight.w900,
                        color: Colors.white,
                      ),
                    ),
                  ).animate(onPlay: (controller) => controller.repeat())
                    .scale(duration: 1000.ms, begin: const Offset(0.9, 0.9), end: const Offset(1.1, 1.1))
                    .then()
                    .scale(duration: 1000.ms, begin: const Offset(1.1, 1.1), end: const Offset(0.9, 0.9)),
                ],
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildAnswersSection(Map<String, dynamic> question) {
    final options = question['options'] as List<dynamic>;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      child: LayoutBuilder(
        builder: (context, constraints) {
          // Use intrinsic sizing instead of fixed heights
          return GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              crossAxisSpacing: 12,
              mainAxisSpacing: 12,
              childAspectRatio: 2.5, // Fixed aspect ratio for consistency
            ),
            itemCount: options.length,
            itemBuilder: (context, index) {
              final option = options[index] as int;
              final isCorrect = option == question['correctAnswer'];
              final isSelected = _selectedAnswer == option;

              return _buildAnswerButton(option, isCorrect, isSelected);
            },
          );
        },
      ),
    );
  }

  Widget _buildAnswerButton(int option, bool isCorrect, bool isSelected) {
    Color? gradientStart;
    Color? gradientEnd;
    bool showParticles = false;

    if (_hasAnswered) {
      if (isCorrect) {
        gradientStart = const Color(0xFF00B894);
        gradientEnd = const Color(0xFF00A085);
        showParticles = true;
      } else if (isSelected && !isCorrect) {
        gradientStart = const Color(0xFFE17055);
        gradientEnd = const Color(0xFFD63031);
      } else {
        gradientStart = Colors.grey[600];
        gradientEnd = Colors.grey[800];
      }
    } else {
      if (isSelected) {
        gradientStart = const Color(0xFF0984e3);
        gradientEnd = const Color(0xFF74b9ff);
      } else {
        gradientStart = Colors.white.withValues(alpha: 0.2);
        gradientEnd = Colors.white.withValues(alpha: 0.1);
      }
    }

    Widget answerWidget = AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [gradientStart!, gradientEnd!],
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: _hasAnswered && isCorrect
            ? Colors.green
            : Colors.white.withValues(alpha: 0.3),
          width: _hasAnswered && isCorrect ? 3 : 2,
        ),
        boxShadow: [
          BoxShadow(
            color: (_hasAnswered && isCorrect ? Colors.green : Colors.black)
                .withValues(alpha: 0.3),
            blurRadius: _hasAnswered && isCorrect ? 12 : 8,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: _hasAnswered ? null : () {
            HapticFeedback.selectionClick();
            _selectAnswer(option);
          },
          borderRadius: BorderRadius.circular(16),
          child: Center(
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                if (_hasAnswered && isCorrect) ...[
                  const Icon(
                    Icons.check_circle,
                    color: Colors.white,
                    size: 24,
                  ).animate().scale(duration: 300.ms).fadeIn(),
                  const SizedBox(width: 8),
                ] else if (_hasAnswered && isSelected && !isCorrect) ...[
                  const Icon(
                    Icons.cancel,
                    color: Colors.white,
                    size: 24,
                  ).animate().scale(duration: 300.ms).shake(),
                  const SizedBox(width: 8),
                ],
                Text(
                  option.toString(),
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );

    // Add particle effect for correct answers
    if (_hasAnswered && isCorrect && showParticles) {
      answerWidget = ParticleEffect(
        isActive: _showCorrectEffect,
        type: ParticleType.sparkle,
        child: answerWidget.animate()
          .scale(duration: 400.ms, begin: const Offset(1.0, 1.0), end: const Offset(1.05, 1.05))
          .then()
          .scale(duration: 400.ms, begin: const Offset(1.05, 1.05), end: const Offset(1.0, 1.0))
          .shimmer(duration: 1000.ms, colors: [
            Colors.white.withValues(alpha: 0.5),
            Colors.transparent,
          ]),
      );
    } else if (_hasAnswered && isSelected && !isCorrect) {
      answerWidget = answerWidget.animate()
        .shake(duration: 600.ms, hz: 4);
    }

    return answerWidget;
  }

  Widget _buildGameEndDialog(bool isWinner, bool isDraw, int userScore, int opponentScore) {
    if (isWinner) {
      _soundService.playVictory();
    } else {
      _soundService.playDefeat();
    }

    return Dialog(
      backgroundColor: Colors.transparent,
      child: Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Color(0xFF16213E),
              Color(0xFF0F3460),
            ],
          ),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: Colors.white.withValues(alpha: 0.3)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.5),
              blurRadius: 20,
              offset: const Offset(0, 10),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              isDraw
                  ? Icons.handshake
                  : isWinner
                      ? Icons.emoji_events
                      : Icons.sentiment_dissatisfied,
              size: 80,
              color: isDraw
                  ? Colors.orange
                  : isWinner
                      ? Colors.amber
                      : Colors.grey,
            ),
            const SizedBox(height: 20),
            Text(
              isDraw
                  ? 'It\'s a Draw!'
                  : isWinner
                      ? '🎉 Victory! 🎉'
                      : '😔 Defeat',
              style: const TextStyle(
                fontSize: 28,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 20),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('Your Score:', style: TextStyle(color: Colors.white, fontSize: 16)),
                      Text(
                        userScore.toString(),
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                          fontSize: 16,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('Opponent Score:', style: TextStyle(color: Colors.white, fontSize: 16)),
                      Text(
                        opponentScore.toString(),
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                          fontSize: 16,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () async {
                  // Close the dialog first
                  Navigator.of(context).pop();

                  // Clean up the game session
                  await _leaveGame();

                  // Go back to main screen
                  if (mounted) {
                    Navigator.of(context).pop();
                  }
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF6C5CE7),
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: const Text(
                  'Continue',
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 18,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

}