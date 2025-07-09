# 🚀 Phase 3: Admin Dashboard and UI Implementation

## 🎯 Objective
Build the core Admin UI and dashboard functionalities for managing users, outlets, products, and synced data from outlets. This includes both online and offline support with local DB fallback.

---

## ✅ Features to Implement in This Phase

### 1. 🧭 Admin Dashboard Overview Page

- Summary Cards:
  - Total Sales Reps
  - Total Outlets
  - Total Products
  - Total Sales
- Low Stock Alert Section
- Navigation Sidebar (fixed)
  - Dashboard
  - Reps
  - Outlets
  - Products
  - Sales
  - Stock Balance
  - Customers
  - Sync
  - Settings
  - Logout

### 2. 🧑‍💼 Reps Management Screen
- List all reps with `full_name`, `email`, `assigned outlet`
- Add New Rep (create Supabase account, assign outlet)
- Edit Rep Info (except email)
- Filter/Search reps by outlet

### 3. 🏬 Outlets Management Screen
- List all outlets: `name`, `location`, `created_at`
- Add New Outlet
- Edit Outlet

### 4. 🛒 Products Management Screen
- View all products
- Add new product and assign to outlet(s)
- Filter by outlet, unit, product name

### 5. 🔄 Sync Screen
- Manual sync button to pull latest:
  - Profiles
  - Outlets
  - Products
  - Sales
  - Customers
  - Stock balances
- Show last sync time and status

---

## 🛠️ Development Steps

### Step 1: Setup Navigation
- Implement `Sidebar` with named routes
- Setup all route placeholders for screens

### Step 2: Dashboard Widgets
- Create metric cards using `Card` or custom widgets
- Create responsive layout (use `Wrap`, `GridView`, or `LayoutBuilder`)

### Step 3: Reps UI + Logic
- Fetch reps from local DB
- Display in a paginated table or card list
- Create modal for new rep creation
- Use Supabase API to create user account + profile entry

### Step 4: Outlets UI + Logic
- Fetch outlets from local DB
- Create form for adding/editing outlets
- Implement search/filter

### Step 5: Products UI + Logic
- Fetch and display products
- Form to create and assign product to outlet
- Product filter by outlet

### Step 6: Sync UI
- Add sync status display
- Show last sync time for each table
- Add “Sync All” button calling `SyncService.syncAll()`

---

## 🧪 What to Test

- [x] Admin can log in and access dashboard
- [x] Dashboard loads local data
- [x] Reps and outlets list correctly
- [x] Admin can add/edit reps and outlets
- [x] Sync pulls latest data from cloud
- [x] All UI responsive and stable

---

## 🚀 Next Step

Proceed to **Phase 4: Advanced Reporting + Analytics** after this phase is fully tested.