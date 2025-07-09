# 🧾 HADRANIEL FROZEN FOODS ADMIN FLUTTER DESKTOP APP — PROJECT OVERVIEW

## 📌 Project Goal

Develop an **offline-first desktop admin application** using **Flutter + Supabase + SQLite** for managing multiple sales outlets, stock records, sales reports, users, and customers.

---

## 🏗️ System Architecture

### 🧱 Offline-First Concept

- Admin can **work offline** with local SQLite database.
- Data syncs with Supabase **when online**.
- Intelligent syncing with:
  - Bi-directional sync (cloud ➝ local, local ➝ cloud)
  - Conflict resolution and status tracking

### 🧮 Local Database (SQLite)

Tables:
- `users`
- `outlets`
- `products`
- `sales`
- `sale_items`
- `stock_balances`
- `customers`
- `sync_logs`

---

## 🔐 Authentication & Roles

- Admin logs in via Supabase (email/password).
- Session cached for offline re-login.
- Admin-only privileges:
  - Create outlets
  - Create reps and assign outlets
  - Create customers
  - Manage stock and push to outlet
  - View and analyze sales

---

## 📦 Features

### ✅ 1. Authentication System
- Login with Supabase
- Offline login after first success (local user cache)
- Secure credential/session handling using `shared_preferences` or `flutter_secure_storage`

---

### ✅ 2. Outlet Management
- Create, update, delete outlets
- View all outlets in a table
- Assign reps and customers to outlets

---

### ✅ 3. Sales Rep Management
- Create new sales rep with:
  - Name
  - Email
  - Password
  - Assigned outlet
- Reps are created in Supabase Auth and `profiles` table

---

### ✅ 4. Product Management
- Create new product and assign to specific outlet
- Fields: `product_name`, `quantity`, `unit`, `cost_per_unit`, `description`
- Products saved to Supabase and pulled to outlet app on sync

---

### ✅ 5. Stock Balance Management
- Pull latest stock balances from Supabase
- Fields: `given_quantity`, `quantity_sold`, `balance_quantity`, `total_given_value`, `total_sold_value`, `balance_value`
- View metrics: current inventory value, stock left

---

### ✅ 6. Customer Management
- Admin or rep can create customer profile
- Fields: `full_name`, `phone`, `outstanding_amount`
- Tracks:
  - Total purchases
  - Total paid
  - Total outstanding

---

### ✅ 7. Sales Analysis
- Pull sales from all outlets
- Filter by:
  - Date range
  - Outlet
  - Rep
  - Product
- Metrics:
  - Total sales
  - Total revenue
  - VAT collected
  - Outstanding payments

---

### ✅ 8. Sync Engine
- Manual and auto sync option
- Tables:
  - Pull from Supabase: `outlets`, `products`, `profiles`, `sales`, `stock_balances`, `customers`
  - Push to Supabase: `sales`, `customers`, `stock_balances`

- Sync Status:
  - Show pending syncs
  - Show last sync time
  - Log failed syncs

---

## 📁 Folder & File Structure

lib/
├── main.dart
├── core/
│ ├── database/
│ │ └── database_helper.dart
│ ├── services/
│ │ ├── supabase_service.dart
│ │ ├── sync_service.dart
│ │ └── auth_service.dart
│ ├── models/
│ │ └── *.dart (for each table)
│ └── utils/
│ └── formatters.dart
├── screens/
│ ├── auth/
│ ├── dashboard/
│ ├── outlets/
│ ├── reps/
│ ├── customers/
│ ├── sales/
│ ├── stock/
│ └── products/
├── widgets/
│ ├── data_table_widget.dart
│ ├── custom_button.dart
│ └── metrics_card.dart
├── env/
│ └── .env


---

## 🎨 UI Guidelines

### 📊 Dashboard

- Metrics: Sales, Stock value, VAT, Revenue
- Quick access to:
  - Sync now
  - Sales report
  - Low stock alert
  - Outstanding customers

### 🧾 Sales Page

- Sticky header with filters
- Tabular view of each sale:
  - Date, Customer, Products, Qty, VAT, Total, Rep
- Sync status per row
- Export to PDF/CSV
- Detailed view on click with receipt

### 📦 Stock Page

- Table layout: product, qty, cost, value, balance
- Low stock list
- Balance summary card (qty/value)

### 🧍 Customers Page

- Table with outstanding tracking
- View customer history
- Add/edit customers

---

## 🔄 Sync Strategy

- On app start: Pull all data from Supabase
- Sync logs table stores last sync state
- Button to manually trigger sync
- Offline actions are stored with `is_synced = false`
- Only sync when online and authenticated

---

## 📅 Development Phases Summary

1. **Phase 1** - Flutter Setup, Supabase integration, folder structure, login screen
2. **Phase 2** - Local database schema and sync engine
3. **Phase 3** - UI + logic for Sales, Products, Stock, Customers
4. **Phase 4** - Reporting and analytics dashboard
5. **Phase 5** - Testing, performance optimization, build & deployment

---

## 🧪 Testing Strategy

- Unit test: Services and models
- Integration test: Sync engine
- Widget tests: Key UI components
- Manual tests for edge cases (offline, sync conflict, invalid data)

---

## 🧯 Security

- Local login validation
- Session expiry detection
- Access control (admin-only actions)
- Secure sync with Supabase keys and roles

---

## ✅ Conclusion

This project provides a **robust, modular, offline-first desktop app** for retail management by the admin. It's optimized for syncing sales and inventory data across outlets and managing all aspects of the retail chain.

