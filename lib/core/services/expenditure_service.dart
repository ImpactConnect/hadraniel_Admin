import 'package:sqflite/sqflite.dart';
import 'package:uuid/uuid.dart';
import '../database/database_helper.dart';
import '../models/expenditure_model.dart';

class ExpenditureService {
  static final ExpenditureService _instance = ExpenditureService._internal();
  factory ExpenditureService() => _instance;
  ExpenditureService._internal();

  final DatabaseHelper _dbHelper = DatabaseHelper();
  final Uuid _uuid = const Uuid();

  // Create expenditure
  Future<String> createExpenditure(Expenditure expenditure) async {
    final db = await _dbHelper.database;
    final id = expenditure.id.isEmpty ? _uuid.v4() : expenditure.id;

    final expenditureWithId = expenditure.copyWith(
      id: id,
      createdAt: DateTime.now(),
    );

    await db.insert(
      'expenditures',
      expenditureWithId.toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );

    // Add to sync queue
    await _addToSyncQueue('expenditures', id);

    return id;
  }

  // Get all expenditures
  Future<List<Expenditure>> getAllExpenditures() async {
    final db = await _dbHelper.database;
    final List<Map<String, dynamic>> maps = await db.query(
      'expenditures',
      orderBy: 'date_incurred DESC',
    );

    return List.generate(maps.length, (i) {
      return Expenditure.fromMap(maps[i]);
    });
  }

  // Get expenditures by outlet
  Future<List<Expenditure>> getExpendituresByOutlet(String outletId) async {
    final db = await _dbHelper.database;
    final List<Map<String, dynamic>> maps = await db.query(
      'expenditures',
      where: 'outlet_id = ?',
      whereArgs: [outletId],
      orderBy: 'date_incurred DESC',
    );

    return List.generate(maps.length, (i) {
      return Expenditure.fromMap(maps[i]);
    });
  }

  // Get expenditures by date range
  Future<List<Expenditure>> getExpendituresByDateRange(
    DateTime startDate,
    DateTime endDate, {
    String? outletId,
    String? category,
  }) async {
    final db = await _dbHelper.database;

    String whereClause = 'date_incurred >= ? AND date_incurred <= ?';
    List<dynamic> whereArgs = [
      startDate.toIso8601String(),
      endDate.toIso8601String(),
    ];

    if (outletId != null) {
      whereClause += ' AND outlet_id = ?';
      whereArgs.add(outletId);
    }

    if (category != null) {
      whereClause += ' AND category = ?';
      whereArgs.add(category);
    }

    final List<Map<String, dynamic>> maps = await db.query(
      'expenditures',
      where: whereClause,
      whereArgs: whereArgs,
      orderBy: 'date_incurred DESC',
    );

    return List.generate(maps.length, (i) {
      return Expenditure.fromMap(maps[i]);
    });
  }

  // Update expenditure
  Future<void> updateExpenditure(Expenditure expenditure) async {
    final db = await _dbHelper.database;

    final updatedExpenditure = expenditure.copyWith(
      updatedAt: DateTime.now(),
      isSynced: false,
    );

    await db.update(
      'expenditures',
      updatedExpenditure.toMap(),
      where: 'id = ?',
      whereArgs: [expenditure.id],
    );

    // Add to sync queue
    await _addToSyncQueue('expenditures', expenditure.id);
  }

  // Delete expenditure
  Future<void> deleteExpenditure(String id) async {
    final db = await _dbHelper.database;

    await db.delete(
      'expenditures',
      where: 'id = ?',
      whereArgs: [id],
    );

    // Add to sync queue for deletion
    await _addToSyncQueue('expenditures', id, isDelete: true);
  }

  // Get expenditure by ID
  Future<Expenditure?> getExpenditureById(String id) async {
    final db = await _dbHelper.database;
    final List<Map<String, dynamic>> maps = await db.query(
      'expenditures',
      where: 'id = ?',
      whereArgs: [id],
    );

    if (maps.isNotEmpty) {
      return Expenditure.fromMap(maps.first);
    }
    return null;
  }

  // Get expenditure analytics
  Future<Map<String, dynamic>> getExpenditureAnalytics({
    String? outletId,
    DateTime? startDate,
    DateTime? endDate,
  }) async {
    final db = await _dbHelper.database;

    String whereClause = '1=1';
    List<dynamic> whereArgs = [];

    if (outletId != null) {
      whereClause += ' AND outlet_id = ?';
      whereArgs.add(outletId);
    }

    if (startDate != null && endDate != null) {
      whereClause += ' AND date_incurred >= ? AND date_incurred <= ?';
      whereArgs.add(startDate.toIso8601String());
      whereArgs.add(endDate.toIso8601String());
    }

    // Total expenditure
    final totalResult = await db.rawQuery(
      'SELECT SUM(amount) as total FROM expenditures WHERE $whereClause',
      whereArgs,
    );
    final totalExpenditure = (totalResult.first['total'] ?? 0.0) as double;

    // Expenditure by category
    final categoryResult = await db.rawQuery(
      'SELECT category, SUM(amount) as total, COUNT(*) as count FROM expenditures WHERE $whereClause GROUP BY category ORDER BY total DESC',
      whereArgs,
    );

    // Monthly trend (last 12 months)
    final monthlyResult = await db.rawQuery(
      '''SELECT 
         strftime('%Y-%m', date_incurred) as month,
         SUM(amount) as total,
         COUNT(*) as count
         FROM expenditures 
         WHERE $whereClause AND date_incurred >= date('now', '-12 months')
         GROUP BY strftime('%Y-%m', date_incurred)
         ORDER BY month''',
      whereArgs,
    );

    // Total count
    final countResult = await db.rawQuery(
      'SELECT COUNT(*) as count FROM expenditures WHERE $whereClause',
      whereArgs,
    );
    final totalCount = (countResult.first['count'] ?? 0) as int;

    return {
      'totalExpenditure': totalExpenditure,
      'categoryBreakdown': categoryResult,
      'monthlyTrend': monthlyResult,
      'totalCount': totalCount,
    };
  }

  // Category management
  Future<void> createCategory(ExpenditureCategory category) async {
    final db = await _dbHelper.database;
    await db.insert(
      'expenditure_categories',
      category.toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<List<ExpenditureCategory>> getAllCategories() async {
    final db = await _dbHelper.database;
    final List<Map<String, dynamic>> maps = await db.query(
      'expenditure_categories',
      where: 'is_active = ?',
      whereArgs: [1],
      orderBy: 'name ASC',
    );

    return List.generate(maps.length, (i) {
      return ExpenditureCategory.fromMap(maps[i]);
    });
  }

  Future<void> initializeDefaultCategories() async {
    final categories = await getAllCategories();
    if (categories.isEmpty) {
      final defaultCategories = ExpenditureCategory.getDefaultCategories();
      for (final category in defaultCategories) {
        await createCategory(category);
      }
    }
  }

  // Helper method to add to sync queue
  Future<void> _addToSyncQueue(String tableName, String recordId,
      {bool isDelete = false}) async {
    final db = await _dbHelper.database;
    await db.insert(
      'sync_queue',
      {
        'table_name': tableName,
        'record_id': recordId,
        'is_delete': isDelete ? 1 : 0,
        'created_at': DateTime.now().toIso8601String(),
      },
    );
  }

  // Get recurring expenditures due
  Future<List<Expenditure>> getRecurringExpendituresDue() async {
    final db = await _dbHelper.database;
    final now = DateTime.now().toIso8601String();

    final List<Map<String, dynamic>> maps = await db.query(
      'expenditures',
      where: 'is_recurring = 1',
      orderBy: 'date_incurred ASC',
    );

    return List.generate(maps.length, (i) {
      return Expenditure.fromMap(maps[i]);
    });
  }

  // Process recurring expenditure
  Future<String> processRecurringExpenditure(
      Expenditure recurringExpenditure) async {
    // Create new expenditure based on recurring one
    final newExpenditure = recurringExpenditure.copyWith(
      id: _uuid.v4(),
      dateIncurred: DateTime.now(),
      createdAt: DateTime.now(),
    );

    // Create the new expenditure
    final newId = await createExpenditure(newExpenditure);

    // Update the next due date for the recurring expenditure
    DateTime nextDueDate;
    switch (recurringExpenditure.recurringFrequency) {
      case 'daily':
        nextDueDate = DateTime.now().add(const Duration(days: 1));
        break;
      case 'weekly':
        nextDueDate = DateTime.now().add(const Duration(days: 7));
        break;
      case 'monthly':
        nextDueDate = DateTime(
            DateTime.now().year, DateTime.now().month + 1, DateTime.now().day);
        break;
      case 'yearly':
        nextDueDate = DateTime(
            DateTime.now().year + 1, DateTime.now().month, DateTime.now().day);
        break;
      default:
        nextDueDate = DateTime.now().add(const Duration(days: 30));
    }

    await updateExpenditure(recurringExpenditure);

    return newId;
  }
}
