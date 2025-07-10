# 🧾 Sales Management Module — Admin App

## 📌 Objective

Enable the Admin to **view, analyze, and filter** sales records submitted from various outlets by sales reps. All data is fetched from the **Supabase Cloud Database**, cached to **SQLite for offline access**, and presented in a clean, user-friendly UI.

---

## 🏗️ Functional Scope

- View-only access to all sales data
- Offline-first architecture (data stored locally)
- Pull from `sales` and `sale_items` tables in Supabase
- Filtering capabilities:
  - 🔹 By Outlet
  - 🔹 By Sales Representative
  - 🔹 By Product
  - 🔹 By Time Range (Today, Yesterday, Last 7 Days, This Month, Last Month, Custom Range)
- Detailed breakdown for each sale including:
  - Product(s) Sold
  - Quantity
  - Unit Price
  - VAT
  - Total Amount
  - Customer Info
  - Sync Status

---

## 🧩 Tables Required (from Supabase & SQLite)

1. **sales**
2. **sale_items**
3. **customers**
4. **profiles (sales reps)**
5. **outlets**
6. **products**

Ensure local SQLite mirrors Supabase schema for smooth mapping.

---

## 🪜 Step-by-Step Development Guide

### ✅ Step 1: Extend Local Database

Add these tables to SQLite if not already present:

- `sales`
- `sale_items`
- `customers`

Ensure the schema supports offline sync.

---

### ✅ Step 2: Sync Sales Data

- Fetch `sales` and `sale_items` from Supabase
- Join with `profiles`, `products`, and `outlets`
- Store data locally

Use background sync service:
```dart
await supabaseClient
  .from('sales')
  .select('*, sale_items(*), customers(*), profiles(*), outlets(*)');
```

---

## 📦 Supabase Table Schemas Required

```sql
-- SALES RECORDS
create table sales (
  id uuid primary key default gen_random_uuid(),
  outlet_id uuid references outlets(id) on delete cascade,
  rep_id uuid references profiles(id) on delete set null,
  customer_id uuid references customers(id) on delete set null,
  vat numeric default 0.0,
  total_amount numeric not null,
  created_at timestamp default now()
);

-- SALE ITEM DETAILS
create table sale_items (
  id uuid primary key default gen_random_uuid(),
  sale_id uuid references sales(id) on delete cascade,
  product_id uuid references products(id) on delete restrict,
  quantity numeric not null,
  unit_price numeric not null,
  total numeric generated always as (quantity * unit_price) stored,
  created_at timestamp default now()
);

-- CUSTOMERS
create table customers (
  id uuid primary key default gen_random_uuid(),
  full_name text,
  phone text,
  created_at timestamp default now()
);

---

### ✅ Step 3: Sales Screen UI

- Create `SalesOverviewScreen` under `screens/sales/`
- UI Components:
  - Metrics cards: Total Sales, Total Revenue, Total Items Sold
  - Filter bar: Dropdowns and Date Picker
  - Sync status: Last Sync Time, Total Synced, Pending Sync
  - Scrollable List/Table for Sale Records

---

### ✅ Step 4: Filtering Logic

Implement filter options:

- 🏷️ Product dropdown: populated from `products` table
- 🧍 Sales Rep dropdown: populated from `profiles`
- 🏬 Outlet dropdown: from `outlets`
- 📅 Date filter: Today, Yesterday, Last 7 Days, This Month, Last Month, Custom Range

Apply filter combinations using local queries from SQLite.

---

### ✅ Step 5: Sale Detail Popup

- When user taps a sale record, show a popup modal:
  - Sale ID / Timestamp
  - Customer name / phone
  - List of products (Qty, Price, Subtotal)
  - VAT / Total / Payment method
  - Option to print receipt (if applicable)

---

### ✅ Step 6: Sync Status Bar

Show top-right section with:

- ✅ Total records fetched
- 🔁 Last sync time
- ⚠️ Number of pending unsynced records (if any)
- 🔄 Manual Sync button

---

## 📤 Deliverables

- [ ] SQLite tables updated and initialized
- [ ] Sales sync logic implemented from Supabase to local DB
- [ ] Modern UI design for sales dashboard
- [ ] Working filters and date pickers
- [ ] Detailed view popup per sale
- [ ] Manual sync control panel

---

## 🎨 UI Tips

- Use `DataTable` or horizontal `ListView.builder` for sales record list
- Sticky headers for filter bar
- Show sync status with colored chip (e.g., green for synced, red for pending)

---

## 🧪 Test Cases

- [ ] Can filter sales by outlet and see correct results
- [ ] Can view sale item breakdown
- [ ] Sales data available offline
- [ ] Sales metrics accurately calculated
- [ ] Sync logic works as expected

---

## 🧠 Additional Ideas

- Export sales report as CSV/PDF
- View sales trends via charts
- Group sales by product/customer

---

