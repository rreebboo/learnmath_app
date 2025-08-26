import 'package:shared_preferences/shared_preferences.dart';
import '../models/math_topic.dart';

class ProgressionService {
  static const String _unlockedTopicsKey = 'unlocked_topics';
  static const String _perfectScoresKey = 'perfect_scores';
  
  static ProgressionService? _instance;
  static ProgressionService get instance {
    return _instance ??= ProgressionService._();
  }
  
  ProgressionService._();
  
  // Check if a perfect score (100% accuracy) unlocks the next topic
  Future<bool> checkPerfectScore(String topicId, String difficulty, double accuracy) async {
    if (accuracy < 1.0) return false; // Must be perfect score
    
    final prefs = await SharedPreferences.getInstance();
    
    // Store perfect score record
    List<String> perfectScores = prefs.getStringList(_perfectScoresKey) ?? [];
    String scoreKey = '${topicId}_$difficulty';
    
    if (!perfectScores.contains(scoreKey)) {
      perfectScores.add(scoreKey);
      await prefs.setStringList(_perfectScoresKey, perfectScores);
      return true; // New perfect score achieved
    }
    
    return false; // Already had perfect score
  }
  
  // Get perfect scores for a topic across all difficulties
  Future<Set<String>> getPerfectScoresForTopic(String topicId) async {
    final prefs = await SharedPreferences.getInstance();
    List<String> perfectScores = prefs.getStringList(_perfectScoresKey) ?? [];
    
    Set<String> topicPerfectScores = {};
    for (String score in perfectScores) {
      if (score.startsWith('${topicId}_')) {
        String difficulty = score.split('_').last;
        topicPerfectScores.add(difficulty);
      }
    }
    
    return topicPerfectScores;
  }
  
  // Check if a topic should be unlocked based on perfect scores in previous topic
  Future<bool> shouldUnlockTopic(String topicId, List<MathTopic> allTopics) async {
    // Find the current topic index
    int currentIndex = allTopics.indexWhere((t) => t.id == topicId);
    if (currentIndex <= 0) return true; // First topic is always unlocked
    
    // Check if previous topic has perfect scores in at least one difficulty
    String previousTopicId = allTopics[currentIndex - 1].id;
    Set<String> perfectScores = await getPerfectScoresForTopic(previousTopicId);
    
    return perfectScores.isNotEmpty; // Unlock if any perfect score exists
  }
  
  // Get unlocked topics
  Future<Set<String>> getUnlockedTopics() async {
    final prefs = await SharedPreferences.getInstance();
    List<String> unlockedList = prefs.getStringList(_unlockedTopicsKey) ?? [];
    return unlockedList.toSet();
  }
  
  // Set unlocked topics
  Future<void> setUnlockedTopics(Set<String> unlockedTopics) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(_unlockedTopicsKey, unlockedTopics.toList());
  }
  
  // Update progression after a session
  Future<Map<String, dynamic>> updateProgression(
    String topicId, 
    String difficulty, 
    double accuracy,
    List<MathTopic> allTopics
  ) async {
    Map<String, dynamic> result = {
      'perfectScore': false,
      'newTopicUnlocked': false,
      'unlockedTopicId': null,
    };
    
    // Check for perfect score
    bool newPerfectScore = await checkPerfectScore(topicId, difficulty, accuracy);
    result['perfectScore'] = newPerfectScore;
    
    // If perfect score, check if next topic should be unlocked
    if (newPerfectScore) {
      int currentIndex = allTopics.indexWhere((t) => t.id == topicId);
      if (currentIndex >= 0 && currentIndex < allTopics.length - 1) {
        String nextTopicId = allTopics[currentIndex + 1].id;
        
        // Check if next topic should be unlocked
        bool shouldUnlock = await shouldUnlockTopic(nextTopicId, allTopics);
        if (shouldUnlock) {
          Set<String> unlockedTopics = await getUnlockedTopics();
          if (!unlockedTopics.contains(nextTopicId)) {
            unlockedTopics.add(nextTopicId);
            await setUnlockedTopics(unlockedTopics);
            
            result['newTopicUnlocked'] = true;
            result['unlockedTopicId'] = nextTopicId;
          }
        }
      }
    }
    
    return result;
  }
  
  // Apply progression rules to topic list
  Future<List<MathTopic>> applyProgressionRules(List<MathTopic> topics) async {
    Set<String> unlockedTopics = await getUnlockedTopics();
    
    List<MathTopic> updatedTopics = [];
    
    for (int i = 0; i < topics.length; i++) {
      MathTopic topic = topics[i];
      bool isUnlocked = topic.isUnlocked;
      
      // First topic is always unlocked
      if (i == 0) {
        isUnlocked = true;
        unlockedTopics.add(topic.id);
      } else {
        // Check if this topic should be unlocked
        isUnlocked = unlockedTopics.contains(topic.id) || 
                    await shouldUnlockTopic(topic.id, topics);
      }
      
      // Get perfect scores for this topic to calculate stars
      Set<String> perfectScores = await getPerfectScoresForTopic(topic.id);
      int stars = perfectScores.length; // 1 star per difficulty with perfect score
      int completedLessons = perfectScores.isNotEmpty ? 1 : 0;
      
      updatedTopics.add(topic.copyWith(
        isUnlocked: isUnlocked,
        stars: stars,
        completedLessons: completedLessons,
      ));
    }
    
    // Update unlocked topics in storage
    await setUnlockedTopics(unlockedTopics);
    
    return updatedTopics;
  }
  
  // Reset all progression (for testing or new users)
  Future<void> resetProgression() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_unlockedTopicsKey);
    await prefs.remove(_perfectScoresKey);
  }

  // Reset progression and start fresh (only keeps first topic unlocked)
  Future<void> resetToBeginning() async {
    final prefs = await SharedPreferences.getInstance();
    
    // Clear all perfect scores
    await prefs.remove(_perfectScoresKey);
    
    // Reset unlocked topics to only the first topic (addition)
    Set<String> defaultUnlocked = {'addition'};
    await setUnlockedTopics(defaultUnlocked);
  }

  // Check if user has any progress
  Future<bool> hasAnyProgress() async {
    final prefs = await SharedPreferences.getInstance();
    List<String> perfectScores = prefs.getStringList(_perfectScoresKey) ?? [];
    Set<String> unlockedTopics = await getUnlockedTopics();
    
    // User has progress if they have perfect scores OR more than just the first topic unlocked
    return perfectScores.isNotEmpty || unlockedTopics.length > 1;
  }

  // Get current progress summary
  Future<Map<String, dynamic>> getProgressSummary() async {
    Set<String> unlockedTopics = await getUnlockedTopics();
    final prefs = await SharedPreferences.getInstance();
    List<String> perfectScores = prefs.getStringList(_perfectScoresKey) ?? [];
    
    return {
      'unlockedTopicsCount': unlockedTopics.length,
      'perfectScoresCount': perfectScores.length,
      'hasProgress': await hasAnyProgress(),
      'unlockedTopics': unlockedTopics.toList(),
      'perfectScores': perfectScores,
    };
  }
}