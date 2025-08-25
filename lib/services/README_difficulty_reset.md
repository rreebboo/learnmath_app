# Difficulty Reset Feature Documentation

## Overview

The Difficulty Reset Feature allows users to change their difficulty level while preserving their account data and preventing loss of meaningful progress. This feature uses Firebase Cloud Functions for secure server-side validation and implements comprehensive progress checking to determine reset eligibility.

## Architecture

```
┌─────────────────┐    ┌──────────────────┐    ┌─────────────────┐
│   Flutter App   │    │  Cloud Functions │    │   Firestore     │
│                 │    │                  │    │                 │
│ ┌─────────────┐ │    │ ┌──────────────┐ │    │ ┌─────────────┐ │
│ │Reset Widget │ │───▶│ │checkProgress │ │───▶│ │User Data    │ │
│ └─────────────┘ │    │ └──────────────┘ │    │ └─────────────┘ │
│ ┌─────────────┐ │    │ ┌──────────────┐ │    │ ┌─────────────┐ │
│ │Reset Service│ │───▶│ │resetDifficulty│ │───▶│ │Sessions     │ │
│ └─────────────┘ │    │ └──────────────┘ │    │ └─────────────┘ │
│ ┌─────────────┐ │    │ ┌──────────────┐ │    │ ┌─────────────┐ │
│ │Preferences  │ │    │ │getHistory    │ │    │ │Archives     │ │
│ └─────────────┘ │    │ └──────────────┘ │    │ └─────────────┘ │
└─────────────────┘    └──────────────────┘    └─────────────────┘
```

## Components

### 1. Firebase Cloud Functions (`functions/index.js`)

#### `checkUserProgress`
- **Purpose**: Validates user progress to determine reset eligibility
- **Parameters**: `{ userId, currentDifficulty }`
- **Returns**: `{ hasProgress, canReset, reason, progressDetails }`
- **Progress Criteria**:
  - More than 5 completed sessions
  - More than 50 total questions answered
  - Any topic with more than 3 completed lessons
  - Total time spent > 30 minutes (1800 seconds)
  - Any achievements earned
  - More than 3 difficulty-specific sessions

#### `resetDifficultyMode`
- **Purpose**: Performs the actual difficulty reset with atomic transactions
- **Parameters**: `{ userId, newDifficulty, forceReset? }`
- **Returns**: `{ success, fromDifficulty, toDifficulty, archivedSessions }`
- **Features**:
  - Rate limiting (1 reset per hour)
  - Progress validation (unless force reset)
  - Session archiving (preserves data)
  - Atomic transactions
  - Comprehensive logging


#### `getDifficultyResetHistory`
- **Purpose**: Retrieves user's difficulty reset history
- **Parameters**: `{ userId }`
- **Returns**: `{ history: [] }`
- **Limit**: Last 10 resets

### 2. Client-Side Service (`lib/services/difficulty_reset_service.dart`)

#### Core Methods
```dart
// Check if reset is possible
Future<ProgressCheckResult> checkUserProgress({int? currentDifficulty})

// Perform difficulty reset
Future<DifficultyResetResult> resetDifficultyMode(int newDifficulty)

// Get reset history
Future<List<Map<String, dynamic>>> getDifficultyResetHistory()

// Quick eligibility check
Future<bool> quickResetEligibilityCheck()
```

#### Data Classes
```dart
class ProgressCheckResult {
  final bool hasProgress;
  final bool canReset;
  final String reason;
  final Map<String, dynamic> progressDetails;
}

class DifficultyResetResult {
  final bool success;
  final String fromDifficulty;
  final String toDifficulty;
  final int archivedSessions;
}
```

### 3. UI Components (`lib/widgets/difficulty_reset_widget.dart`)

#### `DifficultyResetWidget`
- **Purpose**: Main widget for difficulty reset interface
- **Features**:
  - Progress checking and display
  - Difficulty level selection
  - Reset confirmation
  - Error handling
  - Loading states

#### `DifficultyResetDialog`
- **Purpose**: Modal dialog wrapper for reset widget
- **Usage**: `DifficultyResetDialog.show(context)`

### 4. Security Rules (`firestore.rules`)

```javascript
// User can only reset their own difficulty
match /users/{userId} {
  allow read, write: if isOwner(userId);
  
  // Archived sessions are read-only for users
  match /archived_sessions/{sessionId} {
    allow read: if isOwner(userId);
    allow write: if false; // Only Cloud Functions
  }
  
  // Reset logs are read-only for users
  match /difficulty_resets/{resetId} {
    allow read: if isOwner(userId);
    allow write: if false; // Only Cloud Functions
  }
}
```

## Usage Examples

### Basic Reset Flow
```dart
final resetService = DifficultyResetService();

// 1. Check if reset is possible
final progressCheck = await resetService.checkUserProgress();
if (progressCheck.canReset) {
  // 2. Perform reset
  final result = await resetService.resetDifficultyMode(2); // Hard
  if (result.success) {
    print('Reset successful: ${result.fromDifficulty} → ${result.toDifficulty}');
  }
}
```

### Using the UI Widget
```dart
// In your settings screen
DifficultyResetWidget(
  onResetComplete: () {
    // Refresh UI or navigate
    setState(() {});
  },
)

// As a dialog
final result = await DifficultyResetDialog.show(context);
if (result == true) {
  // Reset was completed
}
```

### Extension Methods
```dart
final prefsService = UserPreferencesService.instance;

// Check if reset is possible
final canReset = await prefsService.canResetDifficulty();

// Reset with validation
final success = await prefsService.resetDifficultyWithValidation(1);
```

## Data Flow

### Reset Process
1. **User initiates reset** → UI widget
2. **Check progress** → Cloud Function validates eligibility
3. **Display options** → UI shows available difficulty levels
4. **User confirms** → UI sends reset request
5. **Server validation** → Cloud Function re-checks progress and rate limits
6. **Atomic reset** → Sessions archived, preferences updated, logs created
7. **Client update** → Local preferences synchronized
8. **UI feedback** → Success/error message displayed

### Progress Validation
```javascript
const progressChecks = {
  totalSessions: totalSessions >= 5,
  totalQuestions: totalQuestions >= 50,
  topicProgress: maxTopicLessons >= 3,
  timeSpent: totalTimeSpent >= 1800,
  achievements: hasAchievements,
  difficultySpecific: difficultySpecificSessions >= 3
};

const hasSignificantProgress = Object.values(progressChecks).some(check => check);
```

## Security Features

### Authentication & Authorization
- All operations require user authentication
- Users can only reset their own difficulty
- Firestore security rules enforce access control

### Rate Limiting
- Maximum 1 reset per hour per user
- Prevents spam and abuse
- Configurable time window

### Data Preservation
- Sessions are archived, not deleted
- Topic progress is preserved
- Account data remains intact
- Reset history is logged

### Audit Trail
- All resets are logged with timestamps
- User agent information captured
- Force reset flags recorded

## Error Handling

### Client-Side Errors
```dart
try {
  final result = await resetService.resetDifficultyMode(newDifficulty);
} catch (e) {
  if (e.toString().contains('Rate limit')) {
    // Show rate limit message
  } else if (e.toString().contains('Reset not allowed')) {
    // Show progress blocking message
  } else {
    // Show generic error
  }
}
```

### Server-Side Errors
- Authentication errors (401)
- Authorization errors (403)
- Rate limit errors (429)
- Validation errors (400)
- Server errors (500)

## Testing

### Unit Tests (`test/difficulty_reset_service_test.dart`)
- Progress checking logic
- Reset validation
- Error handling
- Edge cases
- Mock Firebase integration

### Test Categories
1. **Happy Path Tests**
   - Successful reset for eligible users
   - Progress checking for various scenarios
   - History retrieval

2. **Error Cases**
   - Unauthenticated users
   - Invalid difficulty levels
   - Network failures
   - Rate limiting

3. **Edge Cases**
   - Empty progress data
   - Null values
   - Boundary conditions

### Running Tests
```bash
flutter test test/difficulty_reset_service_test.dart
```

## Deployment

### Cloud Functions
```bash
cd functions
npm install
firebase deploy --only functions
```

### Security Rules
```bash
firebase deploy --only firestore:rules
```

### Client App
```bash
flutter pub get
flutter build apk --release
```

## Monitoring & Analytics

### Logging
- Function execution logs in Firebase Console
- Error tracking with stack traces
- Performance monitoring
- Usage analytics

### Metrics to Monitor
- Reset success/failure rates
- Progress threshold effectiveness
- Rate limit triggers

## Configuration

### Adjustable Parameters
```javascript
// In Cloud Functions
const PROGRESS_THRESHOLDS = {
  minSessions: 5,
  minQuestions: 50,
  minTopicLessons: 3,
  minTimeSpent: 1800, // 30 minutes
  minDifficultySpecificSessions: 3
};

const ONE_HOUR = 60 * 60 * 1000; // Rate limit window
```

### Difficulty Levels
```dart
// 0: Easy - Basic arithmetic with small numbers
// 1: Medium - Moderate complexity problems  
// 2: Hard - Advanced problems with larger numbers
```

## Troubleshooting

### Common Issues

1. **"Authentication required" error**
   - Ensure user is logged in
   - Check Firebase Auth configuration

2. **"Reset not allowed" error**
   - User has significant progress
   - Check progress thresholds
   - Consider admin override if needed

3. **"Rate limit" error**
   - User tried to reset too frequently
   - Wait for cooldown period
   - Check rate limit configuration

4. **Function timeout**
   - Large amounts of session data
   - Consider pagination for archives
   - Optimize Firestore queries

### Debug Steps
1. Check Firebase Console logs
2. Verify user authentication status
3. Test with Firebase Emulator
4. Review Firestore security rules
5. Monitor network requests

## Future Enhancements

### Potential Features
- Scheduled difficulty increases
- Progress milestone rewards
- Difficulty recommendation system
- Export archived session data
- Custom progress thresholds per user

### Performance Optimizations
- Batch operations for large datasets
- Caching for frequent checks
- Background processing for archives
- Compression for large payloads

## Support

For issues or questions regarding the Difficulty Reset Feature:
1. Check this documentation
2. Review test cases for examples
3. Check Firebase Console logs
4. Contact development team

---

*Last updated: January 2025*
*Version: 1.0.0*