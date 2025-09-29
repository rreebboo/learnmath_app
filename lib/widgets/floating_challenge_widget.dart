import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'dart:async';
import '../services/quiz_duel_service.dart';
import '../screens/quiz_duel_screen.dart';
import '../widgets/user_avatar.dart';

class FloatingChallengeWidget extends StatefulWidget {
  final String friendId;
  final String friendName;
  final String friendAvatar;
  final String topicName;
  final String operator;
  final String difficulty;
  final String gameId;
  final VoidCallback? onCancel;

  const FloatingChallengeWidget({
    super.key,
    required this.friendId,
    required this.friendName,
    required this.friendAvatar,
    required this.topicName,
    required this.operator,
    required this.difficulty,
    required this.gameId,
    this.onCancel,
  });

  @override
  State<FloatingChallengeWidget> createState() => _FloatingChallengeWidgetState();
}

class _FloatingChallengeWidgetState extends State<FloatingChallengeWidget>
    with TickerProviderStateMixin {
  final QuizDuelService _duelService = QuizDuelService();

  late AnimationController _pulseController;
  late AnimationController _slideController;
  late AnimationController _dynamicIslandController;
  late AnimationController _closeController;
  Animation<double>? _scaleAnimation;
  Animation<double>? _widthAnimation;
  Animation<double>? _heightAnimation;
  Animation<BorderRadius?>? _borderRadiusAnimation;
  Animation<double>? _opacityAnimation;
  Animation<Offset>? _slideOffsetAnimation;
  Animation<double>? _closeScaleAnimation;
  Animation<double>? _closeOpacityAnimation;

  StreamSubscription<DocumentSnapshot>? _gameSubscription;
  int _waitingTime = 0;
  Timer? _waitingTimer;
  bool _challengeAccepted = false;
  bool _challengeDeclined = false;
  bool _isExpanded = false;
  bool _isFirstShow = true;
  bool _isClosing = false;

  // Drag position state
  Offset _position = Offset.zero;
  bool _isDragging = false;

  @override
  void initState() {
    super.initState();
    _setupAnimationControllers();
    _subscribeToGameUpdates();
    _startWaitingTimer();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        _setupAnimations();
        _initializePosition();
        _dynamicIslandController.forward();
        Timer(const Duration(milliseconds: 1200), () {
          if (mounted && _isFirstShow) {
            _toggleExpansion();
            Timer(const Duration(milliseconds: 4000), () {
              if (mounted && _isExpanded && _isFirstShow) {
                _toggleExpansion();
                _isFirstShow = false;
              }
            });
          }
        });
      }
    });
  }

  void _setupAnimationControllers() {
    _pulseController = AnimationController(
      duration: const Duration(seconds: 2),
      vsync: this,
    )..repeat(reverse: true);

    _slideController = AnimationController(
      duration: const Duration(milliseconds: 600),
      vsync: this,
    );

    _dynamicIslandController = AnimationController(
      duration: const Duration(milliseconds: 600),
      vsync: this,
    );

    _closeController = AnimationController(
      duration: const Duration(milliseconds: 500),
      vsync: this,
    );
  }

  void _initializePosition() {
    final screenSize = MediaQuery.of(context).size;
    final safeArea = MediaQuery.of(context).padding;

    // Start at top center
    _position = Offset(
      (screenSize.width - 160) / 2, // Center horizontally
      safeArea.top + 12, // Just below status bar
    );
  }

  void _onPanStart(DragStartDetails details) {
    _isDragging = true;
  }

  void _onPanUpdate(DragUpdateDetails details) {
    if (!_isDragging || _isClosing) return;

    final screenSize = MediaQuery.of(context).size;
    final safeArea = MediaQuery.of(context).padding;
    final widgetWidth = _isExpanded ? (_widthAnimation?.value ?? 400.0) : 160.0;
    final widgetHeight = _isExpanded ? (_heightAnimation?.value ?? 200.0) : 40.0;

    setState(() {
      _position = Offset(
        (_position.dx + details.delta.dx).clamp(
          0.0,
          screenSize.width - widgetWidth,
        ),
        (_position.dy + details.delta.dy).clamp(
          safeArea.top,
          screenSize.height - widgetHeight - safeArea.bottom,
        ),
      );
    });
  }

  void _onPanEnd(DragEndDetails details) {
    _isDragging = false;
  }

  void _setupAnimations() {
    _scaleAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _dynamicIslandController,
      curve: Curves.easeOutBack,
    ));

    final screenWidth = MediaQuery.of(context).size.width;
    final screenHeight = MediaQuery.of(context).size.height;

    final collapsedWidth = screenWidth < 360 ? 120.0 : screenWidth < 400 ? 140.0 : 160.0;
    final expandedWidth = (screenWidth * 0.92).clamp(280.0, 400.0);
    final expandedHeight = screenHeight < 600 ? 160.0 : screenHeight < 700 ? 180.0 : 200.0;

    _widthAnimation = Tween<double>(
      begin: collapsedWidth,
      end: expandedWidth,
    ).animate(CurvedAnimation(
      parent: _slideController,
      curve: Curves.fastOutSlowIn,
    ));

    _heightAnimation = Tween<double>(
      begin: 40.0,
      end: expandedHeight,
    ).animate(CurvedAnimation(
      parent: _slideController,
      curve: Curves.elasticOut,
    ));


    _slideOffsetAnimation = Tween<Offset>(
      begin: const Offset(0.0, 0.1),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _slideController,
      curve: Curves.easeOutQuart,
    ));

    _borderRadiusAnimation = BorderRadiusTween(
      begin: BorderRadius.circular(24),
      end: BorderRadius.circular(16),
    ).animate(CurvedAnimation(
      parent: _slideController,
      curve: Curves.fastOutSlowIn,
    ));

    _opacityAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _slideController,
      curve: Interval(0.4, 1.0, curve: Curves.easeInOut),
    ));

    _closeScaleAnimation = Tween<double>(
      begin: 1.0,
      end: 0.0,
    ).animate(CurvedAnimation(
      parent: _closeController,
      curve: Curves.easeInQuart,
    ));

    _closeOpacityAnimation = Tween<double>(
      begin: 1.0,
      end: 0.0,
    ).animate(CurvedAnimation(
      parent: _closeController,
      curve: Interval(0.0, 0.7, curve: Curves.easeInOut),
    ));
  }

  void _subscribeToGameUpdates() {
    if (kDebugMode) {
      print('FloatingChallenge: Subscribing to game updates for ${widget.gameId}');
    }

    _gameSubscription = _duelService.getDuelStream(widget.gameId).listen(
      (snapshot) {
        if (mounted && snapshot.exists) {
          final data = snapshot.data() as Map<String, dynamic>?;
          if (data != null) {
            _checkIfChallengeAccepted(data);
          }
        } else if (mounted && !snapshot.exists) {
          widget.onCancel?.call();
        }
      },
      onError: (error) {
        if (kDebugMode) {
          print('Stream error in floating challenge: $error');
        }
        widget.onCancel?.call();
      },
    );
  }

  void _checkIfChallengeAccepted(Map<String, dynamic> gameData) {
    final challengeData = gameData['challengeData'] as Map<String, dynamic>?;

    if (challengeData != null) {
      final challengeStatus = challengeData['status'] as String?;

      if (challengeStatus == 'accepted' && !_challengeAccepted) {
        if (kDebugMode) {
          print('FloatingChallenge: Challenge accepted! Switching to accepted state.');
        }
        setState(() {
          _challengeAccepted = true;
        });

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(6),
                    child: const Icon(Icons.celebration, color: Colors.white, size: 20),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      '🎉 ${widget.friendName} accepted your challenge!',
                      style: const TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 15,
                      ),
                    ),
                  ),
                ],
              ),
              backgroundColor: const Color(0xFF4CAF50),
              duration: const Duration(seconds: 4),
              behavior: SnackBarBehavior.floating,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              margin: const EdgeInsets.all(16),
            ),
          );
        }
      } else if (challengeStatus == 'declined' && !_challengeAccepted && !_challengeDeclined) {
        setState(() {
          _challengeDeclined = true;
        });

        // Show declined state for a few seconds before dismissing with animation
        Timer(const Duration(milliseconds: 2500), () async {
          if (mounted) {
            setState(() {
              _isClosing = true;
            });
            await _closeController.forward();
            widget.onCancel?.call();
          }
        });
      }
    }
  }

  void _startWaitingTimer() {
    _waitingTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (mounted) {
        setState(() {
          _waitingTime++;
        });

        if (_waitingTime >= 300) {
          widget.onCancel?.call();
          timer.cancel();
        }
      } else {
        timer.cancel();
      }
    });
  }

  void _toggleExpansion() {
    if (_isClosing) return;

    final screenSize = MediaQuery.of(context).size;
    final safeArea = MediaQuery.of(context).padding;
    final expandedWidth = (screenSize.width * 0.92).clamp(280.0, 400.0);
    final expandedHeight = screenSize.height < 600 ? 160.0 : screenSize.height < 700 ? 180.0 : 200.0;

    setState(() {
      if (!_isExpanded) {
        // Adjust position when expanding to prevent going off screen
        double newX = _position.dx;
        double newY = _position.dy;

        // Check right edge
        if (_position.dx + expandedWidth > screenSize.width) {
          newX = screenSize.width - expandedWidth - 12; // 12px margin
        }

        // Check left edge
        if (newX < 12) {
          newX = 12; // 12px margin
        }

        // Check bottom edge
        if (_position.dy + expandedHeight > screenSize.height - safeArea.bottom) {
          newY = screenSize.height - expandedHeight - safeArea.bottom - 12; // 12px margin
        }

        // Check top edge
        if (newY < safeArea.top + 12) {
          newY = safeArea.top + 12; // 12px margin
        }

        _position = Offset(newX, newY);
      }
      _isExpanded = !_isExpanded;
    });

    if (_isExpanded) {
      _slideController.forward();
    } else {
      _slideController.reverse();
    }
  }

  void _cancelChallenge() async {
    if (_isClosing) return;

    setState(() {
      _isClosing = true;
    });

    await _closeController.forward();

    try {
      await _duelService.leaveDuel(widget.gameId);
      widget.onCancel?.call();
    } catch (e) {
      if (kDebugMode) {
        print('Error cancelling challenge: $e');
      }
      widget.onCancel?.call();
    }
  }

  String _getWaitingTimeText() {
    if (_waitingTime < 60) {
      return '${_waitingTime}s';
    } else {
      final minutes = _waitingTime ~/ 60;
      final seconds = _waitingTime % 60;
      return '${minutes}m ${seconds}s';
    }
  }


  @override
  void dispose() {
    _pulseController.dispose();
    _slideController.dispose();
    _dynamicIslandController.dispose();
    _closeController.dispose();
    _gameSubscription?.cancel();
    _waitingTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_challengeAccepted) {
      return _buildAcceptedState();
    }

    if (_challengeDeclined) {
      return _buildDeclinedState();
    }

    final screenWidth = MediaQuery.of(context).size.width;
    final collapsedWidth = screenWidth < 360 ? 120.0 : screenWidth < 400 ? 140.0 : 160.0;

    if (_scaleAnimation == null ||
        _widthAnimation == null ||
        _heightAnimation == null ||
        _borderRadiusAnimation == null) {
      return const SizedBox.shrink();
    }

    return Positioned(
      top: _position.dy,
      left: _position.dx,
      child: AnimatedBuilder(
        animation: _isClosing ? _closeController : _dynamicIslandController,
        builder: (context, child) {
          return Transform.scale(
            scale: _isClosing ? _closeScaleAnimation!.value : _scaleAnimation!.value,
            alignment: Alignment.topCenter,
            child: Opacity(
              opacity: _isClosing ? _closeOpacityAnimation!.value : 1.0,
              child: GestureDetector(
                onTap: () {
                  if (!_isDragging) {
                    _toggleExpansion();
                  }
                },
                onPanStart: _onPanStart,
                onPanUpdate: _onPanUpdate,
                onPanEnd: _onPanEnd,
                child: AnimatedBuilder(
                  animation: Listenable.merge([_slideController, _dynamicIslandController]),
                  builder: (context, child) {
                    return ConstrainedBox(
                      constraints: BoxConstraints(
                        minWidth: collapsedWidth,
                        maxWidth: screenWidth - 24,
                        minHeight: 40,
                        maxHeight: MediaQuery.of(context).size.height * 0.35,
                      ),
                      child: SlideTransition(
                        position: _slideOffsetAnimation ?? AlwaysStoppedAnimation(Offset.zero),
                        child: AnimatedBuilder(
                          animation: _slideController,
                          builder: (context, child) {
                            return Container(
                                  width: _isExpanded ? _widthAnimation!.value : collapsedWidth,
                                  height: _isExpanded ? _heightAnimation!.value : 40,
                                  decoration: BoxDecoration(
                                    color: _isExpanded
                                        ? Colors.white
                                        : Colors.white.withValues(alpha: 0.95),
                                    borderRadius: _borderRadiusAnimation!.value,
                                    border: Border.all(
                                      color: _isExpanded
                                          ? const Color(0xFF4CAF50)
                                          : const Color(0xFF4CAF50).withValues(alpha: 0.8),
                                      width: _isExpanded ? 2.0 : 1.5,
                                    ),
                                    boxShadow: [
                                      BoxShadow(
                                        color: Colors.black.withValues(alpha: 0.08),
                                        blurRadius: 12,
                                        offset: const Offset(0, 4),
                                        spreadRadius: 0,
                                      ),
                                      BoxShadow(
                                        color: const Color(0xFF81C784).withValues(
                                          alpha: (_isExpanded ? 0.4 : 0.3) * (0.5 + 0.5 * _pulseController.value)
                                        ),
                                        blurRadius: (_isExpanded ? 12 : 8) * (0.8 + 0.4 * _pulseController.value),
                                        offset: const Offset(0, 0),
                                        spreadRadius: (_isExpanded ? 3 : 2) * (0.7 + 0.6 * _pulseController.value),
                                      ),
                                    ],
                                  ),
                                  child: _isExpanded ? _buildExpandedContent() : _buildCollapsedContent(),
                                );
                          },
                        ),
                      ),
                    );
                  },
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildCollapsedContent() {
    final screenWidth = MediaQuery.of(context).size.width;
    final isSmallScreen = screenWidth < 360;
    final avatarSize = isSmallScreen ? 20.0 : 24.0;
    final fontSize = isSmallScreen ? 12.0 : 14.0;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        mainAxisSize: MainAxisSize.min,
        children: [
          UserAvatar(
            avatar: widget.friendAvatar,
            size: avatarSize,
            gradientColors: const [Color(0xFF4CAF50), Color(0xFF66BB6A)],
          ),
          const SizedBox(width: 8),
          Flexible(
            child: Text(
              _getWaitingTimeText(),
              style: TextStyle(
                color: const Color(0xFF4CAF50),
                fontSize: fontSize,
                fontWeight: FontWeight.w700,
                decoration: TextDecoration.none,
              ),
              overflow: TextOverflow.ellipsis,
              maxLines: 1,
            ),
          ),
          const SizedBox(width: 6),
          Container(
            width: 6,
            height: 6,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: RadialGradient(
                colors: [
                  const Color(0xFF4CAF50).withValues(alpha: 0.8),
                  const Color(0xFF4CAF50).withValues(alpha: 0.6),
                ],
                center: Alignment.topLeft,
                radius: 0.8,
              ),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFF4CAF50).withValues(alpha: 0.4),
                  blurRadius: 4,
                  spreadRadius: 1,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildExpandedContent() {
    final screenWidth = MediaQuery.of(context).size.width;
    final isSmallScreen = screenWidth < 360;

    final content = Container(
      padding: const EdgeInsets.all(16),
      child: SingleChildScrollView(
        physics: const BouncingScrollPhysics(),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                UserAvatar(
                  avatar: widget.friendAvatar,
                  size: isSmallScreen ? 32.0 : 36.0,
                  gradientColors: const [Color(0xFF4CAF50), Color(0xFF66BB6A)],
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        'Challenge Sent',
                        style: const TextStyle(
                          color: Color(0xFF2C3E50),
                          fontSize: 11,
                          fontWeight: FontWeight.w500,
                          decoration: TextDecoration.none,
                        ),
                      ),
                      Text(
                        widget.friendName,
                        style: const TextStyle(
                          color: Color(0xFF2C3E50),
                          fontSize: 16,
                          fontWeight: FontWeight.w800,
                          decoration: TextDecoration.none,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                GestureDetector(
                  onTap: _toggleExpansion,
                  child: Container(
                    padding: const EdgeInsets.all(6),
                    child: const Icon(
                      Icons.keyboard_arrow_down,
                      color: Colors.white,
                      size: 18,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.grey.shade200,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: Colors.grey.shade300,
                  width: 1.0,
                ),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Topic:',
                        style: const TextStyle(
                          fontWeight: FontWeight.w700,
                          color: Color(0xFF2C3E50),
                          fontSize: 12,
                          decoration: TextDecoration.none,
                        ),
                      ),
                      Flexible(
                        child: Text(
                          widget.topicName,
                          style: const TextStyle(
                            color: Color(0xFF4CAF50),
                            fontWeight: FontWeight.w700,
                            fontSize: 12,
                            decoration: TextDecoration.none,
                          ),
                          overflow: TextOverflow.ellipsis,
                          textAlign: TextAlign.end,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Difficulty:',
                        style: const TextStyle(
                          fontWeight: FontWeight.w700,
                          color: Color(0xFF2C3E50),
                          fontSize: 12,
                          decoration: TextDecoration.none,
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        child: Text(
                          widget.difficulty.toUpperCase(),
                          style: const TextStyle(
                            color: Color(0xFF4CAF50),
                            fontWeight: FontWeight.w700,
                            fontSize: 10,
                            decoration: TextDecoration.none,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                AnimatedBuilder(
                  animation: _pulseController,
                  builder: (context, child) {
                    return Transform.rotate(
                      angle: _pulseController.value * 2 * 3.14159,
                      child: const Icon(
                        Icons.hourglass_empty,
                        color: Color(0xFF4CAF50),
                        size: 16,
                      ),
                    );
                  },
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    'Waiting ${_getWaitingTimeText()}',
                    style: const TextStyle(
                      fontSize: 13,
                      color: Color(0xFF4CAF50),
                      fontWeight: FontWeight.w700,
                      decoration: TextDecoration.none,
                    ),
                  ),
                ),
                GestureDetector(
                  onTap: _cancelChallenge,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: Theme.of(context).colorScheme.error,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: Theme.of(context).colorScheme.error,
                        width: 1.0,
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(
                          Icons.close,
                          color: Colors.white,
                          size: 14,
                        ),
                        const SizedBox(width: 4),
                        const Text(
                          'Cancel',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            color: Colors.white,
                            decoration: TextDecoration.none,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );

    return _opacityAnimation != null
        ? AnimatedBuilder(
            animation: _slideController,
            builder: (context, child) {
              return FadeTransition(
              opacity: _opacityAnimation!,
              child: SlideTransition(
                position: _slideOffsetAnimation ?? AlwaysStoppedAnimation(Offset.zero),
                child: content,
              ),
            );
            },
          )
        : content;
  }

  Widget _buildAcceptedState() {
    final screenWidth = MediaQuery.of(context).size.width;
    final isSmallScreen = screenWidth < 360;
    final height = isSmallScreen ? 48.0 : 56.0;

    return Positioned(
      top: _position.dy,
      left: _position.dx,
      child: GestureDetector(
        onTap: () async {
          if (!_isDragging) {
            if (kDebugMode) {
              print('FloatingChallenge: Tapped accepted challenge, navigating to QuizDuelScreen with gameId: ${widget.gameId}');
            }

            // Navigate first while context is still valid
            if (mounted && context.mounted) {
              // Navigate to the waiting section (ready phase) when challenge is accepted
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => QuizDuelScreen(
                    topicName: widget.topicName,
                    operator: widget.operator,
                    difficulty: widget.difficulty,
                    gameId: widget.gameId, // Include the gameId for accepted challenge
                  ),
                ),
              ).then((_) {
                if (kDebugMode) {
                  print('FloatingChallenge: Navigation to QuizDuelScreen completed');
                }
              });

              // Small delay to ensure navigation starts, then dismiss widget
              await Future.delayed(const Duration(milliseconds: 100));

              // Start closing animation for smooth dismissal
              if (mounted) {
                setState(() {
                  _isClosing = true;
                });

                // Play close animation briefly
                _closeController.forward();

                // Dismiss the floating widget after navigation
                widget.onCancel?.call();
              }
            }
          }
        },
        onPanStart: _onPanStart,
        onPanUpdate: _onPanUpdate,
        onPanEnd: _onPanEnd,
        child: Container(
          height: height,
          constraints: BoxConstraints(
            maxWidth: (screenWidth * 0.92).clamp(280.0, 400.0),
            minHeight: 48,
          ),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                const Color(0xFF4CAF50),
                const Color(0xFF4CAF50).withValues(alpha: 0.9),
              ],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(height / 2),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFF4CAF50).withValues(alpha: 0.3),
                blurRadius: 8,
                offset: const Offset(0, 4),
                spreadRadius: 0,
              ),
            ],
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(
                  Icons.celebration,
                  color: Colors.white,
                  size: 24,
                ),
                const SizedBox(width: 12),
                Flexible(
                  child: Text(
                    isSmallScreen
                        ? '${widget.friendName} accepted!'
                        : '${widget.friendName} accepted! Tap to enter match',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      decoration: TextDecoration.none,
                    ),
                    maxLines: isSmallScreen ? 2 : 1,
                    overflow: TextOverflow.ellipsis,
                    textAlign: TextAlign.center,
                  ),
                ),
                const SizedBox(width: 12),
                const Icon(
                  Icons.play_arrow,
                  color: Colors.white,
                  size: 24,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildDeclinedState() {
    final screenWidth = MediaQuery.of(context).size.width;
    final isSmallScreen = screenWidth < 360;
    final height = isSmallScreen ? 48.0 : 56.0;

    return Positioned(
      top: _position.dy,
      left: _position.dx,
      child: GestureDetector(
        onTap: () async {
          if (!_isDragging) {
            // Start closing animation
            setState(() {
              _isClosing = true;
            });

            // Play close animation then dismiss
            await _closeController.forward();
            widget.onCancel?.call();
          }
        },
        onPanStart: _onPanStart,
        onPanUpdate: _onPanUpdate,
        onPanEnd: _onPanEnd,
        child: Container(
          height: height,
          constraints: BoxConstraints(
            maxWidth: (screenWidth * 0.92).clamp(280.0, 400.0),
            minHeight: 48,
          ),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                const Color(0xFFE53E3E),
                const Color(0xFFE53E3E).withValues(alpha: 0.9),
              ],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(height / 2),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFFE53E3E).withValues(alpha: 0.3),
                blurRadius: 8,
                offset: const Offset(0, 4),
                spreadRadius: 0,
              ),
            ],
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(
                  Icons.sentiment_dissatisfied,
                  color: Colors.white,
                  size: 24,
                ),
                const SizedBox(width: 12),
                Flexible(
                  child: Text(
                    isSmallScreen
                        ? '${widget.friendName} declined'
                        : '${widget.friendName} declined your challenge',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      decoration: TextDecoration.none,
                    ),
                    maxLines: isSmallScreen ? 2 : 1,
                    overflow: TextOverflow.ellipsis,
                    textAlign: TextAlign.center,
                  ),
                ),
                const SizedBox(width: 12),
                const Icon(
                  Icons.close,
                  color: Colors.white,
                  size: 24,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}