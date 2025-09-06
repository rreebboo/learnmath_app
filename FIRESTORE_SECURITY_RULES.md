# Cloud Firestore Security Rules Documentation

## Overview
The updated Firestore security rules provide comprehensive protection for your LearnMath app while enabling the leaderboard functionality. These rules prevent cheating, protect user privacy, and ensure data integrity.

## Key Security Features

### 🔒 **Anti-Cheating Measures**
- **Score Protection**: Users can only increase their `totalScore`, never decrease it
- **Practice Session Limits**: Max 1000 points per session, max 50 questions
- **Time-Limited Corrections**: Updates allowed only within 5 minutes, deletes within 1 minute
- **Session Validation**: All practice sessions must have valid data structure and logical values

### 👥 **User Data Protection**
- **Own Data Access**: Users can only modify their own profile and progress
- **Leaderboard Access**: All authenticated users can read basic user info needed for leaderboards
- **Field Validation**: Strict validation on all user data fields (names, scores, streaks)
- **Immutable Fields**: Critical fields like `uid` and `createdAt` cannot be changed

### 📊 **Leaderboard Security**
- **Read Access**: All authenticated users can read user data for leaderboard display
- **Data Integrity**: Practice sessions are protected from tampering
- **Real-time Updates**: Secure access to user scores and statistics

## Rule Structure

### Users Collection (`/users/{userId}`)
```javascript
// Read: Own data + leaderboard data for others
allow read: if isAuthenticated() && (isOwner(userId) || canReadLeaderboardData());

// Create: Only own profile with valid data
allow create: if isAuthenticated() && isOwner(userId) && isValidUserData();

// Update: Own profile only, with score increase validation
allow update: if isAuthenticated() && isOwner(userId) && isValidScoreUpdate();
```

### Practice Sessions (`/users/{userId}/practice_sessions/{sessionId}`)
```javascript
// Read/Create: Only own sessions
allow read, create: if isAuthenticated() && isOwner(userId);

// Update: Only within 5 minutes (for corrections)
allow update: if isAuthenticated() && isOwner(userId) && withinTimeLimit(5min);

// Delete: Only within 1 minute (immediate corrections)
allow delete: if isAuthenticated() && isOwner(userId) && withinTimeLimit(1min);
```

### Topic Progress (`/users/{userId}/topic_progress/{topicId}`)
```javascript
// Full CRUD access for own topic progress
allow read, write: if isAuthenticated() && isOwner(userId);
```

## Validation Functions

### `isValidUserData()`
Validates user profile data:
- Name: 1-50 characters, required
- Avatar: Max 10 characters (emoji), required  
- Scores: Non-negative numbers
- Required fields: `name`, `avatar`, `totalScore`, `lessonsCompleted`, `currentStreak`

### `isValidPracticeSession()`
Validates practice session data:
- Score: 0-1000 points maximum
- Questions: 1-50 questions per session
- Correct answers ≤ total questions
- Valid topic name and timestamp

### `isValidScoreUpdate()`
Prevents score manipulation:
- Total score can only increase, never decrease
- Protects against cheating attempts

## Deployment Instructions

### 1. Deploy Rules to Firebase
```bash
# Make sure you're in the project directory
cd /path/to/your/learnmath_app

# Deploy only the Firestore rules
firebase deploy --only firestore:rules
```

### 2. Verify Deployment
```bash
# Check deployment status
firebase firestore:rules:list

# Test rules in Firebase Console
# Go to Firestore > Rules > Playground
```

### 3. Test Rules
Use the Firebase Console Rules Playground to test:

**Test Case 1: User Reading Own Data**
```javascript
// Should ALLOW
auth: {uid: 'user123'}
path: /databases/(default)/documents/users/user123
operation: read
```

**Test Case 2: User Reading Others' Data for Leaderboard**
```javascript
// Should ALLOW
auth: {uid: 'user123'}  
path: /databases/(default)/documents/users/user456
operation: read
```

**Test Case 3: User Trying to Decrease Score**
```javascript
// Should DENY
auth: {uid: 'user123'}
path: /databases/(default)/documents/users/user123
operation: update
data: {totalScore: 500} // when current score is 1000
```

## Future Extensions

### Social Features (Ready to Implement)
- **Friends System**: `/friendships/{friendshipId}` rules included
- **Battles/Challenges**: `/battles/{battleId}` rules included
- **Achievements**: Server-side only rules for `/achievements`

### Admin Features
- **App Configuration**: Read-only access for users
- **Reports System**: Users can report content, admin handles resolution
- **Achievement Awards**: Server-side Cloud Functions recommended

## Security Best Practices

### ✅ **What These Rules Prevent**
- Users modifying other users' data
- Score manipulation and cheating
- Unauthorized access to practice sessions
- Mass data deletion or corruption
- Spam or abuse through unlimited writes

### ⚠️ **Additional Recommendations**
1. **Server-Side Validation**: Implement Cloud Functions for critical operations
2. **Rate Limiting**: Add Firebase App Check for additional protection
3. **Data Backup**: Regular Firestore backups for data recovery
4. **Monitoring**: Set up Firebase Monitoring for unusual activity

## Rule Testing Checklist

Before going live, test these scenarios:

- [ ] User can read their own profile
- [ ] User can read other profiles for leaderboard
- [ ] User cannot modify other users' data
- [ ] User cannot decrease their total score
- [ ] Practice sessions have proper validation
- [ ] Time limits work for updates/deletes
- [ ] Unauthenticated users are blocked
- [ ] Invalid data is rejected

## Troubleshooting

### Common Issues
1. **Permission Denied Errors**: Check user authentication status
2. **Validation Failures**: Verify data structure matches validation functions
3. **Time Limit Issues**: Check system clock synchronization

### Debug Tips
```javascript
// Enable Firestore debug logging in your app
FirebaseFirestore.setLoggingEnabled(true);

// Check rule evaluation in Firebase Console
// Firestore > Rules > Playground
```

## Support

For issues with these security rules:
1. Check the Firebase Console for rule evaluation logs
2. Use the Rules Playground for testing specific scenarios  
3. Review the validation functions for data requirements

---

**Last Updated**: Current Date
**Rules Version**: 2
**Compatible With**: Firebase v9+ SDK