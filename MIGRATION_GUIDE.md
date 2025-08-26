# Migration Guide: Enhanced Sync Service

This guide helps you migrate from the original `SyncService` to the new `EnhancedSyncService` with atomic transactions, retry mechanisms, and database backup features.

## Overview

The enhanced sync service is designed to be **backward compatible** with existing code while providing additional robust features. You can migrate gradually or all at once.

## Migration Strategies

### Strategy 1: Gradual Migration (Recommended)

Start by using the hybrid approach for critical operations while keeping existing sync for less critical data.

#### Step 1: Add Enhanced Sync Service

```dart
// Add to your existing service imports
import 'package:hadraniel_admin/core/services/enhanced_sync_service.dart';
import 'package:hadraniel_admin/core/services/sync_integration_example.dart';

// In your sync management class
class SyncManager {
  final SyncService _originalSync = SyncService();
  final EnhancedSyncService _enhancedSync = EnhancedSyncService();
  final SyncIntegrationExample _integration = SyncIntegrationExample();
  
  // Your existing methods remain unchanged
  Future<void> syncAll() async {
    await _originalSync.syncAll(); // Still works!
  }
}
```

#### Step 2: Migrate Critical Operations

Replace critical sync operations with enhanced versions:

```dart
// BEFORE: Original sales sync
await syncService.syncSalesToLocalDb();

// AFTER: Enhanced sales sync with atomic transactions and backup
await enhancedSyncService.syncSalesToLocalDbEnhanced();
```

```dart
// BEFORE: Original products sync
await syncService.syncProductsToLocalDb();

// AFTER: Enhanced products sync with atomic transactions and backup
await enhancedSyncService.syncProductsToLocalDbEnhanced();
```

#### Step 3: Add Retry Mechanism

```dart
// BEFORE: Basic sync queue processing
await syncService.processSyncQueue();

// AFTER: Enhanced sync queue with retry mechanism
await enhancedSyncService.processSyncQueueWithRetry();
```

#### Step 4: Add Backup and Monitoring

```dart
// Add backup before critical operations
Future<void> performCriticalSync() async {
  try {
    // Create backup before sync
    await enhancedSyncService.createDatabaseBackup();
    
    // Perform enhanced sync
    await enhancedSyncService.syncSalesToLocalDbEnhanced();
    await enhancedSyncService.syncProductsToLocalDbEnhanced();
    
    // Monitor results
    final stats = await enhancedSyncService.getSyncQueueStats();
    print('Sync completed. Failed items: ${stats['failed']}');
    
  } catch (e) {
    // Restore from backup on failure
    final backups = await enhancedSyncService.getAvailableBackups();
    if (backups.isNotEmpty) {
      await enhancedSyncService.restoreDatabaseFromBackup(backups.first);
    }
    rethrow;
  }
}
```

### Strategy 2: Complete Migration

Replace all sync operations with enhanced versions:

```dart
// BEFORE: Complete original sync
class SyncManager {
  final SyncService _syncService = SyncService();
  
  Future<void> performFullSync() async {
    await _syncService.syncAll();
  }
}

// AFTER: Complete enhanced sync
class SyncManager {
  final EnhancedSyncService _enhancedSync = EnhancedSyncService();
  
  Future<void> performFullSync() async {
    await _enhancedSync.syncAllEnhanced();
  }
}
```

### Strategy 3: Hybrid Approach (Best of Both)

Use enhanced sync for critical data and original sync for others:

```dart
class SyncManager {
  final SyncService _originalSync = SyncService();
  final EnhancedSyncService _enhancedSync = EnhancedSyncService();
  
  Future<void> performHybridSync() async {
    try {
      // Backup before starting
      await _enhancedSync.createDatabaseBackup();
      
      // Process sync queue with retry first
      await _enhancedSync.processSyncQueueWithRetry();
      
      // Enhanced sync for critical data
      await _enhancedSync.syncSalesToLocalDbEnhanced();
      await _enhancedSync.syncProductsToLocalDbEnhanced();
      
      // Original sync for other data
      await _originalSync.syncProfilesToLocalDb();
      await _originalSync.syncOutletsToLocalDb();
      await _originalSync.syncCustomersToLocalDb();
      
      // Final sync queue processing
      await _enhancedSync.processSyncQueueWithRetry();
      
      // Cleanup old backups
      await _enhancedSync.cleanupOldBackups();
      
    } catch (e) {
      // Restore from backup on failure
      final backups = await _enhancedSync.getAvailableBackups();
      if (backups.isNotEmpty) {
        await _enhancedSync.restoreDatabaseFromBackup(backups.first);
      }
      rethrow;
    }
  }
}
```

## Code Migration Examples

### 1. Basic Sync Operation

```dart
// BEFORE
class DataSyncService {
  final SyncService _sync = SyncService();
  
  Future<void> syncData() async {
    try {
      await _sync.syncAll();
      print('Sync completed');
    } catch (e) {
      print('Sync failed: $e');
    }
  }
}

// AFTER
class DataSyncService {
  final EnhancedSyncService _enhancedSync = EnhancedSyncService();
  
  Future<void> syncData() async {
    try {
      await _enhancedSync.syncAllEnhanced();
      print('Enhanced sync completed');
      
      // Monitor sync queue
      final stats = await _enhancedSync.getSyncQueueStats();
      if (stats['failed']! > 0) {
        print('Warning: ${stats['failed']} items failed to sync');
      }
    } catch (e) {
      print('Enhanced sync failed: $e');
      
      // Check for failed items and retry
      final failedItems = await _enhancedSync.getFailedSyncItems();
      if (failedItems.isNotEmpty) {
        print('Retrying ${failedItems.length} failed items...');
        await _enhancedSync.retryAllFailedSyncItems();
      }
    }
  }
}
```

### 2. Sales Sync with Error Handling

```dart
// BEFORE
Future<void> syncSalesData() async {
  try {
    await syncService.syncSalesToLocalDb();
  } catch (e) {
    print('Sales sync failed: $e');
    // Manual retry or error handling
  }
}

// AFTER
Future<void> syncSalesData() async {
  try {
    // Create backup before critical operation
    await enhancedSyncService.createDatabaseBackup();
    
    // Enhanced sync with atomic transactions
    await enhancedSyncService.syncSalesToLocalDbEnhanced();
    
    print('Sales sync completed successfully');
  } catch (e) {
    print('Sales sync failed: $e');
    
    // Automatic backup restoration
    final backups = await enhancedSyncService.getAvailableBackups();
    if (backups.isNotEmpty) {
      await enhancedSyncService.restoreDatabaseFromBackup(backups.first);
      print('Database restored from backup');
    }
    
    // Retry mechanism is built-in
    rethrow;
  }
}
```

### 3. Sync Queue Management

```dart
// BEFORE
Future<void> processPendingSync() async {
  try {
    await syncService.processSyncQueue();
  } catch (e) {
    print('Sync queue processing failed: $e');
    // Manual handling required
  }
}

// AFTER
Future<void> processPendingSync() async {
  try {
    // Enhanced processing with automatic retry
    await enhancedSyncService.processSyncQueueWithRetry();
    
    // Get detailed statistics
    final stats = await enhancedSyncService.getSyncQueueStats();
    print('Processed: ${stats['total']} items, Failed: ${stats['failed']}');
    
    // Handle failed items
    if (stats['failed']! > 0) {
      final failedItems = await enhancedSyncService.getFailedSyncItems();
      for (var item in failedItems) {
        print('Failed: ${item['table_name']}:${item['record_id']} - ${item['error_message']}');
      }
    }
  } catch (e) {
    print('Enhanced sync queue processing failed: $e');
  }
}
```

## Database Migration

The database will automatically upgrade to version 10 when you first use the enhanced sync service. No manual intervention required.

### What Gets Added:

1. **sync_queue table enhancements:**
   - `failed_attempts` column
   - `error_message` column
   - `last_retry_at` column

2. **Database optimizations:**
   - WAL mode enabled
   - Foreign key constraints enabled
   - Performance optimizations

### Verification:

```dart
// Check if migration was successful
final enhancedSync = EnhancedSyncService();
final stats = await enhancedSync.getSyncQueueStats();
print('Enhanced sync service ready: ${stats.isNotEmpty}');
```

## Testing Your Migration

### 1. Smoke Test

```dart
import 'package:hadraniel_admin/core/services/enhanced_sync_test.dart';

Future<void> testMigration() async {
  final test = EnhancedSyncTest();
  
  // Run basic functionality test
  await test.runSmokeTest();
  
  print('Migration test completed successfully!');
}
```

### 2. Gradual Testing

```dart
// Test enhanced sync alongside original sync
Future<void> testBothSyncMethods() async {
  final originalSync = SyncService();
  final enhancedSync = EnhancedSyncService();
  
  try {
    // Test original sync still works
    await originalSync.syncProfilesToLocalDb();
    print('✓ Original sync still functional');
    
    // Test enhanced sync works
    await enhancedSync.syncSalesToLocalDbEnhanced();
    print('✓ Enhanced sync functional');
    
    print('Both sync methods working correctly!');
  } catch (e) {
    print('Migration test failed: $e');
  }
}
```

## Rollback Plan

If you need to rollback the migration:

### 1. Code Rollback

```dart
// Simply revert to original sync calls
// ENHANCED (to rollback)
await enhancedSyncService.syncAllEnhanced();

// ORIGINAL (rollback to)
await syncService.syncAll();
```

### 2. Database Rollback

```dart
// Use backup restoration if needed
final enhancedSync = EnhancedSyncService();
final backups = await enhancedSync.getAvailableBackups();

if (backups.isNotEmpty) {
  // Restore from backup before migration
  await enhancedSync.restoreDatabaseFromBackup(backups.last);
  print('Database restored to pre-migration state');
}
```

## Performance Considerations

### Expected Changes:

1. **Slightly slower sync** (2-5% overhead) due to:
   - Atomic transactions
   - Backup creation
   - Enhanced logging

2. **Better reliability** due to:
   - Automatic retry mechanisms
   - Data integrity checks
   - Backup and restore capabilities

3. **Additional storage** for:
   - Database backups (5 files max)
   - Enhanced sync queue metadata

### Optimization Tips:

```dart
// Optimize backup frequency
if (isCriticalOperation) {
  await enhancedSync.createDatabaseBackup();
}

// Cleanup backups regularly
await enhancedSync.cleanupOldBackups();

// Monitor sync queue size
final stats = await enhancedSync.getSyncQueueStats();
if (stats['total']! > 1000) {
  // Consider clearing old failed items
  await enhancedSync.clearFailedSyncItems();
}
```

## Troubleshooting Migration Issues

### Common Issues:

1. **"Column already exists" errors**
   - These are expected and handled automatically
   - The migration includes error handling for existing columns

2. **Performance degradation**
   - Check backup file sizes
   - Monitor sync queue buildup
   - Consider hybrid approach for less critical data

3. **Sync failures after migration**
   - Check network connectivity
   - Verify Supabase credentials
   - Review failed sync items for patterns

### Debug Commands:

```dart
// Check migration status
final stats = await enhancedSync.getSyncQueueStats();
print('Migration status: ${stats.isNotEmpty ? "Complete" : "Pending"}');

// Check for issues
final failedItems = await enhancedSync.getFailedSyncItems();
if (failedItems.isNotEmpty) {
  print('Found ${failedItems.length} failed items after migration');
}

// Validate data integrity
final validator = DataValidationService();
final issues = await validator.checkReferentialIntegrity();
print('Data integrity issues: ${issues.length}');
```

## Support and Next Steps

### After Migration:

1. **Monitor sync performance** for the first few days
2. **Check backup file sizes** and cleanup frequency
3. **Review failed sync items** regularly
4. **Consider implementing monitoring dashboards**

### Getting Help:

- Review the `ENHANCED_SYNC_README.md` for detailed documentation
- Use `enhanced_sync_test.dart` for testing functionality
- Check `sync_integration_example.dart` for usage patterns

### Future Enhancements:

The enhanced sync service is designed to be extensible. Future versions may include:
- Real-time sync monitoring
- Advanced conflict resolution
- Sync performance analytics
- Custom retry strategies

This migration guide ensures a smooth transition to the enhanced sync service while maintaining system stability and data integrity.