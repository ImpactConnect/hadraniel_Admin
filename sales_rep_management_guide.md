
# 👨‍💼 Sales Representative Management - Development Guide

This document provides detailed development instructions for implementing the **Sales Representative Management** feature in the **Admin Desktop App** (Flutter + Supabase + SQLite).

---

## 🎯 Objective

Enable the admin to:

- Add, view, and manage sales reps
- Assign reps to specific outlets
- Sync reps data with Supabase (auth and profiles)
- Operate offline-first with local SQLite fallback

---

## 📁 Folders to Work On

```
lib/
├── screens/
│   └── reps/
│       ├── reps_screen.dart        # Main UI
│       └── rep_form_screen.dart    # Add/Edit Rep Form
├── core/
│   ├── models/
│   │   └── rep_model.dart
│   ├── services/
│   │   ├── rep_service.dart
│   │   └── sync_service.dart
│   └── database/
│       └── db_helper.dart
```

---

## 🧱 Database Schema (SQLite)

Add to your DB init method:

```sql
CREATE TABLE IF NOT EXISTS reps (
  id TEXT PRIMARY KEY,
  full_name TEXT NOT NULL,
  email TEXT NOT NULL,
  outlet_id TEXT,
  role TEXT DEFAULT 'rep',
  created_at TEXT
);
```

---

## 📦 Supabase Tables Involved

- `auth.users` (for email/password authentication)
- `profiles` (for full_name, outlet_id, role)

---

## 🧑‍💻 UI Design

### 🧩 reps_screen.dart

- ListView of all reps
- Search bar to filter reps by name or outlet
- Button to add new rep (navigates to `rep_form_screen.dart`)

### 🧾 rep_form_screen.dart

- Fields: Full Name, Email, Outlet (Dropdown), Password (temporary)
- Validation: Ensure all fields are filled
- Submit: Saves to Supabase & local SQLite

---

## 🔌 Services

### ✅ rep_service.dart

- `Future<void> addRepLocally(Rep rep)`
- `Future<List<Rep>> getAllReps()`
- `Future<void> syncRepsToCloud()`
- `Future<void> fetchRepsFromCloud()`

### ✅ sync_service.dart

- Add methods to sync `profiles` and `auth.users` from cloud to local and vice versa

---

## 🔐 Supabase Integration

To create a user from admin in Supabase:

```dart
final res = await supabase.auth.admin.createUser(AdminUserAttributes(
  email: email,
  password: password,
  userMetadata: {
    'full_name': fullName,
  },
));
final userId = res.user?.id;

// Add to profiles
await supabase.from('profiles').insert({
  'id': userId,
  'full_name': fullName,
  'role': 'rep',
  'outlet_id': outletId,
});
```

---

## ✅ Test Cases

- [ ] Add new rep (check Supabase + local DB)
- [ ] Filter by outlet and name
- [ ] Update existing rep
- [ ] Sync reps manually
- [ ] Offline access to previously synced reps

---

## 📝 Notes

- Reps are created in both `auth.users` and `profiles`
- Make sure outlet dropdown fetches from local `outlets` table
- Store creation time for auditing
- Show sync status for each rep

---

Happy Building 🚀
