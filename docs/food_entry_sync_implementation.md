# Food Entry Daily Sync Implementation

## Overview
Re-enabled food entry synchronization with Supabase that runs automatically once per day at midnight. This ensures user data is backed up to the cloud while minimizing sync frequency to reduce server load and battery usage.

## Key Features

### 1. **Daily Automatic Sync**
- Syncs food entries to Supabase every day at midnight
- Prevents duplicate syncing on the same day
- Automatically schedules the next day's sync

### 2. **Manual Sync Option**
- Users can manually trigger a sync from the Account Dashboard
- Shows sync status (Never synced, Sync needed, Up to date)
- Provides feedback on sync success/failure

### 3. **Sync State Tracking**
- Tracks last sync date in local storage
- Shows visual indicators in the UI
- Prevents unnecessary sync operations

## Technical Implementation

### FoodEntryProvider Changes
- Added `_dailySyncTimer` for scheduling midnight sync
- Added `_lastFoodEntrySyncDate` to track last sync
- Added `_syncFoodEntriesToSupabase()` method for cloud sync
- Added `_performDailySync()` for midnight automation
- Added `forceFoodEntrySync()` for manual sync
- Added `needsSync` and `lastSyncDate` getters for UI

### Account Dashboard UI
- Added "Data & Sync" section showing sync status
- Visual indicators: 
  - Orange cloud icon for "needs sync"
  - Green check for "up to date"
- Manual sync with loading indicator and feedback

### Sync Process
1. **Initialization**: Set up timer to next midnight on app start
2. **Daily Execution**: At midnight, sync all local food entries to Supabase
3. **Batch Processing**: Syncs in batches of 50 entries to avoid overwhelming database
4. **Error Handling**: Graceful error handling with user feedback
5. **State Update**: Updates last sync date and reschedules next sync

## Data Flow

```
User Login → Provider Initialization → Schedule Midnight Sync
     ↓
Midnight Timer → Check if already synced today → Sync to Supabase
     ↓
Update last sync date → Schedule next midnight → Complete
```

## Manual Sync Flow

```
User taps sync → Show loading → Call forceFoodEntrySync() → 
Update UI → Show success/error message
```

## Storage Keys
- `last_food_entry_sync_date`: Stores the last successful sync timestamp

## Database Schema
Uses existing `food_entries` table in Supabase with:
- `user_id`: Links entries to authenticated user
- `synced_at`: Timestamp when entry was synced to cloud
- All existing FoodEntry fields (id, food data, quantity, etc.)

## Benefits
1. **Automatic Backup**: No user intervention required
2. **Minimal Resource Usage**: Only syncs once daily
3. **Offline-First**: App works fully offline, syncs when possible
4. **User Control**: Manual sync option for immediate backup
5. **Visual Feedback**: Clear sync status in UI
6. **Cross-Device Sync**: Data available across user's devices

## Future Enhancements
1. **Bidirectional Sync**: Download cloud entries on login
2. **Conflict Resolution**: Handle data conflicts between devices
3. **Selective Sync**: Sync only recent/modified entries
4. **Background Sync**: Sync when app is backgrounded
5. **Sync Settings**: User-configurable sync frequency

# Food Entry Data Persistence Fix

## Issue Description
Food entries (like adding "egg to breakfast") were disappearing when the app was closed and reopened. This was causing significant data loss for users.

## Root Cause Analysis
The issue was in the `FoodEntryProvider` initialization and data loading flow:

1. **During app startup**: The `_initialize()` method was calling `_entries.clear()`, which removed all food entries from memory
2. **During user authentication**: `loadEntriesForCurrentUser()` was called, but the entries had already been cleared
3. **During storage loading**: `loadEntries()` would set `_entries = []` when no data was found in storage, even if entries existed in memory
4. **Authentication timing issue**: `loadEntriesForCurrentUser()` was calling `clearUserData()` when `currentUser` was null due to Supabase auth timing issues during app startup
5. **Result**: Any food entries added during the previous session were permanently lost

## Solution Implementation

### 1. Fixed Provider Initialization
- Modified `_initialize()` to NOT clear food entries during normal app startup
- Only clear the date cache, not the actual food entries
- Food entries should only be cleared during user logout, not during normal initialization

### 2. Fixed Data Loading Logic
- Modified `loadEntries()` to preserve existing entries in memory when no storage data is found
- Modified `_loadEntriesFromJson()` to only replace entries when actual data is loaded from storage
- Added proper logging to track the data loading process

### 3. Fixed Authentication Timing Issue
- Modified `loadEntriesForCurrentUser()` to NOT call `clearUserData()` when user is null
- Instead, preserve existing data and load from local storage during authentication delays
- This prevents data loss during Supabase authentication timing issues on app startup

### 4. Preserved Data Integrity
- Entries now persist between app sessions as expected
- Local storage is still used for persistence
- No data loss during normal app usage or authentication timing issues

## Code Changes Made

### In `_initialize()`:
```dart
// BEFORE (caused data loss):
_entries.clear();

// AFTER (preserves data):
// Clear cache but NOT entries - entries should persist between app sessions
await _clearDateCache();
```

### In `loadEntries()`:
```dart
// BEFORE (cleared entries):
_entries = []; // when no storage data found

// AFTER (preserves entries):
// Don't clear existing entries - they might have been added during this session
```

### In `_loadEntriesFromJson()`:
```dart
// BEFORE (always replaced entries):
_entries = decodedList.map(...).toList();

// AFTER (only replaces when data exists):
if (loadedEntries.isNotEmpty) {
  _entries = loadedEntries;
} else {
  // Keep existing entries
}
```

### In `loadEntriesForCurrentUser()`:
```dart
// BEFORE (cleared data on null user):
if (user == null) {
  await clearUserData();
  return;
}

// AFTER (preserves data during auth timing issues):
if (user == null) {
  debugPrint("[Provider Load] User not logged in. Preserving existing data and skipping cloud sync.");
  await loadEntries();
  _initialLoadComplete = true;
  notifyListeners();
  return;
}
```

## Testing
To test the fix:
1. Add a food entry (e.g., "egg" to breakfast)
2. Close the app completely
3. Reopen the app
4. Verify the food entry is still present

## Impact
This fix ensures that:
- Food entries persist between app sessions
- No data loss during normal app usage
- No data loss during authentication timing issues
- Proper initialization without clearing user data
- Maintained backwards compatibility with existing storage format
