import 'package:flutter/material.dart';

class WeeklyProgress extends StatelessWidget {
  const WeeklyProgress({super.key});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text(
              'This Week',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Color(0xFF2C3E50),
              ),
            ),
            TextButton(
              onPressed: () {},
              child: const Text(
                'Leaderboard',
                style: TextStyle(
                  fontSize: 14,
                  color: Color(0xFF4285F4),
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: [
            _buildDayIndicator('S', DayStatus.completed, Colors.green),
            _buildDayIndicator('M', DayStatus.completed, Colors.green),
            _buildDayIndicator('T', DayStatus.completed, Colors.green),
            _buildDayIndicator('W', DayStatus.current, const Color(0xFFFF9800)),
            _buildDayIndicator('T', DayStatus.future, const Color(0xFF4285F4)),
            _buildDayIndicator('F', DayStatus.future, const Color(0xFF4285F4)),
            _buildDayIndicator('S', DayStatus.future, const Color(0xFF4285F4)),
          ],
        ),
      ],
    );
  }

  Widget _buildDayIndicator(String day, DayStatus status, Color color) {
    Widget child;
    
    switch (status) {
      case DayStatus.completed:
        child = const Icon(Icons.check, color: Colors.white, size: 18);
        break;
      case DayStatus.current:
        child = const Icon(Icons.star, color: Colors.white, size: 18);
        break;
      case DayStatus.future:
        child = const SizedBox();
        break;
    }

    return Column(
      children: [
        Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: status == DayStatus.future ? color.withOpacity(0.3) : color,
            shape: BoxShape.circle,
          ),
          child: Center(child: child),
        ),
        const SizedBox(height: 8),
        Text(
          day,
          style: TextStyle(
            fontSize: 12,
            color: Colors.grey[600],
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }
}

enum DayStatus { completed, current, future }