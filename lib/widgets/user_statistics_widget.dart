import 'package:flutter/material.dart';
import '../services/user_statistics_service.dart';

class UserStatisticsWidget extends StatefulWidget {
  const UserStatisticsWidget({super.key});

  @override
  State<UserStatisticsWidget> createState() => _UserStatisticsWidgetState();
}

class _UserStatisticsWidgetState extends State<UserStatisticsWidget> {
  final UserStatisticsService _statsService = UserStatisticsService();
  bool isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadStats();
  }

  Future<void> _loadStats() async {
    await _statsService.loadStatistics();
    if (mounted) {
      setState(() {
        isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (isLoading) {
      return const Center(
        child: CircularProgressIndicator(),
      );
    }

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            const Color(0xFF5B9EF3).withValues(alpha: 0.1),
            const Color(0xFF7ED321).withValues(alpha: 0.1),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: const Color(0xFF5B9EF3).withValues(alpha: 0.2),
          width: 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.analytics,
                color: const Color(0xFF5B9EF3),
                size: 24,
              ),
              const SizedBox(width: 8),
              const Text(
                'Your Statistics',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF2C3E50),
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          
          // Overview Stats
          Row(
            children: [
              Expanded(
                child: _buildStatCard(
                  'Sessions',
                  _statsService.totalSessions.toString(),
                  Icons.play_circle_outline,
                  const Color(0xFF5B9EF3),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _buildStatCard(
                  'Accuracy',
                  '${(_statsService.overallAccuracy * 100).round()}%',
                  Icons.track_changes,
                  const Color(0xFF7ED321),
                ),
              ),
            ],
          ),
          
          const SizedBox(height: 10),
          
          Row(
            children: [
              Expanded(
                child: _buildStatCard(
                  'Streak',
                  _statsService.currentStreak.toString(),
                  Icons.local_fire_department,
                  const Color(0xFFFF6B6B),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _buildStatCard(
                  'Total Score',
                  _statsService.totalScore.toString(),
                  Icons.emoji_events,
                  const Color(0xFFFFA500),
                ),
              ),
            ],
          ),
          
          const SizedBox(height: 20),
          
          // Topic Performance
          if (_statsService.topicStats.isNotEmpty) ...[
            const Text(
              'Topic Performance',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: Color(0xFF2C3E50),
              ),
            ),
            const SizedBox(height: 12),
            ..._statsService.topicStats.entries.map((entry) => 
              _buildTopicPerformance(entry.key, entry.value)
            ),
          ],
          
          const SizedBox(height: 20),
          
          // Difficulty Breakdown
          if (_statsService.difficultyStats.isNotEmpty) ...[
            const Text(
              'Difficulty Breakdown',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: Color(0xFF2C3E50),
              ),
            ),
            const SizedBox(height: 12),
            ..._statsService.difficultyStats.entries.map((entry) => 
              _buildDifficultyPerformance(entry.key, entry.value)
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildStatCard(String label, String value, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: color.withValues(alpha: 0.1),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        children: [
          Icon(icon, color: color, size: 24),
          const SizedBox(height: 8),
          Text(
            value,
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              color: Colors.grey[600],
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTopicPerformance(String topic, TopicStats stats) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: Colors.grey[200]!,
          width: 1,
        ),
      ),
      child: Row(
        children: [
          Icon(
            _getTopicIcon(topic),
            color: _getTopicColor(topic),
            size: 20,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  topic.toUpperCase(),
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF2C3E50),
                  ),
                ),
                Text(
                  '${stats.sessions} sessions • ${(stats.accuracy * 100).round()}% accuracy',
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey[600],
                  ),
                ),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Row(
                mainAxisSize: MainAxisSize.min,
                children: List.generate(5, (index) => Icon(
                  Icons.star,
                  size: 12,
                  color: index < stats.bestStars ? Colors.amber : Colors.grey[300],
                )),
              ),
              const SizedBox(height: 2),
              Text(
                '${stats.totalScore} pts',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  color: _getTopicColor(topic),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildDifficultyPerformance(String difficulty, DifficultyStats stats) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: _getDifficultyColor(difficulty).withValues(alpha: 0.3),
          width: 1,
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 8,
            height: 40,
            decoration: BoxDecoration(
              color: _getDifficultyColor(difficulty),
              borderRadius: BorderRadius.circular(4),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${difficulty.toUpperCase()} LEVEL',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: _getDifficultyColor(difficulty),
                  ),
                ),
                Text(
                  '${stats.sessions} sessions • ${(stats.accuracy * 100).round()}% accuracy',
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey[600],
                  ),
                ),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                '${stats.totalScore}',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: _getDifficultyColor(difficulty),
                ),
              ),
              Text(
                'points',
                style: TextStyle(
                  fontSize: 10,
                  color: Colors.grey[600],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  IconData _getTopicIcon(String topic) {
    switch (topic.toLowerCase()) {
      case 'addition':
        return Icons.add;
      case 'subtraction':
        return Icons.remove;
      case 'multiplication':
        return Icons.close;
      case 'division':
        return Icons.more_horiz;
      default:
        return Icons.calculate;
    }
  }

  Color _getTopicColor(String topic) {
    switch (topic.toLowerCase()) {
      case 'addition':
        return const Color(0xFF7ED321);
      case 'subtraction':
        return const Color(0xFFFFA500);
      case 'multiplication':
        return const Color(0xFFE91E63);
      case 'division':
        return const Color(0xFFFF6B6B);
      default:
        return const Color(0xFF5B9EF3);
    }
  }

  Color _getDifficultyColor(String difficulty) {
    switch (difficulty.toLowerCase()) {
      case 'easy':
        return const Color(0xFF7ED321);
      case 'medium':
        return const Color(0xFFFFA500);
      case 'hard':
        return const Color(0xFFFF6B6B);
      default:
        return const Color(0xFF5B9EF3);
    }
  }
}