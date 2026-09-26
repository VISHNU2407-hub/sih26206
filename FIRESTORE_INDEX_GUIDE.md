# Firestore Composite Index Setup

## Issue
The Community Posts queries require composite indexes on the `posts` collection.
Without these indexes, Firestore will fail to execute the queries and the posts
page will show blank/error states.

## Required Indexes

### 1. Community Posts Feed (by Village + Mandal)
Used by the **Posts** tab in the Community Posts screen to show posts from
the user's local area.

**Collection:** `posts`

**Fields:**
1. `userVillage` - Ascending
2. `userMandal` - Ascending
3. `createdAt` - Descending

**Query:**
```dart
_firestore
    .collection('posts')
    .where('userVillage', isEqualTo: village)
    .where('userMandal', isEqualTo: mandal)
    .orderBy('createdAt', descending: true)
    .snapshots();
```

### 2. My Posts (by User ID)
Used by the **My Posts** tab to show only the current user's posts.

**Collection:** `posts`

**Fields:**
1. `userId` - Ascending
2. `createdAt` - Descending

**Query:**
```dart
_firestore
    .collection('posts')
    .where('userId', isEqualTo: userId)
    .orderBy('createdAt', descending: true)
    .snapshots();
```

### 3. Posts by Village (standalone)
Used by other screens that filter posts solely by village.

**Collection:** `posts`

**Fields:**
1. `userVillage` - Ascending
2. `createdAt` - Descending

**Query:**
```dart
_firestore
    .collection('posts')
    .where('userVillage', isEqualTo: village)
    .orderBy('createdAt', descending: true)
    .snapshots();
```

## Steps to Create Indexes

### Option A: Deploy via Firebase CLI (Recommended)

```bash
# Install Firebase CLI if you haven't already
npm install -g firebase-tools

# Login to Firebase
firebase login

# Deploy indexes
firebase deploy --only firestore:indexes
```

### Option B: Create Manually in Firebase Console

1. Go to [Firebase Console](https://console.firebase.google.com/)
2. Select your project
3. Go to **Firestore Database** → **Indexes** tab
4. Click **Add Index**
5. Configure each index as listed above
6. Click **Create**
7. Wait for indexes to build (usually takes a few minutes)

## Troubleshooting

If the index error persists after creating the indexes:

1. **Verify field names match exactly:**
   - Firestore fields: `userVillage`, `userMandal`, `userId`, `createdAt`
   - Note: these are **not** the same as the legacy user model field mapping
     (where Firestore `village` = user `mandal` and Firestore `street` = user `village`)

2. **Verify index configuration:**
   - Equality fields (`userVillage`, `userMandal`, `userId`) must be Ascending
   - `createdAt` must be Descending

3. **Wait for index build:**
   - Index creation can take 1-5 minutes
   - Check index status is "Enabled" before testing

4. **Check for offline persistence:**
   - The app enables Firestore offline persistence for emergency use
   - If the network is unavailable, cached data will be shown instead

## Verification

After creating the indexes, the Community Posts page should load correctly on
both the **Posts** tab and **My Posts** tab.
