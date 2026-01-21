import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:io';
import 'dart:convert';
import 'package:path_provider/path_provider.dart';
import '../database/database_helper.dart';

class AppHealthService {
  final DatabaseHelper _dbHelper = DatabaseHelper();
  
  Future<AppHealthReport> runStartupDiagnostics() async {
    final List<String> issues = [];
    final List<String> fixes = [];
    
    // 1. Check SharedPreferences
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.getString('health_check');
      await prefs.setString('health_check', DateTime.now().toIso8601String());
    } catch (e) {
      issues.add('SharedPreferences access failed');
      debugPrint('SharedPreferences diagnostic failed: $e');
    }
    
    // 2. Check Database
    try {
      final db = await _dbHelper.database;
      await db.rawQuery('SELECT 1');
      
      // Check integrity
      final isHealthy = await _dbHelper.checkDatabaseIntegrity();
      if (!isHealthy) {
        issues.add('Database integrity compromised');
        try {
          await _dbHelper.repairDatabase();
          fixes.add('Database repaired successfully');
        } catch (e) {
          debugPrint('Database repair failed: $e');
        }
      }
    } catch (e) {
      issues.add('Database not accessible');
      debugPrint('Database diagnostic failed: $e');
    }
    
    // 3. Check custom products
    try {
      final prefs = await SharedPreferences.getInstance();
      final products = prefs.getStringList('custom_products');
      
      if (products == null) {
        // Try restore from backup
        final backupRestored = await _restoreFromBackup();
        if (backupRestored) {
          fixes.add('Custom products restored from backup');
        }
      }
    } catch (e) {
      issues.add('Custom products check failed');
      debugPrint('Custom products diagnostic failed: $e');
      
      // Try restore from backup
      final backupRestored = await _restoreFromBackup();
      if (backupRestored) {
        fixes.add('Custom products restored from backup after error');
      }
    }
    
    return AppHealthReport(
      issues: issues,
      fixes: fixes,
      isHealthy: issues.isEmpty,
    );
  }
  
  Future<bool> _restoreFromBackup() async {
    try {
      final directory = await getApplicationDocumentsDirectory();
      final file = File('${directory.path}/custom_products_backup.json');
      
      if (await file.exists()) {
        final contents = await file.readAsString();
        final List<dynamic> decoded = jsonDecode(contents);
        final products = decoded.cast<String>();
        
        debugPrint('Restored ${products.length} products from backup');
        
        // Restore to SharedPreferences
        final prefs = await SharedPreferences.getInstance();
        await prefs.setStringList('custom_products', products);
        
        return true;
      }
    } catch (e) {
      debugPrint('Restore from backup failed: $e');
    }
    
    return false;
  }
}

class AppHealthReport {
  final List<String> issues;
  final List<String> fixes;
  final bool isHealthy;
  
  AppHealthReport({
    required this.issues,
    required this.fixes,
    required this.isHealthy,
  });
  
  bool get needsUserNotification => issues.isNotEmpty || fixes.isNotEmpty;
  
  String get summary {
    if (fixes.isNotEmpty) {
      return 'App recovered from ${fixes.length} issue(s) after unexpected shutdown.\n\nFixed:\n${fixes.map((f) => '• $f').join('\n')}';
    } else if (issues.isNotEmpty) {
      return 'Detected ${issues.length} issue(s). Some features may be limited.\n\nIssues:\n${issues.map((i) => '• $i').join('\n')}';
    } else {
      return 'App is healthy';
    }
  }
}
