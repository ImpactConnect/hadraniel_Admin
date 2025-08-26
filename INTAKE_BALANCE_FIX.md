# Intake Balance Duplication Fix

## Problem Description
The intake balance cloud table was increasing every time a sync operation was performed using the sync button on the stock intake page. With only 94 stock records, there were over 2000 intake balance records in the cloud database, and records multiplied with each sync operation.

**UPDATE**: The sync button has been completely removed from the stock intake page to prevent this issue and centralize all sync operations through the dedicated sync page.

## Root Cause
The issue was caused by:
1. **Improper sync flow**: The sync process was calling both `syncIntakeBalancesToSupabase()` and `syncIntakeBalancesToLocalDb()` separately, causing duplicate data creation.
2. **Missing deduplication logic**: The `upsert` operations were creating new records instead of updating existing ones for the same product.
3. **Redundant balance calculations**: Intake balances were being synced separately instead of being calculated from stock intake data.

## Solution Implemented

### 1. Fixed Sync Methods
- **`syncIntakeBalancesToSupabase()`**: Now checks for existing records by `product_name` before inserting, preventing duplicates.
- **`syncIntakeBalancesToLocalDb()`**: Improved to merge cloud data with locally calculated balances, using local calculations as the source of truth.
- **Added deduplication logic**: Both methods now properly handle existing records.

### 2. Centralized Sync Flow
- **Stock Intake Screen**: Completely removed the sync button and all sync-related functionality to prevent user-initiated duplications.
- **Dedicated Sync Page**: All sync operations are now centralized through the dedicated sync page (`sync_screen.dart`).
- **Automatic balance calculation**: Intake balances are automatically recalculated from stock intake data during sync operations.
- **Prevention of duplicate syncs**: Users can no longer accidentally trigger multiple sync operations from different screens.

### 3. Database Schema Update
- **Added UNIQUE constraint**: The `product_name` field in the `intake_balances` table should be unique to prevent duplicates at the database level.

## How to Apply the Fix

### Step 1: Update Database Schema (Recommended)
Add a unique constraint to your Supabase `intake_balances` table:

```sql
ALTER TABLE public.intake_balances 
ADD CONSTRAINT intake_balances_product_name_unique 
UNIQUE (product_name);
```

### Step 2: Clean Up Existing Duplicates
Run the cleanup utility to remove existing duplicate records:

```dart
// Add this to your main app temporarily (remove after cleanup)
import 'lib/utils/cleanup_duplicates.dart';

// Call this once in your app initialization
await DuplicateCleanupUtility.cleanupDuplicateIntakeBalances();
```

### Step 3: Test the Fix
1. Perform a sync operation from the dedicated sync page (not from stock intake page - sync button has been removed)
2. Check that no duplicate records are created
3. Verify that stock intake data loads correctly without manual sync
3. Verify that intake balances are correctly calculated

## Key Changes Made

### Files Modified:
1. **`lib/core/services/sync_service.dart`**:
   - Fixed `syncIntakeBalancesToSupabase()` with deduplication logic
   - Improved `syncIntakeBalancesToLocalDb()` with proper merging
   - Added `cleanupDuplicateIntakeBalances()` utility method
   - Added `_getCalculatedBalancesFromLocal()` helper method

2. **`lib/screens/stock_intake_screen.dart`**:
   - **REMOVED**: Sync button from the AppBar actions
   - **REMOVED**: `_syncData()` method and all sync-related functionality
   - **REMOVED**: `_isSyncing` variable and sync state management
   - **REMOVED**: Redundant call to `syncIntakeBalancesToLocalDb()` in `_loadData()` method
   - Simplified data loading to rely on automatic sync from dedicated sync page

3. **`lib/utils/cleanup_duplicates.dart`** (New):
   - Utility script for cleaning up existing duplicates

## Benefits of Centralized Sync Approach

1. **Prevents User Error**: Users can no longer accidentally trigger multiple sync operations from different screens
2. **Consistent Sync Experience**: All sync operations go through the same centralized interface with proper progress tracking
3. **Reduces Complexity**: Individual screens no longer need to manage sync state and error handling
4. **Better Monitoring**: All sync operations are logged and tracked in one place
5. **Prevents Race Conditions**: Eliminates the possibility of multiple sync operations running simultaneously from different screens

## Prevention Measures
- **Single source of truth**: Intake balances are now calculated from stock intake data, not synced separately
- **Proper deduplication**: All sync methods now check for existing records before creating new ones
- **Simplified sync flow**: Reduced complexity to minimize chances of duplication
- **Database constraints**: Recommended unique constraint prevents duplicates at the database level

## Monitoring
After applying the fix:
- Monitor the `intake_balances` table size after sync operations
- Verify that each product has only one balance record
- Check that balance calculations are accurate

## Rollback Plan
If issues occur, you can:
1. Revert the code changes
2. Restore from a database backup if needed
3. Manually clean up duplicate records using the cleanup utility

The fix maintains all existing functionality while preventing the duplication issue.