import '../core/services/sync_service.dart';

/// Utility script to clean up duplicate intake balance records in Supabase
///
/// This script should be run once to remove the existing duplicate records
/// that were created due to the sync issue.
///
/// Usage:
/// 1. Import this file in your main app
/// 2. Call cleanupDuplicateIntakeBalances() once
/// 3. Remove this call after cleanup is complete
class DuplicateCleanupUtility {
  static final SyncService _syncService = SyncService();

  /// Cleans up duplicate intake balance records in Supabase
  ///
  /// This method:
  /// - Fetches all intake balance records from Supabase
  /// - Groups them by product_name
  /// - Keeps only the most recent record for each product
  /// - Deletes all duplicate records
  static Future<void> cleanupDuplicateIntakeBalances() async {
    try {
      print('=== DUPLICATE CLEANUP UTILITY ===');
      print('This will remove duplicate intake balance records from Supabase.');
      print('Only the most recent record for each product will be kept.');
      print('');

      await _syncService.cleanupDuplicateIntakeBalances();

      print('');
      print('=== CLEANUP COMPLETED ===');
      print('You can now remove this cleanup call from your code.');
    } catch (e) {
      print('=== CLEANUP FAILED ===');
      print('Error: $e');
      print(
          'Please check your internet connection and Supabase configuration.');
    }
  }
}
