import 'dart:io';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:path/path.dart';

void main() async {
  try {
    print('Starting database initialization test...');

    // Initialize SQLite for Windows
    if (Platform.isWindows || Platform.isLinux) {
      print('Initializing SQLite FFI for Windows/Linux...');
      sqfliteFfiInit();
    }

    print('Getting database path...');
    final databasePath = await databaseFactoryFfi.getDatabasesPath();
    final path = join(databasePath, 'test_admin_app.db');
    print('Database path: $path');

    // Ensure the database directory exists
    final directory = Directory(databasePath);
    if (!await directory.exists()) {
      await directory.create(recursive: true);
      print('Created database directory: $databasePath');
    }

    print('Attempting to open database...');
    final db = await databaseFactoryFfi.openDatabase(
      path,
      options: OpenDatabaseOptions(
        version: 1,
        onCreate: (db, version) async {
          print('Creating test table...');
          await db.execute('''
            CREATE TABLE test_table (
              id INTEGER PRIMARY KEY,
              name TEXT NOT NULL
            )
          ''');
        },
      ),
    );

    print('Database opened successfully!');

    // Test inserting data
    await db.insert('test_table', {'name': 'Test Entry'});
    print('Test data inserted successfully!');

    // Test querying data
    final result = await db.query('test_table');
    print('Query result: $result');

    await db.close();
    print('Database test completed successfully!');

    // Clean up test database
    await databaseFactoryFfi.deleteDatabase(path);
    print('Test database cleaned up.');
  } catch (e, stackTrace) {
    print('Database initialization failed:');
    print('Error: $e');
    print('Stack trace: $stackTrace');
  }
}
