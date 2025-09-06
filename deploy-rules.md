# Deploy Firestore Security Rules

## Quick Deploy Commands

### Deploy Rules Only
```bash
firebase deploy --only firestore:rules
```

### Deploy Everything
```bash
firebase deploy
```

### Check Current Rules
```bash
firebase firestore:rules:list
```

## Testing Your Rules

### 1. Firebase Console Testing
1. Go to [Firebase Console](https://console.firebase.google.com)
2. Select your project
3. Navigate to **Firestore Database > Rules**
4. Click **Rules Playground**

### 2. Test Cases for Leaderboard

**✅ Should ALLOW: User reading leaderboard data**
```
Authenticated: Yes
Auth UID: user123
Path: /users/user456
Operation: read
```

**✅ Should ALLOW: User updating own score (increase)**
```
Authenticated: Yes  
Auth UID: user123
Path: /users/user123
Operation: update
Data: {"totalScore": 1200} // when current is 1000
```

**❌ Should DENY: User decreasing own score**
```
Authenticated: Yes
Auth UID: user123  
Path: /users/user123
Operation: update
Data: {"totalScore": 800} // when current is 1000
```

**❌ Should DENY: User modifying others' data**
```
Authenticated: Yes
Auth UID: user123
Path: /users/user456  
Operation: update
Data: {"totalScore": 9999}
```

### 3. Practice Session Tests

**✅ Should ALLOW: Creating own practice session**
```
Authenticated: Yes
Auth UID: user123
Path: /users/user123/practice_sessions/session1
Operation: create
Data: {
  "topic": "addition",
  "score": 100,
  "totalQuestions": 10,
  "correctAnswers": 8,
  "completedAt": "2024-01-01T10:00:00Z"
}
```

**❌ Should DENY: Invalid practice session (too many points)**
```
Authenticated: Yes
Auth UID: user123
Path: /users/user123/practice_sessions/session1  
Operation: create
Data: {
  "topic": "addition",
  "score": 2000, // Exceeds 1000 limit
  "totalQuestions": 10,
  "correctAnswers": 8,
  "completedAt": "2024-01-01T10:00:00Z"
}
```

## Rule Validation

Your rules are working correctly if:

- ✅ Authenticated users can read any user's basic info (for leaderboard)
- ✅ Users can only modify their own data  
- ✅ Scores can only increase, never decrease
- ✅ Practice sessions have proper validation limits
- ✅ Unauthenticated requests are denied
- ✅ Time limits work for corrections

## Emergency Rollback

If rules cause issues:

```bash
# Revert to previous rules
firebase firestore:rules:release --revision=PREVIOUS_REVISION_ID

# Or deploy permissive rules temporarily  
# (Update firestore.rules to be more permissive, then deploy)
```

## Monitoring

After deployment, monitor:
- Firebase Console > Firestore > Usage tab
- Look for permission denied errors
- Check app functionality, especially leaderboard loading