
# Stock Intake Development Guide

This document provides a detailed development instruction for implementing the **Stock Intake** functionality in the Admin App, including table schemas, logic handling, and UI expectations.

---

## 📁 Overview

The Stock Intake module enables the admin to log incoming stock from distributors, manage available balances, and control stock distribution to outlets.

## ✅ Features

- Record new stock received from distributors
- View all intake history
- Calculate intake balance per product
- Prevent distribution beyond available balance
- Sync intake and intake balances with Supabase
- Filter stock intake records by date, product, outlet

---
The architecture follows an **offline-first** approach:
- Admin can create and manage stock intake records offline.
- Balances are calculated and updated locally.
- On sync, stock intake records and balances are pushed to Supabase for backup and analysis.

---

## 🧱 Database Schema

### 1. `stock_intake` (Cloud + Local)

```sql
create table stock_intake (
  id uuid primary key default gen_random_uuid(),
  product_name text not null,
  quantity_received numeric not null,
  unit text not null,
  cost_per_unit numeric not null,
  total_cost numeric generated always as (quantity_received * cost_per_unit) stored,
  description text,
  date_received timestamp default now(),
  created_at timestamp default now()
);
```

### 2. `intake_balances` (Local only, synced to cloud later)

```sql
create table intake_balances (
  id uuid primary key default gen_random_uuid(),
  product_name text not null,
  total_received numeric not null,
  total_assigned numeric default 0,
  balance_quantity numeric generated always as (total_received - total_assigned) stored,
  last_updated timestamp default current_timestamp
);

```
### 🔁 Workflow Logic (Local)

Step-by-step Flow
1. Admin adds stock intake record

- Enters: product name, quantity received, cost per unit, description.
- System calculates total_cost.

2. Local update to intake_balances

- If the product exists:
    - total_received += new quantity
    - balance_quantity = total_received - total_assigned
- If product does not exist:
    - Insert new record into intake_balances
3. Assign product to outlet
- On the Product Assignment Page, Admin selects product to assign.
    - Dropdown list only includes products with balance > 0 in intake_balances
    - Admin assigns quantity
    - System updates total_assigned
    - balance_quantity = total_received - total_assigned
4. Sync to Supabase (when online)
- Stock intake entries are pushed to Supabase stock_intake table.
- Intake balances are pushed to Supabase (optional).

### 💾 Offline-First Handling
- All actions are performed and stored locally via SQLite.
- stock_intake and intake_balances exist in local DB.
- SyncService detects online state and syncs unsynced records.

### ✅ Functional Requirements
UI Features (Stock Intake Page)
- 📋 List of stock intake records (tabular form)
- ➕ Add New Intake (form):
  - Product name
  - Quantity
  - Unit
  - Cost per unit
  - Description (optional)

- 📊 Metrics:
  - Total value of stocks received
  - Number of items received
- 📍 Balance section (optional pop-up or expandable card):
  - Shows total received, assigned, and balance

### UI Features (Product Assignment Page)
- Product dropdown fetches only products with available balance
- Assigning product updates intake_balances.total_assigned locally
- Prevents assigning more than the available balance

### ⚙️ Core Functions Needed
#### StockIntakeService
- `addIntake(StockIntake intake)`
- `getAllIntakes()`
- `syncIntakesToCloud()`

#### IntakeBalanceService
- `updateBalanceOnNewIntake(String productName, int qty)`
- `updateBalanceOnProductAssignment(String productName, int qty)`
- `getAvailableProductsForAssignment()`

#### ProductAssignmentService
- `getAvailableProducts()` ← pulls from intake_balances
- `assignProductToOutlet(...)`

### ⚙️ Sync Logic
#### Local ➡️ Cloud
- `stock_intake` is pushed to Supabase table
- `intake_balances` can also be synced to a backup table (optional)

#### Sync Occurs
- Manually via Sync button
- Automatically when connectivity is detected


### 🧪 Testing Points
- Intake form correctly stores data in local stock_intake table
- intake_balances updates with each new intake or assignment
- Product assignment page filters products by availability
- Sync logic only pushes unsynced records
- Prevents over-assignment beyond intake balance
- Handles offline-first gracefully

### 🧠 Notes
- This logic allows for a strict and auditable inventory control flow.
- Prevents outlets from receiving products that don't exist in stock.
- Balances are calculated locally to reduce Supabase write costs and allow fast response.

---