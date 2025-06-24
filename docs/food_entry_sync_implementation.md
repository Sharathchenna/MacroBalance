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
