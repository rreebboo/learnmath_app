import 'package:flutter/material.dart';

class GoalItem extends StatelessWidget {
  final String title;
  final bool isCompleted;
  final double? progress;
  final String? progressText;

  const GoalItem({
    super.key,
    required this.title,
    required this.isCompleted,
    this.progress,
    this.progressText,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(
              width: 24,
              height: 24,
              decoration: BoxDecoration(
                color: isCompleted ? const Color(0xFF34A853) : Colors.transparent,
                shape: BoxShape.circle,
                border: isCompleted
                    ? null
                    : Border.all(color: const Color(0xFF6C757D), width: 2),
              ),
              child: isCompleted
                  ? const Icon(
                      Icons.check,
                      color: Colors.white,
                      size: 16,
                    )
                  : Center(
                      child: Container(
                        width: 8,
                        height: 8,
                        decoration: const BoxDecoration(
                          color: Color(0xFF4285F4),
                          shape: BoxShape.circle,
                        ),
                      ),
                    ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                title,
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w500,
                  color: const Color(0xFF2C3E50),
                  decoration: isCompleted ? TextDecoration.lineThrough : null,
                ),
              ),
            ),
            if (!isCompleted && progressText != null)
              Text(
                progressText!,
                style: const TextStyle(
                  fontSize: 12,
                  color: Color(0xFF6C757D),
                  fontWeight: FontWeight.w500,
                ),
              ),
          ],
        ),
        if (!isCompleted && progress != null) ...[
          const SizedBox(height: 8),
          Padding(
            padding: const EdgeInsets.only(left: 36),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(
                value: progress,
                backgroundColor: Colors.grey[200],
                valueColor: const AlwaysStoppedAnimation<Color>(Color(0xFF4285F4)),
                minHeight: 6,
              ),
            ),
          ),
        ],
      ],
    );
  }
}