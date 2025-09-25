import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/services.dart';

class GameSoundService {
  static final GameSoundService _instance = GameSoundService._internal();
  factory GameSoundService() => _instance;
  GameSoundService._internal();

  late AudioPlayer _effectsPlayer;
  late AudioPlayer _backgroundPlayer;
  bool _soundEnabled = true;
  bool _musicEnabled = true;

  Future<void> initialize() async {
    _effectsPlayer = AudioPlayer();
    _backgroundPlayer = AudioPlayer();

    // Configure audio players
    await _effectsPlayer.setReleaseMode(ReleaseMode.release);
    await _backgroundPlayer.setReleaseMode(ReleaseMode.loop);
  }

  void dispose() {
    _effectsPlayer.dispose();
    _backgroundPlayer.dispose();
  }

  // Sound effect methods
  Future<void> playButtonClick() async {
    if (!_soundEnabled) return;
    HapticFeedback.selectionClick();
    // Using system sounds as fallback since we don't have audio assets
    SystemSound.play(SystemSoundType.click);
  }

  Future<void> playCorrectAnswer() async {
    if (!_soundEnabled) return;
    HapticFeedback.lightImpact();
    // Create a sequence of haptics for positive feedback
    await Future.delayed(const Duration(milliseconds: 50));
    HapticFeedback.lightImpact();
  }

  Future<void> playWrongAnswer() async {
    if (!_soundEnabled) return;
    HapticFeedback.heavyImpact();
  }

  Future<void> playVictory() async {
    if (!_soundEnabled) return;
    // Victory sequence
    for (int i = 0; i < 3; i++) {
      HapticFeedback.lightImpact();
      await Future.delayed(const Duration(milliseconds: 150));
    }
  }

  Future<void> playDefeat() async {
    if (!_soundEnabled) return;
    HapticFeedback.heavyImpact();
    await Future.delayed(const Duration(milliseconds: 100));
    HapticFeedback.mediumImpact();
  }

  Future<void> playBattleStart() async {
    if (!_soundEnabled) return;
    HapticFeedback.heavyImpact();
    await Future.delayed(const Duration(milliseconds: 100));
    HapticFeedback.lightImpact();
  }

  Future<void> playScoreIncrease() async {
    if (!_soundEnabled) return;
    HapticFeedback.selectionClick();
  }

  Future<void> playHeartLoss() async {
    if (!_soundEnabled) return;
    HapticFeedback.heavyImpact();
  }

  Future<void> playTimeWarning() async {
    if (!_soundEnabled) return;
    HapticFeedback.mediumImpact();
  }

  Future<void> playCombo() async {
    if (!_soundEnabled) return;
    // Combo feedback - multiple quick haptics
    for (int i = 0; i < 2; i++) {
      HapticFeedback.lightImpact();
      await Future.delayed(const Duration(milliseconds: 50));
    }
  }

  // Background music methods
  Future<void> playBattleMusic() async {
    if (!_musicEnabled) return;
    // Background music would go here if we had audio assets
  }

  Future<void> stopBattleMusic() async {
    await _backgroundPlayer.stop();
  }

  // Settings
  void setSoundEnabled(bool enabled) {
    _soundEnabled = enabled;
  }

  void setMusicEnabled(bool enabled) {
    _musicEnabled = enabled;
    if (!enabled) {
      stopBattleMusic();
    }
  }

  bool get soundEnabled => _soundEnabled;
  bool get musicEnabled => _musicEnabled;
}