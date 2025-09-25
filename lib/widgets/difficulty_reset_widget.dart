import 'package:flutter/material.dart';
import '../services/difficulty_reset_service.dart';
import '../services/user_preferences_service.dart';

class DifficultyResetWidget extends StatefulWidget {
  final VoidCallback? onResetComplete;
  
  const DifficultyResetWidget({
    super.key,
    this.onResetComplete,
  });

  @override
  State<DifficultyResetWidget> createState() => _DifficultyResetWidgetState();
}

class _DifficultyResetWidgetState extends State<DifficultyResetWidget> {
  final DifficultyResetService _resetService = DifficultyResetService();
  final UserPreferencesService _preferencesService = UserPreferencesService.instance;
  
  bool _isLoading = false;
  int _currentDifficulty = 0;
  int _selectedNewDifficulty = 0;
  ProgressCheckResult? _progressCheck;

  @override
  void initState() {
    super.initState();
    _loadCurrentSettings();
  }

  Future<void> _loadCurrentSettings() async {
    setState(() => _isLoading = true);
    
    try {
      _currentDifficulty = await _preferencesService.getSelectedDifficulty();
      _selectedNewDifficulty = _currentDifficulty;
      
      // Check if reset is possible
      _progressCheck = await _resetService.checkUserProgress(
        currentDifficulty: _currentDifficulty,
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error loading settings: $e')),
        );
      }
    }
    
    if (mounted) {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _performReset() async {
    if (_selectedNewDifficulty == _currentDifficulty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select a different difficulty level')),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      final result = await _resetService.resetDifficultyMode(_selectedNewDifficulty);
      
      if (result.success) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                'Math progress reset successful! 🎉\n'
                'Difficulty changed to ${result.toDifficulty}.\n'
                'All scores, sessions, and progress have been cleared.\n'
                'Your account and profile are safely preserved.',
              ),
              duration: const Duration(seconds: 5),
              backgroundColor: Colors.green,
            ),
          );
          
          // Refresh the current settings
          await _loadCurrentSettings();
          
          widget.onResetComplete?.call();
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Reset failed: $e'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 5),
          ),
        );
      }
    }

    if (mounted) {
      setState(() => _isLoading = false);
    }
  }

  Widget _buildProgressInfo() {
    if (_progressCheck == null) return const SizedBox.shrink();

    return Card(
      margin: const EdgeInsets.all(16),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Progress Check',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              _resetService.formatResetReason(_progressCheck!.reason, _progressCheck!.canReset),
              style: TextStyle(
                color: _progressCheck!.canReset ? Colors.green : Colors.orange,
              ),
            ),
            if (_progressCheck!.progressDetails.isNotEmpty) ...[
              const SizedBox(height: 12),
              Text(
                'Current Progress:',
                style: Theme.of(context).textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                _resetService.formatProgressSummary(_progressCheck!.progressDetails),
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildDifficultySelector() {
    return Card(
      margin: const EdgeInsets.all(16),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Select New Difficulty Level',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              'Current: ${_resetService.getDifficultyString(_currentDifficulty).toUpperCase()}',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                fontWeight: FontWeight.w500,
                color: Colors.blue,
              ),
            ),
            const SizedBox(height: 16),
            ...List.generate(3, (index) {
              final isSelected = _selectedNewDifficulty == index;
              final isCurrent = _currentDifficulty == index;
              
              return ListTile(
                title: Text(
                  _resetService.getDifficultyString(index).toUpperCase(),
                  style: TextStyle(
                    fontWeight: isCurrent ? FontWeight.bold : FontWeight.normal,
                    color: isCurrent ? Colors.blue : null,
                  ),
                ),
                subtitle: Text(
                  _resetService.getDifficultyDescription(index),
                ),
                leading: Radio<int>(
                  value: index,
                  groupValue: _selectedNewDifficulty,
                  onChanged: (value) {
                    if (value != null) {
                      setState(() => _selectedNewDifficulty = value);
                    }
                  },
                ),
                selected: isSelected,
                onTap: () {
                  setState(() => _selectedNewDifficulty = index);
                },
              );
            }),
          ],
        ),
      ),
    );
  }

  Widget _buildResetButton() {
    final canReset = _progressCheck?.canReset ?? false;
    final isDifferentDifficulty = _selectedNewDifficulty != _currentDifficulty;
    final isEnabled = canReset && isDifferentDifficulty && !_isLoading;

    return Container(
      width: double.infinity,
      margin: const EdgeInsets.all(16),
      child: ElevatedButton(
        onPressed: isEnabled ? _performReset : null,
        style: ElevatedButton.styleFrom(
          backgroundColor: isEnabled ? Colors.orange : Colors.grey,
          padding: const EdgeInsets.symmetric(vertical: 16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
        child: _isLoading
            ? const SizedBox(
                height: 20,
                width: 20,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                ),
              )
            : Text(
                'Reset Math Progress',
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
      ),
    );
  }

  Widget _buildWarningCard() {
    if (_progressCheck?.canReset != false) return const SizedBox.shrink();

    return Card(
      margin: const EdgeInsets.all(16),
      color: Colors.orange.shade50,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Icon(
              Icons.warning_amber_rounded,
              color: Colors.orange,
              size: 48,
            ),
            const SizedBox(height: 8),
            Text(
              'Reset Not Available',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
                color: Colors.orange,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'You have made significant progress in your current difficulty level. '
              'Resetting would archive your current sessions. Consider continuing '
              'with your current progress or contact support for assistance.',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyMedium,
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        if (_isLoading && _progressCheck == null)
          const Center(
            child: Padding(
              padding: EdgeInsets.all(32),
              child: CircularProgressIndicator(),
            ),
          )
        else ...[
          _buildProgressInfo(),
          if (_progressCheck?.canReset == true) ...[
            _buildDifficultySelector(),
            _buildResetButton(),
          ] else
            _buildWarningCard(),
        ],
      ],
    );
  }
}

/// Dialog widget for difficulty reset
class DifficultyResetDialog extends StatelessWidget {
  const DifficultyResetDialog({super.key});

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Reset Difficulty Level'),
      content: SizedBox(
        width: double.maxFinite,
        child: SingleChildScrollView(
          child: DifficultyResetWidget(
            onResetComplete: () {
              Navigator.of(context).pop(true);
            },
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(false),
          child: const Text('Cancel'),
        ),
      ],
    );
  }

  /// Shows the difficulty reset dialog
  static Future<bool?> show(BuildContext context) {
    return showDialog<bool>(
      context: context,
      builder: (context) => const DifficultyResetDialog(),
    );
  }
}