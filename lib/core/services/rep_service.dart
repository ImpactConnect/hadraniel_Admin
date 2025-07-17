import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import '../models/rep_model.dart';
import '../database/database_helper.dart';

class RepService {
  final supabase = Supabase.instance.client;
  final DatabaseHelper _dbHelper = DatabaseHelper();

  Future<void> addRepLocally(Rep rep) async {
    try {
      final db = await _dbHelper.database;
      await db.insert(
        'reps',
        rep.toMap(),
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
    } catch (e) {
      print('Error adding rep locally: $e');
      throw e;
    }
  }

  Future<List<Rep>> getAllReps() async {
    try {
      final db = await _dbHelper.database;
      final results = await db.query('reps');
      return results.map((map) => Rep.fromMap(map)).toList();
    } catch (e) {
      print('Error getting all reps: $e');
      return [];
    }
  }

  Future<void> syncRepsToCloud() async {
    try {
      final reps = await getAllReps();
      for (var rep in reps) {
        await supabase.from('profiles').upsert({
          'id': rep.id,
          'full_name': rep.fullName,
          'email': rep.email,
          'outlet_id': rep.outletId,
          'role': rep.role,
          'created_at': rep.createdAt,
        });
      }
    } catch (e) {
      print('Error syncing reps to cloud: $e');
      throw e;
    }
  }

  Future<void> fetchRepsFromCloud() async {
    try {
      final response = await supabase
          .from('profiles')
          .select()
          .eq('role', 'rep');

      final reps = (response as List).map((data) => Rep.fromMap(data)).toList();

      final db = await _dbHelper.database;
      await db.transaction((txn) async {
        // Clear existing reps
        await txn.delete('reps');
        // Insert new reps
        for (var rep in reps) {
          await txn.insert(
            'reps',
            rep.toMap(),
            conflictAlgorithm: ConflictAlgorithm.replace,
          );
        }
      });
    } catch (e) {
      print('Error fetching reps from cloud: $e');
      throw e;
    }
  }

  Future<Rep?> createRep({
    required String fullName,
    required String email,
    required String password,
    String? outletId,
  }) async {
    try {
      // Create user in Supabase Auth
      final authResponse = await supabase.auth.signUp(
        email: email,
        password: password,
        data: {'full_name': fullName, 'role': 'rep'},
      );

      if (authResponse.user == null) throw 'Failed to create user';

      final rep = Rep(
        id: authResponse.user!.id,
        fullName: fullName,
        email: email,
        outletId: outletId,
        role: 'rep',
        createdAt: DateTime.now().toIso8601String(),
      );

      // Add to profiles table with correct schema
      await supabase.from('profiles').insert({
        'id': rep.id,
        'outlet_id': rep.outletId,
        'full_name': rep.fullName,
        'role': rep.role,
        'created_at': rep.createdAt,
      });

      // Add to local database
      await addRepLocally(rep);

      return rep;
    } catch (e) {
      print('Error creating rep: $e');
      throw e; // Re-throw to handle in UI
    }
  }

  Future<bool> updateRep(Rep rep) async {
    try {
      // Update in Supabase
      await supabase.from('profiles').update(rep.toMap()).eq('id', rep.id);

      // Update locally
      await addRepLocally(rep);
      return true;
    } catch (e) {
      print('Error updating rep: $e');
      return false;
    }
  }

  Future<bool> deleteRep(String id) async {
    try {
      // Delete from Supabase
      await supabase.from('profiles').delete().eq('id', id);

      // Delete from local database
      final db = await _dbHelper.database;
      await db.delete('reps', where: 'id = ?', whereArgs: [id]);

      return true;
    } catch (e) {
      print('Error deleting rep: $e');
      return false;
    }
  }
}
