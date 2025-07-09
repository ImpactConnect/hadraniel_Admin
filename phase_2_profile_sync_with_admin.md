# 📄 Phase 2: User Profile Sync (Admin Support Included)

## ✅ Objective
Enable the Admin Flutter Desktop App to fetch user profile data from Supabase and store it locally for offline-first functionality. Now updated to support **admin** roles.

---

## 🧱 Tables Involved

### Supabase Table: `profiles`
```sql
create table profiles (
  id uuid primary key references auth.users(id) on delete cascade,
  outlet_id uuid references outlets(id) on delete set null,
  full_name text not null,
  role text default 'rep', -- Can be 'rep' or 'admin'
  created_at timestamp default now()
);
```

### Local SQLite Table: `profiles`
```sql
CREATE TABLE profiles (
  id TEXT PRIMARY KEY,
  outlet_id TEXT,
  full_name TEXT NOT NULL,
  role TEXT DEFAULT 'rep',
  created_at TEXT
);
```

> 🔒 Admin accounts should have `role = 'admin'`

---

## 🔄 Sync Logic

1. On first successful login:
   - Authenticate the admin via Supabase Auth.
   - Fetch the admin's profile record from the `profiles` table.
   - Store the record locally in the `profiles` SQLite table.

2. Store other profile records (including reps) for use in other features like:
   - Assigning reps to outlets
   - Viewing outlet reps
   - Role-based UI

---

## 🧠 Role-Based Access Logic

In your Dart `Profile` model:

```dart
bool get isAdmin => role.toLowerCase() == 'admin';
```

In the UI:
```dart
if (currentUserProfile.isAdmin) {
  // Show Admin-only dashboards and privileges
}
```

> You can restrict rep users from viewing or accessing administrative functionality.

---

## ✅ What to Test

- [x] Admin login is saved locally.
- [x] Admin profile has `role = 'admin'`.
- [x] Admin-exclusive features are visible only when `role == 'admin'`.
- [x] Other reps have limited access.

---

## 🚀 Next Step

Once role-based profile syncing is complete and verified, proceed to **Phase 3: Dashboard UI and Data Views**.