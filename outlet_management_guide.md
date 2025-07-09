
# 🏬 Outlet Management Development Guide

This document outlines the detailed step-by-step process for implementing the **Outlet Management** feature in the Admin Desktop App (Flutter + Supabase + SQLite).

---

## 📌 Feature Overview

The Outlet Management section allows the admin to:

- View all registered outlets
- Add new outlets
- Edit existing outlet details
- Delete outlets (optional)
- Sync outlet data from Supabase (cloud) to local SQLite database
- View outlet-specific details (e.g., location, assigned reps)

All operations are **offline-first** with cloud sync capability.

---

## 📁 Required Tables

### Supabase Table: `outlets`

```sql
create table outlets (
  id uuid primary key default gen_random_uuid(),
  name text not null,
  location text,
  created_at timestamp default now()
);
```

### SQLite Local Table: `outlets`

```sql
CREATE TABLE outlets (
  id TEXT PRIMARY KEY,
  name TEXT NOT NULL,
  location TEXT,
  created_at TEXT
);
```

---

## 🛠 Development Steps

### 1. 📦 Create Model

```dart
class Outlet {
  final String id;
  final String name;
  final String? location;
  final DateTime createdAt;

  Outlet({
    required this.id,
    required this.name,
    this.location,
    required this.createdAt,
  });

  factory Outlet.fromJson(Map<String, dynamic> json) => Outlet(
    id: json['id'],
    name: json['name'],
    location: json['location'],
    createdAt: DateTime.parse(json['created_at']),
  );

  Map<String, dynamic> toMap() => {
    'id': id,
    'name': name,
    'location': location,
    'created_at': createdAt.toIso8601String(),
  };

  factory Outlet.fromMap(Map<String, dynamic> map) => Outlet(
    id: map['id'],
    name: map['name'],
    location: map['location'],
    createdAt: DateTime.parse(map['created_at']),
  );
}
```

### 2. 💽 Local DB Integration

In your `DatabaseHelper`:

```dart
Future<void> insertOutlet(Outlet outlet) async {
  final db = await database;
  await db.insert('outlets', outlet.toMap(), conflictAlgorithm: ConflictAlgorithm.replace);
}

Future<List<Outlet>> getOutlets() async {
  final db = await database;
  final maps = await db.query('outlets');
  return maps.map((map) => Outlet.fromMap(map)).toList();
}
```

### 3. ☁️ Supabase Sync Logic

In your `SyncService`:

```dart
Future<void> syncOutlets() async {
  final response = await supabase.from('outlets').select();
  if (response.isNotEmpty) {
    for (var outlet in response) {
      final outletModel = Outlet.fromJson(outlet);
      await dbHelper.insertOutlet(outletModel);
    }
  }
}
```

### 4. 🖼 UI Implementation

#### Screen: `outlets_screen.dart`

- ListView showing outlet name and location
- Search bar to filter by name/location
- Sync button to fetch latest outlets
- Add New Outlet button (opens dialog/form)
- Edit option via popup menu

#### Example Card Widget

```dart
ListTile(
  title: Text(outlet.name),
  subtitle: Text(outlet.location ?? 'No location'),
  trailing: IconButton(icon: Icon(Icons.edit), onPressed: () {
    // Show edit form
  }),
)
```

---

## ✅ Deliverables

- [x] Outlet model created
- [x] Local table created and initialized
- [x] Supabase sync logic implemented
- [x] Outlet list view created
- [x] Add/Edit outlet form implemented
- [x] Sync button functional

---

## 📌 Notes

- Admin can add/edit outlets offline
- New outlets added offline are pushed to Supabase when sync is triggered
- Duplicate checks should be done using outlet name or ID

---

## 🚀 Next Step

Proceed to implement **Product Management Page** once outlet management is working as expected.
