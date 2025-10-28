import 'package:sqflite/sqflite.dart';

class DatabaseMigrationV15 {
  /// Apply performance indexes for marketer-related tables
  static Future<void> applyMigration(Database db) async {
    print('Applying Database Migration v15: Marketer table indexes');
    await db.transaction((txn) async {
      final List<String> indexSqls = [
        // marketers indexes
        'CREATE INDEX IF NOT EXISTS idx_marketers_outlet_id ON marketers(outlet_id)',
        'CREATE INDEX IF NOT EXISTS idx_marketers_status ON marketers(status)',
        'CREATE INDEX IF NOT EXISTS idx_marketers_created_at ON marketers(created_at)',
        'CREATE INDEX IF NOT EXISTS idx_marketers_outlet_status ON marketers(outlet_id, status)',

        // marketer_targets indexes
        'CREATE INDEX IF NOT EXISTS idx_marketer_targets_marketer_id ON marketer_targets(marketer_id)',
        'CREATE INDEX IF NOT EXISTS idx_marketer_targets_product_id ON marketer_targets(product_id)',
        'CREATE INDEX IF NOT EXISTS idx_marketer_targets_outlet_id ON marketer_targets(outlet_id)',
        'CREATE INDEX IF NOT EXISTS idx_marketer_targets_status ON marketer_targets(status)',
        'CREATE INDEX IF NOT EXISTS idx_marketer_targets_created_at ON marketer_targets(created_at)',
        'CREATE INDEX IF NOT EXISTS idx_marketer_targets_period ON marketer_targets(start_date, end_date)',
        'CREATE INDEX IF NOT EXISTS idx_marketer_targets_marketer_product ON marketer_targets(marketer_id, product_id)'
      ];

      for (final sql in indexSqls) {
        try {
          await txn.execute(sql);
        } catch (e) {
          print('Warning: Could not create index during v15: $e');
          // Continue creating other indexes
        }
      }
    });
    print('Database Migration v15 completed successfully');
  }

  /// Verify critical indexes exist on marketers and marketer_targets
  static Future<bool> verifyMigration(Database db) async {
    try {
      final marketersIndexes =
          await db.rawQuery("PRAGMA index_list(marketers)");
      final targetsIndexes =
          await db.rawQuery("PRAGMA index_list(marketer_targets)");
      final hasMarketersOutletIdx = marketersIndexes
          .any((idx) => idx['name'] == 'idx_marketers_outlet_id');
      final hasTargetsMarketerIdx = targetsIndexes
          .any((idx) => idx['name'] == 'idx_marketer_targets_marketer_id');
      return hasMarketersOutletIdx && hasTargetsMarketerIdx;
    } catch (e) {
      print('Error verifying migration v15: $e');
      return false;
    }
  }
}
