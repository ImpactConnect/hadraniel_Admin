
# 🧩 Phase 2: Local Database Setup & Sync for User Profiles

## 🎯 Objective

Set up a **local SQLite database** to store user profile data (Admin and Reps), fetched from Supabase after the first login with internet. This enables **offline-first authentication**, profile access, and role-based UI rendering.

---

## 🗂️ Step-by-Step Instructions

### 1. ✅ Create the Local SQLite Database Setup

Use `sqflite_common_ffi` for desktop. Create a singleton `DatabaseHelper` class.

```dart
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:path/path.dart';

class DatabaseHelper {
  static final DatabaseHelper _instance = DatabaseHelper._internal();
  factory DatabaseHelper() => _instance;
  DatabaseHelper._internal();

  static Database? _db;

  Future<Database> get database async {
    if (_db != null) return _db!;
    _db = await _initDb();
    return _db!;
  }

  Future<Database> _initDb() async {
    sqfliteFfiInit();
    var databaseFactory = databaseFactoryFfi;
    final path = join(await databaseFactory.getDatabasesPath(), 'admin_app.db');
    return await databaseFactory.openDatabase(path, options: OpenDatabaseOptions(
      version: 1,
      onCreate: _onCreate,
    ));
  }

  Future<void> _onCreate(Database db, int version) async {
    await db.execute('''
      CREATE TABLE profiles (
        id TEXT PRIMARY KEY,
        outlet_id TEXT,
        full_name TEXT NOT NULL,
        role TEXT DEFAULT 'rep',
        created_at TEXT
      );
    ''');
  }
}
```

---

### 2. 🧱 Define Profile Model

```dart
class Profile {
  final String id;
  final String? outletId;
  final String fullName;
  final String role;
  final String? createdAt;

  Profile({
    required this.id,
    this.outletId,
    required this.fullName,
    required this.role,
    this.createdAt,
  });

  factory Profile.fromMap(Map<String, dynamic> json) => Profile(
    id: json['id'],
    outletId: json['outlet_id'],
    fullName: json['full_name'],
    role: json['role'],
    createdAt: json['created_at'],
  );

  Map<String, dynamic> toMap() => {
    'id': id,
    'outlet_id': outletId,
    'full_name': fullName,
    'role': role,
    'created_at': createdAt,
  };
}
```

---

### 3. 🔁 Sync Profiles from Supabase

```dart
import 'package:supabase_flutter/supabase_flutter.dart';
import '../database/database_helper.dart';
import '../../models/profile_model.dart';

class SyncService {
  final supabase = Supabase.instance.client;

  Future<void> syncProfilesToLocalDb() async {
    final db = await DatabaseHelper().database;
    final response = await supabase.from('profiles').select();
    for (var row in response) {
      final profile = Profile.fromMap(row);
      await db.insert(
        'profiles',
        profile.toMap(),
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
    }
  }
}
```

---

### 4. 📲 Offline Access Logic

```dart
Future<Profile?> getLocalUserProfile(String userId) async {
  final db = await DatabaseHelper().database;
  final maps = await db.query(
    'profiles',
    where: 'id = ?',
    whereArgs: [userId],
  );
  if (maps.isNotEmpty) {
    return Profile.fromMap(maps.first);
  }
  return null;
}
```

---

### 5. 🧪 Test Case Checklist

| ✅ Task | Description |
|--------|-------------|
| 🔐 First login | Authenticate online, then call `syncProfilesToLocalDb()` |
| 🔄 Sync success | Profiles fetched and inserted into local DB |
| 🚫 Offline mode | App fetches profile data from local DB |
| 🧪 Validation | Print profile list, check row count matches Supabase |

---

### 📂 Optional Tables to Prepare Now

- `outlets`
- `local_auth`
- `sync_logs`

---

### ✅ Summary

| Feature | Implementation |
|--------|----------------|
| Local DB | `sqflite_common_ffi` |
| Table | `profiles` |
| Model | `Profile` class |
| Sync | Pull from Supabase, store locally |
| Offline | Fetch user profile from local DB |
| Test | Logs and row checks |
