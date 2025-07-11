# 🧾 Stock Management Page – Development Guide (Admin App)

This guide outlines the development steps for implementing the **Stock Management Page** in the **Admin Flutter Desktop App**. The goal is to allow the admin to **view and analyze stock balances** across all outlets with filtering and synchronization from the Supabase backend.

---

## ✅ Objective

Build a **read-only stock management interface** for the admin. This interface will fetch `stock_balances` data that have been pushed from sales rep devices and stored in Supabase, then display it with proper filtering and summary analysis.

---

## 📦 Data Source

## ✅ Functional Requirements

### 1. Data Sources

- **Cloud DB Table:** `stock_balances`  
  The admin app will fetch data from the following Supabase table:
  ```sql
  create table stock_balances (
    id uuid primary key default gen_random_uuid(),
    outlet_id uuid not null references outlets(id) on delete cascade,
    product_id uuid not null references products(id) on delete cascade,
    given_quantity numeric not null,
    sold_quantity numeric default 0,
    balance_quantity numeric not null,
    last_updated timestamp default now(),
    created_at timestamp default now(),
    unique(outlet_id, product_id)
  );
  
```

### Related Tables

- **Supporting Tables Needed for Local DB**
- products (to get cost per unit)
- outlets (to map outlet names)
- local_stock_balances (downloaded from Supabase)
---
- **2. Features**
##🧮 Computed Fields (Locally)
Since the Supabase schema does not store monetary values, compute these in the app:

- total_given_value = given_quantity * product.cost_per_unit
- total_sold_value = sold_quantity * product.cost_per_unit
- balance_value = balance_quantity * product.cost_per_unit

These values should be calculated locally after fetching the records.

---

## 🖥️ UI Design Expectations

- **Title:** "Stock Management"
- **Sticky Header with Filters**
  - Date Picker (Today, Yesterday, Last 7 Days, This Month, Last Month, Custom Range)
  - Filter by Outlet
  - Filter by Product
- **Summary Cards:**
  - 🏬 Total Stock Value
  - 🧮 Total Stock Quantity
  - 🛒 Total Sold Quantity
  - 💰 Balance Value
- **Table Display:**
  | Product Name | Outlet | Given Qty | Sold Qty | Balance |
  |--------------|------|--------|-----------|----------|

- **List Card Display**
- The list card will display the following information:
  - Product Name
  - Outlet
  - Given Qty
  - Sold Qty
  - Balance
  - Cost Price
- Upon clicking on the list card, a detailed view will open.
- The detailed view will display the following information:
  - Product Name
  - Outlet
  - Given Qty
  - Sold Qty
  - Balance
  - Cost Price
  - Total Value
  - Sold Value
  - Balance Value
- The detailed view will also have a section to display the sale history of the particular product.
- The sale history section will display the following information:
  - Outlet
  - Quantity Sold
  - Total Value
  - Sold At
  - Customer name (if available)

---

## 🔁 Synchronization Logic

🔄 Sync Logic
1. Local Table Structure (SQLite)
___
### 1. stock_balances
CREATE TABLE IF NOT EXISTS stock_balances (
  id TEXT PRIMARY KEY,
  outlet_id TEXT NOT NULL,
  product_id TEXT NOT NULL,
  given_quantity REAL NOT NULL,
  sold_quantity REAL DEFAULT 0,
  balance_quantity REAL NOT NULL,
  last_updated TEXT,
  created_at TEXT,
  synced INTEGER DEFAULT 1
);

2. Sync Instructions
#$On first login (with internet), fetch:

- stock_balances from Supabase
- products (cost per unit)
- outlets (name, ID)

#$Save locally using a syncStockBalances() function

#$Display last_synced_at on the UI

#$Option to “Sync Now” manually🔄 Sync Logic
- Fetch stock_balances from Supabase
- Compare with local data
- Update or insert new records
- Update `last_synced_at` timestamp

---

## 🛠️ Development Steps

### Step 1: Model Definitions
- Create Dart models for:
  - `StockBalance`
  - `Product`
  - `Outlet`
- Include `fromJson` and `toMap` methods.

### Step 2: Database Helper Methods
- `insertStockBalance()`
- `getStockBalances({filters})`
- `getTotalStats()`

### Step 3: Sync Service
- Fetch data from Supabase
- Check last sync timestamp
- Save new data locally

### Step 4: UI Page
- Create `StockPage` widget
- Implement filter section
- Display metrics
- Display stock balances in table

### Step 5: Filter Logic
- Filter stock balances by:
  - Date range (use `created_at`)
  - Outlet
  - Product

---

## 🧪 Testing Instructions

1. ✅ Verify local sync from Supabase.
2. ✅ Check that all stock entries load for admin view.
3. ✅ Confirm filter logic returns correct rows.
4. ✅ Validate total calculations (given, sold, balance).
5. ✅ Ensure no editing or modification is possible.

---

## 📌 Notes

- This is a **read-only** page; admin cannot edit stock records.
- Ensure date formatting aligns with selected filter range.
- Optimize table rendering for large datasets.

