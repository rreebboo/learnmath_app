import 'package:flutter/material.dart';
import '../widgets/floating_challenge_widget.dart';

class FloatingChallengeService {
  static final FloatingChallengeService _instance = FloatingChallengeService._internal();
  factory FloatingChallengeService() => _instance;
  FloatingChallengeService._internal();

  OverlayEntry? _overlayEntry;
  FloatingChallengeData? _currentChallenge;

  FloatingChallengeData? get currentChallenge => _currentChallenge;

  void initialize(BuildContext context) {
    // Initialize but don't show anything yet
  }

  void showFloatingChallenge(BuildContext context, FloatingChallengeData challenge) {
    _currentChallenge = challenge;

    // Remove existing overlay if any
    hideFloatingChallenge();

    // Create new overlay entry
    _overlayEntry = OverlayEntry(
      builder: (context) => FloatingChallengeWidget(
        friendId: challenge.friendId,
        friendName: challenge.friendName,
        friendAvatar: challenge.friendAvatar,
        topicName: challenge.topicName,
        operator: challenge.operator,
        difficulty: challenge.difficulty,
        gameId: challenge.gameId,
        onCancel: hideFloatingChallenge,
      ),
    );

    // Insert into overlay
    Overlay.of(context).insert(_overlayEntry!);
  }

  void hideFloatingChallenge() {
    _overlayEntry?.remove();
    _overlayEntry = null;
    _currentChallenge = null;
  }

  bool get isShowing => _overlayEntry != null;

  void dispose() {
    hideFloatingChallenge();
  }
}

class FloatingChallengeData {
  final String friendId;
  final String friendName;
  final String friendAvatar;
  final String topicName;
  final String operator;
  final String difficulty;
  final String gameId;

  FloatingChallengeData({
    required this.friendId,
    required this.friendName,
    required this.friendAvatar,
    required this.topicName,
    required this.operator,
    required this.difficulty,
    required this.gameId,
  });
}